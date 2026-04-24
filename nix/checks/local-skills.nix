# Integration test for the localSkills activation-script builders in
# flake.lib (mkLocalSkillsPreflight / mkLocalSkillsActivation).
#
# Strategy: generate the scripts with synthetic inputs, drop them into a
# sandbox-friendly harness, and run bash against a fake HOME populated with
# real source files. Assert on the resulting filesystem / exit codes.
#
# This exercises the shell logic end-to-end without needing home-manager.
{ pkgs, flake, pname, ... }:

let
  lib = pkgs.lib;
  inherit (flake.lib) mkLocalSkillsPreflight mkLocalSkillsActivation esc;

  # Helper: wrap a preflight/activation script in a runnable bash file.
  # $DRY_RUN_CMD is empty in real home-manager runs; we mirror that here.
  wrap = script: ''
    #!${pkgs.runtimeShell}
    set -eu
    DRY_RUN_CMD=""
    ${script}
  '';

  # -- Synthetic skill inputs used by the scripts --------------------------
  # We point at paths under a to-be-created $TESTROOT. The builders don't
  # resolve paths at eval time; they only embed them as strings.
  skills = {
    md-skill  = "/TESTROOT/src/md-skill.md";     # .md suffix → file
    dir-skill = "/TESTROOT/src/dir-skill";       # no suffix  → dir
  };

  preflightOk = mkLocalSkillsPreflight { localSkills = skills; };
  preflightMissing = mkLocalSkillsPreflight {
    localSkills = { ghost = "/TESTROOT/does-not-exist.md"; };
  };
  preflightWrongKindFile = mkLocalSkillsPreflight {
    # .md suffix but the path will be a directory
    localSkills = { wrong = "/TESTROOT/src/dir-as-md.md"; };
  };
  preflightWrongKindDir = mkLocalSkillsPreflight {
    # no .md suffix but the path will be a file
    localSkills = { wrong = "/TESTROOT/src/file-as-dir"; };
  };
  preflightNoFrontmatter = mkLocalSkillsPreflight {
    localSkills = { bare = "/TESTROOT/src/bare.md"; };
  };
  preflightMissingName = mkLocalSkillsPreflight {
    localSkills = { noname = "/TESTROOT/src/noname.md"; };
  };
  preflightMissingDescription = mkLocalSkillsPreflight {
    localSkills = { nodesc = "/TESTROOT/src/nodesc.md"; };
  };
  preflightDirNoSkillMd = mkLocalSkillsPreflight {
    localSkills = { hollow = "/TESTROOT/src/hollow-dir"; };
  };

  activation = mkLocalSkillsActivation {
    agentRoot = "/TESTROOT/home/.agents/skills";
    localSkills = skills;
  };

  # Activation that will try to overwrite the source with a self-link, by
  # configuring a skill whose dst resolves (through a stale symlink) back to
  # src. We set this up in the test harness below.
  selfLinkActivation = mkLocalSkillsActivation {
    agentRoot = "/TESTROOT/home/.agents/skills";
    localSkills = { selfy = "/TESTROOT/src/selfy.md"; };
  };

