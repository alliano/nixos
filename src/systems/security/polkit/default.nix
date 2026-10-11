{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    polkit
  ];

  security.polkit.enable = true;
  security.polkit.debug = true;
  security.polkit.adminIdentities = [ ];
  programs._1password-gui.polkitPolicyOwners = [
    "${config.users.users.i.name}"
  ];
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "net.reactivated.fprint.device.enroll" &&
          subject.isInGroup("developer")) {
        return polkit.Result.YES;
      }
    });
  '';
}
