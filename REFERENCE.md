# Mentat Reference

Edge cases, join rules, business terms, and configuration details. All output is JSON.

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

## JSON Error Responses

Every error response follows this schema:
```json
{"status":"error","error":{"message":"descriptive message","code":1}}
```

Common error codes:
- 1: General error (missing args, invalid input, unsupported format)
- 2+: DuckDB errors (SQL syntax, type mismatches)
- 3+: Gnuplot errors (rendering failures)

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
5. **Cap join depth at 3** (e.g., users->orders->payments is depth 2)

## Markdown Report

Optional report when user requests "save this":
- Assumptions Block
- Full SQL queries
- Summary statistics as tables
- Embedded plot images (relative paths)
- Interpretation of results

## Degenerate Data

| Scenario | JSON signal | Response |
|---|---|---|
| 1 row | `data.warning: "Only 1 row"` | "Insufficient data for distribution. Need >=10 rows." |
| All categorical | `data.categorical: true` | "Requires numeric data. Consider frequency analysis?" |
| Identical timestamps | Empty `data.points` | "All records share same timestamp. Time-series not possible." |
| Empty result | `data.rows: 0` | "No matching data found." |

## Large Result Sets

| Size | Action |
|---|---|
| <100K rows | Use full data |
| 100K-1M | Sample to 50K (scatter) or auto-bin (distributions) |
| >1M | Always aggregate/bin. Never return raw data. |

When truncated, JSON includes `data.warning` or `data.capped: true`.

## Session State

- Schema cached in conversation context for session duration
- Re-inspect only on error or explicit "refresh the schema"
- Each query is independent — no implicit state carried between queries

## Configuration

Settings read in priority order: env vars > `./mentat.config` > `~/.config/mentat/config`.

| Variable | Default | Description |
|---|---|---|
| `MENTAT_OUTPUT_DIR` | `.` | Directory for `-o` plots |
| `MENTAT_MAX_ROWS` | `100000` | Hard row cap per query |
| `MENTAT_OUTLIER_METHOD` | `iqr` | Outlier detection method (`iqr` / `zscore`) |
| `MENTAT_MAX_RETRIES` | `2` | Self-correction retry limit |

## Directory / Multi-File Input

- Each file = separate queryable table
- Directories: scan for supported extensions, returns `data.names` list
- Cap at 100 files. If exceeded, ask user to narrow scope.

## Version

`mentat --version` returns `{"status":"ok","data":{"version":"0.2.0"}}`.
