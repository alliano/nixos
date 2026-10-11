{ pkgs, inputs, ... }:
let
  # winboat does not exist in the pinned nixpkgs yet, take it from the newer pin
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};
in
{
  # run windows apps on linux, backed by docker + kvm + freerdp
  # docker itself is configured in ../docker, kvm-intel is loaded in hardware-configuration.nix
  environment.systemPackages = [
    unstable.winboat
  ];
}
