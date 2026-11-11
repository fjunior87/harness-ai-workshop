#!/usr/bin/env bash
# Seed near-duplicate HarnessApproval templates + pipelines for the template-sprawl lab.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/harness_api.sh
source "${ROOT_DIR}/lib/harness_api.sh"

harness_init

echo "Template Sprawl seed"
echo "  account: ${ACCOUNT_ID}"
echo "  org:     ${ORG_ID}"
echo "  project: ${PROJECT_ID}"
echo "  base:    ${HARNESS_BASE_URL}"
echo

TEMPLATES=(
  "payments_manual_approval"
  "risk_change_approval"
  "ops_release_gate"
  "platform_prod_approval"
  "sre_deploy_approval_v2"
)

PIPELINES=(
  "payments_release_pipeline"
  "risk_change_pipeline"
  "ops_release_pipeline"
  "platform_prod_pipeline"
  "sre_deploy_pipeline"
)

echo "Upserting templates..."
for id in "${TEMPLATES[@]}"; do
  upsert_template "${id}" "${ROOT_DIR}/templates/${id}.yaml" "1"
done

echo
echo "Upserting pipelines..."
for id in "${PIPELINES[@]}"; do
  upsert_pipeline "${id}" "${ROOT_DIR}/pipelines/${id}.yaml"
done

echo
echo "Done. Next steps:"
echo "  1. Open your project → Templates (Template Library)"
echo "  2. Filter/search tag workshop:template-sprawl or purpose:change-approval"
echo "  3. Open Pipelines and note each team pipeline binds a different approval template"
echo "  4. Use Harness AI with the prompts in README.md (same AI entry as earlier in the workshop)"
echo
echo "UI hint: Project → Templates → look for five HarnessApproval step templates from payments/risk/ops/platform/sre."
