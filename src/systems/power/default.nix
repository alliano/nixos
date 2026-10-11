{
  lib,
  config,
  pkgs,
  ...
}:
{
  services.logind.powerKey = "suspend-then-hibernate";
  services.logind.powerKeyLongPress = "poweroff";
  powerManagement = {
    enable = true;

    # null on purpose: power-profiles-daemon owns the governor and the energy
    # performance preference now, and a non-null value here would make the
    # cpufreq oneshot set a governor at boot that ppd then overrides.
    #
    # Note this CPU uses intel_pstate in active mode, which only exposes the
    # "performance" and "powersave" governors -- "ondemand"/"schedutil" belong
    # to acpi-cpufreq, so they were never actually applied on this machine.
    cpuFreqGovernor = null;

    resumeCommands = ''
      systemctl restart iwd;
      rfkill unblock wifi;
    '';
    powerDownCommands = ''
      rfkill block all;
    '';

    # SCSI link power management policy. The kernel default is "max_performance".
    # "med_power_with_dipm" is supported by kernel versions 4.15 and newer.
    # Values: null or one of "min_power", "max_performance", "medium_power", "med_power_with_dipm"
    scsiLinkPolicy = "max_performance";
  };
  # This i7-10610U is a 15W U-series part, so sustained loads (nixos-rebuild,
  # compiles) hit the package power limit long before anything else. Without
  # thermald the kernel's emergency throttle handles it with deep clock cuts;
  # thermald steers RAPL/P-states down gradually instead, which keeps sustained
  # throughput higher. Runs with --adaptive, i.e. the firmware's DPTF tables.
  services.thermald.enable = true;

  # Manual performance/battery switching: `powerprofilesctl set performance`
  # (also `balanced`, `power-saver`), or click the waybar module. polkit lets a
  # logged-in user switch without doas. On intel_pstate these map to:
  #   performance -> governor performance, EPP performance
  #   balanced    -> governor powersave,   EPP balance_performance
  #   power-saver -> governor powersave,   EPP power
  services.power-profiles-daemon.enable = true;

  # ppd starts in balanced and restores the last manual choice from
  # /var/lib/power-profiles-daemon/state.ini. Declare the boot profile here so
  # it lives in the config instead of in mutable state. Drop this unit if you'd
  # rather let whatever you picked last simply persist.
  systemd.services.power-profile-boot-default = {
    description = "Select the boot-time power profile";
    wants = [ "power-profiles-daemon.service" ];
    after = [ "power-profiles-daemon.service" ];
    wantedBy = [ "graphical.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
    };
  };

  services.tlp.enable = false;
  services.tlp.settings = lib.mkIf (config.services.tlp.enable) {
    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    PLATFORM_PROFILE_ON_BAT = "low-power";
    CPU_BOOST_ON_BAT = 0;
    CPU_HWP_DYN_BOOST_ON_BAT = 0;
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
  };
}
