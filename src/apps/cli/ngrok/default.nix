{ pkgs, ... }:
let
  # nixpkgs pin (9755fc62) ships ngrok 3.19.1, but ngrok's servers reject any
  # agent older than 3.20.0 on free accounts (ERR_NGROK_121). The package is
  # just a fetchurl'd static binary, so bump version + src instead of pulling in
  # a second nixpkgs input.
  #
  # To update: grab the new url/hash from
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ng/ngrok/versions.json
  ngrok = pkgs.ngrok.overrideAttrs (old: rec {
    version = "3.39.9";
    src = pkgs.fetchurl {
      url = "https://bin.ngrok.com/a/58nxNCjvFS5/ngrok-v3-${version}-linux-amd64";
      hash = "sha256-0mw/peLKVlzudwAekqGUDr7Lzwz54vitQxmkKaqhvz8=";
    };
  });
in
{
  environment.systemPackages = [
    ngrok
  ];
}
