{ pkgs, ... }:
{
  languages.lua = {
    enable = true;
    package = pkgs.luajit;
  };

  packages = with pkgs; [
    stylua
    luajitPackages.luacheck
    gnumake
    git
  ];

  tasks."zen:check" = {
    exec = "make test typecheck format-check lint";
    before = [ "devenv:enterTest" ];
  };
}
