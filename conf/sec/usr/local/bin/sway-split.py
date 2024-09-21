import atexit
import i3ipc
import logging
import gdb
import os
import pwndbg
import signal
import subprocess

from time import sleep
from pwndbg.commands.context import contextoutput


NEW_TERM_ID = None

logging.basicConfig(
    level = logging.DEBUG,
    format = "%(asctime)s - %(levelname)s - %(message)s",
    handlers = [logging.StreamHandler()]
)
log = logging.getLogger(__name__)


class Workspace():
    def __init__(self, id):
        self.id = id
        self.leaves = {}
        self._create()

    def open_term(self, name, cmd=None):
        term = Terminal.create(cmd)
        self.leaves[name] = term
        return term

    def add_term(self, term, name):
        self.leaves[name] = term

    def _create(self):
        i3 = i3ipc.Connection()
        i3.command(f"workspace {self.id}")


class Terminal:
    def __init__(self, id) -> None:
        self.id = id
        self.tty = None
        self.is_tmux = False
        self.tmux_pid = 0
        self.con = self._get_con()

    def set_tty(self):
        self.tty = self._get_tty()

    def focus(self):
        self.con.command('focus')

    def size(self, w=None, h=None):
        """
        Set the size of the terminal window to be a percentage of the total
        screen size. Should be an int between 0 and 100.
        Args:
        w (int): Pct of the width of the screen the terminal window takes up, between 0 and 100.
        h (int): Pct of the height of the screen the terminal window takes up, between 0 and 100.
        """
        if w is None and h is None:
            log.debug("No width or height selected")
        elif w is None:
            self.con.command(f"resize set height {h} ppt")
        elif h is None:
            self.con.command(f"resize set width {w} ppt")
        else:
            self.con.command(f"resize set width {w} ppt height {h} ppt")

    def split_horizontal(self):
        self.con.command("split horizontal")

    def split_vertical(self):
        self.con.command("split vertical")

    def move(self, workspace):
        i3 = i3ipc.Connection()
        i3.command(f"[con_id={self.id}] move to workspace {workspace}")

    def swap(self, window_id):
        i3 = i3ipc.Connection()
        i3.command(f"[con_id={self.id}] swap container with con_id {window_id}")

    def set_lines(self, context):
        """ Sets the number of lines to display based on the width
        Args:
        context (str): The pwndbg context argument used to set lines
        """
        con = self._get_con()
        log.debug(f"{self.id} {context} Height: {con.rect.height}")
        lines = int(con.rect.height / 25)
        log.debug(f"Lines: {lines}")
        gdb.execute(f"set context-{context}-lines {lines}")


    def close(self):
        log.debug(f"Closing window {self.id}")

        if self.is_tmux and self.tmux_pid != 0:
            log.debug(f"Closing tmux session {self.tmux_pid}")
            os.kill(self.tmux_pid, signal.SIGHUP)

        i3 = i3ipc.Connection()
        tree = i3.get_tree()
        con = tree.find_by_id(self.id)
        os.kill(con.pid, signal.SIGHUP)

    def _get_con(self):
        i3 = i3ipc.Connection()
        tree = i3.get_tree()
        con = tree.find_by_id(self.id)
        if con is None:
            raise Exception(f"Cannot find terminal with id {self.id} in tree")

        return con

    @staticmethod
    def create(cmd=None):
        """ Create a new terminal window with a set TTY and Sway ID"""

        i3 = i3ipc.Connection()

        # Subscribe to the "window::new" event
        def on_window_new(i3, e):
            log.debug(f"New window event: {e.container.app_id}")
            if e.container.app_id in ['kitty', 'ipython']:
                # {NEW_TERM_ID} is used globally to capture the container ID
                global NEW_TERM_ID
                log.debug(f"Found: {e.container.app_id} with id {e.container.id}")
                NEW_TERM_ID = e.container.id
                i3.main_quit()  # Stop listening for events after finding the new terminal

        log.debug("Setting window event")
        i3.on("window::new", on_window_new)

        # Open the terminal (replace with your actual terminal command)
        log.debug("Creating terminal window")
        if cmd is not None:
            command = f'exec kitty sh -c "zsh -ic {cmd}"'
            log.debug(f"Running kitty with command '{command}'")
            i3.command(command)
        else:
            i3.command('exec kitty')

        # Start the event loop to listen for the "window::new" event
        log.debug("Running main")
        i3.main()
        log.debug(f"Found new terminal id: {NEW_TERM_ID}")

        return Terminal(NEW_TERM_ID)

    def _get_tty(self):
        """ Find the TTY number of the newly created terminal window.
        Due to the way kitty / z4h works, kitty opens a new ZSH window, within
        which Z4H creates a new tmux session. Within this tmus session is the
        TTY that we wish to capture and send output to
        """

        i3 = i3ipc.Connection()
        tree = i3.get_tree()
        con = tree.find_by_id(self.id)
        if not con:
            raise Exception(f"Cannot find sway window with id {id}")

        tries = 0
        tty = None
        while tty is None and tries < 10:
            try:
                tty = self._get_tty_from_ps(con)
            except subprocess.CalledProcessError:
                sleep(0.25)
                tries += 1

        if tty is None:
            msg = f"Can't find tty of ID {self.id}"
            log.error(msg)
            raise Exception(msg)

        return tty

    def _get_tty_from_ps(self, con):

        # Get the initial kitty PID
        parent_pid = con.pid
        log.debug(f"Con Name: {con.name}")
        log.debug(f"Parent PID: {parent_pid}")

        # The first ZSH child process PID, within which Z4H creates a tmux session
        child_pid = subprocess.check_output(['ps', '-o', 'pid=', '--ppid', str(parent_pid)]).decode().strip()
        log.debug(f"Child PID: {child_pid}")

        # If we're not using Z4H, return the child TTY
        if con.name == 'sh' or 'IPython' in con.name:
            log.debug(f"Checking TTY for {child_pid}")
            tty = subprocess.check_output(['ps', '-o', 'tty=', '--ppid', str(parent_pid)]).decode().strip()
            log.debug(f"Found {tty}")
            return f"/dev/{tty}"

        # There are 2 tmux processes, a child to ZSH, and a "standalone" one which we want
        tmux_pids = subprocess.check_output(["pgrep", "-f", f"tmux.*{child_pid}"]).decode().split()
        tty = None

        # Loop through both PID's, only the 2nd one has a TTY number
        for tmux_pid in tmux_pids:
            log.debug(f"Checking tmux PID {tmux_pid}")
            try:
                val = subprocess.check_output(['ps', '-o', 'tty=,pid=', '--ppid', str(tmux_pid)]).decode().strip().split()
                tty = val[0]
                self.tmux_pid = int(val[1])
                self.is_tty = True
                log.debug(f"PID {self.tmux_pid} is the parent process for this shell")
            except subprocess.CalledProcessError:
                continue

        if not tty:
            log.error(f"Cannot find tty for window with parent ID {parent_pid}")
            raise Exception(f"Cannot find tty for window with parent PID {parent_pid}")

        log.debug(f"kitty is on terminal /dev/{tty}")
        self.is_tmux = True
        self.parent_pid = parent_pid
        return f"/dev/{tty}"


