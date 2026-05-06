import os
import argparse

def organize_hub(move_mode=False):
    dirs = [
        "data_hub/csv",
        "data_hub/database",
        "data_hub/csv/enterprise",
        "outputs"
    ]
    for d in dirs:
        os.makedirs(d, exist_ok=True)
        print(f"Ensured directory: {d}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--move", action="store_true")
    args = parser.parse_args()
    organize_hub(args.move)
