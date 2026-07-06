{ config, lib, pkgs, ... }:

let
  cfg = config.programs.mentat;
in
{
  options.programs.mentat = {
    enable = lib.mkEnableOption "Mentat token-efficient EDA agent";

    maxRows = lib.mkOption {
      type = lib.types.int;
      default = 100000;
      description = "Maximum rows before truncation";
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
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      duckdb
      qsv
      gnuplot
      jq
    ];

    home.file.".agents/skills/mentat/SKILL.md".text = builtins.readFile ../SKILL.md;

    home.file.".agents/skills/mentat/scripts".source = ../scripts;

    home.file.".config/mentat/config".text = ''
      MENTAT_MAX_ROWS=${toString cfg.maxRows}
      MENTAT_MAX_RETRIES=${toString cfg.maxRetries}
      MENTAT_OUTPUT_DIR=${cfg.outputDir}
      MENTAT_OUTLIER_METHOD=${cfg.outlierMethod}
    '';

    home.sessionPath = [
      "${config.home.homeDirectory}/.agents/skills/mentat/scripts"
    ];
  };
}
