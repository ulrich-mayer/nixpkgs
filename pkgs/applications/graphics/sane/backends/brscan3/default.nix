{ stdenv, lib, fetchurl, bbe, callPackage, patchelf, makeWrapper, libusb-compat-0_1 }:
let
  myPatchElf = file: with lib; ''
    patchelf --set-interpreter \
      ${stdenv.cc.libc}/lib/ld-linux${optionalString stdenv.is64bit "-x86-64"}.so.2 \
      ${file}
  '';

in
stdenv.mkDerivation rec {
  pname = "brscan3";
  version = "0.2.13-1";
  src = {
    "i686-linux" = fetchurl {
      url = "http://download.brother.com/welcome/dlf006641/${pname}-${version}.i386.deb";
      sha256 = "sha256-rQZmXKwyA1iT9hTZMF2r9zFFr0VPGutri3x/onAP4uY=";
    };
    "x86_64-linux" = fetchurl {
      url = "https://download.brother.com/welcome/dlf006642/${pname}-${version}.amd64.deb";
      sha256 = "sha256-RGrfUxvzkDKJLpUEzjS3v4ieD4YowHMs67O4P6+zJ7g=";
    };
  }."${stdenv.hostPlatform.system}";

  unpackPhase = ''
    ar x $src
    tar xfvz data.tar.gz
  '';

  nativeBuildInputs = [ makeWrapper patchelf ];
  buildInputs = [ libusb-compat-0_1 ];
  dontBuild = true;

  postPatch = ''
    ${myPatchElf "usr/local/Brother/sane/brsaneconfig3"}

    RPATH=${libusb-compat-0_1.out}/lib
    for a in usr/lib64/sane/*.so*; do
      if ! test -L $a; then
        patchelf --set-rpath $RPATH $a
      fi
    done
    
  '';

  installPhase = with lib; ''
    runHook preInstall
    PATH_TO_BRSCAN3="usr/local/Brother/sane"
    mkdir -p $out/$PATH_TO_BRSCAN3
    cp -rp $PATH_TO_BRSCAN3/* $out/$PATH_TO_BRSCAN3
    mkdir -p $out/lib/sane
    cp -rp usr/lib${optionalString stdenv.is64bit "64"}/sane/* $out/lib/sane

    # Symbolic links were absolute. Fix them so that they point to $out.
    pushd "$out/lib/sane" > /dev/null
    for a in *.so*; do
      if test -L $a; then
        fixedTargetFileName="$(basename $(readlink $a))"
        unlink "$a"
        ln -s -T "$fixedTargetFileName" "$a"
      fi
    done
    popd > /dev/null

    # Generate an LD_PRELOAD wrapper to redirect execvp(), open() and open64()
    # calls to `/usr/local/Brother/sane`.
    preload=$out/libexec/brother/scanner/brscan3/libpreload.so
    mkdir -p $(dirname $preload)
    gcc -shared ${./preload.c} -o $preload -ldl -DOUT=\"$out\" -fPIC
    
    makeWrapper \
      "$out/$PATH_TO_BRSCAN3/brsaneconfig3" \
      "$out/bin/brsaneconfig3" \
      --set LD_PRELOAD $preload

    mkdir -p $out/etc/sane.d
    echo "brother3" > $out/etc/sane.d/dll.conf


    #  issue to resolve:
    #  
    # strings /nix/store/caz1xkpyslvzfp8g8a4a7if51mm0cpmx-brscan3-0.2.13-1/lib/sane/libsane-brother3.so | grep /usr
    # /usr/bin/brscan-skey
    # /usr/local/Brother/sane/models3
    # /usr/local/Brother/sane/Brsane3.ini
    # /usr/local/Brother/sane/brsanenetdevice3.cfg
    # .:/usr/local/etc/sane.d
    #
    # potential fix:
    #  https://tapesoftware.net/replace-symbol/

    runHook postInstall
  '';
 
  dontStrip = true;
  dontPatchELF = true;

  meta = {
    description = "Brother brscan3 sane backend driver";
    homepage = "http://www.brother.com";
    platforms = [ "i686-linux" "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ jraygauthier ];
  };
}
