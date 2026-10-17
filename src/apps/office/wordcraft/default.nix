{ pkgs, lib, inputs, ... }:

# WordCraft: an open-source word processor written in pure Rust (egui/wgpu, not
# Electron) that reads and writes .docx natively.
#
# Unlike [stockbit] and [ajaib], which are run as site-specific browsers, this
# is a real desktop application, so it is built from source instead of being
# wrapped in `brave --app=`. It is not in nixpkgs yet (as of October 2026) and
# upstream only ships AppImage/deb/rpm/flatpak; since Cargo.lock is committed,
# building from source is cheaper to maintain than wrapping the AppImage with
# appimageTools.
let
  isEnabled = false;

  # The crates need a toolchain >= 1.95 (rust-version in Cargo.toml, edition
  # 2024) while the main nixpkgs pin still carries rustc 1.84, so the package set
  # comes from a newer pin, as winboat does in ../../container/winboat.
  #
  # It uses its own input rather than the shared nixpkgs-unstable: building this
  # takes ~18 minutes and no binary cache serves it, so bumping nixpkgs-unstable
  # for an unrelated package must not change the rustc here. See flake.nix.
  unstable = inputs.nixpkgs-wordcraft.legacyPackages.${pkgs.system};

  appId = "ai.storyteller.wordcraft";

  wordcraft = unstable.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "wordcraft";
    version = "0.7.0";

    src = unstable.fetchFromGitHub {
      owner = "storytold";
      repo = "wordcraft";
      tag = "v${finalAttrs.version}";
      hash = "sha256-SfrnSydUVuh+3tJ69OINsc1thkubgVh8aEVBfZyXmsM=";
    };

    # Some dependencies come from git (craft-pdf, craft-print and the krilla
    # patch pointing at storytold/craft-libs), so this hash changes on every
    # version bump.
    cargoHash = "sha256-D/CRhDoUbKvz/ev8NKRm2aDEyOA4NL5mdnx+O+iXHRI=";

    # The workspace also holds apps/wordcraft-web (wasm) and xtask, neither of
    # which is used on the desktop, so only these two crates are built.
    cargoBuildFlags = [
      "-p"
      "wordcraft"
      "-p"
      "wordcraft-cli"
    ];

    # The tests use egui_kittest, which renders through the GPU; there is no
    # device inside the build sandbox. Upstream runs them via `cargo xtask ci`,
    # not as part of packaging.
    doCheck = false;

    nativeBuildInputs = [ unstable.makeWrapper ];

    postInstall = ''
      install -Dm644 packaging/linux/${appId}.desktop -t $out/share/applications
      install -Dm644 packaging/linux/${appId}.mime.xml $out/share/mime/packages/${appId}.xml

      # metainfo.xml.in is normally rendered by packaging/linux/package.sh; the
      # date is pinned here to keep the build reproducible.
      mkdir -p $out/share/metainfo
      substitute packaging/linux/${appId}.metainfo.xml.in \
        $out/share/metainfo/${appId}.metainfo.xml \
        --replace-fail "@VERSION@" "${finalAttrs.version}" \
        --replace-fail "@DATE@" "1970-01-01"

      mkdir -p $out/share/icons
      cp -R assets/app-icon/hicolor $out/share/icons/

      # The binaries link only glibc and libgcc_s; windowing (Wayland, X11,
      # xkbcommon) and the GPU (Vulkan, EGL/GL) are dlopen'd at runtime, so they
      # belong on LD_LIBRARY_PATH rather than in buildInputs. This list mirrors
      # the depends/recommends in packaging/linux/nfpm.yaml.
      wrapProgram $out/bin/wordcraft \
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath (
            with unstable;
            [
              libxkbcommon
              wayland
              vulkan-loader
              libGL
              libx11
              libxcb
              libxcursor
              libxi
              libxrandr
            ]
          )
        }
    '';

    meta = {
      description = "Open-source native word processor written in pure Rust";
      homepage = "https://getartcraft.com/apps/wordcraft";
      changelog = "https://github.com/storytold/wordcraft/releases/tag/v${finalAttrs.version}";
      license = with lib.licenses; [
        mit
        asl20
      ];
      mainProgram = "wordcraft";
      platforms = lib.platforms.linux;
    };
  });
in
lib.mkIf (isEnabled) {
  environment.systemPackages = [ wordcraft ];
}
