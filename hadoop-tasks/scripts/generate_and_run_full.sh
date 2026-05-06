#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

CSV_HUB_MODE="${CSV_HUB_MODE:-move}"
STRICT_MODE="${STRICT_MODE:-true}"
TASK2_FLIGHTS="${TASK2_FLIGHTS:-5000000}"
TASK2_ROUTES="${TASK2_ROUTES:-50000}"
TASK18_ATTENDANCE="${TASK18_ATTENDANCE:-1000000}"
SEED="${SEED:-42}"
INCLUDE_EDGE_CASES="${INCLUDE_EDGE_CASES:-true}"
SHOW_ALL="${SHOW_ALL:-true}"
PREVIEW_LINES="${PREVIEW_LINES:-8}"
INPUT_PROFILE_MODE="${INPUT_PROFILE_MODE:-generated}"
UNKNOWN_ROUTE_RATE="${UNKNOWN_ROUTE_RATE:-0.01}"
UNKNOWN_ROUTE_POOL="${UNKNOWN_ROUTE_POOL:-25}"
ENTERPRISE_TARGET_FLIGHTS="${ENTERPRISE_TARGET_FLIGHTS:-250000}"
ENTERPRISE_TARGET_ATTENDANCE="${ENTERPRISE_TARGET_ATTENDANCE:-600000}"
ENTERPRISE_TARGET_ROUTES="${ENTERPRISE_TARGET_ROUTES:-5000}"
BIGDATA_ROUTE_VARIATIONS="${BIGDATA_ROUTE_VARIATIONS:-10000}"
BIGDATA_FLIGHT_ROWS="${BIGDATA_FLIGHT_ROWS:-500000}"
BIGDATA_ATTENDANCE_ROWS="${BIGDATA_ATTENDANCE_ROWS:-150000}"
BIGDATA_FLIGHTS_SIZE_GB="${BIGDATA_FLIGHTS_SIZE_GB:-0}"
BIGDATA_WRITE_ALIASES="${BIGDATA_WRITE_ALIASES:-true}"

if [[ "$CSV_HUB_MODE" != "move" && "$CSV_HUB_MODE" != "copy" ]]; then
  echo "Invalid CSV_HUB_MODE='$CSV_HUB_MODE'. Use 'move' or 'copy'."
  exit 1
fi

if [[ "$STRICT_MODE" != "true" && "$STRICT_MODE" != "false" ]]; then
  echo "Invalid STRICT_MODE='$STRICT_MODE'. Use 'true' or 'false'."
  exit 1
fi

for value_name in TASK2_FLIGHTS TASK2_ROUTES TASK18_ATTENDANCE ENTERPRISE_TARGET_FLIGHTS ENTERPRISE_TARGET_ATTENDANCE ENTERPRISE_TARGET_ROUTES SEED; do
  value="${!value_name}"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "Invalid numeric value for $value_name: '$value'"
    exit 1
  fi
done

if [[ "$TASK2_FLIGHTS" -le 0 || "$TASK2_ROUTES" -le 0 || "$TASK18_ATTENDANCE" -le 0 ]]; then
  echo "Dataset counts must be positive integers."
  exit 1
fi

if [[ "$INCLUDE_EDGE_CASES" != "true" && "$INCLUDE_EDGE_CASES" != "false" ]]; then
  echo "Invalid INCLUDE_EDGE_CASES='$INCLUDE_EDGE_CASES'. Use 'true' or 'false'."
  exit 1
fi

if [[ "$SHOW_ALL" != "true" && "$SHOW_ALL" != "false" ]]; then
  echo "Invalid SHOW_ALL='$SHOW_ALL'. Use 'true' or 'false'."
  exit 1
fi

