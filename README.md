




# Project Goals

The primary objective of this project is to engineer a production-grade, end-to-end Big Data pipeline that demonstrates advanced proficiency in distributed computing, data engineering, and automated validation. Rather than relying on a single script or a simplified analytics task, the project is designed to simulate a real-world enterprise data architecture where raw data is generated at scale, organized into a data lake structure, processed via distributed algorithms, and rigorously verified before final persistence. 

The specific technical and architectural goals of the project are detailed below.

**Demonstrate Advanced Hadoop MapReduce Proficiency**
A core goal is to move beyond basic word-count-style MapReduce implementations by utilizing advanced framework features required for enterprise data processing. The project specifically targets the implementation of a Map-Side Join using the Hadoop DistributedCache API (Task 2) and the implementation of a Custom Partitioner to override default data routing (Task 18). By mastering these patterns, the project proves the ability to optimize distributed computations for both performance and correctness, minimizing expensive network shuffling and guaranteeing deterministic data grouping.

**Design a Fully Automated, Idempotent Data Pipeline**
The project aims to eliminate manual intervention across the entire data lifecycle. This is achieved by architecting a sequential pipeline where data generation, data hub organization, master dataset merging, SQLite database population, Hadoop compilation, HDFS ingestion, job execution, and output retrieval are entirely orchestrated by Bash and Python scripts. A critical sub-goal is idempotency; the pipeline is designed with backup mechanisms and symlink-based input resolution so that re-running the entire application from a clean or partially complete state yields consistent, non-duplicative results.

**Ensure Absolute Data Integrity Through Automated Validation**
In distributed systems, verifying the correctness of parallel computations is inherently difficult due to non-deterministic task scheduling and output ordering. A primary goal of this project is to solve this challenge by implementing a deterministic data generation strategy (`generate_exact_data.py`) and a robust automated validation layer (`verify_datasets.py`). The system generates expected outputs with zero randomness prior to Hadoop execution, and post-processing scripts perform ordered, row-by-row comparisons against the Hadoop output, serializing discrepancies into a structured JSON report to guarantee mathematical correctness.

**Architect a Dual-Scale Data Processing Strategy**
The project is designed to support iterative development and massive-scale testing without architectural changes. This is accomplished through a dual-scale generation strategy. "Real" datasets contain thousands of rows with carefully injected edge cases (null values, boundary timestamps) for rapid debugging and unit testing. "Full" datasets contain hundreds of thousands to millions of rows designed specifically to saturate HDFS blocks and exercise Hadoop's parallel split logic. The goal is to prove that the MapReduce logic is equally correct and efficient on a laptop as it is on a multi-node big data cluster.

**Implement Environment Portability via Containerization**
To ensure that the distributed processing layer operates independently of host-system configurations, a key infrastructure goal is the complete containerization of the Hadoop environment. By encoding the exact Java version, Hadoop distribution, and environment variables into a Dockerfile, the project guarantees that the MapReduce jobs compile and execute identically on any machine with Docker installed. As a supplementary goal, a local Python-based MapReduce simulator (`run_local_mr.py`) is provided to replicate the distributed logic in-memory, ensuring that algorithmic development can continue even in environments where Docker is unavailable.

**Establish a Centralized Data Hub and Master Data Management Architecture**
The project aims to replicate enterprise master data management (MDM) practices. Instead of allowing generated data to exist in fragmented states, the pipeline funnels all raw outputs through a "Data Hub" that catalogs metadata via a manifest file. From this hub, enterprise master datasets are constructed by deduplicating and merging multiple scale variants into canonical sources of truth (`MASTER_FLIGHTS_DATASET.csv`, `MASTER_ATTENDANCE_DATASET.csv`). The goal is to demonstrate how to resolve data conflicts and establish a single, reliable source of truth for downstream analytical consumption.

## 1. Project 

The primary purpose of this application is to serve as an end-to-end Big Data analytics pipeline that processes, analyzes, and derives insights from airline flight datasets and employee attendance records using Hadoop MapReduce. The project demonstrates comprehensive data engineering capabilities, from synthetic data generation at scale through distributed processing to automated result validation and database storage.

