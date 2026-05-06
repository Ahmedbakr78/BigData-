import os
import argparse
import json
import csv

def verify(input_dir, report_path, json_report):
    files = ["flights_full.csv", "attendance_full.csv"]
    results = {}
    
    for f in files:
        path = os.path.join(input_dir, f)
        if os.path.exists(path):
            with open(path, 'r') as csvfile:
                reader = csv.reader(csvfile)
                header = next(reader)
                rows = sum(1 for _ in reader)
                results[f] = {"rows": rows, "header": header}
        else:
            results[f] = "MISSING"

    with open(json_report, 'w') as jf:
        json.dump(results, jf, indent=4)
    
    # Create a dummy PDF report (just a text file for now since I don't have a PDF lib)
    with open(report_path, 'w') as pf:
        pf.write(f"Data Quality Report\n{json.dumps(results, indent=4)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir")
    parser.add_argument("--report-path")
    parser.add_argument("--json-report")
    args = parser.parse_args()
    verify(args.input_dir, args.report_path, args.json_report)
