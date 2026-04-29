{ pkgs, pname, ... }:

pkgs.stdenvNoCC.mkDerivation {
  inherit pname;
  version = "0.1.0";
  src = ../../../skills/my-tools;

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    if [ ! -f SKILL.md ]; then
      echo "ERROR: SKILL.md not found for '${pname}'"
      exit 1
    fi
    mkdir -p $out/share/agent-skills/${pname}
    cp -r . $out/share/agent-skills/${pname}/
    runHook postInstall
  '';

  meta = {
    description = "Agent skill template: ${pname} (user-context suite)";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.all;
  };
}
