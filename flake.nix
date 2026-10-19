{
  description = "Eine einfache Nix dev shell für c/c++";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    odin-overlay = {
      url = "github:couchpotato007/odin-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      odin-overlay,
    }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ odin-overlay.overlays.default ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          glibc
          cmake
          gcc
          odin-bin.stable
          ols-bin.stable
          gdb
          pkg-config
          clang
          clang-tools
          cmake
          raylib
          libxinerama
          libxcursor
          xinput
          libxi
        ];

        nativeBuildInputs = with pkgs; [
          # libc
        ];

        LD_LIBRARY_PATH = lib.makeLibraryPath [
          pkgs.libc
          pkgs.raylib
          pkgs.xinput
        ];

        EMSCRIPTEN_SDK_DIR = "${pkgs.emscripten}";
      };
    };
}
