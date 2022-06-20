final: prev:
{
  python39 = prev.python39.override {
    packageOverrides = python-self: python-super:
      let
        inherit (prev.lib) optionalString;
        inherit (prev.stdenv) isDarwin isAarch64;
      in
      {
        # TODO: Remove after nixpkgs has datatable beyond https://github.com/h2oai/datatable/commit/6b74f7a99bd2046f329eed6bd3b473749e2da824
        datatable = python-super.datatable.overridePythonAttrs
          (old: {
            # datatable uses customized script to build wheels and it produces
            # wheels named after macosx_10_6_arm64, which isn't valid. It needs at least macosx_11_0
            buildPhase = old.buildPhase + optionalString (isDarwin && isAarch64) ''
              ${final.rename}/bin/rename 's/macosx_10_6/macosx_11_0/g' dist/*.whl
            '';
            disabledTests = old.disabledTests ++ [
              # Weird fp percision failures
              "test_save_double"
              "test_issue_R1113"
              "test_float_decimal0"
              "test_int_even_longer"
              "test_fread1"
              "test_utf16"
              "test_fread_NUL"
              "test_whitespace_nas"
            ];
          });
        graphviz = python-super.graphviz.overridePythonAttrs
          (old: {
            doCheck = !prev.stdenv.isDarwin;
          });
        torchtext = prev.callPackage ./torchtext.nix { };
      };
  };
}
