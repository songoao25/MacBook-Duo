#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
TEST_DIR="$PROJECT_DIR/.test-build"
TEST_BINARY="$TEST_DIR/PermissionPreparationTests"

mkdir -p "$TEST_DIR"

swiftc \
  -Onone \
  -framework Foundation \
  -framework Security \
  -o "$TEST_BINARY" \
  "$PROJECT_DIR/Sources/ScreenCapturePermissionPreparation.swift" \
  "$PROJECT_DIR/Tests/PermissionPreparationTests.swift"

"$TEST_BINARY"
