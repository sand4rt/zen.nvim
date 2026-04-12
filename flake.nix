{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    gen-luarc.url = "github:mrcjkb/nix-gen-luarc-json";
  };
  outputs =
    {
      self,
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
        luarc = pkgs.mk-luarc {
          plugins = with pkgs.vimPlugins; [
            mini-nvim
          ];
        };
        luarc-json = pkgs.luarc-to-json (
          luarc
          // {
            diagnostics = luarc.diagnostics // {
              globals = [ "MiniTest" ];
            };
          }
        );
        type-check =
          pkgs.runCommand "type-check"
            {
              nativeBuildInputs = [ pkgs.lua-language-server ];
            }
            ''
              export HOME="$(mktemp -d)"
              cp -r ${self} source
              cd source
              lua-language-server --configpath ${luarc-json} --logpath "$HOME/log" --check .
              touch $out
            '';
        stylua-check =
          pkgs.runCommand "stylua-check"
            {
              nativeBuildInputs = [ pkgs.stylua ];
            }
            ''
              cd ${self}
              stylua --check .
              touch $out
            '';
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            lua-language-server
            stylua
          ];
        };
        checks = {
          inherit type-check stylua-check;
        };
      }
    );
}
