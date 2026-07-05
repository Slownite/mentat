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
    duckdb -c "ATTACH 'test.sqlite' AS _sql (TYPE SQLITE); CREATE TABLE _sql.users(id INTEGER PRIMARY KEY, name TEXT, age INTEGER); CREATE TABLE _sql.orders(id INTEGER PRIMARY KEY, user_id INTEGER, amount REAL);" 2>/dev/null
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
    duckdb -c "ATTACH 'empty.sqlite' AS _empty (TYPE SQLITE);" 2>/dev/null
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

@test "mentat_histogram generates PNG from CSV" {
    echo "value" > test.csv; for i in $(seq 1 50); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat_histogram" test.csv value -o test_hist.png
    [ "$status" -eq 0 ]
    [ -f test_hist.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat_histogram --ascii generates terminal output" {
    echo "value" > test.csv; for i in $(seq 1 20); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat_histogram" test.csv value --ascii
    [ "$status" -eq 0 ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat_histogram rejects missing column" {
    echo "value" > test.csv; echo "1" >> test.csv
    run "$SCRIPTS_DIR/mentat_histogram" test.csv
    [ "$status" -eq 1 ]
    [[ "$output" =~ "column required" ]]
}

@test "mentat_scatter generates PNG from CSV" {
    echo "x,y" > test.csv; echo "1,2" >> test.csv; echo "3,4" >> test.csv; echo "5,6" >> test.csv
    run "$SCRIPTS_DIR/mentat_scatter" test.csv x y -o test_scatter.png
    [ "$status" -eq 0 ]
    [ -f test_scatter.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat_line generates PNG from CSV" {
    echo "dt,val" > test.csv; echo "2024-01-01,10" >> test.csv; echo "2024-01-02,20" >> test.csv; echo "2024-01-03,15" >> test.csv
    run "$SCRIPTS_DIR/mentat_line" test.csv dt val -o test_line.png
    [ "$status" -eq 0 ]
    [ -f test_line.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat_bar generates PNG from CSV" {
    echo "cat,val" > test.csv; echo "a,10" >> test.csv; echo "b,20" >> test.csv; echo "c,15" >> test.csv
    run "$SCRIPTS_DIR/mentat_bar" test.csv cat -o test_bar.png
    [ "$status" -eq 0 ]
    [ -f test_bar.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat_boxplot generates PNG from CSV" {
    echo "cat,val" > test.csv; echo "a,1" >> test.csv; echo "a,2" >> test.csv; echo "b,10" >> test.csv; echo "b,12" >> test.csv
    run "$SCRIPTS_DIR/mentat_boxplot" test.csv cat val -o test_box.png
    [ "$status" -eq 0 ]
    [ -f test_box.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat_heatmap generates PNG from CSV" {
    echo "x,y,z" > test.csv; echo "1,2,5" >> test.csv; echo "3,4,8" >> test.csv; echo "5,6,3" >> test.csv
    run "$SCRIPTS_DIR/mentat_heatmap" test.csv x y z -o test_heat.png
    [ "$status" -eq 0 ]
    [ -f test_heat.png ]
    [[ "$output" =~ "saved" ]]
}