in pkgs.runCommand "check-local-skills" {
  nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.gawk pkgs.gnused pkgs.gnugrep ];
  passAsFile = [
    "preflightOk" "preflightMissing"
    "preflightWrongKindFile" "preflightWrongKindDir"
    "preflightNoFrontmatter"
    "preflightMissingName" "preflightMissingDescription"
    "preflightDirNoSkillMd"
    "activation" "selfLinkActivation"
  ];
  preflightOk = wrap preflightOk;
  preflightMissing = wrap preflightMissing;
  preflightWrongKindFile = wrap preflightWrongKindFile;
  preflightWrongKindDir = wrap preflightWrongKindDir;
  preflightNoFrontmatter = wrap preflightNoFrontmatter;
  preflightMissingName = wrap preflightMissingName;
  preflightMissingDescription = wrap preflightMissingDescription;
  preflightDirNoSkillMd = wrap preflightDirNoSkillMd;
  activation = wrap activation;
  selfLinkActivation = wrap selfLinkActivation;
} ''
  set -eu

  # Per-test harness: build a TESTROOT with the real on-disk layout the
  # scripts expect, substitute the placeholder path in each generated
  # script, then run it.
  setup_root() {
    TESTROOT="$(mktemp -d)"
    mkdir -p "$TESTROOT/src" "$TESTROOT/home/.agents/skills"
    echo "testroot=$TESTROOT"
  }

  # Substitute our placeholder with the real temp dir and make runnable.
  materialize() {
    local src="$1" out="$2"
    sed "s|/TESTROOT|$TESTROOT|g" "$src" > "$out"
    chmod +x "$out"
  }

  fail() { echo "FAIL: $*" >&2; exit 1; }
  pass() { echo "PASS: $*"; }

  # Canonical minimal valid SKILL.md frontmatter helper.
  valid_frontmatter() {
    local name="$1"
    cat <<EOF
---
name: $name
description: Test skill for local-skills preflight checks.
---
# $name
Body.
EOF
  }

  ######################################################################
  # 1. Preflight: happy path — all sources present, correct kind, and
  #    have valid SKILL.md frontmatter (name + description).
  ######################################################################
  setup_root
  valid_frontmatter "md-skill"  > "$TESTROOT/src/md-skill.md"
  mkdir -p "$TESTROOT/src/dir-skill"
  valid_frontmatter "dir-skill" > "$TESTROOT/src/dir-skill/SKILL.md"
  materialize "$preflightOkPath" "$TESTROOT/preflight.sh"
  if ! "$TESTROOT/preflight.sh"; then
    fail "preflight should succeed when all sources exist with valid frontmatter"
  fi
  pass "preflight: happy path"

  ######################################################################
  # 2. Preflight: missing source → exit 1 with a diagnostic.
  ######################################################################
  setup_root
  materialize "$preflightMissingPath" "$TESTROOT/preflight.sh"
  diag="$("$TESTROOT/preflight.sh" 2>&1 || true)"
  rc=$(bash -c "'$TESTROOT/preflight.sh' >/dev/null 2>&1; echo \$?")
  [ "$rc" = "1" ] || fail "preflight-missing: expected exit 1, got $rc"
  echo "$diag" | grep -q "localSkills.ghost: source does not exist" \
    || fail "preflight-missing: missing diagnostic. Got: $diag"
  pass "preflight: missing source reported"

  ######################################################################
  # 3. Preflight: .md suffix pointing at a directory → exit 1.
  ######################################################################
  setup_root
  mkdir -p "$TESTROOT/src/dir-as-md.md"  # directory with .md suffix
  materialize "$preflightWrongKindFilePath" "$TESTROOT/preflight.sh"
  rc=$(bash -c "'$TESTROOT/preflight.sh' >/dev/null 2>&1; echo \$?")
  [ "$rc" = "1" ] || fail "preflight-wrongkind-file: expected exit 1, got $rc"
  diag="$("$TESTROOT/preflight.sh" 2>&1 || true)"
  echo "$diag" | grep -q "expected a file" \
    || fail "preflight-wrongkind-file: wrong diagnostic. Got: $diag"
  pass "preflight: .md-suffix-on-dir rejected"

  ######################################################################
  # 4. Preflight: no-suffix pointing at a file → exit 1.
  ######################################################################
  setup_root
  touch "$TESTROOT/src/file-as-dir"
  materialize "$preflightWrongKindDirPath" "$TESTROOT/preflight.sh"
  rc=$(bash -c "'$TESTROOT/preflight.sh' >/dev/null 2>&1; echo \$?")
  [ "$rc" = "1" ] || fail "preflight-wrongkind-dir: expected exit 1, got $rc"
  diag="$("$TESTROOT/preflight.sh" 2>&1 || true)"
  echo "$diag" | grep -q "expected a directory" \
    || fail "preflight-wrongkind-dir: wrong diagnostic. Got: $diag"
  pass "preflight: no-suffix-on-file rejected"

  ######################################################################
  # 4a. Preflight: .md file with no frontmatter block → error.
  ######################################################################
  setup_root
  printf '# No frontmatter here\nJust body.\n' > "$TESTROOT/src/bare.md"
  materialize "$preflightNoFrontmatterPath" "$TESTROOT/preflight.sh"
  rc=$(bash -c "'$TESTROOT/preflight.sh' >/dev/null 2>&1; echo \$?")
  [ "$rc" = "1" ] || fail "preflight-no-fm: expected exit 1, got $rc"
  diag="$("$TESTROOT/preflight.sh" 2>&1 || true)"
  echo "$diag" | grep -q "missing YAML frontmatter block" \
    || fail "preflight-no-fm: wrong diagnostic. Got: $diag"
  pass "preflight: missing frontmatter rejected"

  ######################################################################
  # 4c. Preflight: frontmatter present but no 'name:' → error.
  ######################################################################
  setup_root
  cat > "$TESTROOT/src/noname.md" <<'EOF'
