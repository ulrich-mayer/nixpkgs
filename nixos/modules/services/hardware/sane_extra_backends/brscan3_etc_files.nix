{ stdenv, lib, brscan3, netDevices ? [] }:

/*

Testing
-------

No net devices:

~~~
nix-shell -E 'with import <nixpkgs> { }; brscan3-etc-files'
~~~

Two net devices:

~~~
nix-shell -E 'with import <nixpkgs> { }; brscan3-etc-files.override{netDevices=[{name="a"; model="MFC-7440N"; nodename="BRW0080927AFBCE";} {name="b"; model="MFC-7440N"; ip="192.168.1.2";}];}'
~~~

*/

let

  addNetDev = nd: ''
    brsaneconfig3 -a \
    name="${nd.name}" \
    model="${nd.model}" \
    ${if (lib.hasAttr "nodename" nd && nd.nodename != null) then
      ''nodename="${nd.nodename}"'' else
      ''ip="${nd.ip}"''}'';
  addAllNetDev = xs: lib.concatStringsSep "\n" (map addNetDev xs);
in

stdenv.mkDerivation {

  pname = "brscan3-etc-files";
  version = "0.2.13-1";
  # "{brscan3}=/nix/store/caz1xkpyslvzfp8g8a4a7if51mm0cpmx-brscan3-0.2.13-1/ 
  src = "${brscan3}/usr/local/Brother/sane";

  nativeBuildInputs = [ brscan3 ];

  dontConfigure = true;

  buildPhase = ''
    # $out=/nix/store/wc3lsrfczrxz6mmvi7j1hn997gjfrkzz-brscan3-etc-files-0.2.13-1 
    TARGET_DIR="$out/etc/opt/brother/scanner/brscan3"
    mkdir -p "$TARGET_DIR"
    cp -rp "./models3" "$TARGET_DIR"
    cp -rp "./Brsane3.ini" "$TARGET_DIR"
    cp -rp "./brsanenetdevice3.cfg" "$TARGET_DIR"

    export BRSANENETDEVICE3_CFG_FILENAME="$TARGET_DIR/brsanenetdevice3.cfg"

    printf "copying config files from $src to $TARGET_DIR\n"
    printf '${addAllNetDev netDevices}\n'

    ${addAllNetDev netDevices}
  '';

  dontInstall = true;
  dontStrip = true;
  dontPatchELF = true;

  meta = with lib; {
    description = "Brother brscan3 sane backend driver etc files";
    homepage = "http://www.brother.com";
    platforms = platforms.linux;
    license = licenses.unfree;
    maintainers = with maintainers; [ jraygauthier ];
  };
}
