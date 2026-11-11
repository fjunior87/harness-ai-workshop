#!/usr/bin/env bash
# Shared helpers for Harness NG Template + Pipeline APIs (SAT via x-api-key).

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
  # Usage: harness_curl METHOD URL [curl args...]
  local method="$1"
  local url="$2"
  shift 2
  curl -sS -X "${method}" "${url}" \
    -H "x-api-key: ${API_KEY}" \
    -H "Harness-Account: ${ACCOUNT_ID}" \
    "$@"
}

http_code_of() {
  # Last line of curl -w "\n%{http_code}" output
  local body="$1"
  echo "${body}" | tail -n 1
}

body_of() {
  local body="$1"
  echo "${body}" | sed '$d'
}

render_yaml() {
  # Replace org/project placeholders in a YAML file; print to stdout
  local file="$1"
  sed \
    -e "s/__ORG_IDENTIFIER__/${ORG_ID}/g" \
    -e "s/__PROJECT_IDENTIFIER__/${PROJECT_ID}/g" \
    "${file}"
}

template_exists() {
  local identifier="$1"
  local version_label="${2:-1}"
  local url="${HARNESS_BASE_URL}/template/api/templates/${identifier}?${SCOPE_QS}&versionLabel=${version_label}"
  local resp code
  resp="$(harness_curl GET "${url}" -w "\n%{http_code}")"
  code="$(http_code_of "${resp}")"
  [[ "${code}" == "200" ]]
}

upsert_template() {
  local identifier="$1"
  local yaml_file="$2"
  local version_label="${3:-1}"
  local yaml tmp url resp code

  yaml="$(render_yaml "${yaml_file}")"
  tmp="$(mktemp)"
  printf '%s\n' "${yaml}" >"${tmp}"

  if template_exists "${identifier}" "${version_label}"; then
    echo "  updating template: ${identifier} (v${version_label})"
    url="${HARNESS_BASE_URL}/template/api/templates/${identifier}?${SCOPE_QS}&setDefaultTemplate=true&comments=workshop-template-sprawl-seed"
    resp="$(harness_curl PUT "${url}" \
      -H "Content-Type: application/yaml" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  else
    echo "  creating template: ${identifier} (v${version_label})"
    url="${HARNESS_BASE_URL}/template/api/templates?${SCOPE_QS}&setDefaultTemplate=true&isNewTemplate=true&comments=workshop-template-sprawl-seed"
    resp="$(harness_curl POST "${url}" \
      -H "Content-Type: application/yaml" \
      --data-binary @"${tmp}" \
      -w "\n%{http_code}")"
  fi

  rm -f "${tmp}"
  code="$(http_code_of "${resp}")"
  if [[ "${code}" != "200" && "${code}" != "201" ]]; then
    echo "error: template ${identifier} failed (HTTP ${code})" >&2
    body_of "${resp}" >&2
    exit 1
  fi
}

delete_template() {
  local identifier="$1"
  local version_label="${2:-1}"
  local url resp code
  url="${HARNESS_BASE_URL}/template/api/templates/${identifier}/${version_label}?${SCOPE_QS}"
  echo "  deleting template: ${identifier} (v${version_label})"
  resp="$(harness_curl DELETE "${url}" -w "\n%{http_code}")"
  code="$(http_code_of "${resp}")"
  if [[ "${code}" != "200" && "${code}" != "204" && "${code}" != "404" ]]; then
    echo "error: delete template ${identifier} failed (HTTP ${code})" >&2
    body_of "${resp}" >&2
    exit 1
  fi
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
