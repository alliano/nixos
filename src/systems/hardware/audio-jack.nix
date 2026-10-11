{ pkgs, ... }:
let
  card = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic";

  # The sof-hda-dsp UCM splits analog output into two mutually exclusive
  # profiles: one containing Headphones, one containing Speaker. The Headphones
  # profile has a higher priority (10300 vs 10200) and that priority does NOT
  # drop when the jack is unplugged, so WirePlumber always picks it and the
  # Speaker sink is never created. As a result, once an HDMI monitor is plugged
  # in, the only available output is HDMI -- and if that monitor has no
  # speakers, the machine goes completely silent.
  #
  # This service picks the profile explicitly from the real jack state, and
  # re-applies it whenever the PipeWire topology changes (monitor plug/unplug).
  audio-profile-sync = pkgs.writeShellApplication {
    name = "audio-profile-sync";
    runtimeInputs = with pkgs; [ evtest jq pipewire wireplumber coreutils gnugrep gawk ];
    text = ''
      CARD="${card}"

      # Headphone jack plus the HDMI jacks, so monitor plug/unplug is observable
      jack_event_devices() {
        awk '/^N: Name="sof-hda-dsp (Headphone|HDMI)/{f=1}
             f && /^H: Handlers=/{
               match($0, /event[0-9]+/)
               print substr($0, RSTART, RLENGTH); f=0
             }' /proc/bus/input/devices
      }

      headphone_event_device() {
        awk '/^N: Name="sof-hda-dsp Headphone"/{f=1}
             f && /^H: Handlers=/{
               match($0, /event[0-9]+/)
               print substr($0, RSTART, RLENGTH); exit
             }' /proc/bus/input/devices
      }

      # "evtest --query" exits 10 when the switch is active (jack plugged in)
      jack_inserted() {
        local ev rc=0
        ev="$(headphone_event_device)"
        [ -n "$ev" ] || return 1
        evtest --query "/dev/input/$ev" EV_SW SW_HEADPHONE_INSERT || rc=$?
        [ "$rc" -eq 10 ]
      }

      apply() {
        local want dev_id prof_idx
        if jack_inserted; then want="Headphones"; else want="Speaker"; fi

        read -r dev_id prof_idx < <(
          pw-dump | jq -r --arg card "$CARD" --arg want "$want" '
            .[] | select(.info.props["device.name"] == $card)
            | .id as $id
            | .info.params.EnumProfile[]
            | select(.name | test("HiFi"))
            | select(.name | test($want))
            | select(.available == "yes")
            | "\($id) \(.index)"' | head -1
        ) || true

        [ -n "''${dev_id:-}" ] || return 0
        wpctl set-profile "$dev_id" "$prof_idx" || true
      }

      # At boot this service can start before sof-hda-dsp has registered its
      # jack input devices. An empty device list would collapse the pipeline
      # below into an instant exit 0, which systemd reads as normal completion
      # and -- with Restart=on-failure -- never restarts.
      for _ in $(seq 60); do
        if [ -n "$(jack_event_devices)" ]; then break; fi
        sleep 1
      done

      if [ -z "$(jack_event_devices)" ]; then
        echo "no sof-hda-dsp jack input devices found" >&2
        exit 1
      fi

      apply

      # React to jack changes on both the headphone port and the HDMI ports.
      # The HDMI jacks matter because plugging a monitor makes WirePlumber
      # re-run its profile selection, which can undo our choice.
      #
      # Deliberately NOT using pw-mon here: it emits ~90 lines/s indefinitely,
      # which kept this loop hot and burned ~7% CPU continuously. The ALSA jack
      # devices are silent until something is actually plugged.
      {
        for ev in $(jack_event_devices); do
          evtest "/dev/input/$ev" 2>/dev/null &
        done
        wait
      } | while read -r _; do
        # debounce: swallow the burst from a single plug event
        while read -r -t 2 _; do :; done
        apply
        # WirePlumber may re-pick a profile shortly after a monitor appears,
        # so assert our choice once more after it has settled.
        sleep 3
        apply
      done
    '';
  };
in
{
  systemd.user.services.audio-profile-sync = {
    description = "Select the UCM audio profile that matches headphone jack state";
    wantedBy = [ "default.target" ];
    after = [ "pipewire.service" "wireplumber.service" ];
    bindsTo = [ "wireplumber.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${audio-profile-sync}/bin/audio-profile-sync";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
