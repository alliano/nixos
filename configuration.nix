# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{ pkgs, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./src/default.nix
  ];
  services.fprintd.enable = true;
  services.fprintd.tod.enable = true;
  services.fprintd.tod.driver = pkgs.lib.mkForce pkgs.libfprint-2-tod1-goodix;
  programs.nix-ld.enable = true;
  # Runtime libs for unpatched downloaded binaries (e.g. `npx playwright
  # install`'s Chrome for Testing build) that expect an FHS-style lib layout.
  programs.nix-ld.libraries = with pkgs; [
    glib
    nss
    nspr
    dbus
    atk
    at-spi2-atk
    at-spi2-core
    cups
    expat
    libxkbcommon
    pango
    cairo
    gtk3
    gdk-pixbuf
    alsa-lib
    mesa
    libdrm
    udev
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    xorg.libxshmfence
    xorg.libXcursor
    xorg.libXi
    xorg.libXtst
    xorg.libXScrnSaver
  ];

  # Add Node.js, TypeScript, and npm
  environment.systemPackages = with pkgs; [
    nodejs
    nodePackages.typescript
    nodePackages.npm
  ];
}