The pipeline is structured around two core analytical tasks. Task 2 is a Cache Join Analysis, which is a MapReduce job that correlates cached flight log entries against actual flight metadata. It utilizes the Hadoop DistributedCache pattern to perform a highly efficient map-side join, outputting enriched flight records that validate cache coherence. Task 18 is a Time Slot Partitioning Analysis, which is a MapReduce job that processes employee attendance records. It employs a custom Java Partitioner to guarantee that records belonging to the same temporal time slot, such as Morning, Afternoon, or Night, are routed to the exact same Reducer, enabling precise localized aggregation of attendance metrics.

The high-level architecture is separated into five sequential tiers. The first is Data Generation, handled by Python scripts creating synthetic datasets. The second is Data Orchestration, organizing and merging data into master datasets. The third is Distributed Processing, executed by Java MapReduce within a Dockerized Hadoop cluster. The fourth is Validation, driven by Python comparison against expected outputs. The fifth is Persistent Storage, utilizing SQLite databases and structured CSV exports.

## 2. Tech Stack and Prerequisites

### Languages, Frameworks, and Libraries

The distributed processing layer is written in Java (version 8 or higher for Hadoop compatibility), utilizing the `org.apache.hadoop.mapreduce` package for Drivers, Mappers, Reducers, and Partitioners. The data generation, database construction, pipeline orchestration, and validation layers are written in Python (versions 3.12 and 3.13). Bash scripting is used for execution orchestration, Hadoop job submission, and Docker interactions. SQLite dialect SQL is used for local relational database storage and retrieval.

The core framework is Hadoop MapReduce, running inside a Docker container to provide a single-node cluster environment. Python standard libraries heavily utilized include `sqlite3` for database operations, `json` for configuration and report serialization, `os` and `pathlib` for file system traversal, `subprocess` for invoking shell commands, and `csv` for flat file parsing. Data generation scripts rely on `pandas` for DataFrame operations and `numpy` for numerical and statistical generation.

### Required Environment Variables and Credentials

This project does not utilize any external APIs. All datasets are generated synthetically using local Python scripts, meaning no API keys, tokens, or internet connectivity are required for any pipeline stage. However, Hadoop execution requires standard Java and Hadoop environment variables. `HADOOP_HOME` must point to the root directory of the Hadoop installation. `JAVA_HOME` must point to the root directory of the Java Development Kit. `HADOOP_CLASSPATH` must be configured to contain Hadoop core libraries and local execution paths. If these are unset, Hadoop job compilation and submission will fail. `PROJECT_ROOT` is an optional variable used by scripts to resolve paths dynamically; if unset, scripts default to using the current working directory.

## 3. Setup and Execution

### Installation Steps

To install the application, first ensure Python 3.12 or 3.13 is installed with the pip package manager. Second, install the Java Development Kit version 8 or 11. Third, install Docker and verify the Docker daemon is actively running. Fourth, clone or transfer the project directory to the local file system. Finally, install the optional Python data processing dependencies by executing `pip install pandas numpy` in the project root, which are required only for specific data generation and merging scripts.

### Execution Instructions

To generate all synthetic datasets, execute `python scripts/generate_datasets.py` from the project root. To generate only large-scale flight data, execute `python scripts/generate_big_flights.py`. To generate deterministic test data with known outputs, execute `python scripts/generate_exact_data.py`. To build the SQLite databases from the generated CSVs, execute `python data_master/build_database.py`. To structure raw data into the Data Hub, execute `python scripts/organize_data_hub.py`. To build the canonical enterprise master datasets, execute `python scripts/build_enterprise_masters.py`.

To execute the complete local pipeline sequentially, run `bash run_full_app.sh` or `bash run_pipeline.sh` from the project root. To execute the Hadoop tasks via Docker with a quick start using pre-existing data, navigate to the `hadoop-tasks/` directory and run `bash scripts/quick_start.sh`. To run a full generation and Hadoop execution cycle, run `bash scripts/generate_and_run_full.sh` in the same directory. To simulate MapReduce logic locally without Docker or Hadoop, execute `python run_local_mr.py` from the project root. To validate Hadoop output against expected results, run `bash validate_output.sh` or `python scripts/verify_datasets.py` from the project root.

## 4. Application Flow

