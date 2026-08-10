# epf/ — not yet ported

The EPF (`OPPAYMENTS`) anonymization has **not** been rebuilt on the v4 architecture yet. It still
runs from the original location:

```
Anonymization_EPF/
├─ sql/start_epf_anonymization.bat        ← entry point
├─ sql/start_anonymous_epf.sql            ← orchestrator, phases A–H
├─ sql/anonymize_epf_itr1.sql             ← phase B: code cascade from OP
├─ sql/anonymize_epf_itr2.sql             ← phase D: users, free text, addresses
├─ sql/anonymize_epf_phase7_refdata.sql   ← phase E: REF_TIERS, REF_BANK_BRANCHE
├─ sql/anonymize_epf_phase8_swift_audit.sql
├─ sql/anonymize_epf_phase9_op_bic_bban.sql
├─ sql/bic/1..5                           ← phase C: BIC components + payment amounts
└─ sql/verify_epf_anon_coverage_final.sql
```

**Order is unchanged: OP must complete before EPF.** EPF phase B reads the code mapping OP
produces. Until the port is done, that means the *v3* mapping table — so if you run v4's OP
anonymization, EPF phase B will not find what it expects. Run both halves from the same generation
until this is resolved.

## What the port involves

Most of the work is writing `config/inventory_epf.csv`. The engine, run state, logging, dry run and
verifier are schema-agnostic and already handle a second inventory.

The EPF-specific pieces that do *not* fit the inventory model and will need engine support or
dedicated steps:

| Piece | Why it doesn't fit |
|---|---|
| **BIC/SWIFT component anonymization** (`bic/1..4`) | A BIC decomposes into bank/country/location/branch sub-fields, each mapped independently and reassembled. Not a whole-column replacement. |
| **Payment amounts** (`bic/5`) | Numeric perturbation, not identifier mapping. |
| **Password reset + hashcode recalculation** (phase H) | Application-specific; must run last, and users cannot log in without it. |
| **Orphan code synthesis** (phase A) | EPF codes with no OP counterpart get generated mappings so the cascade is total. |

## What v4 already took from EPF

- The `epf_anon_log` run-logging pattern, generalized into `anon_meta.anon_step_log`.
- The residual-value check from `verify_epf_anon_coverage_final.sql` PART 6 — asking "is any *real*
  identifier still present?" rather than "does this value look anonymized?" — which is now the
  primary check in `op/verify/verify_op_coverage.sql`.
- Correct escaped `LIKE … ESCAPE '\'` prefix matching, which the EPF verifier got right and the OP
  one did not.

See [../docs/05_history.md](../docs/05_history.md) for the full comparison.
