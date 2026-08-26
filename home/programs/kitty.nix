{ pkgs, ... }:
{
  home.packages = [ pkgs.kitty ];

  xdg.configFile."kitty/kitty.conf".source = ../../conf/desktop/etc/xdg/kitty/kitty.conf;
  xdg.configFile."kitty/diff.conf".source = ../../conf/desktop/etc/xdg/kitty/diff.conf;
  xdg.configFile."kitty/vm.py".source = ../../conf/desktop/etc/xdg/kitty/vm.py;
}
