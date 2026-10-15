#!/usr/bin/env bash
# Hourai Benchmark Script - Run performance benchmarks

set -euo pipefail

# Default options
FILTER=""
ITERATIONS=100000
WARMUP=100
PROFILE=false
VERBOSE=false
OUTPUT_DIR=".build/benchmarks"
COMPARE_BASELINE=false
BASELINE_FILE=""

# Help function
show_help() {
    cat << EOF
Usage: $0 [options]

Run performance benchmarks for Hourai project.

Options:
    -f, --filter=PATTERN    Run benchmarks matching pattern (default: all)
    -i, --iterations=N      Number of iterations (default: 100000)
    -w, --warmup=N         Number of warmup iterations (default: 100)
    -o, --output=DIR       Output directory (default: .build/benchmarks)
    --profile              Enable CPU/memory profiling
    --compare=FILE         Compare against baseline file
    -v, --verbose          Verbose output
    -h, --help             Show this help

Examples:
    $0                           # Run all benchmarks
    $0 -f "Message*"            # Run message-related benchmarks
    $0 -i 1000000               # Run with 1M iterations
    $0 --profile                # Enable profiling
    $0 --compare=baseline.json   # Compare with baseline
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--filter)
            FILTER="$2"
            shift 2
            ;;
        --filter=*)
            FILTER="${1#*=}"
            shift
            ;;
        -i|--iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        --iterations=*)
            ITERATIONS="${1#*=}"
            shift
            ;;
        -w|--warmup)
            WARMUP="$2"
            shift 2
            ;;
        --warmup=*)
            WARMUP="${1#*=}"
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --profile)
            PROFILE=true
            shift
            ;;
        --compare)
            COMPARE_BASELINE=true
            BASELINE_FILE="$2"
            shift 2
            ;;
        --compare=*)
            COMPARE_BASELINE=true
            BASELINE_FILE="${1#*=}"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Set environment variables for benchmarks
export TESTKIT_BENCHMARK_ENABLED=1
export TESTKIT_BENCHMARK_ITERATIONS=$ITERATIONS
export TESTKIT_BENCHMARK_WARMUP=$WARMUP
export TESTKIT_BENCHMARK_OUTPUT="$OUTPUT_DIR"

if [[ -n "$FILTER" ]]; then
    export TESTKIT_BENCHMARK_FILTER="$FILTER"
fi

if [[ "$PROFILE" == "true" ]]; then
    export TESTKIT_BENCHMARK_PROFILE=1
fi

echo "🚀 Running Hourai performance benchmarks..."
echo "   Iterations: $ITERATIONS"
echo "   Warmup: $WARMUP"
if [[ -n "$FILTER" ]]; then
    echo "   Filter: $FILTER"
fi
echo "   Output: $OUTPUT_DIR"

# Check if benchmark binary exists
BENCHMARK_BINARY="benchmarks/bench_simple"
if [[ ! -f "$BENCHMARK_BINARY" ]]; then
    echo "📦 Compiling benchmark binary..."
    nim c -d:release -o:"$BENCHMARK_BINARY" benchmarks/bench_simple.nim
fi

# Run benchmarks
echo "⏱️  Running benchmarks..."
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="$OUTPUT_DIR/benchmark_results_$TIMESTAMP.json"

if [[ "$VERBOSE" == "true" ]]; then
    ./"$BENCHMARK_BINARY" --json --output="$RESULTS_FILE" --verbose
else
    ./"$BENCHMARK_BINARY" --json --output="$RESULTS_FILE"
fi

echo "📊 Benchmark results saved to: $RESULTS_FILE"

# Parse and display results
if [[ -f "$RESULTS_FILE" ]]; then
    echo ""
    echo "📈 Performance Summary:"
    echo "────────────────────────────────────────────────────────────────"
    
    # Extract key metrics (basic implementation)
    if command -v jq >/dev/null 2>&1; then
        jq -r '.benchmarks[] | "\(.name): \(.ops_per_sec | floor) ops/sec"' "$RESULTS_FILE" 2>/dev/null || {
            echo "   Results saved in JSON format"
        }
    else
        echo "   Install 'jq' for formatted output"
        echo "   Results available in: $RESULTS_FILE"
    fi
fi

# Compare with baseline if requested
if [[ "$COMPARE_BASELINE" == "true" && -f "$BASELINE_FILE" ]]; then
    echo ""
    echo "📊 Baseline Comparison:"
    echo "────────────────────────────────────────────────────────────────"
    
    if command -v jq >/dev/null 2>&1; then
        # Create comparison report
        COMPARISON_FILE="$OUTPUT_DIR/comparison_$TIMESTAMP.json"
        echo "{\"baseline\": $(cat "$BASELINE_FILE"), \"current\": $(cat "$RESULTS_FILE")}" > "$COMPARISON_FILE"
        
        echo "   Comparison saved to: $COMPARISON_FILE"
        
        # Show key differences
        jq -r '
        def percentage(old; new): 
            if old == 0 then "N/A" 
            else ((new - old) / old * 100 | floor | tostring) + "%" 
            end;
        
        .baseline.benchmarks as $baseline |
        .current.benchmarks as $current |
        $current[] as $c |
        ($baseline[] | select(.name == $c.name)) as $b |
        "\($c.name): \(percentage($b.ops_per_sec; $c.ops_per_sec)) change"
        ' "$COMPARISON_FILE" 2>/dev/null || echo "   Comparison requires valid JSON files"
    else
        echo "   Install 'jq' for baseline comparison"
    fi
fi

# Create or update latest results link
ln -sf "benchmark_results_$TIMESTAMP.json" "$OUTPUT_DIR/latest.json"

echo ""
echo "✅ Benchmark analysis complete"
echo "   Latest results: $OUTPUT_DIR/latest.json"

# Check for performance regressions
if [[ "$COMPARE_BASELINE" == "true" && -f "$BASELINE_FILE" ]]; then
    echo "   Baseline comparison: $OUTPUT_DIR/comparison_$TIMESTAMP.json"
fi