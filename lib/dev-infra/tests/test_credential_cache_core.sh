#!/bin/bash
# Test core credential cache framework functions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the credential cache component
source "$PROJECT_ROOT/components/credential_cache.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Helper function to run tests
assert_equals() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    echo "✓ PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "✗ FAIL: $test_name"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
  fi
}

assert_success() {
  local test_name="$1"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo "✓ PASS: $test_name"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

assert_contains() {
  local substring="$1"
  local string="$2"
  local test_name="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$string" == *"$substring"* ]]; then
    echo "✓ PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "✗ FAIL: $test_name"
    echo "  Expected to contain: $substring"
    echo "  Actual: $string"
  fi
}

echo "========================================"
echo "Testing Core Framework Functions"
echo "========================================"

# Test 1: get_workspace_root returns a valid path
echo ""
echo "Test 1: get_workspace_root returns valid path"
WORKSPACE_ROOT=$(get_workspace_root)
if [ -n "$WORKSPACE_ROOT" ] && [ -d "$WORKSPACE_ROOT" ]; then
  assert_success "get_workspace_root returns valid directory"
else
  echo "✗ FAIL: get_workspace_root returns valid directory"
  echo "  Returned: $WORKSPACE_ROOT"
fi

# Test 2: AUTH_DIR is set correctly
echo ""
echo "Test 2: AUTH_DIR is set correctly"
EXPECTED_AUTH_DIR="${WORKSPACE_ROOT}/temp/auth"
assert_equals "$EXPECTED_AUTH_DIR" "$AUTH_DIR" "AUTH_DIR matches expected path"

# Test 3: setup_credential_cache with no services (should succeed)
echo ""
echo "Test 3: setup_credential_cache with no services"
if setup_credential_cache; then
  assert_success "setup_credential_cache with no args succeeds"
else
  echo "✗ FAIL: setup_credential_cache with no args should succeed"
fi

# Test 4: setup_credential_cache creates AUTH_DIR
echo ""
echo "Test 4: setup_credential_cache creates AUTH_DIR"
rm -rf "$AUTH_DIR"  # Clean first
setup_credential_cache >/dev/null 2>&1
if [ -d "$AUTH_DIR" ]; then
  assert_success "setup_credential_cache creates AUTH_DIR"
else
  echo "✗ FAIL: setup_credential_cache should create AUTH_DIR"
fi

# Test 5: setup_credential_cache with unknown service (should warn but succeed)
echo ""
echo "Test 5: setup_credential_cache with unknown service"
OUTPUT=$(setup_credential_cache "unknown_service" 2>&1)
if echo "$OUTPUT" | grep -q "Unknown service: unknown_service"; then
  assert_success "setup_credential_cache warns about unknown service"
else
  echo "✗ FAIL: setup_credential_cache should warn about unknown service"
  echo "  Output: $OUTPUT"
fi

# Test 6: setup_credential_cache returns 0 even with unknown service
echo ""
echo "Test 6: setup_credential_cache returns 0 with unknown service"
if setup_credential_cache "unknown_service" >/dev/null 2>&1; then
  assert_success "setup_credential_cache returns 0 with unknown service"
else
  echo "✗ FAIL: setup_credential_cache should return 0 even with unknown service"
fi

# Test 7: setup_credential_cache calls service function when it exists
echo ""
echo "Test 7: setup_credential_cache calls service function when defined"
# Define a mock service function
setup_mock_service_auth() {
  echo "mock_service_called"
  return 0
}
OUTPUT=$(setup_credential_cache "mock_service" 2>&1)
if echo "$OUTPUT" | grep -q "mock_service_called"; then
  assert_success "setup_credential_cache calls service setup function"
else
  echo "✗ FAIL: setup_credential_cache should call service setup function"
  echo "  Output: $OUTPUT"
fi

# Test 8: setup_credential_cache handles failing service function
echo ""
echo "Test 8: setup_credential_cache handles failing service function"
# Define a failing mock service function
setup_failing_service_auth() {
  return 1
}
OUTPUT=$(setup_credential_cache "failing_service" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -q "Some credentials not configured"; then
  assert_success "setup_credential_cache handles failing service gracefully"
else
  echo "✗ FAIL: setup_credential_cache should handle failing service gracefully"
  echo "  Exit code: $EXIT_CODE (expected 0)"
  echo "  Output: $OUTPUT"
fi

# Test 9: Multiple services - mix of valid and invalid
echo ""
echo "Test 9: Multiple services (mixed valid/invalid)"
setup_valid1_auth() {
  return 0
}
setup_valid2_auth() {
  return 0
}
OUTPUT=$(setup_credential_cache "valid1" "invalid" "valid2" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  assert_success "setup_credential_cache handles multiple mixed services"
else
  echo "✗ FAIL: setup_credential_cache should handle multiple mixed services"
  echo "  Exit code: $EXIT_CODE (expected 0)"
fi

# Test 10: setup_claude_auth function exists and is callable
echo ""
echo "Test 10: setup_claude_auth function exists"
if declare -f setup_claude_auth >/dev/null 2>&1; then
  assert_success "setup_claude_auth function is defined"
else
  echo "✗ FAIL: setup_claude_auth function should be defined"
  TESTS_RUN=$((TESTS_RUN + 1))
fi

# Test 11: setup_credential_cache invokes claude auth
echo ""
echo "Test 11: setup_credential_cache invokes claude service"
OUTPUT=$(setup_credential_cache "claude" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  assert_success "setup_credential_cache handles claude service"
else
  echo "✗ FAIL: setup_credential_cache should handle claude service"
  echo "  Exit code: $EXIT_CODE"
  TESTS_RUN=$((TESTS_RUN + 1))
fi

# Test 12: setup_claude_auth returns 0 (non-blocking)
echo ""
echo "Test 12: setup_claude_auth returns 0 (non-blocking)"
setup_claude_auth >/dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  assert_success "setup_claude_auth returns 0"
else
  echo "✗ FAIL: setup_claude_auth should return 0"
  echo "  Exit code: $EXIT_CODE"
  TESTS_RUN=$((TESTS_RUN + 1))
fi

# Test 13: setup_claude_auth with ANTHROPIC_API_KEY (no cached creds)
echo ""
echo "Test 13: setup_claude_auth with ANTHROPIC_API_KEY"
FAKE_HOME=$(mktemp -d)
ANTHROPIC_API_KEY="test-key" HOME="$FAKE_HOME" OUTPUT=$(setup_claude_auth 2>&1)
if echo "$OUTPUT" | grep -q "ANTHROPIC_API_KEY detected"; then
  assert_success "setup_claude_auth detects ANTHROPIC_API_KEY"
else
  echo "✗ FAIL: setup_claude_auth should detect ANTHROPIC_API_KEY"
  echo "  Output: $OUTPUT"
  TESTS_RUN=$((TESTS_RUN + 1))
fi
rm -rf "$FAKE_HOME"

# Cleanup
rm -rf "$AUTH_DIR"

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
