{ pkgs, ... }:
{
  services.printing = {
    enable = false;
    # drivers = [ pkgs.hplip ];
  };
  hardware.sane = {
    enable = true;
    # extraBackends = [ pkgs.hplipWithPlugin ];
  };
  programs.system-config-printer.enable = true;
  environment.systemPackages = [
    # pkgs.hplip
    # pkgs.gutenprint
  ];
}
