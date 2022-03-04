# This dev shell requires synr and tvm to be place in the same working directory
{
  description = "Dev shell for tvm";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    utils = {
      url = "github:gytis-ivaskevicius/flake-utils-plus";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, utils, nixpkgs, ... }@inputs: utils.lib.mkFlake {
    inherit self inputs;

    supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];

    channels.nixpkgs.input = nixpkgs;
    channels.nixpkgs.config.allowUnfree = true;
    channels.nixpkgs.overlaysBuilder = channels: [
      inputs.fenix.overlay
      self.overlay
    ];

    overlay = import ./patches.nix;
    overlays = utils.lib.exportOverlays {
      inherit (self) pkgs inputs;
    };

    outputsBuilder = channels:
      let
        pkgs = channels.nixpkgs;
        inherit (pkgs) lib;
        rustToolchain = with pkgs; [
          (fenix.stable.withComponents [
            "cargo"
            "clippy"
            "rustfmt"
            "rust-src"
            "rustc"
          ])
          rust-analyzer-nightly
        ];
        llvmPackages = pkgs.llvmPackages_11;
        binutils_mold = pkgs.wrapBintoolsWith {
          bintools = pkgs.binutils-unwrapped.overrideAttrs (old: {
            postInstall = ''
              rm $out/bin/ld.gold
              rm $out/bin/ld.bfd
              ln -sf ${pkgs.mold}/bin/mold $out/bin/ld.bfd
            '';
          });
        };
      in
      {
        packages = utils.lib.exportPackages self.overlays channels;
        devShell = pkgs.mkShell
          {
            name = "tvm-shell";
            nativeBuildInputs = with pkgs; [
              pkg-config
              cmake
              binutils_mold
              ccache
            ] ++ rustToolchain;
            buildInputs = with pkgs; [
              llvmPackages.llvm
              llvmPackages.libclang
              openssl.dev
              gtest
            ];
            packages = with pkgs; [
              python39
              clang-tools # To get the latest clangd
            ]
            ++ (with pkgs.python39Packages;
              [
                pip
                setuptools
                numpy
                decorator
                attrs
                tornado
                psutil
                xgboost
                cloudpickle
                pytest
                pillow
                ipython
              ])
            ++ lib.optionals (!pkgs.stdenv.isAarch64) (with pkgs;
              [
                # mxnet is only used for tests and examples
                # The current version in pkgs (1.8) has build problem on ARM
                python39Packages.mxnet
                wasmtime
                wabt
              ]);

            shellHook = ''
              export TVM_HOME=$(pwd)/tvm
              export PIP_PREFIX=$(pwd)/_build/pip_packages
              export PYTHONPATH="$(pwd)/synr:$TVM_HOME/python:$PIP_PREFIX/${pkgs.python38.sitePackages}:$PYTHONPATH"
              export PATH="$PIP_PREFIX/bin:$PATH"
              export CXXFLAGS="-B${binutils_mold}/bin"
              unset SOURCE_DATE_EPOCH

              export LIBCLANG_PATH="${llvmPackages.libclang.lib}/lib"

              export BINDGEN_EXTRA_CLANG_ARGS="-isystem ${llvmPackages.clang}/resource-root/include $NIX_CFLAGS_COMPILE"
              export LLVM_AR="${llvmPackages.llvm}/bin/llvm-ar"

              # Make sure we get the latest clangd
              export PATH="${pkgs.clang-tools}/bin:$PATH";
              export SHELL="fish";

              exec fish --init-command='source ${./prompt.fish}'
            '';
          };
      };
  };
}
