#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/harness_api.sh
source "${ROOT_DIR}/lib/harness_api.sh"

harness_init

echo "analyze-error teardown"
delete_pipeline "fixme_shell_pipeline"
echo "Teardown complete."
