final: prev:
{
  elftoolchain = prev.callPackage ./elftoolchain.nix { };

  # Wrap mold according the snippet from https://github.com/NixOS/nixpkgs/pull/172452#issuecomment-1335903570
  mold-wrapped = (prev.wrapBintoolsWith {
    bintools = prev.mold;
  }).overrideAttrs (old: {
    installPhase = old.installPhase + ''
      for variant in ld.mold ld64.mold; do
        local underlying=$ldPath/$variant
        [[ -e "$underlying" ]] || continue
        wrap $variant ${prev.path}/pkgs/build-support/bintools-wrapper/ld-wrapper.sh $underlying
      done
    '';
  });

  python310 = prev.python310.override {
    packageOverrides = python-self: python-super:
      let
        inherit (prev.lib) optionalString;
        inherit (prev.stdenv) isDarwin isAarch64;
      in
      {
        torchtext = prev.callPackage ./torchtext.nix { };
        pytorch-bin = python-super.pytorch-bin.overridePythonAttrs
          (old:
            let wheels = {
              x86_64-linux = {
                name = "torch-1.14.0.dev20221021+cu117-cp39-cp39-linux_x86_64.whl";
                url = "https://download.pytorch.org/whl/nightly/cu117/torch-1.14.0.dev20221021%2Bcu117-cp39-cp39-linux_x86_64.whl";
                hash = "sha256-ta2vdCYNxcoBlZYvyeM283zXHMIqoKYySs7t4BKHs0Y=";
              };
            }; in
            {
              version = "1.14.0.dev20221021";
              src = prev.fetchurl wheels."${prev.stdenv.system}";
              propagatedBuildInputs = old.propagatedBuildInputs ++ [
                python-super.networkx
                python-super.sympy
              ];
            });
      };
  };
}
