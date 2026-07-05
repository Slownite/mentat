#!/usr/bin/env bats

setup() {
    SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "mentat_selfcheck finds required dependencies" {
    run "$SCRIPTS_DIR/mentat_selfcheck"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "duckdb" ]]
    [[ "$output" =~ "qsv" ]]
    [[ "$output" =~ "gnuplot" ]]
    [[ "$output" =~ "All dependencies found" ]]
}

@test "mentat_inspect handles missing file" {
    run "$SCRIPTS_DIR/mentat_inspect" /nonexistent/file.db
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "mentat_inspect returns schema for CSV" {
    echo "id,name,age" > test.csv
    echo "1,Alice,30" >> test.csv
    echo "2,Bob,25" >> test.csv
    run "$SCRIPTS_DIR/mentat_inspect" test.csv
    [ "$status" -eq 0 ]
    [[ "$output" =~ "id" ]]
    [[ "$output" =~ "name" ]]
    [[ "$output" =~ "age" ]]
}

@test "mentat_inspect returns schema for SQLite" {
    duckdb test.sqlite -c "CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, age INTEGER); CREATE TABLE orders(id INTEGER PRIMARY KEY, user_id INTEGER REFERENCES users(id), amount REAL);" 2>/dev/null
    run "$SCRIPTS_DIR/mentat_inspect" test.sqlite
    [ "$status" -eq 0 ]
    [[ "$output" =~ "users" ]]
    [[ "$output" =~ "orders" ]]
    [[ "$output" =~ "id PK" ]]
}

@test "mentat_inspect rejects unsupported format" {
    echo "hello" > test.txt
    run "$SCRIPTS_DIR/mentat_inspect" test.txt
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unsupported" ]]
}

@test "mentat_inspect handles empty SQLite database" {
    duckdb empty.sqlite "SELECT 1;" 2>/dev/null
    run "$SCRIPTS_DIR/mentat_inspect" empty.sqlite
    [ "$status" -eq 1 ]
    [[ "$output" =~ "no tables" ]]
}

@test "mentat_query returns stats for numeric data" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    echo "2,20" >> test.csv
    echo "3,30" >> test.csv
    echo "4,40" >> test.csv
    echo "5,50" >> test.csv
    run "$SCRIPTS_DIR/mentat_query" test.csv "SELECT value FROM read_csv_auto('test.csv')"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "rows=5" ]]
    [[ "$output" =~ "min" ]]
    [[ "$output" =~ "max" ]]
    [[ "$output" =~ "mean" ]]
    [[ "$output" =~ "median" ]]
    [[ "$output" =~ "sample:" ]]
}

@test "mentat_query handles empty result set" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    run "$SCRIPTS_DIR/mentat_query" test.csv "SELECT * FROM read_csv_auto('test.csv') WHERE value > 100"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "rows=0" ]]
}

@test "mentat_query handles single row result" {
    echo "id,value" > test.csv
    echo "1,42" >> test.csv
    run "$SCRIPTS_DIR/mentat_query" test.csv "SELECT * FROM read_csv_auto('test.csv') WHERE id = 1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "rows=1" ]]
    [[ "$output" =~ "WARNING" ]]
}

@test "mentat_query --histogram returns bins" {
    echo "value" > test.csv
    for i in $(seq 1 50); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat_query" test.csv "SELECT value FROM read_csv_auto('test.csv')" --histogram --bins=10
    [ "$status" -eq 0 ]
    [[ "$output" =~ "bin_center" ]]
    [[ "$output" =~ "cnt" ]]
}

@test "mentat_query --raw returns rows" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    echo "2,20" >> test.csv
    run "$SCRIPTS_DIR/mentat_query" test.csv "SELECT * FROM read_csv_auto('test.csv')" --raw
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1,10" ]]
    [[ "$output" =~ "2,20" ]]
}

@test "mentat_plot generates PNG for histogram" {
    echo "bin_center,count" > test.csv
    echo "1.0,5" >> test.csv
    echo "2.0,10" >> test.csv
    echo "3.0,15" >> test.csv
    run "$SCRIPTS_DIR/mentat_plot" test.csv histogram output.png
    [ "$status" -eq 0 ]
    [ -f output.png ]
    [[ "$output" =~ "Plot saved" ]]
}

@test "mentat_plot --ascii generates terminal output" {
    echo "bin_center,count" > test.csv
    echo "1.0,5" >> test.csv
    echo "2.0,10" >> test.csv
    run "$SCRIPTS_DIR/mentat_plot" test.csv histogram out.png --ascii
    [ "$status" -eq 0 ]
}

@test "mentat_plot handles missing data file" {
    run "$SCRIPTS_DIR/mentat_plot" nonexistent.csv histogram out.png
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "mentat_plot rejects unknown template" {
    echo "x,y" > test.csv
    echo "1,2" >> test.csv
    run "$SCRIPTS_DIR/mentat_plot" test.csv unknown out.png
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown template" ]]
}