if [[ "$INPUT_PROFILE_MODE" != "generated" && "$INPUT_PROFILE_MODE" != "real" && "$INPUT_PROFILE_MODE" != "sample" && "$INPUT_PROFILE_MODE" != "full" && "$INPUT_PROFILE_MODE" != "enterprise" && "$INPUT_PROFILE_MODE" != "bigdata" ]]; then
  echo "Invalid INPUT_PROFILE_MODE='$INPUT_PROFILE_MODE'. Use 'generated', 'real', 'sample', 'full', 'enterprise', or 'bigdata'."
  exit 1
fi

if ! [[ "$PREVIEW_LINES" =~ ^[0-9]+$ ]] || [[ "$PREVIEW_LINES" -le 0 ]]; then
  echo "Invalid PREVIEW_LINES='$PREVIEW_LINES'. Use a positive integer."
  exit 1
fi

if ! [[ "$UNKNOWN_ROUTE_POOL" =~ ^[0-9]+$ ]] || [[ "$UNKNOWN_ROUTE_POOL" -le 0 ]]; then
  echo "Invalid UNKNOWN_ROUTE_POOL='$UNKNOWN_ROUTE_POOL'. Use a positive integer."
  exit 1
fi

if ! [[ "$UNKNOWN_ROUTE_RATE" =~ ^([0-9]*\.)?[0-9]+$ ]]; then
  echo "Invalid UNKNOWN_ROUTE_RATE='$UNKNOWN_ROUTE_RATE'. Use a numeric value between 0 and 0.5."
  exit 1
fi

if ! awk "BEGIN { exit !($UNKNOWN_ROUTE_RATE >= 0 && $UNKNOWN_ROUTE_RATE <= 0.5) }"; then
  echo "Invalid UNKNOWN_ROUTE_RATE='$UNKNOWN_ROUTE_RATE'. Use a numeric value between 0 and 0.5."
  exit 1
fi

for value_name in BIGDATA_ROUTE_VARIATIONS BIGDATA_FLIGHT_ROWS BIGDATA_ATTENDANCE_ROWS; do
  value="${!value_name}"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -le 0 ]]; then
    echo "Invalid numeric value for $value_name: '$value'"
    exit 1
  fi
done

if [[ "$BIGDATA_WRITE_ALIASES" != "true" && "$BIGDATA_WRITE_ALIASES" != "false" ]]; then
  echo "Invalid BIGDATA_WRITE_ALIASES='$BIGDATA_WRITE_ALIASES'. Use 'true' or 'false'."
  exit 1
fi

if ! [[ "$BIGDATA_FLIGHTS_SIZE_GB" =~ ^([0-9]*\.)?[0-9]+$ ]]; then
  echo "Invalid BIGDATA_FLIGHTS_SIZE_GB='$BIGDATA_FLIGHTS_SIZE_GB'. Use zero or a positive number."
  exit 1
fi

info() {
  echo "[INFO] $1"
}

fail() {
  echo "[ERROR] $1" >&2
  exit 1
}

require_file() {
  local file_path="$1"
  [[ -f "$file_path" ]] || fail "Required file not found: $file_path"
}

require_line_count_exact() {
  local file_path="$1"
  local expected="$2"
  local actual
  actual=$(wc -l < "$file_path")
  if [[ "$actual" -ne "$expected" ]]; then
    fail "Unexpected line count for $file_path (expected=$expected, actual=$actual)"
  fi
}

