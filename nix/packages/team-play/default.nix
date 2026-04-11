{ pkgs, pname, ... }:

let
  base = pkgs.stdenvNoCC.mkDerivation {
    inherit pname;
    version = "0.1.0";
    src = ../../../skills/team-play;

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
      description = "Agent skill: ${pname}";
      license = pkgs.lib.licenses.mit;
      platforms = pkgs.lib.platforms.all;
    };

    passthru = {
      # Extend team-play with additional role directories.
      #
      # Usage:
      #   team-play.withExtraRoles [
      #     ./my-roles            # my-roles/engineer/python.md
      #     ./company-standards   # company-standards/reviewer/internal.md
      #   ]
      #
      # Files at the same path override the base (user wins).
      # New directories are added alongside built-in roles.
      withExtraRoles = extraRoles:
        pkgs.runCommand pname { } ''
          mkdir -p $out/share/agent-skills/${pname}
          cp -r --no-preserve=mode ${base}/share/agent-skills/${pname}/. $out/share/agent-skills/${pname}/

          ${pkgs.lib.concatMapStringsSep "\n" (extra: ''
            if [ -d "${extra}" ]; then
              cp -r --no-preserve=mode "${extra}"/. $out/share/agent-skills/${pname}/
            else
              echo "Warning: extraRoles entry '${extra}' is not a directory" >&2
            fi
          '') extraRoles}

          if [ ! -f $out/share/agent-skills/${pname}/SKILL.md ]; then
            echo "ERROR: SKILL.md missing after merge" >&2
            exit 1
          fi
        '';
    };
  };
in
base
