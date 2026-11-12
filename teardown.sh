#!/usr/bin/env bash
# Single entry point: tear down all workshop labs (reverse order).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo " Workshop teardown (all labs)"
echo "========================================"
echo

echo ">>> Lab 3/3 teardown: analyze-error"
echo
"${ROOT_DIR}/analyze-error/teardown.sh"

echo
echo ">>> Lab 2/3 teardown: payment-api-deployments"
echo
"${ROOT_DIR}/payment-api-deployments/teardown.sh"

echo
echo ">>> Lab 1/3 teardown: template-sprawl"
echo
"${ROOT_DIR}/template-sprawl/teardown.sh"

echo
echo "========================================"
echo " All workshop labs removed."
echo "========================================"
