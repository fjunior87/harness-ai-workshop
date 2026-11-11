# Lab: payment-api deployment failures (Harness AI)

Seed a minimal CD setup around service **payment-api**, run mixed success/fail Production and QA executions, then use **Harness AI in the product UI** to explore deployment failure and duration questions.

No manifests, no artifact sources, no OPA policies. Deploy stages use a **ShellScript** step only. Failures are controlled with runtime input `should_fail`.

## What gets created

| Kind | Identifiers |
|------|-------------|
| Connector | `workshop_k8s` — `K8sCluster` / **InheritFromDelegate**, selector **`workshop`** |
| Service | `payment_api` (`payment-api`) — Kubernetes, empty spec |
| Environments | `qa` (PreProduction), `prod` (Production) |
| Infrastructures | `qa_infra`, `prod_infra` |
| Pipelines | `payment_api_prod_deploy`, `payment_api_qa_deploy`, `payment_api_hotfix` |

Pipeline variables (runtime inputs):

- `should_fail` — `true` / `false`
- `sleep_seconds` — varies stage duration for “longest execution” demos

## Prerequisites

- `bash`, `curl`, `jq`
- Env vars:

```bash
export MY_HARNESS_ACCOUNT="<accountId>"
export MY_HARNESS_ORG="<orgIdentifier>"
export MY_HARNESS_PROJECT="<projectIdentifier>"
export MY_HARNESS_SAT="<service account token>"
```

- A Harness Delegate that can run ShellScript, tagged with selector **`workshop`** (must match the connector).

## Seed

```bash
chmod +x seed.sh teardown.sh
./seed.sh
```

Creates/updates resources, then runs several executions (Prod failures, longer sleeps, QA mix, hotfix successes).

```bash
SKIP_RUNS=true ./seed.sh          # resources only
WAIT_TIMEOUT_S=600 ./seed.sh      # longer wait for delegate pickup
```

## Suggested Harness AI prompts

1. `Which services experienced deployment failures in Production during the last seven days?`
2. `Which pipelines have the highest failure rate?`
3. `Which deployment stages consistently have the longest execution duration across Production deployments?`

## Teardown

```bash
./teardown.sh
```

## Notes

- ShellScript steps have **no** delegate selectors; the connector carries selector `workshop`.
- This lab does **not** seed policy-evaluation failures (OPA). Failures are script `exit 1` when `should_fail=true`.
