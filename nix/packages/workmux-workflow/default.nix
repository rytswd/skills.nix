{ pkgs, pname, ... }:

pkgs.stdenvNoCC.mkDerivation {
  inherit pname;
  version = "0.1.0";
  src = ../../../skills/workmux-workflow;

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/agent-skills/${pname}
    cp -r . $out/share/agent-skills/${pname}/
    runHook postInstall
  '';

  meta = {
    description = "Agent skill: workmux orchestration workflow patterns";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.all;
  };
}