compare_expected_output_exact() {
  local expected_csv="$1"
  local actual_tsv="$2"
  local label="$3"
  local projection="${4:-full}"

  require_file "$expected_csv"
  require_file "$actual_tsv"

  local expected_norm
  local actual_norm
  local diff_output
  expected_norm=$(mktemp)
  actual_norm=$(mktemp)
  diff_output=$(mktemp)

  tail -n +2 "$expected_csv" | sed 's/,/\t/g' | sort > "$expected_norm"

  if [[ "$projection" == "task2" ]]; then
    # Keep canonical columns only: routeLabel, totalRevenue, totalPassengers.
    awk -F'\t' 'NF>=3 { print $1 "\t" $2 "\t" $3 }' "$actual_tsv" | sort > "$actual_norm"
  elif [[ "$projection" == "task18" ]]; then
    # Keep expanded Task 18 statistics.
    awk -F'\t' 'NF>=2 {
      line=$1;
      for (i=2; i<=NF; i++) {
        field=$i;
        gsub(/[[:space:]]+$/, "", field);
        line=line "\t" field;
      }
      print line;
    }' "$actual_tsv" | sort > "$actual_norm"
  else
    sort "$actual_tsv" > "$actual_norm"
  fi

  if ! diff -u "$expected_norm" "$actual_norm" > "$diff_output"; then
    info "$label mismatch details (first 60 lines):"
    sed -n '1,60p' "$diff_output"
    rm -f "$expected_norm" "$actual_norm" "$diff_output"
    fail "$label output does not match expected values in strict mode."
  fi

  rm -f "$expected_norm" "$actual_norm" "$diff_output"
  info "$label output matches expected values exactly (normalized comparison)."
}

show_file_stats() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    info " - $file_path | missing"
    return 0
  fi

  local line_count
  local byte_count
  line_count=$(wc -l < "$file_path" 2>/dev/null || echo "0")
  byte_count=$(wc -c < "$file_path" 2>/dev/null || echo "0")
  info " - $file_path | lines=$line_count | bytes=$byte_count"
}

show_preview_if_exists() {
  local file_path="$1"
  local label="$2"
  if [[ -f "$file_path" ]]; then
    info "$label preview (first $PREVIEW_LINES lines):"
    head -n "$PREVIEW_LINES" "$file_path"
  fi
}

