# Lab: Analyze Error / Help me fix YAML

Pipeline **`fixme_shell_pipeline`** is a Custom stage with one ShellScript step that fails on purpose (`sllep` typo instead of `sleep`).

Seed creates the pipeline and **runs it once** (expected **Failed** on `sllep`). Attendees open that execution for Analyze Error / Help me fix.

## Seed

```bash
export MY_HARNESS_ACCOUNT=...
export MY_HARNESS_ORG=...
export MY_HARNESS_PROJECT=...
export MY_HARNESS_SAT=...

./seed.sh
```

Or use the top-level `workshop/seed.sh`.  
`SKIP_RUNS=true ./seed.sh` creates the pipeline without executing.

## Lab steps

1. Open the failed **Fixme Shell Pipeline** execution → **Analyze Error**.
2. Note root cause and top action.
3. Ask Chat: `Why did this step fail, and what is the smallest fix?`
4. Use **Help me fix the pipeline yaml**, review the diff, accept.
5. Rerun and confirm it passes.

## Intended fix

In the ShellScript, change `sllep 1` → `sleep 1`.

Needs any available delegate (no special selector on this pipeline).
