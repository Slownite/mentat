---
name: Mentat
description: Token-efficient EDA agent — inspect, query, and visualize data via DuckDB, QSV & Gnuplot. All output is JSON. Use when user provides data files (CSV, Parquet, JSON, SQLite) and asks analytical questions or requests charts.
---

# Mentat

CLI-driven EDA using DuckDB, QSV and Gnuplot. No Python libraries needed. All output is **JSON**.

## Quick Start

```
mentat selfcheck              # verify tools (once per session)
mentat inspect data.csv       # schema discovery (once per session)
mentat query data.csv "SELECT col1, COUNT(*) FROM data GROUP BY col1"
mentat histogram data.csv col1
```

## Prerequisites

Run `mentat selfcheck` at session start. Exit 0 = all good. Required: `duckdb`, `qsv`, `gnuplot`, `jq`.

Script: `~/.agents/skills/mentat/scripts/mentat`. Add to PATH or reference directly.

All data flows through pipes — no temp files or scratch directories used.

## JSON Output Convention

Every command outputs a single JSON object to stdout:

```
{"status":"ok","data":{...}}
{"status":"error","error":{"message":"...","code":1}}
```

Parse the `status` field. If `error`, read `error.message`. If `ok`, read `data`.

### Common response fields

| Field | Type | Description |
|---|---|---|
| `status` | string | `"ok"` or `"error"` |
| `data` | object | Present on success |
| `data.rows` | int | Row count (query/inspect) |
| `data.sample` | array | Data sample (query default mode) |
| `data.image` | string | PNG path (charts with `-o`) |
| `data.warning` | string | Non-fatal advisory |

## Workflows

### 1. Analytical Query

High-level question (e.g., "what drives churn?"):
1. `mentat inspect <path>` — discover schema
2. Propose approach → get user confirmation
3. `mentat query <path> <sql>` — execute with optional `--timeseries`, `--histogram`, `--groupby`, `--outlier-method`, `--raw`

Parse `data.stats` for min, max, mean, median, p25, p75, stddev, outliers.

### 2. Direct Plot

Explicit chart request:
- Single command: `mentat <chart-type> <path> <args> [--output PATH]`
- JSON response includes chart data; `--output` adds `data.image`

**If user requests a chart type that doesn't match the data, propose a data-appropriate alternative. Never render a misleading chart.**

## Commands

### Schema Discovery

`mentat inspect <path>` — returns `data.columns` as array of `{name, type}`.

`--stats <table>` for row count, null ratios, distinct counts, value ranges on each column.

### Query

`mentat query <path> <sql> [flags]`

For the `SQL` argument, you can pass it as a positional argument or pipe it via stdin.

Flags: `--histogram`, `--bins N`, `--groupby COL`, `--timeseries`, `--bucket auto|hourly|daily|weekly|monthly|yearly`, `--outlier-method iqr|zscore`, `--raw`, `--table NAME`

Default mode returns `data.stats` (min, max, mean, median, p25, p75, stddev) and `data.outliers` on the first numeric column. If the column is non-numeric, returns `data.frequency` instead.

#### Query modes and their `data` shape:

| Mode | Key field | Shape |
|---|---|---|
| default | `stats` | `{"min":1,"max":100,"mean":50,"median":45,"p25":25,"p75":75,"stddev":28}` |
| default | `outliers` | `{"count":3,"method":"iqr","bounds":[12.5,112.5]}` |
| default | `sample` | `[10,20,30]` |
| `--raw` | `data` | `[[1,"a"],[2,"b"]]` with `columns` and `capped` |
| `--histogram` (numeric) | `bins` | `[{"center":10,"pct":5.0}]` with `mode:"histogram"` |
| `--histogram` (categorical) | `categories` | `[{"category":"A","n":10}]` with `mode:"frequency"` |
| `--groupby` | `groups` | `[{"group":"A","n":10,"mean":50,"med":45}]` |
| `--timeseries` | `points` | `[{"ts":"2024-01-01","n":10,"mean":50}]` with `bucket` |

### Visualization

DuckDB aggregation + optional Gnuplot PNG render. No ASCII output. `--output PATH` saves PNG and includes `"image"` in response.

| Subcommand | Required Args | Key `data` field |
|---|---|---|
| `histogram` | datasource, column | `bins: [{center, pct}]` |
| `scatter` | datasource, x_col, y_col | `points: [{x, y}], correlation` |
| `line` | datasource, time_col, value_col | `points: [{ts, val}], bucket` |
| `bar` | datasource, category_col | `bars: [{category, n}]` |
| `boxplot` | datasource, category_col, value_col | `groups: [{category, mn, q1, med, q3, mx}]` |
| `heatmap` | datasource, x_col, y_col, z_col | `grid: [{x, y, z}]` |

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
