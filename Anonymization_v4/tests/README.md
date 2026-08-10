# tests/

**Nothing in this folder is part of a run.** These are ad-hoc scripts for inspecting an instance by
hand — before a run, during one, or when something looks wrong.

The workflow scripts live elsewhere and are the only things the orchestrator executes:

| Purpose | Location |
|---|---|
| Anonymization workflow | `op/sql/` |
| Post-run verification | `op/verify/` |
| Documentation generation | `tools/` |
| **Manual inspection (this folder)** | `tests/manual/` |

This separation is deliberate. In v3 the ad-hoc scripts (`check_cti_tables.sql`,
`check_ktp_cti_tables.sql`, `monitor_*.sql`) sat in the same `sql/` directory as the workflow
scripts, and it was not possible to tell by looking which ones a run would execute.

## What's here

| Script | Use |
|---|---|
| `manual/check_tables_exist.sql` | Which inventory tables/columns exist on this instance. Read-only. Answers "will anything be skipped?" before committing to a run. |
| `manual/row_counts.sql` | Row counts for the main anonymization targets. Read-only. Useful for estimating runtime. |
| `manual/monitor_op_progress.sql` | Live progress of a run in flight, read from `anon_meta.anon_step_log`. Run from a second session. |
| `manual/inspect_code_map.sql` | Sample the generated mapping; check category counts and look for anomalies. Read-only. |

## Ground rules

- **Read-only.** Nothing here issues DML. If you need a script that changes data, it belongs in
  `op/sql/` and in the inventory.
- **Safe to run any time**, including against a database mid-run.
- **Not required for correctness.** Skipping all of them changes nothing about a run's outcome.
