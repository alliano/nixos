{ ... }:
{
  programs.home-manager.enable = true;

  home.enableNixpkgsReleaseCheck = false;

  # restart user services whose unit definition changed during activation,
  # instead of only printing a suggestion to do it manually
  systemd.user.startServices = "sd-switch";
  imports = import ../importer.nix { dir = builtins.toPath ./src; };
}
