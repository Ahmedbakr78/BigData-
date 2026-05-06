#!/bin/bash
set -euo pipefail
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
CHECKMARK="✓"
CROSS="✗"
ARROW="→"
STAR="★"
INPUT_PROFILE="${INPUT_PROFILE:-full}"
CLEANUP_DONE=0

pick_largest_file() {
    local first="$1"
    local second="$2"
    local first_lines=0
    local second_lines=0

    if [ -f "$first" ]; then
        first_lines=$(wc -l < "$first")
    fi
    if [ -f "$second" ]; then
        second_lines=$(wc -l < "$second")
    fi

    if [ "$first_lines" -ge "$second_lines" ]; then
        echo "$first"
    else
        echo "$second"
    fi
}

resolve_input_file() {
    local profile="$1"
    local real_file="$2"
    local sample_file="$3"

    case "$profile" in
        full)
            if [ -f "$real_file" ] && [ -f "$sample_file" ]; then
                pick_largest_file "$real_file" "$sample_file"
                return 0
            elif [ -f "$real_file" ]; then
                echo "$real_file"
                return 0
            elif [ -f "$sample_file" ]; then
                echo "$sample_file"
                return 0
            fi
            ;;
        real)
            if [ -f "$real_file" ]; then
                echo "$real_file"
                return 0
            elif [ -f "$sample_file" ]; then
                echo "$sample_file"
                return 0
            fi
            ;;
        sample)
            if [ -f "$sample_file" ]; then
                echo "$sample_file"
                return 0
            elif [ -f "$real_file" ]; then
                echo "$real_file"
                return 0
            fi
            ;;
        *)
            print_warning "Unknown INPUT_PROFILE='$profile'. Falling back to full."
            resolve_input_file "full" "$real_file" "$sample_file"
            return $?
            ;;
    esac

    return 1
}

