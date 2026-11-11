#!/usr/bin/env bash
# Seed payment-api CD demo resources and run mixed success/fail executions.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/harness_api.sh
source "${ROOT_DIR}/lib/harness_api.sh"

SKIP_RUNS="${SKIP_RUNS:-false}"
WAIT_TIMEOUT_S="${WAIT_TIMEOUT_S:-300}"

harness_init

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required for pipeline execution polling" >&2
  exit 1
fi

echo "payment-api deployments seed"
echo "  account: ${ACCOUNT_ID}"
echo "  org:     ${ORG_ID}"
echo "  project: ${PROJECT_ID}"
echo "  base:    ${HARNESS_BASE_URL}"
echo

echo "Upserting connector..."
upsert_connector_json "workshop_k8s" "${ROOT_DIR}/connectors/workshop_k8s.json"

echo
echo "Upserting service..."
upsert_service "payment_api" "${ROOT_DIR}/services/payment_api.yaml" "payment-api"

echo
echo "Upserting environments..."
upsert_environment "qa" "${ROOT_DIR}/environments/qa.yaml" "QA" "PreProduction"
upsert_environment "prod" "${ROOT_DIR}/environments/prod.yaml" "Prod" "Production"

echo
echo "Upserting infrastructures..."
upsert_infrastructure "qa_infra" "qa" "${ROOT_DIR}/infrastructures/qa_infra.yaml" "QA K8s"
upsert_infrastructure "prod_infra" "prod" "${ROOT_DIR}/infrastructures/prod_infra.yaml" "Prod K8s"

echo
echo "Upserting pipelines..."
upsert_pipeline "payment_api_prod_deploy" "${ROOT_DIR}/pipelines/payment_api_prod_deploy.yaml"
upsert_pipeline "payment_api_qa_deploy" "${ROOT_DIR}/pipelines/payment_api_qa_deploy.yaml"
upsert_pipeline "payment_api_hotfix" "${ROOT_DIR}/pipelines/payment_api_hotfix.yaml"

run_one() {
  local pipeline_id="$1"
  local should_fail="$2"
  local sleep_seconds="$3"
  local plan_id status
  local input_yaml

  input_yaml="$(cat <<EOF
pipeline:
  identifier: ${pipeline_id}
  variables:
    - name: should_fail
      type: String
      value: "${should_fail}"
    - name: sleep_seconds
      type: String
      value: "${sleep_seconds}"
EOF
)"

  plan_id="$(execute_pipeline "${pipeline_id}" "${input_yaml}")"
  status="$(wait_for_execution "${plan_id}" "${WAIT_TIMEOUT_S}")"
  echo "    finished: ${pipeline_id} -> ${status} (should_fail=${should_fail}, sleep=${sleep_seconds}s)"
}

if [[ "${SKIP_RUNS}" == "true" ]]; then
  echo
  echo "SKIP_RUNS=true — resources created, executions skipped."
else
  echo
  echo "Running seed executions (requires a delegate with selector 'workshop')..."
  # Prod failures + one longer failing stage (duration signal)
  run_one "payment_api_prod_deploy" "true" "3"
  run_one "payment_api_prod_deploy" "true" "12"
  run_one "payment_api_prod_deploy" "false" "4"
  # QA mix
  run_one "payment_api_qa_deploy" "false" "2"
  run_one "payment_api_qa_deploy" "true" "2"
  # Second prod pipeline (lower fail rate, longer success)
  run_one "payment_api_hotfix" "false" "10"
  run_one "payment_api_hotfix" "false" "6"
fi

echo
echo "Done. Next steps:"
echo "  1. Confirm a delegate is tagged with selector: workshop"
echo "  2. Open Deployments / Pipelines execution history for payment-api"
echo "  3. Ask Harness AI:"
echo "       - Which services experienced deployment failures in Production during the last seven days?"
echo "       - Which pipelines have the highest failure rate?"
echo "       - Which deployment stages consistently have the longest execution duration across Production deployments?"
echo
echo "Tip: SKIP_RUNS=true ./seed.sh seeds resources only."
echo "     WAIT_TIMEOUT_S=600 ./seed.sh waits longer for slow delegates."
