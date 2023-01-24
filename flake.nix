# This dev shell requires synr and tvm to be place in the same working directory
{
  description = "Dev shell for tvm";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    utils = {
      url = "github:gytis-ivaskevicius/flake-utils-plus";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, utils, nixpkgs, ... }@inputs: utils.lib.mkFlake {
    inherit self inputs;

    supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];

    channels.nixpkgs = {
      input = nixpkgs;
      config = {
        allowUnfree = true;
        cudaSupport = false;
      };
      overlaysBuilder = channels: [
        self.overlay
      ];
    };

    overlay = import ./pkgs;
    overlays = utils.lib.exportOverlays {
      inherit (self) pkgs inputs;
    };

    outputsBuilder = channels:
      let
        pkgs = channels.nixpkgs;
        inherit (pkgs) stdenv lib;
        useCuda = stdenv.isLinux;

        cudatoolkit = pkgs.cudaPackages_11_7.cudatoolkit;
        tvm-llvm = pkgs.llvmPackages_11;
        python = pkgs.python310;

      in
      {
        packages = utils.lib.exportPackages self.overlays channels;

        devShell = pkgs.mkShell
          {
            name = "tvm-shell";

            nativeBuildInputs = with pkgs; [
              pkg-config
              cmake
              ccache
              cargo
              rustc
            ] ++ lib.optionals stdenv.isLinux [
              mold-wrapped
            ] ++ lib.optionals stdenv.isDarwin [
              llvmPackages_14.bintools
            ];

            buildInputs = with pkgs; [
              tvm-llvm.llvm
              tvm-llvm.libclang
              openssl.dev
              (libbacktrace.override {
                enableStatic = true;
              })
              gtest
            ] ++ lib.optionals stdenv.isLinux [
              # elftoolchain
            ];

            packages = with pkgs; ([
              python
              ninja
              rustfmt
              clippy
              rust-analyzer
              doxygen
              clang-tools # To get the latest clangd
              git-lfs # for benchmark
            ]
            ++ lib.optionals useCuda [
              cudatoolkit
            ]
            ++ lib.optionals stdenv.isLinux [
              gdb
            ]
            ++ lib.optionals (!pkgs.stdenv.isAarch64) [
              wasmtime
              wabt
            ]
            ++ (with python.pkgs; [
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

              black
              mypy
              flake8
            ]
            ++ lib.optional stdenv.isLinux [
              jupyter
              opencv4 # For benchmark yolov3
              seaborn # For benchmark analysis

              pytorch-bin
              torchvision
            ])
            );

            hardeningDisable = [ "fortify" ];

            shellHook = ''
              export TVM_HOME=$(pwd)/tvm
              export PYTHONPATH="$(pwd)/synr:$TVM_HOME/python:$PYTHONPATH"
              export PATH="$PIP_PREFIX/bin:$PATH"
              unset SOURCE_DATE_EPOCH

              export LIBCLANG_PATH="${tvm-llvm.libclang.lib}/lib"

              export BINDGEN_EXTRA_CLANG_ARGS="-isystem ${tvm-llvm.clang}/resource-root/include $NIX_CFLAGS_COMPILE"
              export LLVM_AR="${tvm-llvm.llvm}/bin/llvm-ar"

              # Make sure we get the latest clangd
              export PATH="${pkgs.clang-tools}/bin:$PATH";
            ''
            + lib.optionalString useCuda ''
              export CUDA_HOME="${cudatoolkit}"
              # This is for NixOS, to add libcuda to ld path.
              # TODO: condition this on the os type
              export LD_LIBRARY_PATH="/var/run/opengl-driver/lib:$LD_LIBRARY_PATH"
            '';
          };
      };
  };
}