print_header() {
    echo -e "\n${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC} ${BOLD}$1${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}
print_section() {
    echo -e "\n${BOLD}${CYAN}▸ $1${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
}
print_success() {
    echo -e "${GREEN}${CHECKMARK} $1${NC}"
}
print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}
print_info() {
    echo -e "${BLUE}${ARROW} $1${NC}"
}
print_star() {
    echo -e "${MAGENTA}${STAR} $1${NC}"
}
check_docker() {
    print_section "Docker Status Check"
    if command -v docker &> /dev/null; then
        print_success "Docker is installed"
        DOCKER_VERSION=$(docker --version)
        print_info "Version: $DOCKER_VERSION"
        if docker info &> /dev/null; then
            print_success "Docker daemon is running"
            return 0
        else
            print_error "Docker daemon is NOT running"
            return 1
        fi
    else
        print_error "Docker is NOT installed"
        return 1
    fi
}
cleanup_docker() {
    print_section "Docker Cleanup"
    if docker ps -a | grep -q hadoop-mapreduce; then
        docker stop hadoop-mapreduce 2>/dev/null || true
        docker rm hadoop-mapreduce 2>/dev/null || true
        print_success "Existing container removed"
    fi
}
build_docker_image() {
    print_section "Building Docker Image"
    if docker build -t hadoop-mapreduce:latest .; then
        print_success "Docker image built successfully"
        return 0
    else
        print_error "Failed to build Docker image"
        return 1
    fi
}
wait_for_container_ready() {
    local max_attempts=30
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if docker exec hadoop-mapreduce bash -c "test -x /usr/local/hadoop/bin/hadoop && test -d /app/task2 && test -d /app/task18" >/dev/null 2>&1; then
            print_success "Container is ready"
            return 0
        fi

        print_info "Waiting for container readiness (attempt ${attempt}/${max_attempts})..."
        sleep 1
        attempt=$((attempt + 1))
    done

    print_error "Container failed readiness checks"
    return 1
}
start_container() {
    print_section "Starting Docker Container"
    local container_id

    container_id=$(docker run -d \
        --name hadoop-mapreduce \
        -v "$(pwd)/task2":/data/task2 \
        -v "$(pwd)/task18":/data/task18 \
        -v "$(pwd)/output":/output \
        hadoop-mapreduce:latest \
        tail -f /dev/null) || {
        print_error "Failed to start container"
        return 1
    }

    if ! docker ps --filter "name=^/hadoop-mapreduce$" --filter "status=running" | grep -q hadoop-mapreduce; then
        print_error "Failed to start container"
        return 1
    fi

    print_success "Container started successfully (${container_id:0:12})"
    wait_for_container_ready
}
compile_task2() {
    print_section "Compiling Task 2"
    docker exec hadoop-mapreduce mkdir -p /app/classes/task2
    docker exec hadoop-mapreduce bash -c "cd /app && javac -classpath \$HADOOP_CLASSPATH:/usr/local/hadoop/share/hadoop/common/hadoop-common-3.3.1.jar:/usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-core-3.3.1.jar -d /app/classes/task2 task2/*.java"
    if [ $? -eq 0 ]; then
        docker exec hadoop-mapreduce bash -c "cd /app/classes/task2 && jar -cvf /app/task2.jar task2/*.class"
        print_success "Task 2 compiled"
        return 0
    else
        print_error "Task 2 compilation failed"
        return 1
    fi
}
compile_task18() {
    print_section "Compiling Task 18"
    docker exec hadoop-mapreduce mkdir -p /app/classes/task18
    docker exec hadoop-mapreduce bash -c "cd /app && javac -classpath \$HADOOP_CLASSPATH:/usr/local/hadoop/share/hadoop/common/hadoop-common-3.3.1.jar:/usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-core-3.3.1.jar -d /app/classes/task18 task18/*.java"
    if [ $? -eq 0 ]; then
        docker exec hadoop-mapreduce bash -c "cd /app/classes/task18 && jar -cvf /app/task18.jar task18/*.class"
        print_success "Task 18 compiled"
        return 0
    else
        print_error "Task 18 compilation failed"
        return 1
    fi
}
prepare_input_data() {
    print_section "Preparing Input Data"
    # Build dedicated full input files and run against them by default.
    DATA_ROOT="../data_master"
    HUB_CSV_ROOT="../data_hub/csv"

    if [ "$INPUT_PROFILE" = "generated" ] || [ "$INPUT_PROFILE" = "production" ] || [ "$INPUT_PROFILE" = "hub" ]; then
        GENERATED_ROOT="$HUB_CSV_ROOT"

        # Backward compatibility fallback for older project layouts.
        if [ ! -f "$GENERATED_ROOT/routes_full.csv" ] || [ ! -f "$GENERATED_ROOT/flights_full.csv" ] || [ ! -f "$GENERATED_ROOT/attendance_full.csv" ]; then
            GENERATED_ROOT="$DATA_ROOT/generated_data"
        fi

        CACHE_SRC="$GENERATED_ROOT/routes_full.csv"
        FLIGHTS_SRC="$GENERATED_ROOT/flights_full.csv"
        ATTENDANCE_SRC="$GENERATED_ROOT/attendance_full.csv"

        if [ ! -f "$CACHE_SRC" ] || [ ! -f "$FLIGHTS_SRC" ] || [ ! -f "$ATTENDANCE_SRC" ]; then
            print_error "Generated profile selected but required files are missing in $GENERATED_ROOT"
            print_info "Run: python3 scripts/generate_datasets.py --output-dir data_hub/csv --include-edge-cases"
            return 1
        fi
    else
        CACHE_SRC=$(resolve_input_file "$INPUT_PROFILE" "$DATA_ROOT/cache_real.csv" "$DATA_ROOT/cache_sample.csv" || true)
        FLIGHTS_SRC=$(resolve_input_file "$INPUT_PROFILE" "$DATA_ROOT/flights_real.csv" "$DATA_ROOT/flights_sample.csv" || true)
        ATTENDANCE_SRC=$(resolve_input_file "$INPUT_PROFILE" "$DATA_ROOT/attendance_real.csv" "$DATA_ROOT/attendance_sample.csv" || true)

        # If CSVs were centralized into data_hub/csv (move mode), fallback there.
        if [ -z "$CACHE_SRC" ]; then
            CACHE_SRC=$(resolve_input_file "$INPUT_PROFILE" "$HUB_CSV_ROOT/cache_real.csv" "$HUB_CSV_ROOT/cache_sample.csv" || true)
        fi
        if [ -z "$FLIGHTS_SRC" ]; then
            FLIGHTS_SRC=$(resolve_input_file "$INPUT_PROFILE" "$HUB_CSV_ROOT/flights_real.csv" "$HUB_CSV_ROOT/flights_sample.csv" || true)
        fi
        if [ -z "$ATTENDANCE_SRC" ]; then
            ATTENDANCE_SRC=$(resolve_input_file "$INPUT_PROFILE" "$HUB_CSV_ROOT/attendance_real.csv" "$HUB_CSV_ROOT/attendance_sample.csv" || true)
        fi
    fi

    if [ -z "$CACHE_SRC" ] || [ -z "$FLIGHTS_SRC" ] || [ -z "$ATTENDANCE_SRC" ]; then
        print_error "Could not resolve one or more input datasets from $DATA_ROOT"
        return 1
    fi

    cp "$CACHE_SRC" task2/cache_full.csv
    cp "$FLIGHTS_SRC" task2/flights_full.csv
    cp "$ATTENDANCE_SRC" task18/attendance_full.csv

    # Keep compatibility files for users who open *_real.csv directly.
    cp task2/cache_full.csv task2/cache_real.csv
    cp task2/flights_full.csv task2/flights_real.csv
    cp task18/attendance_full.csv task18/attendance_real.csv

    # Print dataset statistics
    CACHE_LINES=$(wc -l < task2/cache_full.csv 2>/dev/null || echo "0")
    FLIGHT_LINES=$(wc -l < task2/flights_full.csv 2>/dev/null || echo "0")
    ATTEND_LINES=$(wc -l < task18/attendance_full.csv 2>/dev/null || echo "0")
    print_info "Input profile:   ${INPUT_PROFILE^^}"
    print_info "Cache source:    $(basename "$CACHE_SRC")"
    print_info "Flights source:  $(basename "$FLIGHTS_SRC")"
    print_info "Attendance src:  $(basename "$ATTENDANCE_SRC")"
    print_info "Cache routes:    $CACHE_LINES records"
    print_info "Flight records:  $FLIGHT_LINES records"
    print_info "Attendance data: $ATTEND_LINES records"
    # Prepare directories inside container
    docker exec hadoop-mapreduce bash -c "mkdir -p /data/input/task2 /data/input/task18"
    docker exec hadoop-mapreduce bash -c "cp /data/task2/cache_full.csv /data/input/task2/ || true"
    docker exec hadoop-mapreduce bash -c "cp /data/task2/flights_full.csv /data/input/task2/ || true"
    docker exec hadoop-mapreduce bash -c "cp /data/task18/attendance_full.csv /data/input/task18/ || true"
    print_success "Input data prepared"
}
display_task2_results() {
    print_section "Task 2 Results — Flight Route Enrichment"
    echo -e "${BOLD}routeLabel\ttotalRevenue\ttotalPassengers${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    docker exec hadoop-mapreduce bash -c "cat /output/task2/part-r-00000" | tee ../outputs/task2_results.txt
    echo ""
    ROUTE_COUNT=$(wc -l < ../outputs/task2_results.txt)
    print_info "Total routes: $ROUTE_COUNT"
    print_info "Results saved to ../outputs/task2_results.txt"
}
run_task2() {
    print_section "Executing Task 2 — Flight Route Enrichment (DistributedCache)"
    docker exec hadoop-mapreduce rm -rf /output/task2
    START_TIME=$(date +%s)
    docker exec hadoop-mapreduce bash -c "cd /app && hadoop jar task2.jar task2.CacheDriver /data/input/task2/flights_full.csv /output/task2 /data/input/task2/cache_full.csv" 2>&1 | tee task2_execution_log.txt
    EXIT_CODE=${PIPESTATUS[0]}
    END_TIME=$(date +%s)
    if [ $EXIT_CODE -eq 0 ]; then
        print_success "Task 2 completed in $((END_TIME - START_TIME))s"
        display_task2_results
        return 0
    else
        print_error "Task 2 failed"
        return 1
    fi
}
display_task18_results() {
    local normalized_output="../outputs/task18_results.txt"
    local part
    local content
    local -a task18_parts

    mapfile -t task18_parts < <(
        docker exec hadoop-mapreduce bash -lc '
            shopt -s nullglob
            for f in /output/task18/part-r-*; do
                [ -f "$f" ] && basename "$f"
            done | sort
        '
    )

    if ! docker exec hadoop-mapreduce bash -lc '
        shopt -s nullglob
        cat /output/task18/part-r-* | sort
    ' > "$normalized_output"; then
        print_error "Failed to capture Task 18 output"
        return 1
    fi

    print_section "Task 18 Results — Time Slot Partitioning"
    echo -e "${BOLD}time_slot\tpresent\tabsent\ttotal\tunique_employees\tattendance_rate${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    cat "$normalized_output"
    echo ""
    # Show partition breakdown
    print_info "Partition breakdown:"
    for part in "${task18_parts[@]}"; do
        content=$(docker exec hadoop-mapreduce bash -lc "cat /output/task18/$part 2>/dev/null" | tr '\n' ';')
        content="${content%; }"
        content="${content%;}"
        if [ -z "$content" ]; then
            content="(empty -> no valid records for this partition)"
        fi
        content="${content//;/ | }"
        print_info "  $part: $content"
    done
    print_info "Results saved to $normalized_output"
}
run_task18() {
    print_section "Executing Task 18 — Time Slot Partitioning (Custom Partitioner)"
    docker exec hadoop-mapreduce rm -rf /output/task18
    START_TIME=$(date +%s)
    docker exec hadoop-mapreduce bash -c "cd /app && hadoop jar task18.jar task18.TimeSlotDriver /data/input/task18/attendance_full.csv /output/task18" 2>&1 | tee /tmp/task18_output.log
    EXIT_CODE=${PIPESTATUS[0]}
    END_TIME=$(date +%s)
    if [ $EXIT_CODE -eq 0 ]; then
        print_success "Task 18 completed in $((END_TIME - START_TIME))s"
        display_task18_results
        return 0
    else
        print_error "Task 18 failed"
        return 1
    fi
}
cleanup_on_exit() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then
        return 0
    fi

    CLEANUP_DONE=1
    if docker ps -a --format '{{.Names}}' | grep -Fxq "hadoop-mapreduce"; then
        docker stop hadoop-mapreduce 2>/dev/null || true
        docker rm hadoop-mapreduce 2>/dev/null || true
    fi

    print_success "Cleanup complete"
}
main() {
    # clear removed to prevent silent exit under dumb terminals
    print_header "HADOOP MAPREDUCE AUTOMATION — REAL DATA PIPELINE"
    print_info "Student: Ahmed Abobakr"
    print_info "Course:  Big Data Processing with Hadoop"
    print_info "Tasks:   Task 2 (Flight Route Enrichment) + Task 18 (Time Slot Partitioning)"
    print_info "Input profile: ${INPUT_PROFILE^^} (full | real | sample | generated | hub)"
    echo ""
    check_docker || exit 1
    cleanup_docker
    build_docker_image || exit 1
    start_container || exit 1
    prepare_input_data
    compile_task2 || exit 1
    compile_task18 || exit 1
    run_task2
    run_task18
    print_header "FINAL OUTPUT SUMMARY"
    print_star "Task 2 output: ../outputs/task2_results.txt ($(wc -l < ../outputs/task2_results.txt) routes)"
    print_star "Task 18 output: ../outputs/task18_results.txt ($(wc -l < ../outputs/task18_results.txt) time slots)"
    cleanup_on_exit
    print_header "EXECUTION COMPLETED SUCCESSFULLY"
}
trap cleanup_on_exit EXIT INT TERM
main "$@" 2>&1 | tee execution_output.txt
