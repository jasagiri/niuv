#!/bin/bash
# Generate Nim-aware coverage report using gcov with source mapping

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NIMCACHE_DIR="${PROJECT_ROOT}/nimcache"
COVERAGE_DIR="${PROJECT_ROOT}/coverage"

mkdir -p "${COVERAGE_DIR}"

echo "Generating Nim coverage report..."

# Process all gcno/gcda files
cd "${NIMCACHE_DIR}"
for gcno_file in *.gcno; do
    if [ -f "$gcno_file" ]; then
        base_name="${gcno_file%.gcno}"
        gcda_file="${base_name}.gcda"
        
        # Only process if gcda exists (has coverage data)
        if [ -f "$gcda_file" ]; then
            echo "Processing ${base_name}..."
            gcov "$gcno_file" -b 2>/dev/null || true
        fi
    fi
done

# Create HTML report
cat > "${COVERAGE_DIR}/nim_coverage_report.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Niuv Coverage Report (Nim Source)</title>
    <style>
        body {
            font-family: 'Consolas', 'Monaco', monospace;
            margin: 20px;
        }
        h1, h2 { color: #333; }
        .summary {
            background: #f0f0f0;
            padding: 10px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .file {
            margin: 20px 0;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .file-header {
            background: #e0e0e0;
            padding: 10px;
            font-weight: bold;
        }
        .file-content {
            padding: 10px;
            overflow-x: auto;
        }
        .line {
            white-space: pre;
            font-family: monospace;
        }
        .line-number {
            display: inline-block;
            width: 50px;
            text-align: right;
            margin-right: 10px;
            color: #666;
        }
        .executed {
            background-color: #c8f7c5;
        }
        .not-executed {
            background-color: #ffcccb;
        }
        .no-code {
            color: #999;
        }
    </style>
</head>
<body>
    <h1>Niuv Coverage Report</h1>
    <div class="summary">
        <h2>Summary</h2>
EOF

# Process .gcov files for Nim sources
total_lines=0
covered_lines=0

for gcov_file in *.gcov; do
    if [ -f "$gcov_file" ] && [[ "$gcov_file" == *.nim.gcov ]]; then
        # Extract source file path
        source_file=$(grep "Source:" "$gcov_file" | cut -d: -f2-)
        
        # Only process project files
        if [[ "$source_file" == *"/niuv/src/"* ]] || [[ "$source_file" == *"/niuv/tests/"* ]]; then
            # Count coverage
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*([0-9]+|\#\#\#\#\#):.*$ ]]; then
                    total_lines=$((total_lines + 1))
                    if [[ "$line" =~ ^[[:space:]]*[0-9]+:.*$ ]]; then
                        covered_lines=$((covered_lines + 1))
                    fi
                fi
            done < "$gcov_file"
        fi
    fi
done

# Calculate percentage
if [ $total_lines -gt 0 ]; then
    coverage_percent=$(awk "BEGIN {printf \"%.2f\", ($covered_lines / $total_lines) * 100}")
else
    coverage_percent="0.00"
fi

echo "        <p>Total executable lines: $total_lines</p>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
echo "        <p>Covered lines: $covered_lines</p>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
echo "        <p>Coverage: ${coverage_percent}%</p>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
echo "    </div>" >> "${COVERAGE_DIR}/nim_coverage_report.html"

# Add file details
echo "    <h2>File Coverage</h2>" >> "${COVERAGE_DIR}/nim_coverage_report.html"

for gcov_file in *.gcov; do
    if [ -f "$gcov_file" ] && [[ "$gcov_file" == *.nim.gcov ]]; then
        source_file=$(grep "Source:" "$gcov_file" | cut -d: -f2-)
        
        # Only process project files
        if [[ "$source_file" == *"/niuv/src/"* ]] || [[ "$source_file" == *"/niuv/tests/"* ]]; then
            # Get relative path
            rel_path=${source_file#*niuv/}
            
            echo "    <div class='file'>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
            echo "        <div class='file-header'>$rel_path</div>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
            echo "        <div class='file-content'>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
            
            # Process lines
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*(.*):([[:space:]]*[0-9]+):(.*)$ ]]; then
                    count="${BASH_REMATCH[1]}"
                    line_num="${BASH_REMATCH[2]}"
                    code="${BASH_REMATCH[3]}"
                    
                    # Skip special sections
                    if [[ "$code" == "------------------" ]]; then
                        continue
                    fi
                    
                    if [[ "$count" =~ ^[0-9]+\*?$ ]]; then
                        # Executed line
                        echo "            <div class='line executed'><span class='line-number'>$line_num:</span>$code</div>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
                    elif [[ "$count" == "#####" ]]; then
                        # Not executed
                        echo "            <div class='line not-executed'><span class='line-number'>$line_num:</span>$code</div>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
                    elif [[ "$count" == "-" ]]; then
                        # No code
                        echo "            <div class='line no-code'><span class='line-number'>$line_num:</span>$code</div>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
                    fi
                fi
            done < "$gcov_file"
            
            echo "        </div>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
            echo "    </div>" >> "${COVERAGE_DIR}/nim_coverage_report.html"
        fi
    fi
done

echo "</body></html>" >> "${COVERAGE_DIR}/nim_coverage_report.html"

echo "Coverage report generated: ${COVERAGE_DIR}/nim_coverage_report.html"
echo "Coverage: ${coverage_percent}% (${covered_lines}/${total_lines} lines)"