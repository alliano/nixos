{ ... }:
{
  global = {
    lsp = [
      "scls"
      # "helix-gpt"
      "typos"
    ];
  };
  java = false;
  php = false;
  go = false;
  js = true;
  ts = true;
  rust = true;
  docker = true;
  cpp = false;
  nix = true;
  yaml = true;
  kubernetes = false;
  json = false;
  css = true;
  html = true;
  markdown = false;
  helix-gpt = true;
  scls = false; # Simple Completion Language Server, a autocomplete for plain text from buffer
  sql = false; # require scls enable
  env = true; # require scls enable
  svelte = true;
  astro = false;
  nginx = false;
  vue = false;
  cs = false;
  fish = true;
  prisma = false;
  typos = false;
  sonarlint = false;
}