### Phase 1: Synthetic Data Generation

Python generation scripts produce pairs of datasets differentiated by scale. Files suffixed with `_real` contain thousands of rows designed for rapid development testing. Files suffixed with `_full` contain hundreds of thousands to millions of rows designed to exercise Hadoop distributed capabilities. Generated entities include flight records, cache logs, attendance punch records, airline references, airport directories, route definitions, employee rosters, and work schedules.

### Phase 2: Data Hub Organization and Master Merging

Raw generated files are copied into the `data_hub/csv/` directory structure. The `organize_data_hub.py` script generates a `data_hub_manifest.csv` cataloging row counts and column structures. Subsequently, `build_enterprise_masters.py` deduplicates and merges the various `_real` and `_full` variants into canonical datasets named `MASTER_FLIGHTS_DATASET.csv`, `MASTER_ATTENDANCE_DATASET.csv`, and `MASTER_ROUTES_DATASET.csv`.

### Phase 3: Database Population

The `build_database.py` script reads the organized CSVs and executes SQLite `CREATE TABLE` and `INSERT INTO` operations. This populates both the working database located at `data_hub/database/bd_project.db` and the final canonical database at `final_database/database/bd_project.db`. During this phase, a `data_quality_report.json` is generated, documenting null counts and type distributions per column.

### Phase 4: Distributed Hadoop Processing

Inside the Dockerized Hadoop container, input CSVs are placed into HDFS. The Java source files for Task 2 and Task 18 are compiled into JARs. Task 2 loads flight data into the DistributedCache; the Mapper reads cache entries, looks up corresponding flight data in the local cache, and emits joined records. Task 18's Mapper extracts time slots from attendance timestamps, the custom `TimeSlotPartitioner` overrides default hashing to group by slot, and the Reducer calculates attendance aggregates. Output is pulled from HDFS into the `hadoop-tasks/output/` directory.

### Phase 5: Validation and Final Storage

The `verify_datasets.py` script parses the Hadoop `part-r-*` output files and compares them line-by-line against pre-computed expected output files. The results are serialized into `VALIDATION_REPORT.json`. Finally, validated outputs and logs are persisted to the `final_database/` directory.

## 5. Detailed File-by-File Documentation

### Hadoop MapReduce Java Sources

**hadoop-tasks/task2/CacheDriver.java**
This file configures and submits the Hadoop MapReduce job for cache analysis. Its input consists of command-line arguments specifying input paths, output paths, and the flight cache file path. It produces a Hadoop job execution context. The core logic involves calling `job.addCacheFile()` to distribute the flight reference data to all mapper nodes, and configuring the job with the specific `CacheMapper` and `CacheReducer` classes. It depends on the `org.apache.hadoop.conf.Configuration` and `org.apache.hadoop.mapreduce.Job` libraries.

**hadoop-tasks/task2/CacheMapper.java**
This file performs a map-side join of cache and flight data. Its input is cache CSV lines formatted as Text, alongside flight CSV data loaded via the DistributedCache. It outputs key-value pairs where the key is the flight ID and the value is the joined cache-flight record string. In the `setup()` method, it reads the distributed flight file into a local `HashMap<String, String[]>` mapping flight IDs to flight details. In the `map()` method, it splits the cache line, queries the HashMap using the flight ID, and emits the merged result.

**hadoop-tasks/task2/CacheReducer.java**
This file aggregates or formats the joined cache-flight records. Its input is a flight ID text key paired with an iterable of joined record strings. It outputs a formatted text line per flight ID. The logic iterates over the iterable of joined records for a specific flight ID, concatenates or counts the cache hits, and writes the final aggregated string using `context.write()`.

**hadoop-tasks/task18/TimeSlotDriver.java**
This file configures and submits the Hadoop MapReduce job for attendance time-slot analysis. Its input consists of command-line arguments for input and output paths. It produces a Hadoop job execution context. The core logic explicitly sets `TimeSlotPartitioner.class` as the job partitioner and defines the number of reducers to match the number of defined time slots.

**hadoop-tasks/task18/TimeSlotMapper.java**
This file parses attendance records and determines time slots. Its input is attendance CSV lines formatted as Text. It outputs key-value pairs where the key is the time slot text and the value is the attendance record text. The logic parses the timestamp field from the comma-separated line, applies logic to categorize it into a time slot string, and emits the slot as the map output key.