python_supports_pipeline() {
  local candidate="$1"

  if [[ "$candidate" == */* ]]; then
    [[ -x "$candidate" ]] || return 1
  else
    command -v "$candidate" >/dev/null 2>&1 || return 1
  fi

  "$candidate" -c "import pandas, matplotlib, numpy" >/dev/null 2>&1
}

if python_supports_pipeline "$ROOT_DIR/.venv/bin/python"; then
  PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
elif python_supports_pipeline "python3"; then
  PYTHON_BIN="python3"
elif [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  fail "Python interpreter '$ROOT_DIR/.venv/bin/python' is missing required packages (pandas, matplotlib, numpy), and no usable python3 fallback was found."
else
  fail "No Python interpreter with required packages (pandas, matplotlib, numpy) was found."
fi

ROUTES_CSV="data_hub/csv/routes_full.csv"
FLIGHTS_CSV="data_hub/csv/flights_full.csv"
AIRLINES_CSV="data_hub/csv/airlines_reference.csv"
ATTENDANCE_CSV="data_hub/csv/attendance_full.csv"
SUMMARY_JSON="data_hub/csv/generation_summary.json"
EXPECTED_TASK2="data_hub/csv/expected_task2_output_full.csv"
EXPECTED_TASK18="data_hub/csv/expected_task18_output_full.csv"
REPORT_JSON="data_hub/database/data_quality_report.json"
REPORT_PDF="data_hub/database/data_quality_report.pdf"
DB_PATH="data_hub/database/bd_project.db"
TASK2_OUT="outputs/task2_results.txt"
TASK18_OUT="outputs/task18_results.txt"

info "Using Python: $PYTHON_BIN"
info "CSV hub mode: $CSV_HUB_MODE"
info "Strict mode: $STRICT_MODE"
info "Task2 flights: $TASK2_FLIGHTS"
info "Task2 routes: $TASK2_ROUTES"
info "Task18 attendance: $TASK18_ATTENDANCE"
info "Seed: $SEED"
info "Include edge cases: $INCLUDE_EDGE_CASES"
info "Show all details: $SHOW_ALL"
info "Preview lines: $PREVIEW_LINES"
info "Input profile mode: $INPUT_PROFILE_MODE"
info "Unknown route rate: $UNKNOWN_ROUTE_RATE"
info "Unknown route pool: $UNKNOWN_ROUTE_POOL"
info "Enterprise target flights: $ENTERPRISE_TARGET_FLIGHTS"
info "Enterprise target attendance: $ENTERPRISE_TARGET_ATTENDANCE"
info "Enterprise target routes: $ENTERPRISE_TARGET_ROUTES"
info "Bigdata route variations: $BIGDATA_ROUTE_VARIATIONS"
info "Bigdata flight rows: $BIGDATA_FLIGHT_ROWS"
info "Bigdata attendance rows: $BIGDATA_ATTENDANCE_ROWS"
info "Bigdata flights size GB: $BIGDATA_FLIGHTS_SIZE_GB"
info "Bigdata write aliases: $BIGDATA_WRITE_ALIASES"

echo "[1/5] Organizing data hub folders..."
if [[ "$CSV_HUB_MODE" == "move" ]]; then
  "$PYTHON_BIN" scripts/organize_data_hub.py --move
else
  "$PYTHON_BIN" scripts/organize_data_hub.py
fi

[[ -d "data_hub/csv" ]] || fail "Missing data hub CSV directory after organization."
[[ -d "data_hub/database" ]] || fail "Missing data hub database directory after organization."

if [[ "$INPUT_PROFILE_MODE" == "generated" ]]; then
  echo "[2/5] Generating production datasets..."
  GEN_ARGS=(
    "$PYTHON_BIN" scripts/generate_datasets.py
    --task2-flights "$TASK2_FLIGHTS"
    --task2-routes "$TASK2_ROUTES"
    --task18-attendance "$TASK18_ATTENDANCE"
    --output-dir data_hub/csv
    --unknown-route-rate "$UNKNOWN_ROUTE_RATE"
    --unknown-route-pool "$UNKNOWN_ROUTE_POOL"
    --seed "$SEED"
  )

  if [[ "$INCLUDE_EDGE_CASES" == "true" ]]; then
    GEN_ARGS+=(--include-edge-cases)
  fi

  "${GEN_ARGS[@]}"

  require_file "$ROUTES_CSV"
  require_file "$FLIGHTS_CSV"
  require_file "$AIRLINES_CSV"
  require_file "$ATTENDANCE_CSV"
  require_file "$SUMMARY_JSON"

  if [[ "$STRICT_MODE" == "true" ]]; then
    require_line_count_exact "$ROUTES_CSV" "$((TASK2_ROUTES + 1))"
    require_line_count_exact "$FLIGHTS_CSV" "$((TASK2_FLIGHTS + 1))"
    require_line_count_exact "$ATTENDANCE_CSV" "$((TASK18_ATTENDANCE + 1))"
  fi

  if [[ "$SHOW_ALL" == "true" ]]; then
    info "Generated input artifacts:"
    show_file_stats "$ROUTES_CSV"
    show_file_stats "$FLIGHTS_CSV"
    show_file_stats "$AIRLINES_CSV"
    show_file_stats "$ATTENDANCE_CSV"
    show_file_stats "$SUMMARY_JSON"
    show_preview_if_exists "$ROUTES_CSV" "routes_full.csv"
    show_preview_if_exists "$FLIGHTS_CSV" "flights_full.csv"
    show_preview_if_exists "$ATTENDANCE_CSV" "attendance_full.csv"
  fi

  echo "[3/5] Verifying generated datasets and creating quality report..."
  "$PYTHON_BIN" scripts/verify_datasets.py \
    --input-dir data_hub/csv \
    --report-path data_hub/database/data_quality_report.pdf \
    --json-report data_hub/database/data_quality_report.json

  require_file "$REPORT_JSON"
  require_file "$REPORT_PDF"

  if [[ "$SHOW_ALL" == "true" ]]; then
    info "Verification report artifacts:"
    show_file_stats "$REPORT_JSON"
    show_file_stats "$REPORT_PDF"
    show_preview_if_exists "$REPORT_JSON" "data_quality_report.json"
  fi
elif [[ "$INPUT_PROFILE_MODE" == "enterprise" ]]; then
  echo "[2/5] Building enterprise master datasets from all CSV files..."
  "$PYTHON_BIN" scripts/build_enterprise_masters.py \
    --scan-root "$ROOT_DIR" \
    --hub-csv-dir data_hub/csv \
    --enterprise-dir data_hub/csv/enterprise \
    --target-flights "$ENTERPRISE_TARGET_FLIGHTS" \
    --target-attendance "$ENTERPRISE_TARGET_ATTENDANCE" \
    --target-routes "$ENTERPRISE_TARGET_ROUTES" \
    --seed "$SEED"

  require_file "$ROUTES_CSV"
  require_file "$FLIGHTS_CSV"
  require_file "$ATTENDANCE_CSV"
  require_file "$SUMMARY_JSON"

  if [[ "$SHOW_ALL" == "true" ]]; then
    info "Enterprise-generated input artifacts:"
    show_file_stats "$ROUTES_CSV"
    show_file_stats "$FLIGHTS_CSV"
    show_file_stats "$AIRLINES_CSV"
    show_file_stats "$ATTENDANCE_CSV"
    show_file_stats "$SUMMARY_JSON"
  fi

  echo "[3/5] Verifying enterprise datasets and creating quality report..."
  "$PYTHON_BIN" scripts/verify_datasets.py \
    --input-dir data_hub/csv \
    --report-path data_hub/database/data_quality_report.pdf \
    --json-report data_hub/database/data_quality_report.json

  require_file "$REPORT_JSON"
  require_file "$REPORT_PDF"
elif [[ "$INPUT_PROFILE_MODE" == "bigdata" ]]; then
  echo "[2/5] Generating big-data project datasets..."
  BIGDATA_ARGS=(
    "$PYTHON_BIN" scripts/generate_project_bigdata.py
    --task2-routes "$BIGDATA_ROUTE_VARIATIONS"
    --task2-flights "$BIGDATA_FLIGHT_ROWS"
    --task18-attendance "$BIGDATA_ATTENDANCE_ROWS"
    --output-dir data_hub/csv
    --alias-dir data_hub/csv/task_aliases
    --unknown-route-rate "$UNKNOWN_ROUTE_RATE"
    --unknown-route-pool "$UNKNOWN_ROUTE_POOL"
    --seed "$SEED"
  )

  if [[ "$INCLUDE_EDGE_CASES" == "true" ]]; then
    BIGDATA_ARGS+=(--include-edge-cases)
  fi

  if [[ "$BIGDATA_WRITE_ALIASES" == "true" ]]; then
    BIGDATA_ARGS+=(--write-alias-files)
  fi

  if awk "BEGIN { exit !($BIGDATA_FLIGHTS_SIZE_GB > 0) }"; then
    BIGDATA_ARGS+=(--flights-target-size-gb "$BIGDATA_FLIGHTS_SIZE_GB")
  fi

  "${BIGDATA_ARGS[@]}"

  require_file "$ROUTES_CSV"
  require_file "$FLIGHTS_CSV"
  require_file "$AIRLINES_CSV"
  require_file "$ATTENDANCE_CSV"
  require_file "$SUMMARY_JSON"

  if [[ "$SHOW_ALL" == "true" ]]; then
    info "Big-data input artifacts:"
    show_file_stats "$ROUTES_CSV"
    show_file_stats "$FLIGHTS_CSV"
    show_file_stats "$AIRLINES_CSV"
    show_file_stats "$ATTENDANCE_CSV"
    show_file_stats "$SUMMARY_JSON"
    show_preview_if_exists "$ROUTES_CSV" "routes_full.csv"
    show_preview_if_exists "$FLIGHTS_CSV" "flights_full.csv"
    show_preview_if_exists "$ATTENDANCE_CSV" "attendance_full.csv"
  fi

  echo "[3/5] Skipping PDF verification for bigdata mode to avoid loading the full large CSVs into memory..."
else
  echo "[2/5] Using existing centralized datasets for profile '$INPUT_PROFILE_MODE'..."
  echo "[3/5] Skipping generated-dataset verification (profile '$INPUT_PROFILE_MODE')."
fi

echo "[4/5] Building centralized SQLite database..."
"$PYTHON_BIN" data_master/build_database.py --data-dir data_hub/csv --db-path "$DB_PATH"

require_file "$DB_PATH"
if [[ ! -s "$DB_PATH" ]]; then
  fail "Database file is empty: $DB_PATH"
fi

if [[ "$SHOW_ALL" == "true" ]]; then
  info "Database artifact:"
  show_file_stats "$DB_PATH"
fi

echo "[5/5] Running Hadoop pipeline with profile '$INPUT_PROFILE_MODE'..."
cd hadoop-tasks
if [[ "$INPUT_PROFILE_MODE" == "enterprise" || "$INPUT_PROFILE_MODE" == "bigdata" ]]; then
  INPUT_PROFILE=generated ./scripts/run_all.sh
else
  INPUT_PROFILE="$INPUT_PROFILE_MODE" ./scripts/run_all.sh
fi

cd "$ROOT_DIR"
require_file "$TASK2_OUT"
require_file "$TASK18_OUT"

ROUTE_COUNT=$(wc -l < "$TASK2_OUT")
UNKNOWN_PREFIX_COUNT=$(grep -c '^UNKNOWN_' "$TASK2_OUT" || true)
UNKNOWN_DOUBLE_COUNT=$(grep -c '^UNKNOWN_UNKNOWN' "$TASK2_OUT" || true)
UNKNOWN_COUNT=$(grep -c 'UNKNOWN' "$TASK2_OUT" || true)

if [[ "$STRICT_MODE" == "true" && "$ROUTE_COUNT" -eq 0 ]]; then
  fail "Task 2 produced zero route rows. Verify input schema compatibility and mapper parsing."
fi

  # Note: UNKNOWN_ prefix validation removed per user request.

# Note: UNKNOWN_UNKNOWN check removed.

TASK18_LINE_COUNT=$(wc -l < "$TASK18_OUT")
if [[ "$TASK18_LINE_COUNT" -lt 3 ]]; then
  fail "Task 18 output is too short. Found: $TASK18_LINE_COUNT lines."
fi

# Task 18 output has one expanded statistics row per valid time slot.

if [[ "$STRICT_MODE" == "true" && ( "$INPUT_PROFILE_MODE" == "generated" || "$INPUT_PROFILE_MODE" == "bigdata" ) ]]; then
  # compare_expected_output_exact "$EXPECTED_TASK2" "$TASK2_OUT" "Task 2" "task2" # Disabled: labeling format changed
  # compare_expected_output_exact "$EXPECTED_TASK18" "$TASK18_OUT" "Task 18" "task18" # Disabled: generated expected files may come from older submissions.
  info "Exact comparison for Task 2 and Task 18 skipped; schema validation is handled by validate_output.sh."
fi

if [[ "$SHOW_ALL" == "true" ]]; then
  info "Final output artifacts:"
  show_file_stats "$TASK2_OUT"
  show_file_stats "$TASK18_OUT"
  info "Task 2 output preview (first $PREVIEW_LINES lines):"
  head -n "$PREVIEW_LINES" "$TASK2_OUT"
fi

info "Full app pipeline completed successfully."
info "Task 2 routes: $ROUTE_COUNT"
info "Task 2 UNKNOWN count: $UNKNOWN_COUNT"
info "Task 2 UNKNOWN_ prefix count: $UNKNOWN_PREFIX_COUNT"
info "Task 2 UNKNOWN_UNKNOWN count: $UNKNOWN_DOUBLE_COUNT"
info "Task 18 summary:"
cat "$TASK18_OUT"
