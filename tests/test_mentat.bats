#!/usr/bin/env bats

setup() {
    SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# === selfcheck ===

@test "mentat selfcheck finds required dependencies" {
    run "$SCRIPTS_DIR/mentat" selfcheck
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local deps
    deps=$(echo "$output" | jq '.data.dependencies | length')
    [ "$deps" -eq 4 ]
    local all_found
    all_found=$(echo "$output" | jq '[.data.dependencies[].found] | all')
    [ "$all_found" = "true" ]
}

# === inspect ===

@test "mentat inspect handles missing file" {
    run "$SCRIPTS_DIR/mentat" inspect /nonexistent/file.db
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
    [[ "$(echo "$output" | jq -r '.error.message')" =~ "not found" ]]
}

@test "mentat inspect returns schema for CSV" {
    echo "id,name,age" > test.csv
    echo "1,Alice,30" >> test.csv
    echo "2,Bob,25" >> test.csv
    run "$SCRIPTS_DIR/mentat" inspect test.csv
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local col_count
    col_count=$(echo "$output" | jq '.data.col_count')
    [ "$col_count" -ge 3 ]
}

@test "mentat inspect returns schema for SQLite" {
    duckdb -c "INSTALL sqlite_scanner; LOAD sqlite_scanner; ATTACH 'test_sqlite.db' AS _s (TYPE SQLITE); CREATE TABLE _s.users(id INTEGER PRIMARY KEY, name TEXT, age INTEGER); CREATE TABLE _s.orders(id INTEGER PRIMARY KEY, user_id INTEGER, amount REAL);" 2>/dev/null
    mv test_sqlite.db test.sqlite
    run "$SCRIPTS_DIR/mentat" inspect test.sqlite
    [ "$status" -eq 0 ]
    local status tables
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    tables=$(echo "$output" | jq '.data.tables')
    [ "$tables" -ge 2 ]
}

@test "mentat inspect rejects unsupported format" {
    echo "hello" > test.txt
    run "$SCRIPTS_DIR/mentat" inspect test.txt
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "mentat inspect handles empty SQLite database" {
    duckdb -c "INSTALL sqlite_scanner; LOAD sqlite_scanner; ATTACH 'empty.db' AS _e (TYPE SQLITE); CREATE TABLE _e.empty_tbl(id INTEGER); DROP TABLE _e.empty_tbl;" 2>/dev/null
    run "$SCRIPTS_DIR/mentat" inspect empty.db
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

# === query ===

@test "mentat query returns stats for numeric data" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    echo "2,20" >> test.csv
    echo "3,30" >> test.csv
    echo "4,40" >> test.csv
    echo "5,50" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT value FROM read_csv_auto('test.csv')"
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local rows
    rows=$(echo "$output" | jq '.data.rows')
    [ "$rows" -eq 5 ]
    local has_stats
    has_stats=$(echo "$output" | jq 'has("data") and (.data | has("stats"))')
    [ "$has_stats" = "true" ]
    local sample
    sample=$(echo "$output" | jq '.data.sample | length')
    [ "$sample" -gt 0 ]
}

@test "mentat query handles empty result set" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT * FROM read_csv_auto('test.csv') WHERE value > 100"
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local rows
    rows=$(echo "$output" | jq '.data.rows')
    [ "$rows" -eq 0 ]
}

@test "mentat query handles single row result" {
    echo "id,value" > test.csv
    echo "1,42" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT * FROM read_csv_auto('test.csv') WHERE id = 1"
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local rows
    rows=$(echo "$output" | jq '.data.rows')
    [ "$rows" -eq 1 ]
    local has_warning
    has_warning=$(echo "$output" | jq 'has("data") and (.data | has("warning"))')
    [ "$has_warning" = "true" ]
}

@test "mentat query --histogram returns bins" {
    echo "value" > test.csv
    for i in $(seq 1 50); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT value FROM read_csv_auto('test.csv')" --histogram --bins 10
    [ "$status" -eq 0 ]
    local status mode
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    mode=$(echo "$output" | jq -r '.data.mode')
    [ "$mode" = "histogram" ]
    local bins
    bins=$(echo "$output" | jq '.data.bins | length')
    [ "$bins" -gt 0 ]
}

@test "mentat query --raw returns rows" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    echo "2,20" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT * FROM read_csv_auto('test.csv')" --raw
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local rows
    rows=$(echo "$output" | jq '.data.rows')
    [ "$rows" -eq 2 ]
    local has_data
    has_data=$(echo "$output" | jq 'has("data") and (.data | has("data"))')
    [ "$has_data" = "true" ]
}

# === chart commands (PNG output) ===

