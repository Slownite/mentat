---
name: Mentat
description: Token-efficient EDA agent — inspect, query, and visualize data via DuckDB, QSV & Gnuplot
---

# Mentat — Token-Efficient EDA Agent

CLI-driven EDA agent using DuckDB, QSV and Gnuplot. No Python libraries needed.

## Prerequisites

Run `mentat selfcheck` once at session start. Exit 0 = all good. Required: `duckdb`, `qsv`, `gnuplot`.

The script lives at `~/.agents/skills/mentat/scripts/mentat`. Define dir in PATH or reference directly.

## Entry Points

1. **Analytical Query** — High-level question (e.g., "what drives churn?"). Propose approach, get confirmation.
2. **Direct Plot** — Explicit chart request. Generate directly.

## Workflow

Schema (`mentat inspect <path>`, once per session) → Query or Plot.

**Fast path:** `mentat selfcheck` → `mentat inspect` → `mentat query` or `mentat <chart> ...` (3-4 calls).

## Schema Discovery

`mentat inspect <path>` returns compressed DDL. Cache in context. Re-inspect only on error or explicit request.

Use `--stats <table>` for row count, null ratios, distinct counts, value ranges — only for tables touched by current query.

## Query

`mentat query <path> <sql> [--histogram --bins=N] [--groupby <col>] [--timeseries --bucket=auto|hourly|daily|weekly|monthly|yearly] [--outlier-method=iqr|zscore] [--raw]`

Default output: `rows=N | min=X max=X mean=X median=X p25=X p75=X | outliers=N bounds=[X,Y] | sample: [...]`

## Visualization

**Single entry point** — `mentat <chart-type>` does DuckDB aggregation + Gnuplot render. ASCII to stdout by default. `--output PATH` saves PNG to file (also prints ASCII for LLM validation).

| Subcommand | Use Case | Required Args |
|---|---|---|
| `mentat histogram` | Distribution of 1 numeric col | datasource, column |
| `mentat scatter` | Correlation of 2 numeric cols | datasource, x_col, y_col |
| `mentat line` | Time-series trend | datasource, time_col, value_col |
| `mentat bar` | Categorical frequencies | datasource, category_col |
| `mentat boxplot` | Categorical vs numeric comparison | datasource, category_col, value_col |
| `mentat heatmap` | 2D density / cross-tab | datasource, x_col, y_col, z_col |

Common flags: `--output PATH`, `--table NAME`, `--title`, `--xlabel`, `--ylabel`.

Type-specific: `--bins N` (histogram), `--bucket auto|hourly|daily|weekly|monthly|yearly` (line).

**If user requests a chart type that doesn't match the data, propose a data-appropriate alternative. Never render a misleading chart.**

## Self-Correction

- **Mechanical errors** (SQL syntax, type mismatches, Gnuplot errors): retry up to 2 times.
- **Logic errors** (0 rows, div by 0, timeout): escalate to user with alternative.
- **Degenerate data** (1 row, all categorical, identical timestamps): escalate with alternative.

## Token Budget

Soft target: 6K tokens/query (`MENTAT_TOKEN_BUDGET`). Schema ~2K, SQL+results ~2K, interpretation ~2K.

For large schemas (>20 tables), use keyword matching on user's question to filter relevance.

## Configuration

Priority: env vars > `./mentat.config` > `~/.config/mentat/config`. See `MENTAT_TOKEN_BUDGET`, `MENTAT_MAX_RETRIES`, `MENTAT_OUTLIER_METHOD`, `MENTAT_TIMESERIES_BUCKET`, `MENTAT_LOG_LEVEL`.

## Data Source Rules

- **SQLite:** Always ATTACH `(TYPE SQLITE, READ_ONLY)`. Fail on `database is locked` (no retry). Empty DBs fail with "no tables".
- **Flat files:** Auto-detect from extension (.csv, .parquet, .json). CSV profiling via `qsv stats`. Table name = filename (sanitized).
- **Directory:** Scan for supported extensions, present summary. Cap at 100 files.

## Large Results

Auto-reduce: <100K rows = full data, 100K-1M = sample to 50K, >1M = aggregate. Announce strategy.

## REFERENCE.md

Edge cases, join rules, business terms, output structure, Assumptions Block details → **REFERENCE.md**. Consult when encountering ambiguous terms, multi-table joins, or one-off edge cases.

Always propose an alternative when analysis is impossible.
