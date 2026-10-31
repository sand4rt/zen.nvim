{ pkgs, ... }:
{
  packages = with pkgs; [
    lua-language-server
    stylua
    gnumake
    git
  ];
}
