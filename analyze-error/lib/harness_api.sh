#!/usr/bin/env bash
# Minimal helpers for analyze-error lab (pipeline upsert/delete only).

set -euo pipefail

require_env() {
  local missing=0
  local var
  for var in MY_HARNESS_ACCOUNT MY_HARNESS_ORG MY_HARNESS_PROJECT MY_HARNESS_SAT; do
    if [[ -z "${!var:-}" ]]; then
      echo "error: missing required env var: ${var}" >&2
      missing=1
    fi
  done
  if [[ "${missing}" -ne 0 ]]; then
    echo "Set MY_HARNESS_ACCOUNT, MY_HARNESS_ORG, MY_HARNESS_PROJECT, MY_HARNESS_SAT and retry." >&2
    exit 1
  fi
}

harness_init() {
  require_env
  HARNESS_BASE_URL="${MY_HARNESS_BASE_URL:-https://app.harness.io}"
  HARNESS_BASE_URL="${HARNESS_BASE_URL%/}"
  ACCOUNT_ID="${MY_HARNESS_ACCOUNT}"
  ORG_ID="${MY_HARNESS_ORG}"
  PROJECT_ID="${MY_HARNESS_PROJECT}"
  API_KEY="${MY_HARNESS_SAT}"
  SCOPE_QS="accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}"
}

harness_curl() {
  local method="$1"
  local url="$2"
  shift 2
  curl -sS -X "${method}" "${url}" \
    -H "x-api-key: ${API_KEY}" \
    -H "Harness-Account: ${ACCOUNT_ID}" \
    "$@"
}

http_code_of() {
  local body="$1"
  echo "${body}" | tail -n 1
}

body_of() {
  local body="$1"
  echo "${body}" | sed '$d'
}

render_yaml() {
  local file="$1"
  sed \
    -e "s/__ORG_IDENTIFIER__/${ORG_ID}/g" \
    -e "s/__PROJECT_IDENTIFIER__/${PROJECT_ID}/g" \
    "${file}"
}

pipeline_exists() {
  local identifier="$1"
  local url="${HARNESS_BASE_URL}/pipeline/api/pipelines/${identifier}?${SCOPE_QS}"
  local resp code
  resp="$(harness_curl GET "${url}" -w "\n%{http_code}")"
  code="$(http_code_of "${resp}")"
  [[ "${code}" == "200" ]]
}

upsert_pipeline() {
  local identifier="$1"
  local yaml_file="$2"
  local yaml tmp url resp code

  yaml="$(render_yaml "${yaml_file}")"
  tmp="$(mktemp)"
  printf '%s\n' "${yaml}" >"${tmp}"

  if pipeline_exists "${identifier}"; then
    echo "  updating pipeline: ${identifier}"
    url="${HARNESS_BASE_URL}/pipeline/api/pipelines/v2/${identifier}?${SCOPE_QS}"
    resp="$(harness_curl PUT "${url}" \
      -H "Content-Type: application/yaml" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  else
    echo "  creating pipeline: ${identifier}"
    url="${HARNESS_BASE_URL}/pipeline/api/pipelines/v2?${SCOPE_QS}"
    resp="$(harness_curl POST "${url}" \
      -H "Content-Type: application/yaml" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  fi

  rm -f "${tmp}"
  code="$(http_code_of "${resp}")"
  if [[ "${code}" != "200" && "${code}" != "201" ]]; then
    echo "error: pipeline ${identifier} failed (HTTP ${code})" >&2
    body_of "${resp}" >&2
    exit 1
  fi
}

delete_pipeline() {
  local identifier="$1"
  local url resp code
  url="${HARNESS_BASE_URL}/pipeline/api/pipelines/${identifier}?${SCOPE_QS}"
  echo "  deleting pipeline: ${identifier}"
  resp="$(harness_curl DELETE "${url}" -w "\n%{http_code}")"
  code="$(http_code_of "${resp}")"
  if [[ "${code}" != "200" && "${code}" != "204" && "${code}" != "404" ]]; then
    echo "error: delete pipeline ${identifier} failed (HTTP ${code})" >&2
    body_of "${resp}" >&2
    exit 1
  fi
}

execute_pipeline() {
  local identifier="$1"
  local input_yaml="${2:-}"
  local url resp code body plan_id tmp
  url="${HARNESS_BASE_URL}/pipeline/api/pipeline/execute/${identifier}?${SCOPE_QS}"

  echo "  executing pipeline: ${identifier}" >&2
  tmp="$(mktemp)"
  if [[ -n "${input_yaml}" ]]; then
    printf '%s\n' "${input_yaml}" >"${tmp}"
  else
    printf '' >"${tmp}"
  fi
  resp="$(harness_curl POST "${url}" \
    -H "Content-Type: application/yaml" \
    --data-binary @"${tmp}" \
    -w "\n%{http_code}")"
  rm -f "${tmp}"
  code="$(http_code_of "${resp}")"
  body="$(body_of "${resp}")"

  if [[ "${code}" != "200" && "${code}" != "201" ]]; then
    echo "error: execute ${identifier} failed (HTTP ${code})" >&2
    echo "${body}" >&2
    exit 1
  fi

  plan_id="$(echo "${body}" | jq -r '.data.planExecution.uuid // .data.planExecutionId // .data.executionDetails.planExecutionId // .data.executionId // empty' 2>/dev/null || true)"
  if [[ -z "${plan_id}" || "${plan_id}" == "null" ]]; then
    plan_id="$(echo "${body}" | sed -n 's/.*"planExecutionId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  fi
  if [[ -z "${plan_id}" ]]; then
    echo "error: could not parse planExecutionId from execute response:" >&2
    echo "${body}" >&2
    exit 1
  fi
  echo "    planExecutionId=${plan_id}" >&2
  printf '%s\n' "${plan_id}"
}

wait_for_execution() {
  local plan_id="$1"
  local timeout_s="${2:-180}"
  local url status elapsed=0 body resp code
  url="${HARNESS_BASE_URL}/pipeline/api/pipelines/execution/v2/${plan_id}?${SCOPE_QS}&renderFullBottomGraph=false"

  while (( elapsed < timeout_s )); do
    resp="$(harness_curl GET "${url}" -w "\n%{http_code}")"
    code="$(http_code_of "${resp}")"
    body="$(body_of "${resp}")"
    if [[ "${code}" != "200" ]]; then
      echo "    warn: status poll HTTP ${code}" >&2
      sleep 5
      elapsed=$((elapsed + 5))
      continue
    fi
    status="$(echo "${body}" | jq -r '.data.pipelineExecutionSummary.status // empty' 2>/dev/null || true)"
    if [[ -z "${status}" || "${status}" == "null" ]]; then
      status="$(echo "${body}" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([A-Za-z_]*\)".*/\1/p' | head -n1)"
    fi
    echo "    status=${status:-unknown} (${elapsed}s)" >&2
    case "${status}" in
      Success|IgnoreFailed|Failed|Aborted|Expired|ApprovalRejected)
        printf '%s\n' "${status}"
        return 0
        ;;
    esac
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo "error: timed out waiting for execution ${plan_id}" >&2
  return 1
}
