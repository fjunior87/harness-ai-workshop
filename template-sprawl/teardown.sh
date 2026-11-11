#!/usr/bin/env bash
# Remove workshop-seeded pipelines (first) then templates.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/harness_api.sh
source "${ROOT_DIR}/lib/harness_api.sh"

harness_init

echo "Template Sprawl teardown"
echo "  account: ${ACCOUNT_ID}"
echo "  org:     ${ORG_ID}"
echo "  project: ${PROJECT_ID}"
echo

PIPELINES=(
  "payments_release_pipeline"
  "risk_change_pipeline"
  "ops_release_pipeline"
  "platform_prod_pipeline"
  "sre_deploy_pipeline"
)

TEMPLATES=(
  "payments_manual_approval"
  "risk_change_approval"
  "ops_release_gate"
  "platform_prod_approval"
  "sre_deploy_approval_v2"
)

echo "Deleting pipelines..."
for id in "${PIPELINES[@]}"; do
  delete_pipeline "${id}"
done

echo
echo "Deleting templates..."
for id in "${TEMPLATES[@]}"; do
  delete_template "${id}" "1"
done

echo
echo "Teardown complete."