---
description: Has a description but no name.
---
body
EOF
  materialize "$preflightMissingNamePath" "$TESTROOT/preflight.sh"
  rc=$(bash -c "'$TESTROOT/preflight.sh' >/dev/null 2>&1; echo \$?")
  [ "$rc" = "1" ] || fail "preflight-no-name: expected exit 1, got $rc"
  diag="$("$TESTROOT/preflight.sh" 2>&1 || true)"
  echo "$diag" | grep -q "frontmatter field 'name' missing" \
    || fail "preflight-no-name: wrong diagnostic. Got: $diag"
  pass "preflight: missing 'name' rejected"

  ######################################################################
  # 4d. Preflight: frontmatter present but no 'description:' → error.
  ######################################################################
  setup_root
  cat > "$TESTROOT/src/nodesc.md" <<'EOF'
---
name: nodesc
---
body
EOF
  materialize "$preflightMissingDescriptionPath" "$TESTROOT/preflight.sh"
  rc=$(bash -c "'$TESTROOT/preflight.sh' >/dev/null 2>&1; echo \$?")
  [ "$rc" = "1" ] || fail "preflight-no-desc: expected exit 1, got $rc"
  diag="$("$TESTROOT/preflight.sh" 2>&1 || true)"
  echo "$diag" | grep -q "frontmatter field 'description' missing" \
    || fail "preflight-no-desc: wrong diagnostic. Got: $diag"
  pass "preflight: missing 'description' rejected"

  ######################################################################
  # 4e. Preflight: directory skill without SKILL.md inside → error.
  ######################################################################
  setup_root
  mkdir -p "$TESTROOT/src/hollow-dir"   # no SKILL.md inside
  materialize "$preflightDirNoSkillMdPath" "$TESTROOT/preflight.sh"
  rc=$(bash -c "'$TESTROOT/preflight.sh' >/dev/null 2>&1; echo \$?")
  [ "$rc" = "1" ] || fail "preflight-dir-no-skillmd: expected exit 1, got $rc"
  diag="$("$TESTROOT/preflight.sh" 2>&1 || true)"
  echo "$diag" | grep -q "directory is missing SKILL.md" \
    || fail "preflight-dir-no-skillmd: wrong diagnostic. Got: $diag"
  pass "preflight: dir skill missing SKILL.md rejected"

  ######################################################################
  # 5. Activation: creates expected links for md file + directory skills.
  ######################################################################
  setup_root
  valid_frontmatter "md-skill"  > "$TESTROOT/src/md-skill.md"
  mkdir -p "$TESTROOT/src/dir-skill"
  valid_frontmatter "dir-skill" > "$TESTROOT/src/dir-skill/SKILL.md"
  materialize "$activationPath" "$TESTROOT/activate.sh"
  "$TESTROOT/activate.sh"

  # md-skill → wrapped in a real directory containing a SKILL.md symlink
  linkMd="$TESTROOT/home/.agents/skills/md-skill/SKILL.md"
  [ -L "$linkMd" ] || fail "activation: expected symlink at $linkMd"
  target="$(readlink "$linkMd")"
  [ "$target" = "$TESTROOT/src/md-skill.md" ] \
    || fail "activation: md symlink target wrong: $target"
  grep -q '^name: md-skill$' "$linkMd" \
    || fail "activation: md symlink does not resolve to source content"
  # Parent must be a real directory, not a symlink
  parent="$TESTROOT/home/.agents/skills/md-skill"
  [ -d "$parent" ] && [ ! -L "$parent" ] \
    || fail "activation: md skill parent should be a real directory"
  pass "activation: md-file skill wrapped correctly"

  # dir-skill → direct symlink to the source directory
  linkDir="$TESTROOT/home/.agents/skills/dir-skill"
  [ -L "$linkDir" ] || fail "activation: expected symlink at $linkDir"
  target="$(readlink "$linkDir")"
  [ "$target" = "$TESTROOT/src/dir-skill" ] \
    || fail "activation: dir symlink target wrong: $target"
  [ -f "$linkDir/SKILL.md" ] \
    || fail "activation: dir symlink does not expose SKILL.md"
  pass "activation: directory skill linked correctly"

  ######################################################################
  # 6. Idempotency: running activation again is a no-op.
  ######################################################################
  mtime1=$(stat -c %Y "$linkMd" 2>/dev/null || stat -f %m "$linkMd")
  "$TESTROOT/activate.sh"
  [ "$(readlink "$linkMd")" = "$TESTROOT/src/md-skill.md" ] \
    || fail "idempotency: md link target changed after re-run"
  [ "$(readlink "$linkDir")" = "$TESTROOT/src/dir-skill" ] \
    || fail "idempotency: dir link target changed after re-run"
  pass "activation: idempotent on re-run"

  ######################################################################
  # 7. Self-healing: user deletes a link, next activation restores it.
  ######################################################################
  rm -f "$linkMd"
  rm -f "$linkDir"
  "$TESTROOT/activate.sh"
  [ -L "$linkMd" ] || fail "self-heal: md link not recreated"
  [ -L "$linkDir" ] || fail "self-heal: dir link not recreated"
  pass "activation: heals user-deleted links"

  ######################################################################
  # 8. Self-link safety: if the link path resolves back to the source
  #    (via a stale parent symlink from a prior config), the script must
  #    NOT overwrite the source with a self-link.
  #
  #    Layout: the agentRoot/selfy is a symlink into src/, so
  #            agentRoot/selfy/SKILL.md resolves to src/selfy.md itself.
  ######################################################################
  setup_root
  mkdir -p "$TESTROOT/src/selfy-dir"
  echo "original" > "$TESTROOT/src/selfy-dir/SKILL.md"
  # Give the activation a file source named selfy.md that is the same
  # inode as what agentRoot/selfy/SKILL.md will resolve to via stale link.
  ln -s "$TESTROOT/src/selfy-dir/SKILL.md" "$TESTROOT/src/selfy.md"
  # Stale symlink leftover from a previous "directory" config:
  ln -s "$TESTROOT/src/selfy-dir" "$TESTROOT/home/.agents/skills/selfy"

  materialize "$selfLinkActivationPath" "$TESTROOT/activate-self.sh"
  "$TESTROOT/activate-self.sh"

  # The source must still hold its original contents.
  [ -f "$TESTROOT/src/selfy-dir/SKILL.md" ] \
    || fail "self-link: source file was destroyed"
  [ "$(cat "$TESTROOT/src/selfy-dir/SKILL.md")" = "original" ] \
    || fail "self-link: source content was mutated"
  # The stale symlink must have been removed (replaced with a real dir).
  [ -d "$TESTROOT/home/.agents/skills/selfy" ] \
    && [ ! -L "$TESTROOT/home/.agents/skills/selfy" ] \
    || fail "self-link: stale parent symlink was not replaced by a real dir"
  pass "activation: safe against self-link (source preserved)"

  echo ""
  echo "All localSkills checks passed."
  touch "$out"
''
