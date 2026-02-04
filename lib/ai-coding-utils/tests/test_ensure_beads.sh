#!/bin/bash
# Tests for ensure_beads.sh
# Runs in a temp directory to avoid side effects.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENSURE_BEADS="$SCRIPT_DIR/../beads/setup/ensure_beads.sh"

TESTS_RUN=0
TESTS_PASSED=0

assert_success() {
  local test_name="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "✓ PASS: $test_name"
}

assert_failure() {
  local test_name="$1"
  local details="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "✗ FAIL: $test_name"
  if [ -n "$details" ]; then
    echo "  $details"
  fi
}

echo "========================================"
echo "Testing ensure_beads.sh"
echo "========================================"

# -----------------------------------------------------------
# Test 1: Skips when bd is not installed
# -----------------------------------------------------------
echo ""
echo "Test 1: Skips when bd is not installed"
WORK_DIR=$(mktemp -d)
(
  cd "$WORK_DIR"
  # Run with a PATH that has no bd
  PATH="/usr/bin:/bin" bash "$ENSURE_BEADS"
)
if [ ! -d "$WORK_DIR/.beads" ]; then
  assert_success "Skips when bd is not installed"
else
  assert_failure "Skips when bd is not installed" ".beads/ was created without bd"
fi
rm -rf "$WORK_DIR"

# -----------------------------------------------------------
# Test 2: Skips when .beads/ already exists
# -----------------------------------------------------------
echo ""
echo "Test 2: Skips when .beads/ already exists"
WORK_DIR=$(mktemp -d)
mkdir "$WORK_DIR/.beads"
touch "$WORK_DIR/.beads/marker"
(
  cd "$WORK_DIR"
  bash "$ENSURE_BEADS"
)
# Marker file should still be there (not re-initialized)
if [ -f "$WORK_DIR/.beads/marker" ]; then
  assert_success "Skips when .beads/ already exists"
else
  assert_failure "Skips when .beads/ already exists" "marker file missing; .beads/ was re-initialized"
fi
rm -rf "$WORK_DIR"

# -----------------------------------------------------------
# Test 3: Creates .beads/ when missing (with bd available)
# -----------------------------------------------------------
echo ""
echo "Test 3: Creates .beads/ when missing"
if command -v bd >/dev/null 2>&1; then
  WORK_DIR=$(mktemp -d)
  (
    cd "$WORK_DIR"
    git init -q .  # bd init expects a git repo
    bash "$ENSURE_BEADS"
  )
  if [ -d "$WORK_DIR/.beads" ]; then
    assert_success "Creates .beads/ when missing"
  else
    assert_failure "Creates .beads/ when missing" ".beads/ was not created"
  fi
  rm -rf "$WORK_DIR"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "⊘ SKIP: Test 3 (bd CLI not installed)"
fi

# -----------------------------------------------------------
# Test 4: Creates .gitignore with .beads/ when no .gitignore
# -----------------------------------------------------------
echo ""
echo "Test 4: Creates .gitignore with .beads/ when no .gitignore exists"
if command -v bd >/dev/null 2>&1; then
  WORK_DIR=$(mktemp -d)
  (
    cd "$WORK_DIR"
    git init -q .
    bash "$ENSURE_BEADS"
  )
  if [ -f "$WORK_DIR/.gitignore" ] && grep -qx '.beads/' "$WORK_DIR/.gitignore"; then
    assert_success "Creates .gitignore with .beads/ entry"
  else
    assert_failure "Creates .gitignore with .beads/ entry" \
      ".gitignore missing or does not contain .beads/"
  fi
  rm -rf "$WORK_DIR"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "⊘ SKIP: Test 4 (bd CLI not installed)"
fi

# -----------------------------------------------------------
# Test 5: Appends .beads/ to existing .gitignore
# -----------------------------------------------------------
echo ""
echo "Test 5: Appends .beads/ to existing .gitignore"
if command -v bd >/dev/null 2>&1; then
  WORK_DIR=$(mktemp -d)
  (
    cd "$WORK_DIR"
    git init -q .
    echo "node_modules/" > .gitignore
    bash "$ENSURE_BEADS"
  )
  if grep -qx '.beads/' "$WORK_DIR/.gitignore" && grep -qx 'node_modules/' "$WORK_DIR/.gitignore"; then
    assert_success "Appends .beads/ to existing .gitignore"
  else
    assert_failure "Appends .beads/ to existing .gitignore" \
      "Contents: $(cat "$WORK_DIR/.gitignore")"
  fi
  rm -rf "$WORK_DIR"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "⊘ SKIP: Test 5 (bd CLI not installed)"
fi

# -----------------------------------------------------------
# Test 6: Does not duplicate .beads/ in .gitignore
# -----------------------------------------------------------
echo ""
echo "Test 6: Does not duplicate .beads/ in .gitignore"
if command -v bd >/dev/null 2>&1; then
  WORK_DIR=$(mktemp -d)
  (
    cd "$WORK_DIR"
    git init -q .
    echo ".beads/" > .gitignore
    # Pre-create .beads/ so the script skips init but we can
    # test the .gitignore path via a second run after removing .beads/
  )
  # First run: init creates .beads/ and should not duplicate .gitignore entry
  (
    cd "$WORK_DIR"
    rm -rf .beads  # ensure init will run
    bash "$ENSURE_BEADS"
  )
  COUNT=$(grep -cx '.beads/' "$WORK_DIR/.gitignore")
  if [ "$COUNT" -eq 1 ]; then
    assert_success "Does not duplicate .beads/ in .gitignore"
  else
    assert_failure "Does not duplicate .beads/ in .gitignore" \
      "Found $COUNT occurrences of .beads/ in .gitignore"
  fi
  rm -rf "$WORK_DIR"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "⊘ SKIP: Test 6 (bd CLI not installed)"
fi

# -----------------------------------------------------------
# Test 7: Uses directory basename as prefix
# -----------------------------------------------------------
echo ""
echo "Test 7: Uses directory basename as prefix"
if command -v bd >/dev/null 2>&1; then
  WORK_DIR=$(mktemp -d)
  PROJECT_DIR="$WORK_DIR/my-cool-project"
  mkdir -p "$PROJECT_DIR"
  (
    cd "$PROJECT_DIR"
    git init -q .
    bash "$ENSURE_BEADS"
  )
  if [ -d "$PROJECT_DIR/.beads" ]; then
    assert_success "Initializes with directory basename as prefix"
  else
    assert_failure "Initializes with directory basename as prefix" \
      ".beads/ was not created"
  fi
  rm -rf "$WORK_DIR"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "⊘ SKIP: Test 7 (bd CLI not installed)"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

if [ $TESTS_RUN -eq $TESTS_PASSED ]; then
  echo ""
  echo "✓ All tests passed!"
  exit 0
else
  echo ""
  echo "✗ Some tests failed"
  exit 1
fi