def get_current_term():
    i3 = i3ipc.Connection()
    tree = i3.get_tree()
    con = tree.find_focused()
    return Terminal(con.id)


def setup_sway():
    main = get_current_term()
    main.move(3)
    main.focus()

    workspace = Workspace(3)
    workspace.add_term(main, 'main')

    main.split_horizontal()
    bt = workspace.open_term('backtrace', "tty; tail -f /dev/null")
    bt.size(w=20)
    main.focus()

    main.split_vertical()
    code = workspace.open_term('code', "tty; tail -f /dev/null")
    code.swap(main.id)
    main.size(h=20)
    code.focus()
    code.split_vertical()

    code.focus()
    code.split_horizontal()
    regs = workspace.open_term('regs', "tty; tail -f /dev/null")

    code.focus()
    code.split_vertical()
    disasm = workspace.open_term('disasm', "tty; tail -f /dev/null")
    disasm.size(h=60)

    regs.focus()
    regs.split_vertical()
    workspace.open_term('stack', "tty; tail -f /dev/null")
    workspace.open_term('io', "tty; tail -f /dev/null")

    bt.focus()
    bt.split_vertical()
    ipy = workspace.open_term('ipy', 'ipython')
    ipy.size(h=25)

    main.focus()

    for w in workspace.leaves:
        window = workspace.leaves[w]
        window.set_tty()

    return workspace

def close(workspace):
    terms = [workspace.leaves[w] for w in workspace.leaves if w != 'main']
    for t in terms:
        t.close()

    workspace.leaves['main'].close()


def setup_pwndbg(workspace):
    pwndbg.commands.context.config_context_ghidra = "if-no-source"
    contextoutput("code", workspace.leaves["code"].tty, True)
    contextoutput("ghidra", workspace.leaves["code"].tty, True)
    contextoutput("disasm", workspace.leaves["disasm"].tty, True)
    contextoutput("legend", workspace.leaves["regs"].tty, True)
    contextoutput("regs", workspace.leaves["regs"].tty, True)
    contextoutput("stack", workspace.leaves["stack"].tty, True)
    contextoutput("backtrace", workspace.leaves["backtrace"].tty, True)
    gdb.execute(f"tty {workspace.leaves['io'].tty}")
    workspace.leaves['code'].set_lines('source-code')
    workspace.leaves['disasm'].set_lines('code')
    workspace.leaves['stack'].set_lines('stack')
    workspace.leaves['backtrace'].set_lines('backtrace')

if __name__ == "__main__":
    # TODO:
    # - Integrate into init-pwndbg or gdbinit
    # - BinaryNinja integration
    workspace = setup_sway()
    setup_pwndbg(workspace)
    atexit.register(close, workspace)

