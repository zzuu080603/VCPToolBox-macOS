#!/bin/bash
# Regression tests for this repository's update scripts (Issue #1).
#
# The tests run the real update.sh / update_no_dep.sh against real Git
# repositories (a local bare "origin"), so the asserted contract is the actual
# remote-pull path a macOS user exercises, not a mock of it.
#
# Usage: bash test_update_scripts.sh
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
NO_DEP="$ROOT/update_no_dep.sh"
WITH_DEP="$ROOT/update.sh"

# Keep the tests independent from the machine's global/system Git config.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

PASS=0
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { PASS=$((PASS + 1)); echo "ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

assert() { # assert <description> <exit-status>
    if [ "$2" -eq 0 ]; then pass "$1"; else fail "$1"; fi
}
assert_nonzero() { # assert_nonzero <description> <exit-status>
    if [ "$2" -ne 0 ]; then pass "$1"; else fail "$1"; fi
}
file_has() { # file_has <description> <file> <needle>
    if grep -qF -- "$3" "$2" 2>/dev/null; then pass "$1"; else fail "$1 (missing: $3)"; fi
}
file_lacks() { # file_lacks <description> <file> <needle>
    if grep -qF -- "$3" "$2" 2>/dev/null; then fail "$1 (unexpected: $3)"; else pass "$1"; fi
}
content_is() { # content_is <description> <file> <expected>
    if [ "$(cat "$2" 2>/dev/null)" = "$3" ]; then pass "$1"; else fail "$1"; fi
}

git_identity() { # git_identity <dir>
    git -C "$1" config user.name tester
    git -C "$1" config user.email tester@example.com
    git -C "$1" config commit.gpgsign false
}

setup_repo() { # setup_repo <name> [with-requirements]
    local name="$1"
    REMOTE="$TMP/$name.git"
    CLONE="$TMP/$name"
    git init -q --bare "$REMOTE"
    git -C "$REMOTE" symbolic-ref HEAD refs/heads/master
    git clone -q "$REMOTE" "$CLONE" 2>/dev/null
    git -C "$CLONE" symbolic-ref HEAD refs/heads/master
    git_identity "$CLONE"
    echo "v1" > "$CLONE/code.txt"
    git -C "$CLONE" add code.txt
    git -C "$CLONE" commit -qm "init"
    if [ "${2:-}" = "with-requirements" ]; then
        mkdir -p "$CLONE/Plugin/SciCalculator" "$CLONE/Plugin/VideoGenerator"
        echo "sympy" > "$CLONE/Plugin/SciCalculator/requirements.txt"
        echo "numpy" > "$CLONE/Plugin/VideoGenerator/requirements.txt"
        git -C "$CLONE" add Plugin
        git -C "$CLONE" commit -qm "plugins"
    fi
    git -C "$CLONE" push -q -u origin master
}

advance_remote() { # advance_remote <name> <new-content>
    local name="$1" work="$TMP/$1-push"
    rm -rf "$work"
    git clone -q "$REMOTE" "$work"
    git_identity "$work"
    echo "$2" > "$work/code.txt"
    git -C "$work" add code.txt
    git -C "$work" commit -qm "advance"
    git -C "$work" push -q origin master
}

make_fake_tools() { # make_fake_tools <bindir> <fail-command|none>
    local bindir="$1" fail_on="${2:-none}"
    mkdir -p "$bindir"
    cat > "$bindir/pip3" <<'SH'
#!/bin/bash
echo "$PWD" >> "$FAKE_LOG"
exit 0
SH
    cat > "$bindir/npm" <<'SH'
#!/bin/bash
echo "$PWD" >> "$FAKE_LOG"
if [ "${FAKE_NPM_FAIL:-0}" = "1" ]; then exit 1; fi
exit 0
SH
    chmod +x "$bindir/pip3" "$bindir/npm"
    if [ "$fail_on" = "npm" ]; then export FAKE_NPM_FAIL=1; else export FAKE_NPM_FAIL=0; fi
}

echo "# update_no_dep.sh / update.sh regression tests"

# --- 1. fast-forward to the latest code ------------------------------------
setup_repo t1
cp "$NO_DEP" "$CLONE/update_no_dep.sh"
advance_remote t1 "v2"
( cd "$TMP" && bash "$CLONE/update_no_dep.sh" ) > "$TMP/t1.out" 2>&1
rc=$?
assert "1a update_no_dep.sh exits 0 after fast-forward" "$rc"
content_is "1b working tree has the latest code (v2)" "$CLONE/code.txt" "v2"
file_has "1c reports Update complete" "$TMP/t1.out" "Update complete."

# --- 2. already up to date -------------------------------------------------
( cd / && bash "$CLONE/update_no_dep.sh" ) > "$TMP/t2.out" 2>&1
rc=$?
assert "2a still exits 0 when already up to date" "$rc"
content_is "2b code unchanged" "$CLONE/code.txt" "v2"
file_has "2c reports Update complete" "$TMP/t2.out" "Update complete."

# --- 3. dirty tree must fail loudly, not fake success ----------------------
advance_remote t1 "v3"
echo "dirty" > "$CLONE/code.txt"
( cd "$TMP" && bash "$CLONE/update_no_dep.sh" ) > "$TMP/t3.out" 2>&1
rc=$?
assert_nonzero "3a dirty tree exits non-zero" "$rc"
file_has "3b explains the failure" "$TMP/t3.out" "Update failed"
file_lacks "3c does not print Update complete" "$TMP/t3.out" "Update complete."
content_is "3d keeps the local modification" "$CLONE/code.txt" "dirty"
git -C "$CLONE" checkout -q -- code.txt

# --- 4. running outside a Git repository must fail loudly ------------------
mkdir -p "$TMP/not-a-repo"
cp "$NO_DEP" "$TMP/not-a-repo/update_no_dep.sh"
( cd "$TMP" && bash "$TMP/not-a-repo/update_no_dep.sh" ) > "$TMP/t4.out" 2>&1
rc=$?
assert_nonzero "4a non-Git directory exits non-zero" "$rc"
file_has "4b says it is not a Git working tree" "$TMP/t4.out" "not a Git working tree"
file_lacks "4c does not print Update complete" "$TMP/t4.out" "Update complete."

# --- 5. update.sh pulls and installs deps from the repo root ---------------
setup_repo t5 with-requirements
cp "$WITH_DEP" "$CLONE/update.sh"
advance_remote t5 "v2"
FAKEBIN="$TMP/fakebin-ok"
make_fake_tools "$FAKEBIN" none
export FAKE_LOG="$TMP/fake-ok.log"
rm -f "$FAKE_LOG"
( cd "$TMP" && PATH="$FAKEBIN:$PATH" bash "$CLONE/update.sh" ) > "$TMP/t5.out" 2>&1
rc=$?
assert "5a update.sh exits 0" "$rc"
content_is "5b working tree has the latest code (v2)" "$CLONE/code.txt" "v2"
file_has "5c pip3 ran inside Plugin/SciCalculator" "$FAKE_LOG" "$CLONE/Plugin/SciCalculator"
file_has "5d pip3 ran inside Plugin/VideoGenerator" "$FAKE_LOG" "$CLONE/Plugin/VideoGenerator"
file_has "5e npm ran in the repository root" "$FAKE_LOG" "$CLONE"
file_has "5f reports Update complete" "$TMP/t5.out" "Update complete."

# --- 6. a failing dependency step still reports the successful pull --------
setup_repo t6 with-requirements
cp "$WITH_DEP" "$CLONE/update.sh"
advance_remote t6 "v2"
FAKEBIN_FAIL="$TMP/fakebin-fail"
make_fake_tools "$FAKEBIN_FAIL" npm
export FAKE_LOG="$TMP/fake-fail.log"
rm -f "$FAKE_LOG"
( cd "$TMP" && PATH="$FAKEBIN_FAIL:$PATH" bash "$CLONE/update.sh" ) > "$TMP/t6.out" 2>&1
rc=$?
assert_nonzero "6a failing npm exits non-zero" "$rc"
content_is "6b the pull still happened (v2)" "$CLONE/code.txt" "v2"
file_has "6c reports the dependency failure" "$TMP/t6.out" "dependency steps failed"
file_lacks "6d does not print Update complete" "$TMP/t6.out" "Update complete."

# --- 7. update.sh fails fast before dependencies on a dirty tree -----------
setup_repo t7 with-requirements
cp "$WITH_DEP" "$CLONE/update.sh"
advance_remote t7 "v2"
echo "dirty" > "$CLONE/code.txt"
FAKEBIN_T7="$TMP/fakebin-t7"
make_fake_tools "$FAKEBIN_T7" none
export FAKE_LOG="$TMP/fake-t7.log"
rm -f "$FAKE_LOG"
( cd "$TMP" && PATH="$FAKEBIN_T7:$PATH" bash "$CLONE/update.sh" ) > "$TMP/t7.out" 2>&1
rc=$?
assert_nonzero "7a dirty tree exits non-zero" "$rc"
file_has "7b explains the failure" "$TMP/t7.out" "Update failed"
if [ -s "$FAKE_LOG" ]; then fail "7c dependency steps were not run"; else pass "7c dependency steps were not run"; fi

# --- summary ---------------------------------------------------------------
echo
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
    echo "TESTS FAILED"
    exit 1
fi
echo "TESTS PASSED"
exit 0
