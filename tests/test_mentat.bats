#!/usr/bin/env bats

setup() {
    SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "mentat selfcheck finds required dependencies" {
    run "$SCRIPTS_DIR/mentat" selfcheck
    [ "$status" -eq 0 ]
    [[ "$output" =~ "duckdb" ]]
    [[ "$output" =~ "qsv" ]]
    [[ "$output" =~ "gnuplot" ]]
    [[ "$output" =~ "All dependencies found" ]]
}

@test "mentat inspect handles missing file" {
    run "$SCRIPTS_DIR/mentat" inspect /nonexistent/file.db
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "mentat inspect returns schema for CSV" {
    echo "id,name,age" > test.csv
    echo "1,Alice,30" >> test.csv
    echo "2,Bob,25" >> test.csv
    run "$SCRIPTS_DIR/mentat" inspect test.csv
    [ "$status" -eq 0 ]
    [[ "$output" =~ "id" ]]
    [[ "$output" =~ "name" ]]
    [[ "$output" =~ "age" ]]
}

@test "mentat inspect returns schema for SQLite" {
    duckdb -c "INSTALL sqlite_scanner; LOAD sqlite_scanner; ATTACH 'test_sqlite.db' AS _s (TYPE SQLITE); CREATE TABLE _s.users(id INTEGER PRIMARY KEY, name TEXT, age INTEGER); CREATE TABLE _s.orders(id INTEGER PRIMARY KEY, user_id INTEGER, amount REAL);" 2>/dev/null
    # rename to .sqlite for inspection
    mv test_sqlite.db test.sqlite
    run "$SCRIPTS_DIR/mentat" inspect test.sqlite
    [ "$status" -eq 0 ]
    [[ "$output" =~ "users" ]]
    [[ "$output" =~ "orders" ]]
    [[ "$output" =~ "PK" ]]
}

@test "mentat inspect rejects unsupported format" {
    echo "hello" > test.txt
    run "$SCRIPTS_DIR/mentat" inspect test.txt
    [ "$status" -eq 1 ]
    [[ "$output" =~ "unsupported" ]]
}

@test "mentat inspect handles empty SQLite database" {
    duckdb -c "INSTALL sqlite_scanner; LOAD sqlite_scanner; ATTACH 'empty.db' AS _e (TYPE SQLITE); CREATE TABLE _e.empty_tbl(id INTEGER); DROP TABLE _e.empty_tbl;" 2>/dev/null
    run "$SCRIPTS_DIR/mentat" inspect empty.db
    [ "$status" -eq 1 ]
    [[ "$output" =~ "no tables" ]]
}

@test "mentat query returns stats for numeric data" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    echo "2,20" >> test.csv
    echo "3,30" >> test.csv
    echo "4,40" >> test.csv
    echo "5,50" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT value FROM read_csv_auto('test.csv')"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "rows=5" ]]
    [[ "$output" =~ "min" ]]
    [[ "$output" =~ "max" ]]
    [[ "$output" =~ "mean" ]]
    [[ "$output" =~ "median" ]]
    [[ "$output" =~ "sample:" ]]
}

@test "mentat query handles empty result set" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT * FROM read_csv_auto('test.csv') WHERE value > 100"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "rows=0" ]]
}

@test "mentat query handles single row result" {
    echo "id,value" > test.csv
    echo "1,42" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT * FROM read_csv_auto('test.csv') WHERE id = 1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "rows=1" ]]
    [[ "$output" =~ "WARNING" ]]
}

@test "mentat query --histogram returns bins" {
    echo "value" > test.csv
    for i in $(seq 1 50); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT value FROM read_csv_auto('test.csv')" --histogram --bins=10
    [ "$status" -eq 0 ]
    [[ "$output" =~ "bin_center" ]]
    [[ "$output" =~ "n" ]]
}

@test "mentat query --raw returns rows" {
    echo "id,value" > test.csv
    echo "1,10" >> test.csv
    echo "2,20" >> test.csv
    run "$SCRIPTS_DIR/mentat" query test.csv "SELECT * FROM read_csv_auto('test.csv')" --raw
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1,10" ]]
    [[ "$output" =~ "2,20" ]]
}

@test "mentat histogram generates PNG from CSV" {
    echo "value" > test.csv; for i in $(seq 1 50); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat" histogram test.csv value -o test_hist.png
    [ "$status" -eq 0 ]
    [ -f test_hist.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat histogram outputs ASCII by default" {
    echo "value" > test.csv; for i in $(seq 1 20); do echo "$i" >> test.csv; done
    run "$SCRIPTS_DIR/mentat" histogram test.csv value
    [ "$status" -eq 0 ]
}

@test "mentat histogram rejects missing column" {
    echo "value" > test.csv; echo "1" >> test.csv
    run "$SCRIPTS_DIR/mentat" histogram test.csv
    [ "$status" -eq 1 ]
    [[ "$output" =~ "column required" ]]
}

@test "mentat scatter generates PNG from CSV" {
    echo "x,y" > test.csv; echo "1,2" >> test.csv; echo "3,4" >> test.csv; echo "5,6" >> test.csv
    run "$SCRIPTS_DIR/mentat" scatter test.csv x y -o test_scatter.png
    [ "$status" -eq 0 ]
    [ -f test_scatter.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat line generates PNG from CSV" {
    echo "dt,val" > test.csv; echo "2024-01-01,10" >> test.csv; echo "2024-01-02,20" >> test.csv; echo "2024-01-03,15" >> test.csv
    run "$SCRIPTS_DIR/mentat" line test.csv dt val -o test_line.png
    [ "$status" -eq 0 ]
    [ -f test_line.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat bar generates PNG from CSV" {
    echo "cat,val" > test.csv; echo "a,10" >> test.csv; echo "b,20" >> test.csv; echo "c,15" >> test.csv
    run "$SCRIPTS_DIR/mentat" bar test.csv cat -o test_bar.png
    [ "$status" -eq 0 ]
    [ -f test_bar.png ]
    [[ "$output" =~ "saved" ]]
}

@test "mentat boxplot generates PNG from CSV" {
    echo "cat,val" > test.csv; echo "a,1" >> test.csv; echo "a,2" >> test.csv; echo "b,10" >> test.csv; echo "b,12" >> test.csv
    run "$SCRIPTS_DIR/mentat" boxplot test.csv cat val -o test_box.png
    [ "$status" -eq 0 ]
    [ -f test_box.png ]
    [[ "$output" =~ "saved" ]]
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
    [[ "$output" =~ "saved" ]]
}

@test "mentat heatmap generates PNG from CSV" {
    echo "x,y,z" > test.csv; echo "1,2,5" >> test.csv; echo "3,4,8" >> test.csv; echo "5,6,3" >> test.csv
    run "$SCRIPTS_DIR/mentat" heatmap test.csv x y z -o test_heat.png
    [ "$status" -eq 0 ]
    [ -f test_heat.png ]
    [[ "$output" =~ "saved" ]]
}
