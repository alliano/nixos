{ config, ... }: rec{
  isEnableAutoStart = true;
  dirName = "hypr";
  dir = builtins.toPath "/home/kim/.config/${dirName}";
  wallpaper = rec {
    name = "astralbed.png";
    path = builtins.toPath ./assets/${name};
  };
  locker = {
    image = rec {
      name = "eh.jpeg";
      path = builtins.toPath ./assets/${name};
    };
  };
}
