# Mentat

Token-efficient, CLI-driven exploratory data analysis agent. Works with any AI agent that can execute shell commands. Uses lightweight CLI tools (DuckDB, QSV, Gnuplot) instead of heavy Python libraries.

[![CI](https://github.com/Slownite/mentat/actions/workflows/test.yml/badge.svg)](https://github.com/Slownite/mentat/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Requirements

- [DuckDB](https://duckdb.org/) >= 0.9 (`brew install duckdb` / `sudo apt install duckdb` / `nix-shell -p duckdb`)
- [QSV](https://github.com/jqnatividad/qsv) (`brew install qsv` / [download binary](https://github.com/jqnatividad/qsv/releases))
- [Gnuplot](https://gnuplot.info/) (`brew install gnuplot` / `sudo apt install gnuplot`)

## Installation

### NixOS / Home-Manager

```nix
inputs.mentat.url = "github:Slownite/mentat";
```

Then in your home-manager config:

```nix
{
  imports = [ inputs.mentat.homeManagerModules.mentat ];

  programs.mentat = {
    enable = true;
    tokenBudget = 6000;
    maxRetries = 2;
    outputDir = "./mentat_output";
  };
}
```

### Manual

```bash
# Clone the repository
git clone https://github.com/Slownite/mentat ~/mentat

# Symlink to your agent's skills directory (e.g., OpenCode: ~/.agents/skills/mentat)
ln -s ~/mentat ~/.agents/skills/mentat

# Install dependencies
# macOS:
brew install duckdb qsv gnuplot

# Ubuntu/Debian:
sudo apt install duckdb gnuplot
# QSV: download from https://github.com/jqnatividad/qsv/releases

# Fedora:
sudo dnf install duckdb gnuplot
# QSV: download from https://github.com/jqnatividad/qsv/releases

# Verify installation
~/.agents/skills/mentat/scripts/mentat_selfcheck

# Optional: add scripts to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.agents/skills/mentat/scripts:$PATH"

# Optional: create config
mkdir -p ~/.config/mentat
cp ~/mentat/config.example ~/.config/mentat/config
```

## Usage

In your AI agent, load the Mentat skill and ask questions:

```
# Analytical Query (high-level)
Based on my SQLite database, what are the primary factors driving user churn?

# Direct Plot Request (explicit chart)
Show me a histogram of transaction amounts faceted by region.
```

## CLI

Mentat provides helper scripts that the agent invokes during analysis:

| Script | Purpose |
|--------|---------|
| `mentat_selfcheck` | Validate required dependencies (DuckDB, QSV, Gnuplot) |
| `mentat_inspect` | Discover schema from CSV, Parquet, JSON, or SQLite sources |
| `mentat_query` | Execute SQL via DuckDB and return stats-enriched results |
| `mentat_histogram` | Histogram (distribution of 1 numeric column) |
| `mentat_scatter` | Scatter plot (correlation of 2 numeric columns) |
| `mentat_line` | Line chart (time-series trend) |
| `mentat_bar` | Bar chart (categorical frequencies) |
| `mentat_boxplot` | Box plot (categorical vs numeric comparison) |
| `mentat_heatmap` | Heatmap (2D density / cross-tabulation) |

Each script supports `--help` for full flag documentation.

## Configuration

Settings are read from (in priority order):
1. Environment variables
2. `./mentat.config` (per-project)
3. `~/.config/mentat/config` (global)

| Variable | Default | Description |
|----------|---------|-------------|
| `MENTAT_TOKEN_BUDGET` | `6000` | Soft token target per query |
| `MENTAT_MAX_RETRIES` | `2` | Self-correction retry limit |
| `MENTAT_OUTPUT_DIR` | `./mentat_output` | Directory for plots and reports |
| `MENTAT_OUTLIER_METHOD` | `iqr` | Outlier detection method (`iqr` or `zscore`) |
| `MENTAT_TIMESERIES_BUCKET` | `auto` | Default time-series granularity |
| `MENTAT_LOG_LEVEL` | `info` | Logging level (`debug`, `info`, `warn`, `error`) |

## Architecture

```
mentat/
├── SKILL.md                    # Agent instructions
├── REFERENCE.md                # Edge case reference
├── scripts/                    # Helper scripts
│   ├── mentat_selfcheck        # Dependency validation
│   ├── mentat_inspect          # Schema discovery (Phase 1 + 2)
│   ├── mentat_query            # SQL execution + stats
│   ├── mentat_histogram        # Histogram chart
│   ├── mentat_scatter          # Scatter chart
│   ├── mentat_line             # Line chart
│   ├── mentat_bar              # Bar chart
│   ├── mentat_boxplot          # Box plot
│   └── mentat_heatmap          # Heatmap
├── config.example              # Example configuration
├── flake.nix                   # Nix flake
├── modules/
│   └── home-manager.nix        # Home-manager module
├── tests/
│   └── test_mentat.bats        # Test suite
└── README.md
```

## Testing

```bash
# Install bats
# macOS: brew install bats-core
# Ubuntu: sudo apt install bats

# Run tests
bats tests/ --verbose-run
```

## CI/CD

GitHub Actions runs the test suite on push and pull requests across Ubuntu and macOS.

## License

MIT
