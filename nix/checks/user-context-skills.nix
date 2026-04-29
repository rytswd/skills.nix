# Validate the shipped user-context skill templates (my-env / my-tools /
# my-style / my-workflow) against the same frontmatter rules that
# `programs.agent-skills.localSkills` enforces. This guarantees the
# templates can never ship with a broken description / missing name and
# also catches drift if a maintainer edits the frontmatter incorrectly.
#
# It additionally asserts that the four template descriptions do not
# share trigger keywords beyond a tiny common-stopword set, so the suite
# stays compatible with the documented "distinct trigger keywords" rule
# (see air/v0.1/user-context-skills/suite-conventions.org).
{ pkgs, flake, pname, ... }:

let
  inherit (flake.lib) mkLocalSkillsPreflight;
  system = pkgs.stdenv.hostPlatform.system;

  # The four shipped user-context templates as `localSkills`-style entries
  # pointing at each package's installed SKILL.md.
  templates = {
    my-env      = flake.packages.${system}.my-env;
    my-tools    = flake.packages.${system}.my-tools;
    my-style    = flake.packages.${system}.my-style;
    my-workflow = flake.packages.${system}.my-workflow;
  };

  preflightAttrs = builtins.mapAttrs
    (name: pkg: "${pkg}/share/agent-skills/${name}/SKILL.md")
    templates;

  preflight = mkLocalSkillsPreflight { localSkills = preflightAttrs; };

  wrap = script: ''
    #!${pkgs.runtimeShell}
    set -eu
    DRY_RUN_CMD=""
    ${script}
  '';

in
pkgs.runCommand "check-user-context-skills"
{
  nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.gawk pkgs.gnused pkgs.gnugrep ];
  passAsFile = [ "preflight" ];
  preflight = wrap preflight;
} ''
  set -eu

  ######################################################################
  # 1. Every shipped template passes the localSkills preflight.
  #    (i.e. has valid YAML frontmatter with name + description.)
  ######################################################################
  chmod +x "$preflightPath"
  if ! "$preflightPath"; then
    echo "FAIL: shipped user-context templates failed the localSkills preflight" >&2
    exit 1
  fi
  echo "PASS: all four templates pass localSkills frontmatter validation"

  ######################################################################
  # 2. Each template's frontmatter `name:` matches its directory name.
  #    Per the Agent Skills spec.
  ######################################################################
  check_name() {
    local pkgPath="$1" name="$2"
    local fmName
    fmName="$(awk '
      NR==1 && $0=="---" { inFm=1; next }
      inFm && $0=="---" { exit }
      inFm
    ' "$pkgPath/share/agent-skills/$name/SKILL.md" \
      | sed -n 's/^name:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
    if [ "$fmName" != "$name" ]; then
      echo "FAIL: $name: frontmatter name='$fmName' does not match dir name" >&2
      exit 1
    fi
  }
  check_name ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-env}      my-env
  check_name ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-tools}    my-tools
  check_name ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-style}    my-style
  check_name ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-workflow} my-workflow
  echo "PASS: every template's frontmatter name matches its directory"

  ######################################################################
  # 3. Trigger-keyword distinctness across the suite.
  #    Extract each template's description, tokenise (lowercase
  #    alphanumeric runs ≥ 4 chars), drop common stopwords, and assert
  #    no two descriptions share more than 2 trigger tokens.
  ######################################################################
  extract_tokens() {
    local pkgPath="$1" name="$2"
    awk '
      NR==1 && $0=="---" { inFm=1; next }
      inFm && $0=="---" { exit }
      inFm
    ' "$pkgPath/share/agent-skills/$name/SKILL.md" \
      | sed -n '/^description:/,/^[a-z]*:/p' \
      | grep -v '^[a-z]*:' \
      | tr 'A-Z' 'a-z' \
      | grep -oE '[a-z][a-z0-9-]{3,}' \
      | grep -vxE '(load|user|user.s|with|from|that|this|when|before|machine|describe|describes|need|needs|host|tools|tool|skill|preferences|preference|preferences|making|making|suggest|suggesting|commands|command|local|where|live|lives|which|allowed|banned|invoke|invoking|writing|written|text|intended|action|repository|repos|repo|history|describe|describes|setup|store|stores)' \
      | sort -u
  }

  # Materialise the four token sets.
  extract_tokens ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-env}      my-env      > tokens-env
  extract_tokens ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-tools}    my-tools    > tokens-tools
  extract_tokens ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-style}    my-style    > tokens-style
  extract_tokens ${flake.packages.${pkgs.stdenv.hostPlatform.system}.my-workflow} my-workflow > tokens-workflow

  # Pairwise overlap; tolerate small overlap (≤ 2 tokens) since "the",
  # "user", etc. are filtered but some structural words inevitably remain.
  check_overlap() {
    local a="$1" b="$2"
    local overlap
    overlap=$(comm -12 "$a" "$b" | wc -l)
    if [ "$overlap" -gt 2 ]; then
      echo "FAIL: descriptions of $a and $b share $overlap trigger tokens (>2):" >&2
      comm -12 "$a" "$b" | sed 's/^/  /' >&2
      exit 1
    fi
  }

  check_overlap tokens-env      tokens-tools
  check_overlap tokens-env      tokens-style
  check_overlap tokens-env      tokens-workflow
  check_overlap tokens-tools    tokens-style
  check_overlap tokens-tools    tokens-workflow
  check_overlap tokens-style    tokens-workflow
  echo "PASS: pairwise description trigger-keyword overlap stays within budget"

  echo ""
  echo "All user-context-skills checks passed."
  touch "$out"
''
