{ lib, ... }:

# Sama seperti [stockbit]: Ajaib Trade tidak punya build Linux dan web-nya
# bukan PWA (tidak ada manifest maupun service worker), jadi dijalankan
# sebagai site-specific browser lewat mode --app= milik Brave.
#
# Ditulis via home.file, bukan xdg.desktopEntries, karena xdg.enable = false
# di config ini membuat desktopEntries tidak pernah ter-generate.
let
  isEnabled = true;
  icon = ./assets/ajaib.png;
in
lib.mkIf (isEnabled) {
  home.file.".local/share/applications/ajaib.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.4
    Name=Ajaib Trade
    GenericName=Stock Trading
    Comment=Ajaib Trade web sebagai jendela terpisah
    Exec=brave --app=https://trade.ajaib.co.id/ --class=ajaib
    Icon=${icon}
    Terminal=false
    Categories=Office;Finance;
    StartupWMClass=ajaib
  '';
}
