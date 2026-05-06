import os
import argparse
import sqlite3
import pandas as pd

def build_db(data_dir, db_path):
    conn = sqlite3.connect(db_path)
    
    # Just load whatever CSVs are in the data_dir into sqlite
    for f in os.listdir(data_dir):
        if f.endswith(".csv"):
            table_name = f.split(".")[0]
            path = os.path.join(data_dir, f)
            try:
                # Use pandas for easy CSV-to-SQL
                df = pd.read_csv(path)
                df.to_sql(table_name, conn, if_exists='replace', index=False)
                print(f"Loaded {table_name} into database.")
            except Exception as e:
                print(f"Error loading {f}: {e}")
                
    conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir")
    parser.add_argument("--db-path")
    args = parser.parse_args()
    build_db(args.data_dir, args.db_path)