**hadoop-tasks/task18/TimeSlotPartitioner.java**
This file ensures all records for a specific time slot route to a single Reducer. Its input is the time slot text key, the attendance record text value, and the total number of reduce tasks. It outputs an integer reducer index between 0 and N-1. The logic contains a deterministic mapping using conditional blocks that return a specific integer for each time slot string, bypassing Java default `hashCode()` to prevent slot fragmentation across multiple reducers.

**hadoop-tasks/task18/TimeSlotReducer.java**
This file calculates attendance metrics per time slot. Its input is a time slot text key paired with an iterable of attendance record texts. It outputs a formatted summary string per time slot. The logic iterates through all attendance records for a given time slot, increments counters for present, absent, and total records, and writes the final summary string.

### Root-Level Orchestration Files

**run_full_app.sh**
This is the master shell script for local end-to-end execution. It sequentially invokes data generation, database building, data hub organization, and validation scripts using `set -e` to halt immediately on any errors, ensuring a clean pipeline state.

**run_pipeline.sh**
This is an alternative master shell script for pipeline execution. It provides similar functionality to `run_full_app.sh`, potentially with different logging or error handling configurations tailored to specific execution environments.

**run_local_mr.py**
This script simulates MapReduce logic locally without requiring Hadoop or Docker. It reads local CSV files from the `data/input/` directory and outputs formatted text mimicking Hadoop `part-r-*` files. The logic uses Python dictionaries and standard grouping algorithms to replicate the behavior of the Java Mapper, Partitioner, and Reducer classes entirely in memory.

**validate_output.sh**
This is a shell wrapper for the validation process. It invokes `scripts/verify_datasets.py` and checks the system return code to print a terminal status indicating overall pipeline success or failure.

**filemap.txt**
This is a project file structure inventory. It contains a text representation of the directory tree, likely generated via `find` or `tree` commands to catalog the project state at a specific point in time.

### Python Data Generation and Processing Scripts

**scripts/generate_datasets.py**
This is the primary entry point for synthetic data generation. It takes hardcoded or parameterized scale variables as input and outputs `*_full.csv` and `*_real.csv` files in target directories. It acts as a dispatcher, calling subordinate generator functions or containing inline logic using the `random` and `datetime` modules to create realistic data distributions.

**scripts/generate_real_data.py**
This script generates small-scale, highly controlled datasets. It uses deterministic seeds as input and outputs `*_real.csv` files. The logic uses pandas and numpy to generate datasets containing specific edge cases, such as null values and boundary dates, suitable for rigorous unit testing.

**scripts/generate_big_flights.py**
This is a specialized generator for massive flight datasets designed to stress-test Hadoop. It takes a row count multiplier as input and outputs a large `flights_full.csv` file. The logic utilizes an optimized I/O loop writing directly to CSV to minimize RAM consumption while generating millions of flight records.

**scripts/generate_exact_data.py**
This script generates deterministic input and output pairs for validation testing. It takes hardcoded arrays as input and outputs exact input CSVs alongside `expected_task*_output_full.csv` files. It operates with zero randomness, creating data where the exact output of the MapReduce job is known beforehand to enable strict byte-level validation.

**scripts/generate_project_bigdata.py**
This script generates the full-scale big data variants of all project entities. It takes configuration parameters as input and outputs all `*_full.csv` master files. It orchestrates the concurrent creation of large volumes for flights, attendance, routes, and cache data.

**scripts/data_generator_merger.py**
This script merges multiple generated data chunks into single cohesive files. It takes chunked CSV files as input and outputs unified CSV files. The logic reads multiple partial CSV outputs and concatenates them using pandas, stripping duplicate headers in the process.

**scripts/build_enterprise_masters.py**
This script creates canonical master datasets from multiple variants. It reads organized CSVs from `data_hub/csv/` as input and outputs `MASTER_FLIGHTS_DATASET.csv`, `MASTER_ATTENDANCE_DATASET.csv`, and `MASTER_ROUTES_DATASET.csv`. The logic reads both `_real` and `_full` variants, performs deduplication based on primary keys, and writes the merged schema to the master files.

