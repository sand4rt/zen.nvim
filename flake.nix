{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    gen-luarc.url = "github:mrcjkb/nix-gen-luarc-json";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      gen-luarc,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            gen-luarc.overlays.default
          ];
        };
        luarc = pkgs.mk-luarc-json {
          plugins = with pkgs.vimPlugins; [
            mini-nvim
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            lua-language-server
          ];
          shellHook = # bash
            ''
              ln -fs ${luarc} .luarc.json
            '';
        };
      }
    );
}
