#!/bin/sh

# My own binaries
export PATH="$HOME/bin:$PATH"

# Use gpg-agent as ssh-agent
export GPG_TTY="$(tty)"
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

export XSECURELOCK_FONT="-*-open sans-medium-r-*-*-30-*-*-*-*-*-*-uni"
export XSECURELOCK_SHOW_HOSTNAME=1
export XSECURELOCK_SHOW_USERNAME=1
export XSECURELOCK_WANT_FIRST_KEYPRESS=1

export PASSWORD_STORE_CHARACTER_SET='a-zA-Z0-9~!@#$%^&*()-_=+[]{};:,.<>?'
export PASSWORD_STORE_GENERATED_LENGTH=40

