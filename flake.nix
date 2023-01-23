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
        cudaEnv = lib.optionalString useCuda ''
          export CUDA_HOME="${cudatoolkit}"
          # This is for NixOS, to add libcuda to ld path.
          # TODO: condition this on the os type
          export LD_LIBRARY_PATH="/var/run/opengl-driver/lib:$LD_LIBRARY_PATH"
        '';
        llvmPackages = pkgs.llvmPackages_11;
        # Wrap mold according the snippet from https://github.com/NixOS/nixpkgs/pull/172452#issuecomment-1335903570
        mold' = (pkgs.wrapBintoolsWith {
          bintools = pkgs.mold;
        }).overrideAttrs (old: {
          installPhase = old.installPhase + ''
            for variant in ld.mold ld64.mold; do
              local underlying=$ldPath/$variant
              [[ -e "$underlying" ]] || continue
              wrap $variant ${pkgs.path}/pkgs/build-support/bintools-wrapper/ld-wrapper.sh $underlying
            done
          '';
        });
      in
      {
        packages = utils.lib.exportPackages self.overlays channels;
        devShell = pkgs.mkShell
          {
            name = "tvm-shell";

            nativeBuildInputs = with pkgs; [
              pkg-config
              cmake
              clang
              ccache
              cargo
              rustc
            ] ++ lib.optionals stdenv.isLinux [
              # TODO: Remove this after mold can be built on macOS
              mold'
            ];

            buildInputs = with pkgs; [
              llvmPackages.llvm
              llvmPackages.libclang
              openssl.dev
              gtest
            ] ++ lib.optionals stdenv.isLinux [
              # elftoolchain
              (libbacktrace.override {
                enableStatic = true;
              })
            ];
            packages = with pkgs; [
              python39
              gdb
              ninja
              rustfmt
              clippy
              rust-analyzer
              doxygen
              clang-tools # To get the latest clangd
              libclang
              git-lfs # for benchmark
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
                jupyter
                opencv4 # For benchmark yolov3
                seaborn # For benchmark analysis

                pytorch-bin
                torchvision

                black
                mypy
                flake8
              ])
            ++ lib.optionals useCuda [
              cudatoolkit
            ]
            ++ lib.optionals (!pkgs.stdenv.isAarch64) (with pkgs;
              [
                wasmtime
                wabt
              ]);

            hardeningDisable = [ "fortify" ];

            shellHook = ''
              export TVM_HOME=$(pwd)/tvm
              export PIP_PREFIX=$(pwd)/_build/pip_packages
              export PYTHONPATH="$(pwd)/synr:$TVM_HOME/python:$PIP_PREFIX/${pkgs.python39.sitePackages}:$PYTHONPATH"
              export PATH="$PIP_PREFIX/bin:$PATH"
              unset SOURCE_DATE_EPOCH

              export LIBCLANG_PATH="${llvmPackages.libclang.lib}/lib"

              export BINDGEN_EXTRA_CLANG_ARGS="-isystem ${llvmPackages.clang}/resource-root/include $NIX_CFLAGS_COMPILE"
              export LLVM_AR="${llvmPackages.llvm}/bin/llvm-ar"

              ${cudaEnv}

              # Make sure we get the latest clangd
              export PATH="${pkgs.clang-tools}/bin:$PATH";
            '';
          };
      };
  };
}
