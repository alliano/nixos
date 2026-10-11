{ pkgs, lib, ... }:
let
  isEnable = false;
  fetchedPinnedPkgs = builtins.fetchTarball rec {
    url = "https://github.com/NixOS/nixpkgs/archive/243895692ae2a2fbd08a05141462c0cc0d3ca10f.tar.gz";
    sha256 = "1x375yl26aw8gwdcm7jqpc5c87dz8hizhxkwzkfrjf60cqd0ibg0";
  };
  pinnedPkgs = import fetchedPinnedPkgs {
    inherit (pkgs) system config;
  };
in
lib.mkIf (isEnable) {
  home.packages = [ pinnedPkgs.opencode ];
  home.file.".config/opencode/opencode.json" = {
    enable = true;
    text = builtins.readFile ./config/opencode.json;
  };
}
