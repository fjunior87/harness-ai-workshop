# Workshop seeds

Single entry point for attendees:

```bash
export MY_HARNESS_ACCOUNT="<accountId>"
export MY_HARNESS_ORG="<orgIdentifier>"
export MY_HARNESS_PROJECT="<projectIdentifier>"
export MY_HARNESS_SAT="<service account token>"

cd workshop
chmod +x seed.sh teardown.sh */seed.sh */teardown.sh
./seed.sh
```

This runs:

1. `template-sprawl/seed.sh` — near-duplicate approval templates + pipelines  
2. `payment-api-deployments/seed.sh` — payment-api CD demo + mixed executions  
3. `analyze-error/seed.sh` — broken ShellScript pipeline for Analyze Error / Help me fix YAML  


Teardown everything:

```bash
./teardown.sh
```

You can still run an individual lab from its folder if needed. See each lab’s README for prompts and details.

### payment-api note

`payment-api-deployments` needs a delegate with selector **`workshop`**.  
Optional: `SKIP_RUNS=true ./seed.sh` skips pipeline executions in that lab (env var is read by that seed script).
