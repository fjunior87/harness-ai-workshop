# Lab: Template Sprawl → Consolidate with Harness AI

Simulate approval-template sprawl (inspired by many near-duplicate ServiceNow approval templates), then use **Harness AI in the product UI** to find merge candidates and impacted pipelines.

This lab does **not** use Cursor, Claude, or other external agents for the showcase path.

## What gets created

| Kind | Identifiers |
|------|-------------|
| Step templates (`HarnessApproval`) | `payments_manual_approval`, `risk_change_approval`, `ops_release_gate`, `platform_prod_approval`, `sre_deploy_approval_v2` |
| Pipelines | `payments_release_pipeline`, `risk_change_pipeline`, `ops_release_pipeline`, `platform_prod_pipeline`, `sre_deploy_pipeline` |

Each pipeline references a **different** approval template. Tags include `workshop: template-sprawl` and a fake `team:` (`payments`, `risk`, `ops`, `platform`, `sre`).

Intentional drift (so sprawl is obvious):

- Timeouts: `1d` / `3d` / `2d` / `4h` / `20h`
- Messages, `minimumCount`, `disallowPipelineExecutor`, `isAutoRejectEnabled`
- `sre_deploy_approval_v2` nearly clones payments (classic duplicate smell)
- `platform_prod_approval` adds `env: prod`

## Prerequisites

- macOS/Linux with `bash`, `curl`, and `jq` available (`jq` is optional for this seed; `curl` is required)
- Your workshop project already exists
- Env vars set in your shell:

```bash
export MY_HARNESS_ACCOUNT="<accountId>"
export MY_HARNESS_ORG="<orgIdentifier>"
export MY_HARNESS_PROJECT="<projectIdentifier>"
export MY_HARNESS_SAT="<service account token>"
# optional
# export MY_HARNESS_BASE_URL="https://app.harness.io"
```

## Seed your project

From this directory:

```bash
chmod +x seed.sh teardown.sh
./seed.sh
```

Re-running `./seed.sh` updates the same identifiers (idempotent).

## Lab steps

1. **Template Library**  
   In your project, open **Templates**. Find the five `HarnessApproval` step templates (search `template-sprawl` or team names). Open two side by side and note timeout / message / approver settings drift.

2. **Pipelines**  
   Open **Pipelines**. Confirm each `*_pipeline` binds a different approval `templateRef`.

3. **Harness AI** (same entry point as the earlier workshop module)  
   Paste prompts like:

   - `List all HarnessApproval step templates in this project tagged workshop template-sprawl. Group ones that look like duplicates of the same approval gate.`
   - `For each duplicate group, which fields differ and which should become runtime inputs on a single shared template?`
   - `Which pipelines reference these templates, and what is the blast radius if we consolidate to one approval template?`

4. **Manual fallback** (if AI context is narrow)  
   In Template Library, open a template → **References** / usages, and/or inspect each pipeline YAML for `templateRef`.

5. **Debrief**  
   Harness does not ship a single “find mergeable templates” button. The win is **Template Library inventory** + **Harness AI analysis** + **template → pipeline references** for impact.

## Teardown

```bash
./teardown.sh
```

Deletes the five pipelines first, then the five templates.

## Facilitator notes

- Approver `userGroups` is `<+input>` so seeding does not depend on named user groups existing in every project.
- Pipelines are Custom-stage only — no service, environment, infra, or ServiceNow connector required.
- Running an approval execution is optional; the lab is about sprawl discovery and consolidation analysis.
