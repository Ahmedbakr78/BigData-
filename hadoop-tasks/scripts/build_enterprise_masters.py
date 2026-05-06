import os
import csv
import json
import logging
from datetime import datetime
from collections import defaultdict

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EnterpriseDataBuilder:
    def __init__(self, scan_root, hub_csv_dir, enterprise_dir, target_flights=250000, target_attendance=600000, target_routes=5000, seed=42):
        self.scan_root = scan_root
        self.hub_csv_dir = hub_csv_dir
        self.enterprise_dir = enterprise_dir
        self.target_flights = target_flights
        self.target_attendance = target_attendance
        self.target_routes = target_routes
        self.seed = seed
        
        self.stats = {
            "flights": {"files_processed": 0, "total_records": 0, "duplicates_removed": 0, "invalid_rows": 0},
            "attendance": {"files_processed": 0, "total_records": 0, "duplicates_removed": 0, "invalid_rows": 0},
            "routes": {"files_processed": 0, "total_records": 0},
            "airlines": {"files_processed": 0, "total_records": 0},
            "airports": {"files_processed": 0, "total_records": 0},
            "employees": {"files_processed": 0, "total_records": 0}
        }

        # Reference data stores
        self.routes_ref = {}
        self.airlines_ref = {}
        self.airports_ref = {}
        self.employees_ref = {}

    def normalize_column_name(self, col):
        return col.strip().lower().replace(" ", "_").replace("id", "_id").replace("__", "_")

    def identify_csv_type(self, headers, filename):
        headers_set = set(self.normalize_column_name(h) for h in headers)
        
        # Flight detection
        if "flight_id" in headers_set or "flightld" in headers_set or ("route_code" in headers_set and "passenger_count" in headers_set):
            return "flight"
        
        # Attendance matrix detection
        if any(h.startswith("person_") for h in headers_set):
            return "attendance_matrix"
        
        # Attendance transactional detection
        if "employee_id" in headers_set and "time_slot" in headers_set:
            return "attendance_transactional"
        
        # Route detection
        if "route_code" in headers_set and "origin" in headers_set and "destination" in headers_set:
            return "route"
        
        # Airline detection
        if "airline_id" in headers_set and "iata" in headers_set:
            return "airline"
            
        # Airport detection
        if "airport_id" in headers_set and "latitude" in headers_set:
            return "airport"

        # Employee detection
        if "employee_id" in headers_set and "department" in headers_set and not "time_slot" in headers_set:
            return "employee"

        return "unknown"

    def scan_and_load_references(self):
        logger.info(f"Scanning {self.scan_root} for reference data...")
        for root, _, files in os.walk(self.scan_root):
            for f in files:
                if f.endswith(".csv"):
                    path = os.path.join(root, f)
                    try:
                        with open(path, 'r', encoding='utf-8') as csvfile:
                            reader = csv.reader(csvfile)
                            headers = next(reader, None)
                            if not headers: continue
                            
                            csv_type = self.identify_csv_type(headers, f)
                            if csv_type == "airline":
                                self.load_airlines(path, headers)
                            elif csv_type == "airport":
                                self.load_airports(path, headers)
                            elif csv_type == "route":
                                self.load_routes(path, headers)
                            elif csv_type == "employee":
                                self.load_employees(path, headers)
                    except Exception as e:
                        logger.error(f"Error processing {path}: {e}")

    def load_airlines(self, path, headers):
        with open(path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Standardize keys
                id_val = row.get("airline_id") or row.get("airlineId") or row.get("id")
                name_val = row.get("name") or row.get("airline")
                if id_val:
                    self.airlines_ref[id_val] = name_val
        self.stats["airlines"]["files_processed"] += 1
        self.stats["airlines"]["total_records"] = len(self.airlines_ref)

    def load_airports(self, path, headers):
        with open(path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                iata = row.get("iata") or row.get("IATA")
                if iata:
                    self.airports_ref[iata] = row
        self.stats["airports"]["files_processed"] += 1
        self.stats["airports"]["total_records"] = len(self.airports_ref)

    def load_routes(self, path, headers):
        with open(path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                code = row.get("routeCode") or row.get("route_code")
                if code:
                    self.routes_ref[code] = row
        self.stats["routes"]["files_processed"] += 1
        self.stats["routes"]["total_records"] = len(self.routes_ref)

    def load_employees(self, path, headers):
        with open(path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                eid = row.get("employee_id") or row.get("employeeId")
                if eid:
                    self.employees_ref[eid] = row
        self.stats["employees"]["files_processed"] += 1
        self.stats["employees"]["total_records"] = len(self.employees_ref)

    def build_flights_master(self):
        logger.info("Building MASTER_FLIGHTS_DATASET.csv...")
        output_path = os.path.join(self.hub_csv_dir, "flights_full.csv")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        fieldnames = ["flightId", "routeCode", "airline", "origin", "destination", "distance", 
                      "passengerCount", "fare", "revenue", "cost", "profit", "date"]
        
        seen_flights = set()
        
        with open(output_path, 'w', newline='', encoding='utf-8') as outfile:
            writer = csv.DictWriter(outfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for root, _, files in os.walk(self.scan_root):
                for f in files:
                    if not f.endswith(".csv"): continue
                    path = os.path.join(root, f)
                    
                    try:
                        with open(path, 'r', encoding='utf-8') as csvfile:
                            reader = csv.reader(csvfile)
                            headers = next(reader, None)
                            if not headers: continue
                            
                            if self.identify_csv_type(headers, f) != "flight":
                                continue
                            
                            csvfile.seek(0)
                            dict_reader = csv.DictReader(csvfile)
                            self.stats["flights"]["files_processed"] += 1
                            
                            for row in dict_reader:
                                flight_id = row.get("flightId") or row.get("flight_id") or row.get("flightld")
                                route_code = row.get("routeCode") or row.get("route_code")
                                date_val = row.get("date") or "2026-04-19"
                                
                                # Deduplication
                                key = f"{flight_id}_{date_val}"
                                if key in seen_flights:
                                    self.stats["flights"]["duplicates_removed"] += 1
                                    continue
                                seen_flights.add(key)
                                
                                # Basic fields
                                pass_count = int(row.get("passengerCount") or row.get("passengers") or 0)
                                fare = float(row.get("fare") or row.get("price") or 0)
                                
                                # Enrichment from routes
                                route_info = self.routes_ref.get(route_code, {})
                                origin = route_info.get("origin", "UNKNOWN")
                                destination = route_info.get("destination", "UNKNOWN")
                                distance = float(route_info.get("distanceKm") or route_info.get("distance") or 0)
                                
                                # Enrichment from airlines
                                airline_name = self.airlines_ref.get(row.get("airlineId") or row.get("airline"), "UNKNOWN")
                                
                                # Financials
                                revenue = pass_count * fare
                                cost = distance * 5.0 + (pass_count * 20.0) # Dummy cost model
                                profit = revenue - cost
                                
                                master_row = {
                                    "flightId": flight_id,
                                    "routeCode": route_code,
                                    "airline": airline_name,
                                    "origin": origin,
                                    "destination": destination,
                                    "distance": distance,
                                    "passengerCount": pass_count,
                                    "fare": fare,
                                    "revenue": round(revenue, 2),
                                    "cost": round(cost, 2),
                                    "profit": round(profit, 2),
                                    "date": date_val
                                }
                                writer.writerow(master_row)
                                self.stats["flights"]["total_records"] += 1
                                
                    except Exception as e:
                        logger.error(f"Error processing flight file {path}: {e}")

    def build_attendance_master(self):
        logger.info("Building MASTER_ATTENDANCE_DATASET.csv...")
        output_path = os.path.join(self.hub_csv_dir, "attendance_full.csv")
        
        fieldnames = ["employee_id", "department", "time_slot", "present", "expected_shift", 
                      "date", "leave_status", "deviation_minutes"]
        
        seen_attendance = set()
        
        with open(output_path, 'w', newline='', encoding='utf-8') as outfile:
            writer = csv.DictWriter(outfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for root, _, files in os.walk(self.scan_root):
                for f in files:
                    if not f.endswith(".csv"): continue
                    path = os.path.join(root, f)
                    
                    try:
                        with open(path, 'r', encoding='utf-8') as csvfile:
                            reader = csv.reader(csvfile)
                            headers = next(reader, None)
                            if not headers: continue
                            
                            csv_type = self.identify_csv_type(headers, f)
                            self.stats["attendance"]["files_processed"] += 1
                            
                            if csv_type == "attendance_matrix":
                                self.process_matrix_attendance(path, headers, writer, seen_attendance)
                            elif csv_type == "attendance_transactional":
                                self.process_transactional_attendance(path, headers, writer, seen_attendance)
                                
                    except Exception as e:
                        logger.error(f"Error processing attendance file {path}: {e}")

    def process_matrix_attendance(self, path, headers, writer, seen_attendance):
        with open(path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                date_val = row.get("date") or "2026-04-19"
                time_slot = row.get("time_slot") or "Morning"
                
                for col, val in row.items():
                    if col.startswith("Person_") or col.startswith("person_"):
                        emp_id = col
                        present = "Yes" if val in ["1", "Present", "P", "yes"] else "No"
                        
                        key = f"{emp_id}_{date_val}_{time_slot}"
                        if key in seen_attendance:
                            self.stats["attendance"]["duplicates_removed"] += 1
                            continue
                        seen_attendance.add(key)
                        
                        self.write_attendance_row(writer, emp_id, time_slot, present, date_val)

    def process_transactional_attendance(self, path, headers, writer, seen_attendance):
        with open(path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                emp_id = row.get("employee_id") or row.get("employeeId")
                time_slot = row.get("time_slot")
                present = row.get("present") or row.get("status")
                date_val = row.get("date") or "2026-04-19"
                
                key = f"{emp_id}_{date_val}_{time_slot}"
                if key in seen_attendance:
                    self.stats["attendance"]["duplicates_removed"] += 1
                    continue
                seen_attendance.add(key)
                
                self.write_attendance_row(writer, emp_id, time_slot, present, date_val)

    def write_attendance_row(self, writer, emp_id, time_slot, present, date_val):
        emp_info = self.employees_ref.get(emp_id, {})
        dept = emp_info.get("department", "UNKNOWN")
        expected_shift = emp_info.get("work_shift") or "09:00-17:00"
        
        # Simple logic for deviation and leave
        leave_status = "None"
        deviation = 0
        if present == "No":
            if "holiday" in date_val.lower():
                leave_status = "Public Holiday"
            elif hash(emp_id + date_val) % 20 == 0: # Randomly assign some leaves
                leave_status = "Approved Leave"
                
        if present == "Yes" and hash(emp_id + date_val) % 10 == 0:
            deviation = (hash(emp_id + date_val) % 30) # Late by up to 30 mins
            
        writer.writerow({
            "employee_id": emp_id,
            "department": dept,
            "time_slot": time_slot,
            "present": present,
            "expected_shift": expected_shift,
            "date": date_val,
            "leave_status": leave_status,
            "deviation_minutes": deviation
        })
        self.stats["attendance"]["total_records"] += 1

    def run(self):
        self.scan_and_load_references()
        self.build_flights_master()
        self.build_attendance_master()
        
        # Save summary
        summary_path = os.path.join(self.hub_csv_dir, "generation_summary.json")
        with open(summary_path, 'w') as f:
            json.dump(self.stats, f, indent=4)
        logger.info(f"Summary saved to {summary_path}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--scan-root", required=True)
    parser.add_argument("--hub-csv-dir", required=True)
    parser.add_argument("--enterprise-dir", required=True)
    parser.add_argument("--target-flights", type=int, default=250000)
    parser.add_argument("--target-attendance", type=int, default=600000)
    parser.add_argument("--target-routes", type=int, default=5000)
    parser.add_argument("--seed", type=int, default=42)
    
    args = parser.parse_args()
    
    builder = EnterpriseDataBuilder(
        scan_root=args.scan_root,
        hub_csv_dir=args.hub_csv_dir,
        enterprise_dir=args.enterprise_dir,
        target_flights=args.target_flights,
        target_attendance=args.target_attendance,
        target_routes=args.target_routes,
        seed=args.seed
    )
    builder.run()
