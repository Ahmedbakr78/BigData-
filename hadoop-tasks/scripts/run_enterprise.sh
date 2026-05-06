#!/bin/bash
set -euo pipefail

# Enterprise Hadoop Pipeline Orchestrator
# This script runs the Python ETL then the Hadoop MapReduce jobs.

# 1. Organization
python3 scripts/organize_data_hub.py

# 2. ETL Phase: Build Master Datasets
echo "Running Enterprise ETL Pipeline..."
python3 scripts/build_enterprise_masters.py \
    --scan-root "." \
    --hub-csv-dir "data_hub/csv" \
    --enterprise-dir "data_hub/csv/enterprise"

# 3. Reference Data for Task 2 (Routes for DistributedCache)
# The master builder also creates routes_full.csv (via scan) or we use the original.
# If routes_full.csv exists in data_hub, use it.
if [ -f "data_hub/csv/routes_full.csv" ]; then
    ROUTES_SRC="data_hub/csv/routes_full.csv"
else
    # Fallback to creating a minimal one if missing
    echo "routeCode,origin,destination,distanceKm" > data_hub/csv/routes_full.csv
    echo "R001,DXB,LHR,5500" >> data_hub/csv/routes_full.csv
    ROUTES_SRC="data_hub/csv/routes_full.csv"
fi

# 4. Run Hadoop Pipeline
echo "Starting Hadoop MapReduce Jobs..."
# Use existing run_all.sh but override input profile
INPUT_PROFILE=generated ./scripts/run_all.sh

# 5. Summarize Results
echo -e "\n=========================================="
echo "      ENTERPRISE PIPELINE SUMMARY"
echo "=========================================="
echo "Datasets Produced:"
ls -lh data_hub/csv/*.csv

echo -e "\nTask 2 - Flight Route Enrichment (Top Routes):"
sort -k2 -nr outputs/task2_results.txt | head -n 10

echo -e "\nTask 18 - Attendance Summary:"
cat outputs/task18_results.txt

echo "=========================================="
echo "Pipeline Completed Successfully."
