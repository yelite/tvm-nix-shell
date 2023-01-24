{ stdenv
, fetchsvn
, bmake
, gnum4
, lsb-release
, groff
,
}:
let
  revision = "3987";
in
stdenv.mkDerivation {
  pname = "elftoolchain";
  version = revision;

  src = fetchsvn {
    url = "svn://svn.code.sf.net/p/elftoolchain/code/trunk";
    rev = revision;
    sha256 = "sha256-ze5ROWcD00b9zqGsg3VC/rxJ5sbBDpb3TUneUrQkaik=";
  };

  nativeBuildInputs = [
    bmake
    gnum4
    lsb-release
    groff
  ];

  postPatch = ''
    cp ${./elfdefinitions.h} common/elfdefinitions.h
  '';

  buildPhase = ''
    runHook preBuild

      local flagsArray=(
          ''${enableParallelBuilding:+-j''${NIX_BUILD_CORES}}
          SHELL=$SHELL
          $makeFlags ''${makeFlagsArray+"''${makeFlagsArray[@]}"}
          $buildFlags ''${buildFlagsArray+"''${buildFlagsArray[@]}"}
      )

      echoCmd 'build flags' "''${flagsArray[@]}"

      pushd common
      bmake ''${makefile:+-f $makefile} "''${flagsArray[@]}"
      popd
      
      pushd libelf
      bmake ''${makefile:+-f $makefile} "''${flagsArray[@]}"
      popd

      pushd libdwarf
      bmake ''${makefile:+-f $makefile} "''${flagsArray[@]}"
      popd

      unset flagsArray

      runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    mkdir -p $out/include

    mv libelf/libelf.a $out/lib/
    mv libelf/libelf.so.1 $out/lib/libelf.so
    mv libdwarf/libdwarf.a $out/lib/
    mv libdwarf/libdwarf.so.3 $out/lib/libdwarf.so

    cp common/elfdefinitions.h $out/include/
    cp libelf/gelf.h $out/include/
    cp libelf/libelf.h $out/include/
    cp libdwarf/libdwarf.h $out/include/
    cp libdwarf/dwarf.h $out/include/

    runHook postInstall
  '';

  dontUseBmakeDist = true;
}
