final: prev:
{
  elftoolchain = prev.callPackage ./elftoolchain.nix { };

  python39 = prev.python39.override {
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
