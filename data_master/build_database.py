#!/usr/bin/env python3

import argparse
import re
import sqlite3
from pathlib import Path

import pandas as pd

CHUNKED_LOAD_THRESHOLD_BYTES = 64 * 1024 * 1024
CSV_CHUNK_ROWS = 50000


def sanitize_table_name(filename: str) -> str:
    name = Path(filename).stem.strip()
    name = re.sub(r"[^a-zA-Z0-9]", "_", name)
    name = re.sub(r"_+", "_", name)
    return name.strip("_").lower()


def sanitize_column_names(columns) -> list[str]:
    return [
        re.sub(r"[^a-zA-Z0-9]", "_", str(col).strip()).strip("_")
        for col in columns
    ]


def load_csv_frame(csv_path: Path) -> pd.DataFrame:
    try:
        return pd.read_csv(csv_path, low_memory=False)
    except Exception as decode_error:
        print(f"  [warn] fallback decoding for {csv_path.name}: {type(decode_error).__name__}")
        return pd.read_csv(csv_path, encoding="ISO-8859-1", low_memory=False)


def ingest_csv_in_chunks(csv_path: Path, conn: sqlite3.Connection, table_name: str) -> tuple[int, int]:
    last_error: Exception | None = None

    for encoding in (None, "ISO-8859-1"):
        try:
            wrote_table = False
            total_rows = 0
            num_cols = 0

            reader = pd.read_csv(
                csv_path,
                low_memory=False,
                chunksize=CSV_CHUNK_ROWS,
                encoding=encoding,
            )

            for chunk in reader:
                chunk.columns = sanitize_column_names(chunk.columns)
                num_cols = len(chunk.columns)
                chunk.to_sql(table_name, conn, if_exists="replace" if not wrote_table else "append", index=False)
                wrote_table = True
                total_rows += len(chunk)

            if not wrote_table:
                empty_df = pd.read_csv(csv_path, low_memory=False, nrows=0, encoding=encoding)
                empty_df.columns = sanitize_column_names(empty_df.columns)
                num_cols = len(empty_df.columns)
                empty_df.to_sql(table_name, conn, if_exists="replace", index=False)

            return total_rows, num_cols
        except Exception as ingest_error:
            last_error = ingest_error
            conn.execute(f'DROP TABLE IF EXISTS "{table_name}"')
            if encoding is None:
                print(f"  [warn] chunked fallback decoding for {csv_path.name}: {type(ingest_error).__name__}")
                continue
            raise

    if last_error is not None:
        raise last_error
    raise RuntimeError(f"Failed to ingest CSV in chunks: {csv_path}")


def compile_database(data_dir: Path, db_path: Path) -> int:
    print("Initializing unified database compilation...")
    print(f"CSV source directory: {data_dir}")
    print(f"Target database file: {db_path}\n")

    if not data_dir.exists():
        print(f"Error: CSV source directory does not exist: {data_dir}")
        return 1

    csv_files = sorted([p for p in data_dir.iterdir() if p.suffix.lower() == ".csv"])
    if not csv_files:
        print("Error: no CSV files found to compile.")
        return 1

    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))

    print(f"Found {len(csv_files)} CSV datasets. Starting ingestion...\n")

    for count, csv_path in enumerate(csv_files, 1):
        table_name = sanitize_table_name(csv_path.name)

        try:
            file_size = csv_path.stat().st_size
            if file_size > 500 * 1024 * 1024:
                print(f"[{count:02}/{len(csv_files)}] skipping '{csv_path.name}' (size > 500MB is too large for SQLite ingestion)")
                continue

            if file_size >= CHUNKED_LOAD_THRESHOLD_BYTES:
                num_rows, num_cols = ingest_csv_in_chunks(csv_path, conn, table_name)
                mode_label = "chunked"
            else:
                df = load_csv_frame(csv_path)
                df.columns = sanitize_column_names(df.columns)
                num_rows, num_cols = df.shape
                df.to_sql(table_name, conn, if_exists="replace", index=False)
                mode_label = "single-pass"

            print(
                f"[{count:02}/{len(csv_files)}] loaded '{csv_path.name}' -> table [{table_name}] "
                f"({num_rows:,} rows | {num_cols} cols | {mode_label})"
            )
            conn.commit()
        except Exception as ingest_error:
            print(f"[{count:02}/{len(csv_files)}] failed '{csv_path.name}': {ingest_error}")

    conn.close()

    size_mb = db_path.stat().st_size / (1024 * 1024)
    print(f"\nDatabase compilation completed. Final DB size: {size_mb:.2f} MB")
    return 0


def parse_args() -> argparse.Namespace:
    project_root = Path(__file__).resolve().parents[1]
    default_csv_dir = project_root / "data_hub" / "csv"
    default_db_path = project_root / "data_hub" / "database" / "bd_project.db"

    parser = argparse.ArgumentParser(description="Build SQLite database from centralized CSV data.")
    parser.add_argument("--data-dir", type=Path, default=default_csv_dir)
    parser.add_argument("--db-path", type=Path, default=default_db_path)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    raise SystemExit(compile_database(args.data_dir, args.db_path))
