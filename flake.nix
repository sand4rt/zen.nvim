{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        basePackages = with pkgs; [
          lua-language-server
          gnumake
          git
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = basePackages;
        };
        devShells.ci = pkgs.mkShell {
          packages = basePackages ++ [ pkgs.neovim ];
        };
      }
    );
}
