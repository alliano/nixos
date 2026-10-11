# AGENTS.md

Personal NixOS + home-manager configuration managed as a flake. There is no
application source code; every file is a Nix module. Read this before editing.

## Commands

The canonical entry points are the two Makefile targets (these are the only
commands wired up; the rest of the Makefile is commented-out legacy):

| Task | Command | What it runs |
|------|---------|--------------|
| Apply system config | `doas make flake-build-switch` (or `sudo`) | `nixos-rebuild switch --fast --log-format bar --flake .#developer` |
| Apply home-manager config | `make flake-home-switch` | `home-manager switch --flake .#i` |

`doas`/`sudo` is required for the system switch. If `make` fails with
"Current user is not owner of this repository", run
`doas git config --global --add safe.directory $(pwd)` (see README).

There is **no** build/test/lint target in the Makefile. To validate a change
without activating it, use standard Nix commands directly:

```sh
nix flake show .#                     # sanity-check that the flake evaluates
nixos-rebuild build --flake .#developer          # build system closure (no switch)
home-manager build --flake .#i                   # build home closure (no switch)
nixos-rebuild dry-activate --flake .#developer   # preview activate actions
```

`nixfmt-rfc-style` is the formatter (2-space indent) but there is no formatter
target — format manually if desired.

## Flake topology

`flake.nix` defines exactly two outputs:

- `nixosConfigurations.developer` — the system. Key `developer` is also the
  hostname (`networking.hostName = "developer"` in `src/systems/network/default.nix`).
- `homeConfigurations.i` — the home-manager profile. The key `i` matches the
  NixOS user attribute key `users.users.i` (see "Username gotcha" below).

Both outputs are built for `x86_64-linux` via `flake-utils.eachDefaultSystemPassThrough`.

`inputs` is threaded into modules: `specialArgs = { inherit inputs; }` for
NixOS and `extraSpecialArgs = { inherit inputs; }` for home-manager. Any module
can add `inputs` to its parameter set and pull packages from flake inputs, e.g.
`inputs.iwmenu.packages.${pkgs.system}.default`
(`src/systems/network/default.nix`) and
`inputs.scls.defaultPackage.${pkgs.system}`
(`home-manager/src/configs/helix/langs/scls/default.nix` — note this uses the
deprecated `defaultPackage` accessor while `iwmenu` uses `packages.${system}`).

Extra flake inputs: `home-manager`, `scls` (simple-completion-language-server),
`iwmenu` (iwd rofi menu), `flake-utils`. `nixpkgs` and `home-manager` are pinned
to specific commit hashes.

## The `importer.nix` auto-discovery mechanism (most important thing to understand)

The entire repo is organized around `importer.nix` at the repo root:

```nix
{ dir, ... }:
let
  defaultFileName = "default.nix";
  listDir = builtins.readDir dir;
  listDirAttrNames = builtins.attrNames (listDir);
  filteredDir = builtins.filter (f: f != defaultFileName) (listDirAttrNames);
  mappedDir = builtins.map (d: "${builtins.toPath "${dir}/${d}"}/${defaultFileName}") (filteredDir);
in mappedDir
```

Given a directory, it returns the list of `<sibling>/default.nix` paths for
**every entry except `default.nix` itself**. Category directories consume it
verbatim:

```nix
{ ... }: {
  imports = import ../../importer.nix { dir = builtins.toPath ./.; };
}
```

Consequences / constraints (these are landmines):

- **To add a module, create a new subdirectory containing `default.nix`.** It is
  picked up automatically; do not edit any registry or `imports` list.
- **Every sibling entry must be a directory that contains `default.nix`.** The
  importer does not distinguish files from directories — it only excludes the
  literal name `default.nix`. Dropping a stray file (README, `*.nix` that isn't
  `default.nix`) into a category dir produces `<name>/default.nix`, which breaks
  evaluation. Keep category dirs to subdirectories + their own `default.nix`.
- **An empty subdirectory breaks the build** because `<name>/default.nix` will
  not exist. `src/systems/fingierprint/` (also misspelled — note the extra `i`)
  is currently empty and has no `default.nix`; it is a latent evaluation error
  waiting for that branch to be exercised.
- The relative path to `importer.nix` changes with depth — count the `../`
  carefully when creating a new category dir. Examples in this repo use
  `../../importer.nix` (depth 2), `../../../importer.nix` (depth 3), and
  `../../../../importer.nix` (depth 4, from `home-manager/src/configs/helix/`).

## Directory layout

Two parallel trees, both driven by the importer:

```
configuration.nix ──► src/default.nix ──► importer
│                                        ├── src/apps/<category>/<tool>/default.nix
│                                        └── src/systems/<topic>/default.nix
hardware-configuration.nix (machine-generated; see below)

home-manager/home.nix ──► src/configs/default.nix ──► importer
                                                └── src/configs/<app>/default.nix
```

- `src/apps/` — applications grouped by category (`cli/`, `container/`, `ide/`,
  `shell/`, `window-manager/`, `web-browser/`, `package-manager/`, etc.). Each
  category dir has its own `default.nix` that re-runs the importer over its
  children. Leaves set `environment.systemPackages`, `programs.*`, `services.*`.
- `src/systems/` — OS-level concerns (`boot/`, `network/`, `security/`,
  `graphics/`, `users/`, `nixpkgs/`, `themes/`, etc.). Same importer pattern.
