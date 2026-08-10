# 01 — Overview

## What this project is

The KTP Payment Factory is a treasury and payments product running on Oracle. Support and
development work needs realistic data volumes and realistic data shapes, but must not expose real
client identities. This package takes a **restored copy** of a production instance and rewrites the
client-identifying data in place, leaving the database structurally intact and the application
functional.

It is not a data generator and not a masking proxy. It is a one-shot, in-place, irreversible
transformation of a database copy.

## The two schemas

| Schema | Contains | Anonymized by |
|---|---|---|
| **OP** | Core treasury. Entities, portfolios, counterparties, bank accounts, plus ~60 `histo_*` history tables and the KTP/CTI extension tables (`cm_*`, `dm_*`, `tp_*`, `uaa_*`, `val_*`, `charge_*`) | `op/` (v4) |
| **EPF** (Oracle user `OPPAYMENTS`) | Payment factory. Payments, bulk payments, application users, SWIFT/BIC reference data, payment audit trail | `Anonymization_EPF/` (not yet ported — see [epf/README.md](../epf/README.md)) |

**Order matters.** OP runs first and produces the code mapping. EPF reads that mapping so that a
counterparty code appearing in both schemas ends up as the same anonymized value in both. Running
EPF against an un-anonymized OP produces an EPF database whose codes point at nothing.

## What "anonymized" means here

Four different treatments, chosen per column. The `rule` column in the inventory says which:

### `CODE` — replace an identifier with its mapped equivalent

The heart of the tool. Identifiers in OP are short codes: an entity might be `ACME`, a bank account
`FR7630001007941234567890185`. Every distinct code gets one generated replacement, recorded in
`anon_meta.code_map`, and **every column anywhere in the schema that references that code gets the
same replacement**. That consistency is what keeps the database usable — joins still join, foreign
keys still resolve, reports still balance.

Generated codes carry a category prefix so they are recognisable at a glance:

| Category | Prefix | Source of codes |
|---|---|---|
| `ENTITY` | `E_` | `structure` ⋈ `tiers` where `structure='Entite'`, `ecran='w_tiers'`, `flag_portefeuille='N'` |
| `PORTFOLIO` | `P_` | same, but `flag_portefeuille='O'` |
| `COUNTERPARTY` | `T_` | `structure` where `structure='Compte'`, `ecran='w_tiers'` |
| `BANK_ACCOUNT` | `CB_` | `compte_banque` |

### `NULL_OUT` — erase free text and PII

Descriptions, comments, names, phone numbers, email addresses, IBAN fragments. These have no
referential meaning, so nothing is gained by mapping them — they are set to `NULL`. This treatment
is **never optional**: it applies regardless of configuration, because free text is the highest-risk
category and the least useful to preserve.

### `DESCRIPTION` — overwrite a label with the row's own new code

`tiers.description`, `structure.description`, `compte_banque.description`. Setting these to the
row's own anonymized code (rather than `NULL`) keeps the UI readable — a screen showing a
counterparty displays `T_0000412` instead of a blank.

### `SELF_CODE` — overwrite a PII field with the row's own new code

Applies to per-entity attribute columns such as `tiers.telephone`, `tiers.email_adress`,
`tiers.nom_pp`. Same effect as `NULL_OUT` for privacy purposes, but leaves the column populated so
that application code performing `NOT NULL` or format checks does not break. Inherited from the
original vendor behaviour.

## What is deliberately *not* anonymized

- **Amounts, dates, currencies, statuses** in OP. They carry no client identity on their own and
  destroying them would make the copy useless for reproducing production behaviour. (EPF does
  anonymize payment amounts — a payment amount plus a beneficiary is more identifying than an OP
  balance.)
- **System and reference codes** that are not client data: currency codes, country codes, product
  codes, and any code not present in the source tables listed above.
- **System user accounts** (`INTERFACE`, `BATCH`, `Swift Agt`, …). These are application
  infrastructure, not people. The verifier explicitly distinguishes them from leaked real users.
- **Schema structure.** No table, column, index, constraint or trigger is renamed or dropped as a
  side effect of anonymizing. (Triggers are disabled during the run and re-enabled after.)

## Reversibility

**There is none, by design.** The mapping table `anon_meta.code_map` records old → new and is
retained after a run, but only so that a partial or failed run can be resumed and verified. It is
not a decryption key you are meant to keep: on a copy destined for a lower environment, drop the
`anon_meta` schema once the run has been verified.

## See also

- [02_architecture.md](02_architecture.md) — how the pieces fit together
- [03_coverage.md](03_coverage.md) — the exact list of anonymized columns
- [06_glossary.md](06_glossary.md) — what `tiers`, `portefeuille`, `entite` and friends mean
