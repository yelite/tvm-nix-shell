final: prev:
{
  elftoolchain = prev.callPackage ./elftoolchain { };

  mold = prev.mold.overrideAttrs (oldAttrs: rec {
    version = "1.6.0";
    src = prev.fetchFromGitHub {
      owner = "rui314";
      repo = oldAttrs.pname;
      rev = "v${version}";
      hash = "sha256-IXXyZZw1Tp/s9YkPR5Y+A6LpvaRo+XfA8UJBtt5Bjmg=";
    };
  });

  # Wrap mold according the snippet from https://github.com/NixOS/nixpkgs/pull/172452#issuecomment-1335903570
  mold-wrapped = (prev.wrapBintoolsWith {
    bintools = final.mold;
  }).overrideAttrs (old: {
    installPhase = old.installPhase + ''
      for variant in ld.mold ld64.mold; do
        local underlying=$ldPath/$variant
        [[ -e "$underlying" ]] || continue
        wrap $variant ${prev.path}/pkgs/build-support/bintools-wrapper/ld-wrapper.sh $underlying
      done
    '';
  });
}
