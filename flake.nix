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

    supportedSystems = [ "x86_64-linux" ];

    channels.nixpkgs.input = nixpkgs;
    channels.nixpkgs.config.allowUnfree = true;
    channels.nixpkgs.overlaysBuilder = channels: [ inputs.fenix.overlay ];

    outputsBuilder = channels:
      let
        pkgs = channels.nixpkgs;
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
      in
      {
        devShell = pkgs.mkShell
          {
            name = "tvm-shell";
            packages = with pkgs; [
              pkg-config
              cmake
              ccache
              gtest
              python38
              wasmtime
              wabt
              llvmPackages.llvm
              llvmPackages.libclang
              cudatoolkit_11_5
              openssl.dev
            ]
            ++ (with pkgs.python38Packages;
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
                mxnet
              ])
            ++ rustToolchain;

            shellHook = ''
              export TVM_HOME=$(pwd)/tvm
              export PIP_PREFIX=$(pwd)/_build/pip_packages
              export PYTHONPATH="$(pwd)/synr:$TVM_HOME/python:$PIP_PREFIX/${pkgs.python38.sitePackages}:$PYTHONPATH"
              export PATH="$PIP_PREFIX/bin:$PATH"
              unset SOURCE_DATE_EPOCH

              export LIBCLANG_PATH="${llvmPackages.libclang.lib}/lib"

              export BINDGEN_EXTRA_CLANG_ARGS="-isystem ${llvmPackages.clang}/resource-root/include $NIX_CFLAGS_COMPILE"
              export LLVM_AR="${llvmPackages.llvm}/bin/llvm-ar"

              export CUDA_HOME="${pkgs.cudatoolkit}"
              export LD_LIBRARY_PATH="${pkgs.gtest}/lib:/var/run/opengl-driver/lib:$LD_LIBRARY_PATH"

              exec fish --init-command='source ${./prompt.fish}'
            '';
          };
      };
  };
}
