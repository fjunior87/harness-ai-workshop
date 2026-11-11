#!/usr/bin/env bash
# Single entry point: seed all workshop labs into the target Harness project.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo " Workshop seed (all labs)"
echo "========================================"
echo

echo ">>> Lab 1/2: template-sprawl"
echo
"${ROOT_DIR}/template-sprawl/seed.sh"

echo
echo ">>> Lab 2/2: payment-api-deployments"
echo
"${ROOT_DIR}/payment-api-deployments/seed.sh"

echo
echo "========================================"
echo " All workshop labs seeded."
echo "========================================"
echo "Individual labs (optional):"
echo "  ${ROOT_DIR}/template-sprawl/seed.sh"
echo "  ${ROOT_DIR}/payment-api-deployments/seed.sh"
echo "Teardown all: ${ROOT_DIR}/teardown.sh"
