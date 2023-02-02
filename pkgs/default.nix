final: prev:
{
  elftoolchain = prev.callPackage ./elftoolchain { };

  # Wrap mold according the snippet from https://github.com/NixOS/nixpkgs/pull/172452#issuecomment-1335903570
  mold-wrapped = (final.wrapBintoolsWith {
    bintools = final.mold;
  }).overrideAttrs (old: {
    installPhase = old.installPhase + ''
      for variant in ld.mold ld64.mold mold; do
        local underlying=$ldPath/$variant
        [[ -e "$underlying" ]] || continue
        wrap $variant ${prev.path}/pkgs/build-support/bintools-wrapper/ld-wrapper.sh $underlying
      done
      mkdir -p $out/libexec/mold
      ln -s $out/bin/ld.mold $out/libexec/mold/ld
    '';
  });
}
