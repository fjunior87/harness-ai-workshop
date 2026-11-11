#!/usr/bin/env bash
# Shared helpers for Harness NG connector/service/env/infra/pipeline APIs.

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

_yaml_to_json_request() {
  # Build {"name","identifier","orgIdentifier","projectIdentifier","yaml":"..."} plus optional fields via jq
  # Args: yaml_file name identifier [extra_jq_args as JSON object string]
  local yaml_file="$1"
  local name="$2"
  local identifier="$3"
  local extra_json="${4:-"{}"}"
  local yaml
  yaml="$(render_yaml "${yaml_file}")"
  jq -n \
    --arg name "${name}" \
    --arg identifier "${identifier}" \
    --arg org "${ORG_ID}" \
    --arg project "${PROJECT_ID}" \
    --arg yaml "${yaml}" \
    --argjson extra "${extra_json}" \
    '{name:$name, identifier:$identifier, orgIdentifier:$org, projectIdentifier:$project, yaml:$yaml} + $extra'
}

_upsert_ng_yaml_entity() {
  # _upsert_ng_yaml_entity kind identifier name yaml_file get_url create_url update_url [extra_json]
  local kind="$1"
  local identifier="$2"
  local name="$3"
  local yaml_file="$4"
  local get_url="$5"
  local create_url="$6"
  local update_url="$7"
  local extra_json="${8:-"{}"}"
  local payload tmp resp code get_resp get_code

  payload="$(_yaml_to_json_request "${yaml_file}" "${name}" "${identifier}" "${extra_json}")"
  tmp="$(mktemp)"
  printf '%s\n' "${payload}" >"${tmp}"

  get_resp="$(harness_curl GET "${get_url}" -w "\n%{http_code}")"
  get_code="$(http_code_of "${get_resp}")"

  if [[ "${get_code}" == "200" ]]; then
    echo "  updating ${kind}: ${identifier}"
    resp="$(harness_curl PUT "${update_url}" \
      -H "Content-Type: application/json" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  else
    echo "  creating ${kind}: ${identifier}"
    resp="$(harness_curl POST "${create_url}" \
      -H "Content-Type: application/json" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  fi

  rm -f "${tmp}"
  code="$(http_code_of "${resp}")"
  if [[ "${code}" != "200" && "${code}" != "201" ]]; then
    echo "error: ${kind} ${identifier} failed (HTTP ${code})" >&2
    body_of "${resp}" >&2
    exit 1
  fi
}

_delete_if_exists() {
  local kind="$1"
  local identifier="$2"
  local delete_url="$3"
  local resp code
  echo "  deleting ${kind}: ${identifier}"
  resp="$(harness_curl DELETE "${delete_url}" -w "\n%{http_code}")"
  code="$(http_code_of "${resp}")"
  if [[ "${code}" != "200" && "${code}" != "204" && "${code}" != "404" ]]; then
    echo "error: delete ${kind} ${identifier} failed (HTTP ${code})" >&2
    body_of "${resp}" >&2
    exit 1
  fi
}

# --- Connector (NG JSON API is more reliable than YAML for connectors) ---

connector_exists() {
  local identifier="$1"
  local url="${HARNESS_BASE_URL}/ng/api/connectors/${identifier}?${SCOPE_QS}"
  local resp code
  resp="$(harness_curl GET "${url}" -w "\n%{http_code}")"
  code="$(http_code_of "${resp}")"
  [[ "${code}" == "200" ]]
}

upsert_connector_json() {
  local identifier="$1"
  local json_file="$2"
  local json tmp url resp code

  json="$(render_yaml "${json_file}")"
  tmp="$(mktemp)"
  printf '%s\n' "${json}" >"${tmp}"

  if connector_exists "${identifier}"; then
    echo "  updating connector: ${identifier}"
    url="${HARNESS_BASE_URL}/ng/api/connectors?${SCOPE_QS}"
    resp="$(harness_curl PUT "${url}" \
      -H "Content-Type: application/json" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  else
    echo "  creating connector: ${identifier}"
    url="${HARNESS_BASE_URL}/ng/api/connectors?${SCOPE_QS}"
    resp="$(harness_curl POST "${url}" \
      -H "Content-Type: application/json" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  fi

  rm -f "${tmp}"
  code="$(http_code_of "${resp}")"
  if [[ "${code}" != "200" && "${code}" != "201" ]]; then
    echo "error: connector ${identifier} failed (HTTP ${code})" >&2
    body_of "${resp}" >&2
    exit 1
  fi
}

