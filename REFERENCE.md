# Mentat Reference

Edge cases, join rules, business terms, and configuration details extracted from SKILL.md.

## Assumptions Block

Before every analysis or chart, list every non-trivial decision:

```
Assumptions:
  - Inferred join: orders.user_id -> users.id (naming convention, no FK declared)
  - "Churn" defined as status IN ('inactive', 'cancelled')
  - Ignored table 'audit_log' (not relevant to query)
  - Time-series bucketed to monthly (span: 2022-01-01 to 2025-01-15)
  - Gaps filled with zeros
```

**ALL assumptions must be declared.** No silent inferences, no hidden defaults.

## Business Terms

When the user uses ambiguous business terms (churn, active, engaged, high-value):
1. Inspect schema for indicator columns (status, churned, is_active)
2. If found, show distinct values and ask user which define the term
3. If none, propose a definition based on schema (e.g., "churn = no login 30d AND subscription ended")
4. Record definition in Assumptions Block

## Join Discovery

When tables have no declared foreign keys:
1. **Tier 1:** Use declared FKs (always reliable)
2. **Tier 2:** Infer from `{table}_id` / `id` naming convention (announce as assumption)
3. **Tier 3:** Ask user if naming convention fails
4. **Never** use value-domain matching (comparing actual data values)
5. **Cap join depth at 3** (e.g., users→orders→payments is depth 2)

## Output Structure

Chart output: ASCII to stdout by default. `--output PATH` saves PNG to the given path (no default output directory).

A `latest` symlink can be managed by the user. User handles cleanup.

## Markdown Report

Optional report when user requests "save this":
- Assumptions Block
- Full SQL queries
- Summary statistics as tables
- Embedded plot images (relative paths)
- Interpretation of results

## Degenerate Data

| Scenario | Response |
|----------|----------|
| 1 row | "Insufficient data for distribution. Need ≥10 rows." |
| All categorical | "Requires numeric data. Consider frequency analysis?" |
| Identical timestamps | "All records share same timestamp. Time-series not possible." |

## Large Result Sets

| Size | Action |
|------|--------|
| <100K rows | Use full data |
| 100K-1M | Sample to 50K (scatter) or auto-bin (distributions) |
| >1M | Always aggregate/bin. Never return raw data. |

Announce strategy. Do not ask permission.

## Session State

- Schema cached in conversation context for session duration
- Re-inspect only on error or explicit "refresh the schema"
- Each query is independent — no implicit state carried between queries

## Directory / Multi-File Input

- Each file = separate queryable table
- Directories: scan for supported extensions, present summary ("Found 50 CSVs, 3 Parquet, 1 SQLite"), ask which to inspect
- Cap at 100 files. If exceeded, ask user to narrow scope.
