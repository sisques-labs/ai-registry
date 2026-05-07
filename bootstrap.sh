#!/usr/bin/env bash
# =============================================================================
# ai-registry — Bootstrap Installer
#
# One-liner to install ai-registry into the current project:
#
#   curl -fsSL https://raw.githubusercontent.com/sisques-labs/ai-registry/main/bootstrap.sh | bash
#
# Or if you want a specific level/target:
#
#   curl -fsSL https://raw.githubusercontent.com/sisques-labs/ai-registry/main/bootstrap.sh | bash -s -- --user
#   curl -fsSL https://raw.githubusercontent.com/sisques-labs/ai-registry/main/bootstrap.sh | bash -s -- --tool claude
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/sisques-labs/ai-registry.git"
TEMP_DIR=""

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

main() {
  echo "==> Bootstrapping ai-registry..."
  echo ""

  # Create a temp directory for cloning
  TEMP_DIR="$(mktemp -d)"
  echo "  Cloning registry..."
  git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null || {
    echo "  ✗ Failed to clone. Check your internet connection and access to $REPO_URL"
    exit 1
  }

  echo "  Running installer..."
  echo ""
  bash "$TEMP_DIR/install.sh" all "$@"
}

main "$@"
