{
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = (import ../../../importer.nix { dir = builtins.toPath ./.; });

  environment.systemPackages = with pkgs; [
    iwd
    # openvpn
    wirelesstools
    # bluetuith
    # impala
    inputs.iwmenu.packages.${pkgs.system}.default
  ];

  networking.hostName = "developer";
  networking.useNetworkd = false;
  # false, so no dhcpcd unit is generated at all: iwd already does DHCP via
  # EnableNetworkConfiguration below. With true, dhcpcd runs unrestricted and
  # fights iwd over wlan0's lease/routes, and probes the docker bridges too.
  networking.useDHCP = false;

  # Force disable power saving at the kernel driver level (change iwlwifi if using AMD/Realtek)
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
  '';
  networking.wireless.iwd = {
    package = pkgs.iwd;
    enable = true;
    settings = {
      Network = rec {
        EnableIPv6 = false;
        EnableDHCPv6 = EnableIPv6;
        RoutePriorityOffset = 300;
        NameResolvingService = "systemd";
      };
      General = {
        UseDefaultInterface = false;
        IgnorePeerSignalStrength = false;
        EnableNetworkConfiguration = true;
        DisablePowerSave = true;
        AutoConnect = true;
        Country = "ID";
        AddressRandomization = true;
        AutoconnectNetworkInterval = 5;
      };
      Blacklist = {
        InitialTimeout = 0;
      };
      Rank = {
        BandModifier5GHz = 1.5;
        BandModifier2_4GHz = 1.0;
      };
    };
  };
  services.resolved.enable = true;

  services.haveged.enable = false;
  # systemd.services.haveged.unitConfig.ConditionKernelVersion = lib.mkIf (config.services.haveged.enable) (lib.mkForce ">5.6");

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id.startsWith("net.connman.iwd") && subject.isInGroup("${config.users.users.i.group}")) {
        return polkit.Result.YES;
      }
    })
  '';

  # wpa_supplicant, i use iwd so i don't need this
  networking.wireless.enable = false;
  networking.networkmanager.enable = false;

  networking.firewall = {
    enable = false;
    allowedTCPPorts = [ ];
    allowedTCPPortRanges = [ ];
    allowedUDPPorts = [ ];
    allowedUDPPortRanges = [
      # Chromecast client-to-control communication
      {
        from = 32768;
        to = 61000;
      }
    ];
  };
}
