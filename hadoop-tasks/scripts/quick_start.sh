#!/bin/bash


echo "Starting Hadoop MapReduce Tasks..."
echo "This will:"
echo "  1. Check Docker status"
echo "  2. Build Docker image"
echo "  3. Build FULL input CSV files (largest available datasets)"
echo "  4. Compile and run Task 2 (Flight Route Enrichment)"
echo "  5. Compile and run Task 18 (Time Slot Partitioning)"
echo ""
echo "Full app mode (recommended):"
echo "  FULL_APP=true ./scripts/quick_start.sh"
echo "  or from project root: ./run_full_app.sh"
echo "  - Move all CSV files into data_hub/csv"
echo "  - Use data_hub/database for DB and reports"
echo "  - Generate + verify + build DB + run Hadoop pipeline"
echo ""
echo "Input profile options:"
echo "  INPUT_PROFILE=full   -> use largest files (default)"
echo "  INPUT_PROFILE=real   -> prefer *_real.csv"
echo "  INPUT_PROFILE=sample -> prefer *_sample.csv"
echo "  INPUT_PROFILE=generated -> use data_hub/csv/*.csv (fallback: data_master/generated_data/*.csv)"
echo "  INPUT_PROFILE=hub -> same as generated"
echo ""

if [[ "${FULL_APP:-false}" == "true" ]]; then
    echo "Running full app pipeline..."
    if [[ -f "../run_full_app.sh" ]]; then
        (cd .. && ./run_full_app.sh)
    else
        ./scripts/generate_and_run_full.sh
    fi
    exit $?
fi

if [[ "${AUTO_YES:-false}" != "true" ]]; then
    read -p "Continue? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

INPUT_PROFILE=${INPUT_PROFILE:-full} ./scripts/run_all.sh
