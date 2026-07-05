{ config, lib, pkgs, ... }:

let
  cfg = config.programs.mentat;
in
{
  options.programs.mentat = {
    enable = lib.mkEnableOption "Mentat token-efficient EDA agent";

    tokenBudget = lib.mkOption {
      type = lib.types.int;
      default = 6000;
      description = "Soft token target per query";
    };

    maxRetries = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Self-correction retry limit";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "./mentat_output";
      description = "Directory for plots and reports";
    };

    outlierMethod = lib.mkOption {
      type = lib.types.enum [ "iqr" "zscore" ];
      default = "iqr";
      description = "Default outlier detection method";
    };

    timeseriesBucket = lib.mkOption {
      type = lib.types.enum [ "auto" "hourly" "daily" "weekly" "monthly" "yearly" ];
      default = "auto";
      description = "Default time-series bucketing";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      duckdb
      qsv
      gnuplot
    ];

    home.file.".agents/skills/mentat/SKILL.md".text = builtins.readFile ../SKILL.md;

    home.file.".agents/skills/mentat/scripts".source = ../scripts;

    home.file.".config/mentat/config".text = ''
      MENTAT_TOKEN_BUDGET=${toString cfg.tokenBudget}
      MENTAT_MAX_RETRIES=${toString cfg.maxRetries}
      MENTAT_OUTPUT_DIR=${cfg.outputDir}
      MENTAT_OUTLIER_METHOD=${cfg.outlierMethod}
      MENTAT_TIMESERIES_BUCKET=${cfg.timeseriesBucket}
    '';

    home.sessionPath = [
      "${config.home.homeDirectory}/.agents/skills/mentat/scripts"
    ];
  };
}
