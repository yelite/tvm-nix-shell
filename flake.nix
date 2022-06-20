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

    channels.nixpkgs = {
      input = nixpkgs;
      config = {
        allowUnfree = true;
        cudaSupport = false;
      };
      overlaysBuilder = channels: [
        inputs.fenix.overlay
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
        cudaEnv = lib.optionalString useCuda ''
          export CUDA_HOME="${pkgs.cudatoolkit}"
          # This is for NixOS, to add libcuda to ld path.
          # TODO: condition this on the os type
          export LD_LIBRARY_PATH="/var/run/opengl-driver/lib:$LD_LIBRARY_PATH"
        '';
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
        binutils_with_mold = (pkgs.wrapBintoolsWith {
          bintools = pkgs.binutils-unwrapped.overrideAttrs (old: {
            # Need this to trigger wrapper script
            postInstall = ''
              ln -sf ${pkgs.mold}/bin/mold $out/bin/ld.bfd
            '';
          });
        }).overrideAttrs (old: {
          # Put mold back to its own place, also add libexec/mold to align with
          # the original installation directory layout
          postFixup = old.postFixup + ''
            mv $out/bin/ld.bfd $out/bin/mold
            mkdir -p $out/libexec/mold
            ln -sf $out/bin/mold $out/libexec/mold/ld
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
            ] ++ lib.optionals stdenv.isLinux [
              # TODO: Remove this after mold can be built on macOS
              binutils_with_mold
            ] ++ rustToolchain;

            buildInputs = with pkgs; [
              llvmPackages.llvm
              llvmPackages.libclang
              openssl.dev
              gtest
            ];
            packages = with pkgs; [
              python39
              gdb
              ninja
              clang-tools # To get the latest clangd
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

                pytorch
                torchvision
              ])
            ++ lib.optionals useCuda (with pkgs; [
              cudaPackages_11_6.cudatoolkit
            ])
            ++ lib.optionals (!pkgs.stdenv.isAarch64) (with pkgs;
              [
                wasmtime
                wabt
              ]);

            shellHook = ''
              export TVM_HOME=$(pwd)/tvm
              export PIP_PREFIX=$(pwd)/_build/pip_packages
              export PYTHONPATH="$(pwd)/benchmark:$(pwd)/torchdynamo:$(pwd)/synr:$TVM_HOME/python:$PIP_PREFIX/${pkgs.python39.sitePackages}:$PYTHONPATH"
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