- `home-manager/src/configs/` — per-application user config (`helix/`, `hyprland/`,
  `git/`, `fish/`, `kitty/`, `vscode/`, `waybar/`, etc.). Leaves set
  `programs.*`, `home.packages`, `home.file.*`.

`configuration.nix` is the system entry point: it imports
`hardware-configuration.nix` and `src/default.nix`, and also carries a few
ad-hoc system settings (fprintd, `nix-ld`, nodejs). Prefer adding new system
concerns under `src/systems/` rather than bloating `configuration.nix`.

`hardware-configuration.nix` is **machine-generated by `nixos-generate-config`**
and is gitignored — it must not be hand-edited and will be overwritten. It is
specific to the current machine (btrfs subvols, Intel CPU, NVMe).

## Recurring module patterns

### Conditional enablement

Most leaf modules gate themselves on a local boolean rather than being removed:

```nix
{ lib, pkgs, ... }:
let isEnable = true; in
lib.mkIf isEnable { ... }          # or: if isEnable then { ... } else { }
```

Some use `let isEnabled = false; in if isEnabled then {...} else {...}` so the
"disabled" branch can still emit config (e.g. `src/systems/graphics/nvidia/`
blacklists nouveau when NVIDIA is disabled). When toggling a feature, flip the
local `isEnable`/`isEnabled` constant — do not delete the file.

### Centralized toggle boards

`home-manager/src/configs/helix/langs.nix` is a plain attribute set of booleans
(one per language) plus a `global.lsp` list. Each
`helix/langs/<lang>/default.nix` does:

```nix
let langs = import ../../langs.nix { }; in
lib.mkIf (langs.<lang>) { ... }
```

So `langs.nix` is the single switchboard for which language servers helix loads;
edit it to turn a language on/off without touching per-language files. Some
language toggles have dependencies noted inline (e.g. `env = true; # require
scls enable`, `sql = false; # require scls enable`).

### Shared `settings.nix` constants

Several configs (`hyprland/`, `helix/`) ship a sibling `settings.nix` that is a
plain attribute-set function (`{ config }: rec { ... }`) holding shared
constants (feature flags, wallpaper paths, directory names). It is imported
explicitly where needed:

```nix
let settings = import ./settings.nix { inherit config; }; in { ... }
```

`hyprland/settings.nix` holds `isEnableAutoStart`, `dirName`, wallpaper/locker
asset paths, etc. When editing hyprland modules, reuse `settings` instead of
hardcoding paths.

### Hyprland config concatenation

`home-manager/src/configs/hyprland/configs/default.nix` does something unusual:
it `builtins.readDir`s `./modules/`, concatenates the *contents* of every file
there into one big string (skipping `autostart.nix`), and feeds the result to
`wayland.windowManager.hyprland.extraConfig`. `autostart.nix` is imported
separately and appended. So Hyprland is configured via plain `.conf`/`.nix`
text fragments in `configs/modules/` (`binds.conf`, `window_rules.conf`,
`general.conf`, etc.), not via NixOS-style options. Add a new `.conf` fragment
to `modules/` and it is auto-included.

### Tarball pinning

`home-manager/src/configs/helix/default.nix` pins `helix` and `prettier` to a
specific nixpkgs revision by fetching a tarball with a pinned `sha256` and
re-importing nixpkgs from it. Follow this pattern (don't bump `pkgs.helix`
directly) when changing the pinned editor version, and recompute the `sha256`.

### Shell-alias scripts

`src/apps/cli/git/default.nix` generates wrapped CLI aliases
(`gst`, `gad`, `gps`, `gpl`, `gout`, `gbrd`, etc.) via
`pkgs.writeShellScriptBin` + `lib.mapAttrsToList`, then appends them to
`environment.systemPackages`. Some aliases reference each other through the
`rec` attrset (e.g. `gam = ''git add --all && ${gmit}''`).

## Username & identity gotcha (easy to misread)

The Linux username is **`kim`**, but it is registered under the NixOS attribute
key **`i`**:

```nix
# src/systems/users/default.nix
users.users.i = { name = "kim"; group = "developer"; ... };
```

So the real `$HOME` user is `kim`, while code references like
`config.users.users.i.name` (polkit rule, getty autologin) resolve to `"kim"`.
The home-manager flake output is keyed `i` to mirror `users.users.i`, which is
why `make flake-home-switch` targets `.#i` even though you run it as user
`kim`. Group is `developer` (also the hostname). Do not "fix" the `i`/`kim`
mismatch — it is intentional coupling between the HM output name and the
`users.users.i` attribute key.

## Tooling & diagnostics

- **LSP**: `nil` (`nil_ls`) is active. It emits many `unused-binding` /
  `unused-rec` warnings project-wide. These are endemic and stylistic — module
  heads like `{ config, pkgs, lib, ... }` routinely declare parameters they
  don't use. **Do not treat them as errors** and do not churn files just to
  silence them.
- **Editor**: Helix is the default editor (`defaultEditor = true`), configured
  heavily under `home-manager/src/configs/helix/`.
- **Shell**: fish is the default user shell (`users.defaultUserShell = pkgs.fish`).

## Git conventions

- Conventional Commits with optional scope: `feat:`, `feat(helix):`,
  `chore(helix):`, `refactor(vpn):`, `chore(zellij):`.
- PRs are squash-merged with a trailing `(#NNN)` on the subject.
- Active branch is `master`; upstream also has `common` and `git` branches.
