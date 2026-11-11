#!/usr/bin/env bash
# Remove payment-api deployment workshop resources (pipelines → infra → envs → service → connector).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/harness_api.sh
source "${ROOT_DIR}/lib/harness_api.sh"

harness_init

echo "payment-api deployments teardown"
echo "  account: ${ACCOUNT_ID}"
echo "  org:     ${ORG_ID}"
echo "  project: ${PROJECT_ID}"
echo

echo "Deleting pipelines..."
delete_pipeline "payment_api_prod_deploy"
delete_pipeline "payment_api_qa_deploy"
delete_pipeline "payment_api_hotfix"

echo
echo "Deleting infrastructures..."
delete_infrastructure "prod_infra" "prod"
delete_infrastructure "qa_infra" "qa"

echo
echo "Deleting environments..."
delete_environment "prod"
delete_environment "qa"

echo
echo "Deleting service..."
delete_service "payment_api"

echo
echo "Deleting connector..."
delete_connector "workshop_k8s"

echo
echo "Teardown complete."