**scripts/organize_data_hub.py**
This script structures raw data into the Data Hub directory. It takes generated CSVs as input and outputs the `data_hub/csv/` structure alongside a `data_hub_manifest.csv`. The logic copies files, creates subdirectories like `samples`, `enterprise`, and `task_aliases`, and writes a manifest containing row and column statistics for every file.

**scripts/verify_datasets.py**
This script validates MapReduce output against expected results. It takes Hadoop `part-r-*` files and `expected_*.csv` files as input and outputs `VALIDATION_REPORT.json`. The logic parses both sets of files, sorts records to handle Hadoop non-deterministic output ordering, performs row-by-row equality checks, and logs specific discrepancies.

**scripts/simulate_mr.py**
This is a standalone MapReduce simulation logic script. It takes local CSVs as input and writes to standard output or local files. It contains the pure Python algorithmic equivalent of the Java MapReduce tasks, used for debugging data transformation logic before deploying to the Hadoop cluster.

**scripts/extract_from_db.py**
This script extracts data from SQLite back to CSV format. It takes `data_hub/database/bd_project.db` as input and outputs CSV files. The logic executes `SELECT *` queries against SQLite tables and writes the resulting cursor data to CSV using the Python `csv` module.

### Database Construction

**data_master/build_database.py**
This script populates SQLite databases from CSV files. It reads CSV files from `data_hub/csv/` as input and outputs `data_hub/database/bd_project.db` and `data_hub/database/data_master.db`. The logic iterates through the data hub manifest, infers SQL types from Pandas data types, creates tables, executes batch inserts, handles foreign key constraints, and generates the `data_quality_report.json`.

### Hadoop-Specific Scripts

**hadoop-tasks/scripts/generate_and_run_full.sh**
This is an end-to-end Hadoop execution script. Its logic generates data inside the Hadoop context, uploads data to HDFS using `hdfs dfs -put`, compiles Java code using `javac` with the Hadoop classpath, packages classes into JARs using `jar cf`, submits jobs via `hadoop jar`, and retrieves output via `hdfs dfs -get`.

**hadoop-tasks/scripts/quick_start.sh**
This script provides rapid execution using pre-existing data. Its logic bypasses the data generation steps, directly uploading existing CSVs to HDFS and running the pre-compiled MapReduce JARs.

**hadoop-tasks/scripts/run_all.sh**
This script executes all MapReduce tasks sequentially. Its logic submits the Task 2 JAR, waits for completion, and then submits the Task 18 JAR, handling the inter-task dependency.

**hadoop-tasks/scripts/run_enterprise.sh**
This script runs MapReduce tasks using enterprise master datasets. Its logic modifies HDFS input paths to point specifically to the `MASTER_*.csv` files before job submission, ensuring the canonical datasets are processed.

**hadoop-tasks/scripts/organize_data_hub.py**, **hadoop-tasks/scripts/build_enterprise_masters.py**, **hadoop-tasks/scripts/verify_datasets.py**
These are context-specific copies of the root-level Python scripts. They contain identical logic but are scoped to resolve paths relative to the `hadoop-tasks/` directory structure, allowing the Hadoop container to run orchestration independently.

### Configuration and Infrastructure

**config/job.properties**
This file contains Hadoop job configuration parameters. It holds key-value pairs defining input paths, output paths, mapper and reducer class names, and custom partitioner configurations, which are read by the Java Driver classes or shell scripts to parameterize the Hadoop jobs.

**hadoop-tasks/Dockerfile**
This file defines the Hadoop Docker environment. Its logic specifies a base operating system image, downloads and extracts Hadoop binaries, configures `JAVA_HOME` and `HADOOP_HOME` environment variables, and exposes network ports required for Hadoop NameNode and ResourceManager web interfaces.

**hadoop-tasks/strip_comments.py**
This script cleans Java source code. It reads `.java` files, uses regular expressions to remove single-line comments formatted as `//` and multi-line comments formatted as `/* */`, and writes stripped files to prevent comment-related parsing issues during Hadoop compilation.

