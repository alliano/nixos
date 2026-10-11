{ lib, ... }:

# Stockbit tidak punya build Linux dan web-nya bukan PWA (tidak ada manifest
# maupun service worker), jadi dijalankan sebagai site-specific browser lewat
# mode --app= milik Brave. --class dipisah supaya punya windowrule sendiri.
#
# Ditulis via home.file, bukan xdg.desktopEntries, karena xdg.enable = false
# di config ini membuat desktopEntries tidak pernah ter-generate.
let
  isEnabled = true;
  icon = ./assets/stockbit.png;
in
lib.mkIf (isEnabled) {
  home.file.".local/share/applications/stockbit.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.4
    Name=Stockbit
    GenericName=Stock Trading
    Comment=Stockbit web sebagai jendela terpisah
    Exec=brave --app=https://stockbit.com/ --class=stockbit
    Icon=${icon}
    Terminal=false
    Categories=Office;Finance;
    StartupWMClass=stockbit
  '';
}
