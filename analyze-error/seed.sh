#!/usr/bin/env bash
# Seed the Analyze Error lab pipeline and run it once (expected to Fail).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/harness_api.sh
source "${ROOT_DIR}/lib/harness_api.sh"

SKIP_RUNS="${SKIP_RUNS:-false}"
WAIT_TIMEOUT_S="${WAIT_TIMEOUT_S:-180}"

harness_init

if [[ "${SKIP_RUNS}" != "true" ]] && ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required for pipeline execution polling" >&2
  exit 1
fi

echo "analyze-error seed"
echo "  account: ${ACCOUNT_ID}"
echo "  org:     ${ORG_ID}"
echo "  project: ${PROJECT_ID}"
echo

echo "Upserting pipeline..."
upsert_pipeline "fixme_shell_pipeline" "${ROOT_DIR}/pipelines/fixme_shell_pipeline.yaml"

if [[ "${SKIP_RUNS}" == "true" ]]; then
  echo
  echo "SKIP_RUNS=true — pipeline created, execution skipped."
else
  echo
  echo "Running fixme_shell_pipeline once (expected status: Failed)..."
  plan_id="$(execute_pipeline "fixme_shell_pipeline")"
  status="$(wait_for_execution "${plan_id}" "${WAIT_TIMEOUT_S}")"
  echo "  finished: fixme_shell_pipeline -> ${status}"
  if [[ "${status}" != "Failed" ]]; then
    echo "warn: expected Failed (sllep typo); got ${status}. Check delegate availability." >&2
  fi
fi

echo
echo "Done. Lab pipeline: fixme_shell_pipeline"
echo "  1. Open the failed execution → Analyze Error"
echo "  2. Ask Chat: Why did this step fail, and what is the smallest fix?"
echo "  3. Use Help me fix the pipeline yaml, review the diff, accept"
echo "  4. Rerun and confirm it passes"
echo
echo "Facilitator note: intended fix is changing 'sllep' → 'sleep' in the ShellScript."