@test "mentat histogram generates PNG from CSV" {
    echo "value" > test.csv; for i in $(seq 1 50); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat" histogram test.csv value -o test_hist.png
    [ "$status" -eq 0 ]
    [ -f test_hist.png ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local has_image
    has_image=$(echo "$output" | jq 'has("data") and (.data | has("image"))')
    [ "$has_image" = "true" ]
}

@test "mentat histogram outputs JSON by default" {
    echo "value" > test.csv; for i in $(seq 1 20); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat" histogram test.csv value
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local has_bins
    has_bins=$(echo "$output" | jq 'has("data") and (.data | has("bins"))')
    [ "$has_bins" = "true" ]
}

@test "mentat histogram rejects missing column" {
    echo "value" > test.csv; echo "1" >> test.csv
    run "$SCRIPTS_DIR/mentat" histogram test.csv
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "mentat scatter generates PNG from CSV" {
    echo "x,y" > test.csv; echo "1,2" >> test.csv; echo "3,4" >> test.csv; echo "5,6" >> test.csv
    run "$SCRIPTS_DIR/mentat" scatter test.csv x y -o test_scatter.png
    [ "$status" -eq 0 ]
    [ -f test_scatter.png ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local has_image
    has_image=$(echo "$output" | jq 'has("data") and (.data | has("image"))')
    [ "$has_image" = "true" ]
}

@test "mentat line generates PNG from CSV" {
    echo "dt,val" > test.csv; echo "2024-01-01,10" >> test.csv; echo "2024-01-02,20" >> test.csv; echo "2024-01-03,15" >> test.csv
    run "$SCRIPTS_DIR/mentat" line test.csv dt val -o test_line.png
    [ "$status" -eq 0 ]
    [ -f test_line.png ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local has_image
    has_image=$(echo "$output" | jq 'has("data") and (.data | has("image"))')
    [ "$has_image" = "true" ]
}

@test "mentat bar generates PNG from CSV" {
    echo "cat,val" > test.csv; echo "a,10" >> test.csv; echo "b,20" >> test.csv; echo "c,15" >> test.csv
    run "$SCRIPTS_DIR/mentat" bar test.csv cat -o test_bar.png
    [ "$status" -eq 0 ]
    [ -f test_bar.png ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local has_image
    has_image=$(echo "$output" | jq 'has("data") and (.data | has("image"))')
    [ "$has_image" = "true" ]
}

@test "mentat boxplot generates PNG from CSV" {
    echo "cat,val" > test.csv; echo "a,1" >> test.csv; echo "a,2" >> test.csv; echo "b,10" >> test.csv; echo "b,12" >> test.csv
    run "$SCRIPTS_DIR/mentat" boxplot test.csv cat val -o test_box.png
    [ "$status" -eq 0 ]
    [ -f test_box.png ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local has_image
    has_image=$(echo "$output" | jq 'has("data") and (.data | has("image"))')
    [ "$has_image" = "true" ]
}

@test "mentat boxplot shows multiple categories" {
    echo "lang,cer" > test.csv
    echo "fr,0.05" >> test.csv
    echo "fr,0.06" >> test.csv
    echo "en,0.04" >> test.csv
    echo "en,0.03" >> test.csv
    echo "es,0.07" >> test.csv
    echo "es,0.08" >> test.csv
    run "$SCRIPTS_DIR/mentat" boxplot test.csv lang cer -o test_box.png
    [ "$status" -eq 0 ]
    [ -f test_box.png ]
    local groups
    groups=$(echo "$output" | jq '.data.groups | length')
    [ "$groups" -eq 3 ]
}

@test "mentat heatmap generates PNG from CSV" {
    echo "x,y,z" > test.csv; echo "1,2,5" >> test.csv; echo "3,4,8" >> test.csv; echo "5,6,3" >> test.csv
    run "$SCRIPTS_DIR/mentat" heatmap test.csv x y z -o test_heat.png
    [ "$status" -eq 0 ]
    [ -f test_heat.png ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local has_image
    has_image=$(echo "$output" | jq 'has("data") and (.data | has("image"))')
    [ "$has_image" = "true" ]
}

# === Error-case tests (P0 additions) ===

@test "inspect requires path" {
    run "$SCRIPTS_DIR/mentat" inspect
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "query requires path" {
    run "$SCRIPTS_DIR/mentat" query
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "query requires SQL" {
    echo "id,val" > test.csv
    echo "1,10" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "rejects unknown subcommand" {
    run "$SCRIPTS_DIR/mentat" nonexistent_cmd
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "histogram requires datasource" {
    run "$SCRIPTS_DIR/mentat" histogram
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "scatter requires y_col" {
    echo "x,y" > test.csv; echo "1,2" >> test.csv
    run "$SCRIPTS_DIR/mentat" scatter test.csv x
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "line requires bucket validation" {
    echo "dt,val" > test.csv; echo "2024-01-01,10" >> test.csv
    run "$SCRIPTS_DIR/mentat" line test.csv dt val --bucket century
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "boxplot requires value_col" {
    echo "cat,val" > test.csv; echo "a,1" >> test.csv
    run "$SCRIPTS_DIR/mentat" boxplot test.csv cat
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "heatmap requires z_col" {
    echo "x,y,z" > test.csv; echo "1,2,3" >> test.csv
    run "$SCRIPTS_DIR/mentat" heatmap test.csv x y
    [ "$status" -eq 1 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "error" ]
}

@test "display version" {
    run "$SCRIPTS_DIR/mentat" --version
    [ "$status" -eq 0 ]
    local status
    status=$(echo "$output" | jq -r '.status')
    [ "$status" = "ok" ]
    local ver
    ver=$(echo "$output" | jq -r '.data.version')
    [ "$ver" = "0.2.0" ]
}