delete_connector() {
  local identifier="$1"
  _delete_if_exists "connector" "${identifier}" \
    "${HARNESS_BASE_URL}/ng/api/connectors/${identifier}?${SCOPE_QS}"
}

# --- Service ---

upsert_service() {
  local identifier="$1"
  local yaml_file="$2"
  local name="$3"
  _upsert_ng_yaml_entity "service" "${identifier}" "${name}" "${yaml_file}" \
    "${HARNESS_BASE_URL}/ng/api/servicesV2/${identifier}?${SCOPE_QS}" \
    "${HARNESS_BASE_URL}/ng/api/servicesV2?${SCOPE_QS}" \
    "${HARNESS_BASE_URL}/ng/api/servicesV2?${SCOPE_QS}"
}

delete_service() {
  local identifier="$1"
  _delete_if_exists "service" "${identifier}" \
    "${HARNESS_BASE_URL}/ng/api/servicesV2/${identifier}?${SCOPE_QS}"
}

# --- Environment ---

upsert_environment() {
  local identifier="$1"
  local yaml_file="$2"
  local name="$3"
  local env_type="$4"
  _upsert_ng_yaml_entity "environment" "${identifier}" "${name}" "${yaml_file}" \
    "${HARNESS_BASE_URL}/ng/api/environmentsV2/${identifier}?${SCOPE_QS}" \
    "${HARNESS_BASE_URL}/ng/api/environmentsV2?${SCOPE_QS}" \
    "${HARNESS_BASE_URL}/ng/api/environmentsV2?${SCOPE_QS}" \
    "$(jq -n --arg t "${env_type}" '{type:$t}')"
}

delete_environment() {
  local identifier="$1"
  _delete_if_exists "environment" "${identifier}" \
    "${HARNESS_BASE_URL}/ng/api/environmentsV2/${identifier}?${SCOPE_QS}"
}

# --- Infrastructure (scoped to environment) ---

upsert_infrastructure() {
  local identifier="$1"
  local env_id="$2"
  local yaml_file="$3"
  local name="$4"
  local qs="${SCOPE_QS}&environmentIdentifier=${env_id}"
  _upsert_ng_yaml_entity "infrastructure" "${identifier}" "${name}" "${yaml_file}" \
    "${HARNESS_BASE_URL}/ng/api/infrastructures/${identifier}?${qs}" \
    "${HARNESS_BASE_URL}/ng/api/infrastructures?${qs}" \
    "${HARNESS_BASE_URL}/ng/api/infrastructures?${qs}" \
    "$(jq -n --arg e "${env_id}" '{environmentRef:$e}')"
}

delete_infrastructure() {
  local identifier="$1"
  local env_id="$2"
  local qs="${SCOPE_QS}&environmentIdentifier=${env_id}"
  _delete_if_exists "infrastructure" "${identifier}" \
    "${HARNESS_BASE_URL}/ng/api/infrastructures/${identifier}?${qs}"
}

# --- Pipeline ---

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
  _delete_if_exists "pipeline" "${identifier}" \
    "${HARNESS_BASE_URL}/pipeline/api/pipelines/${identifier}?${SCOPE_QS}"
}

# --- Execute + wait ---

execute_pipeline() {
  local identifier="$1"
  local input_yaml="$2"
  local url resp code body plan_id
  local tmp
  url="${HARNESS_BASE_URL}/pipeline/api/pipeline/execute/${identifier}?${SCOPE_QS}&moduleType=CD"

  echo "  executing pipeline: ${identifier}" >&2
  tmp="$(mktemp)"
  printf '%s\n' "${input_yaml}" >"${tmp}"
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
      body_of "${resp}" >&2 || true
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
