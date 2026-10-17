{ pkgs, lib, ... }:

# Concat: an open-source CapCut replacement (Rust + wgpu), bundling its own
# ffmpeg and onnxruntime.
#
# Upstream ships AppImage/deb/rpm/pkg.tar.zst but no source tarball of the
# dependency set, and it is not in nixpkgs yet (as of October 2026), so unlike
# [wordcraft] in ../office this is wrapped with appimageTools instead of being
# built from source.
let
  isEnabled = true;

  version = "0.2.7";

  src = pkgs.fetchurl {
    url = "https://github.com/jub0t/Concat/releases/download/v${version}/Concat-${version}-x86_64.AppImage";
    # Matches the SHA256SUMS asset published alongside the release.
    hash = "sha256-P0pK/p5Cs61AJBqXjMqWqXEKw1RbakQiCjxlp5vF8W8=";
  };

  # Extracted a second time (cheap, no network) only to copy the desktop entry
  # and icon out; the AppImage carries no metainfo.
  contents = pkgs.appimageTools.extractType2 {
    pname = "concat";
    inherit version src;
  };

  concat = pkgs.appimageTools.wrapType2 {
    pname = "concat";
    inherit version src;

    # The FHS base from appimageTools already covers libstdc++, fontconfig,
    # freetype, wayland, libxkbcommon, vulkan-loader and alsa. Only the video
    # acceleration client libraries are missing: the bundled ffmpeg dlopen's
    # libva.so.2 (plus -drm/-x11) and libvpl.so for QSV. The matching drivers
    # (intel-media-driver, vpl-gpu-rt) come from the host through
    # /run/opengl-driver, see ../../systems/graphics/intel.
    extraPkgs =
      p: with p; [
        libva
        libvpl
      ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    extraInstallCommands = ''
      # The FHS /etc/profile appends the host's LD_LIBRARY_PATH to its own (see
      # build-fhsenv-chroot/env.nix). This session exports alsa, wayland and
      # pipewire-jack from the running system, which are linked against a newer
      # glibc than the one inside the env, so the AppImage dies on missing
      # GLIBC_ABI_* symbols. Drop the variable before entering the chroot; the
      # env provides those libraries itself.
      wrapProgram $out/bin/concat --unset LD_LIBRARY_PATH

      install -Dm644 ${contents}/concat.desktop -t $out/share/applications
      install -Dm644 ${contents}/usr/share/icons/hicolor/256x256/apps/concat.png \
        -t $out/share/icons/hicolor/256x256/apps
    '';

    meta = {
      description = "Open-source cross-platform CapCut replacement";
      homepage = "https://concat.standalones.org";
      changelog = "https://github.com/jub0t/Concat/releases/tag/v${version}";
      license = lib.licenses.agpl3Only;
      mainProgram = "concat";
      platforms = [ "x86_64-linux" ];
    };
  };
in
lib.mkIf (isEnabled) {
  environment.systemPackages = [ concat ];

  # The AI features (background cutout, upscaling, speech-to-text) are not in
  # the AppImage: on first use the app fetches the ONNX models from GitHub
  # releases and Hugging Face into $XDG_DATA_HOME, so they are downloaded at
  # runtime rather than pinned here.
}
