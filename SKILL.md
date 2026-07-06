---
name: Mentat
description: Token-efficient EDA agent — inspect, query, and visualize data via DuckDB, QSV & Gnuplot. Use when user provides data files (CSV, Parquet, JSON, SQLite) and asks analytical questions or requests charts.
---

# Mentat

CLI-driven EDA using DuckDB, QSV and Gnuplot. No Python libraries needed.

## Quick Start

```
mentat selfcheck              # verify tools (once per session)
mentat inspect data.csv       # schema discovery (once per session)
mentat query data.csv "SELECT col1, COUNT(*) FROM data GROUP BY col1"
mentat histogram data.csv col1
```

## Prerequisites

Run `mentat selfcheck` at session start. Exit 0 = all good. Required: `duckdb`, `qsv`, `gnuplot`.

Script: `~/.agents/skills/mentat/scripts/mentat`. Add to PATH or reference directly.

All data flows through pipes — no temp files or scratch directories used.

## Workflows

### 1. Analytical Query

High-level question (e.g., "what drives churn?"):
1. `mentat inspect <path>` — discover schema
2. Propose approach → get user confirmation
3. `mentat query <path> <sql>` — execute with optional `--timeseries`, `--histogram`, `--groupby`, `--outlier-method`

### 2. Direct Plot

Explicit chart request:
- Single command: `mentat <chart-type> <path> <args>`
- Common flags: `--output PATH`, `--table NAME`, `--title`, `--xlabel`, `--ylabel`

**If user requests a chart type that doesn't match the data, propose a data-appropriate alternative. Never render a misleading chart.**

## Commands

### Schema Discovery

`mentat inspect <path>` returns compressed DDL. Cache in context. Re-inspect only on error or request.

`--stats <table>` for row count, null ratios, distinct counts, value ranges.

### Query

`mentat query <path> <sql> [--histogram --bins=N] [--groupby <col>] [--timeseries --bucket=auto|hourly|daily|weekly|monthly|yearly] [--outlier-method=iqr|zscore] [--raw]`

Default output: `rows=N | min=X max=X mean=X median=X p25=X p75=X | outliers=N bounds=[X,Y] | sample: [...]`

### Visualization

DuckDB aggregation + Gnuplot render. ASCII to stdout. `--output PATH` saves PNG.

| Subcommand | Required Args |
|---|---|
| `mentat histogram` | datasource, column |
| `mentat scatter` | datasource, x_col, y_col |
| `mentat line` | datasource, time_col, value_col |
| `mentat bar` | datasource, category_col |
| `mentat boxplot` | datasource, category_col, value_col |
| `mentat heatmap` | datasource, x_col, y_col, z_col |

Type-specific flags: `--bins N` (histogram), `--bucket auto|hourly|daily|weekly|monthly|yearly` (line).

## Self-Correction

- **Mechanical errors** (SQL, type mismatches, Gnuplot): retry up to 2 times
- **Logic errors** (0 rows, div by 0, timeout): escalate to user with alternative
- **Degenerate data** (1 row, all categorical, identical timestamps): escalate
- Always propose alternatives when analysis impossible

## Advanced Features

See [REFERENCE.md](REFERENCE.md) for:
- Assumptions Block — declare all non-trivial decisions before analysis
- Business terms — disambiguate churn, active, high-value
- Join discovery — FK inference rules and depth cap
- Large results — auto-reduction strategies
- Data sources — SQLite, flat files, directory input specifics
- Configuration — env vars, config file priority
- Token budget — soft target per query
