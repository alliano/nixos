{ pkgs, lib, ... }:
{
  imports = [ ./audio-jack.nix ];

  # enable hardware like wlan and etc
  hardware.enableRedistributableFirmware = true;
  hardware.alsa.enablePersistence = lib.mkForce true;
  hardware.uinput.enable = true;
  boot.kernelParams = [ "snd_hda_intel.power_save=0" ];
  services.pulseaudio.enable = lib.mkForce false;
  environment.systemPackages = with pkgs; [
    pulsemixer
    alsa-utils
    easyeffects
  ];
  services.pipewire.enable = true;
  services.pipewire.audio.enable = true;
  services.pipewire.wireplumber.enable = true;
  services.pipewire.alsa.enable = true;
  services.pipewire.alsa.support32Bit = true;
  services.pipewire.jack.enable = true;
  services.pipewire.pulse.enable = true;

  # HDMI monitors (e.g. AOC 27G2G4) advertise speakers in their EDID even when
  # they physically have none, so the HDMI sink reports itself as available and
  # audio silently lands there when extending the display. Demote its priority
  # so a laptop output always wins the default-sink election; HDMI stays
  # selectable manually.
  # Bluetooth can't stream A2DP and capture the headset mic at the same time,
  # so WirePlumber's default policy yanks the card to the HSP/HFP profile
  # (mono, 16kHz mSBC) the moment any app opens the Bluetooth source. A browser
  # tab silently holding the mic is enough to make music playback sound like a
  # phone call, or vanish entirely. Keep A2DP pinned; the earbud mic can still
  # be enabled by hand with `wpctl set-profile <id> headset-head-unit`.
  services.pipewire.wireplumber.extraConfig."52-bluetooth-no-autoswitch" = {
    "wireplumber.settings" = {
      "bluetooth.autoswitch-to-headset-profile" = false;
    };
  };

  services.pipewire.wireplumber.extraConfig."51-hdmi-low-priority" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "~alsa_output.*HDMI.*"; } ];
        actions.update-props = {
          "priority.driver" = 100;
          "priority.session" = 100;
        };
      }
    ];
  };
}