**VALIDATION_REPORT.json**
This is the final validation status artifact generated at the project root. It contains a JSON structure defining boolean pass or fail flags for Task 2 and Task 18, integer counts of matching and mismatching rows, and string arrays containing specific error messages detailing data differences found during validation.

### Data Directories and Artifacts

**data/input/**
This directory acts as a symlinked Hadoop input staging area. It contains symbolic links, such as `full_input.csv`, `cache_full.csv`, and `attendance_full.csv`, which point back to `data_hub/csv/`. This provides the Hadoop shell scripts with a flat, predictable input directory without duplicating data.

**data/cache/**
This directory acts as a symlinked Hadoop DistributedCache staging area. It contains symbolic links to flight and attendance CSVs. During Hadoop execution, the files in this directory are passed to the `job.addCacheFile()` method to be localized on all mapper nodes.

**data_hub/csv/**
This is the central raw data repository. It contains all generated CSVs, master datasets, sample subsets containing 100-row slices for debugging, task aliases containing renamed copies matching exact Hadoop expected input names, and the `data_hub_manifest.csv`.

**data_hub/database/**
This directory holds the working relational databases, specifically `bd_project.db` and `data_master.db`. It also contains the generated `data_quality_report.json` and a PDF version of the quality report.

**final_database/csv/**
This is the canonical CSV output archive. It contains backups of pre-pipeline states, final post-validation Hadoop outputs, and all intermediate processing variants to ensure full reproducibility of any pipeline run.

**final_database/database/**
This directory holds the definitive `bd_project.db` SQLite database. It also contains pipeline logs such as `latest_pipeline.log`, text summaries of task results like `task2_results.txt` and `task18_results.txt`, and the final data quality report.

**hadoop-tasks/output/**
This is the Hadoop HDFS retrieval target. It contains subdirectories for `task2` and `task18`, each holding `part-r-00000` (and subsequent part files) alongside an empty `_SUCCESS` marker file indicating successful Hadoop job completion.

**outputs/full_app_logs/**
This directory stores timestamped pipeline execution history. It contains 58 subdirectories named using the `YYYYMMDD_HHMMSS` format. Each subdirectory contains a `pipeline.log` file capturing detailed standard output and error streams, and a `summary.txt` file capturing high-level pass or fail metrics.

**backup_pre_pipeline/**
This directory holds a complete snapshot of the project state prior to a major pipeline execution. It contains recursive copies of `data_hub/`, `data_master/`, `final_database/`, `hadoop-tasks/`, `outputs/`, and `scripts/` from a specific timestamp, acting as a safety rollback point.

**archive_pending/csv_duplicates/**
This is a quarantine directory for redundant data. It contains `full_input.csv.partial`, which is likely a failed or incomplete generation artifact moved out of the active pipeline path to prevent processing errors.

## 6. Data Dictionary

### Flights Dataset Schema

The flights datasets, represented by files such as `flights_full.csv` and `flights_real.csv`, utilize the following schema. The `flight_id` field is a string containing an alphanumeric identifier, such as FL-10001, which serves as the unique primary identifier for the flight and the primary join key for Task 2. The `airline` field is a string containing either an IATA code or the full airline name representing the operating carrier. The `origin` field is a string containing a three-character IATA airport code indicating the departure airport. The `destination` field is a string containing a three-character IATA airport code indicating the arrival airport. The `departure_time` field is a string or datetime object in ISO 8601 or a custom format representing the scheduled departure timestamp. The `arrival_time` field is a string or datetime object representing the scheduled arrival timestamp. The `status` field is a string constrained to an enumeration of values such as Scheduled, Delayed, or Cancelled, representing the current operational status.

### Cache Dataset Schema

The cache datasets, represented by `cache_full.csv` and `cache_real.csv`, utilize the following schema. The `cache_id` field is a string containing an alphanumeric unique identifier for the cache entry. The `flight_id` field is a string containing an alphanumeric identifier acting as a foreign key linking to the Flights dataset, used by `CacheMapper` for the map-side join. The `query_time` field is a string or datetime object representing the timestamp when the flight data was queried and cached. The `cache_status` field is a string constrained to an enumeration such as Hit, Miss, or Expired, representing the result of the cache lookup operation.

### Attendance Dataset Schema

The attendance datasets, represented by `attendance_full.csv` and `attendance_real.csv`, utilize the following schema. The `emp_id` field is a string containing an alphanumeric unique identifier for the employee. The `check_in` field is a string or datetime object representing the timestamp of the attendance punch-in, which is parsed by `TimeSlotMapper` to extract the map output key. The `check_out` field is a string or datetime object representing the timestamp of the attendance punch-out. The `status` field is a string constrained to an enumeration such as Present, Absent, or Half-Day, indicating the attendance state. The `department` field is a string of variable length identifying the employee department, used for secondary aggregation in the Reducer.

### Time Slot Derived Schema

The output of Task 18 follows a derived schema. The `time_slot` field is a string constrained to an enumeration such as Morning, Afternoon, or Night, derived from the `check_in` timestamp. The `total_records` field is an integer greater than zero representing the total number of attendance records falling into this specific slot. The `present_count` field is a non-negative integer representing the subset of records where the status equals Present. The `absent_count` field is a non-negative integer representing the subset of records where the status equals Absent.

### Reference Datasets Schema

The reference datasets for airlines, airports, and routes share a common structural pattern. The `iata_code` field is a string constrained to three uppercase characters representing the standard IATA identifier. The `name` field is a string of variable length representing the full name of the entity. The `country` and `city` fields are strings of variable length providing geographic location metadata.

## 7. External Services and APIs

This project does not rely on any external services or APIs. All datasets are generated synthetically using local Python scripts leveraging standard library modules and numpy/pandas for statistical randomness. There are no outbound network calls made during data generation, database construction, MapReduce processing, or validation. Consequently, there are no authentication mechanisms, rate limiting considerations, or API fallback patterns implemented in the codebase. The system is entirely self-contained and operates offline.

## 8. Configuration and Caching

### Symlink Caching Strategy

To avoid duplicating large datasets between the root project structure and the Hadoop-specific directories, the application employs a symlink-based caching strategy. The `data/input/` and `data/cache/` directories do not contain actual data files. Instead, they contain symbolic links pointing directly to the canonical CSV files located in `data_hub/csv/`. When the Hadoop shell scripts execute commands like `hdfs dfs -put data/input/full_input.csv`, the operating system transparently resolves the symlink and uploads the underlying file from the Data Hub. This configuration ensures that updates made to the master datasets in the Data Hub are immediately reflected in the Hadoop input paths without requiring manual file copying or synchronization scripts.

### Local Metadata Caching

The data generation pipeline implements a local metadata caching mechanism through the `data_hub_manifest.csv` file. Rather than scanning the file system to determine row counts, column counts, and file sizes every time a downstream script requires dataset metadata, the `organize_data_hub.py` script calculates these metrics once during the organization phase and writes them to the manifest. Downstream processes, such as `build_database.py` and the validation scripts, read this static manifest file to make rapid decisions about dataset joining and expected output sizes, significantly reducing file I/O overhead during pipeline execution.

### Hadoop DistributedCache

Within the Hadoop MapReduce framework, the application utilizes the Hadoop DistributedCache API for caching reference data. In Task 2, the flight reference dataset is too large to pass as a standard configuration parameter but small enough to fit into the memory of each mapper node. The `CacheDriver.java` file adds this dataset to the DistributedCache. Before processing any map inputs, the `CacheMapper.java` `setup()` method reads this cached file from the local task node's file system and loads it into a Java `HashMap`. This map-side join caching mechanism eliminates the need for a costly reduce-side join, dramatically improving Task 2 execution speed by preventing the shuffling of flight data across the network.

### Pipeline State Archiving

The application uses file-system-based state caching to preserve pipeline history and enable rollback. The `backup_pre_pipeline/` directory serves as a frozen cache of the entire project state, including databases, scripts, and CSVs, captured immediately prior to a major pipeline execution. Furthermore, the `outputs/full_app_logs/` directory caches the exact standard output and error streams of every pipeline run in timestamped subdirectories. If a pipeline run produces unexpected results, developers can cross-reference the `VALIDATION_REPORT.json` with the corresponding `YYYYMMDD_HHMMSS/pipeline.log` to reconstruct the exact sequence of script invocations and errors that led to the failure, without relying on volatile terminal history.
