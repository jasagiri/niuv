#!/usr/bin/env python3
"""
Process coverage data for Nim source files.
This script works around the limitations of gcov/lcov with Nim-generated C code.
"""

import os
import sys
import re
import subprocess
from pathlib import Path
import json

def find_file_macros(c_file):
    """Extract file path mappings from generated C file."""
    macros = {}
    with open(c_file, 'r') as f:
        for line in f:
            match = re.match(r'^#define\s+FX_(\d+)\s+"([^"]+)"', line)
            if match:
                macros[f"FX_{match.group(1)}"] = match.group(2)
    return macros

def process_gcov_output(gcov_file, file_macros):
    """Process gcov output and map back to Nim source."""
    nim_coverage = {}
    current_file = None
    
    with open(gcov_file, 'r') as f:
        for line in f:
            # Look for source file indicators
            if line.startswith("        -:    0:Source:"):
                source = line.split(":")[-1].strip()
                # Check if it's a macro reference
                for macro, path in file_macros.items():
                    if source == macro and path.endswith('.nim'):
                        current_file = path
                        nim_coverage[current_file] = {}
                        break
            
            # Parse coverage data
            elif current_file and re.match(r'^\s*(\d+|-):\s*(\d+):', line):
                parts = line.split(':', 2)
                if len(parts) >= 2:
                    count = parts[0].strip()
                    line_num = int(parts[1].strip())
                    if count != '-':
                        nim_coverage[current_file][line_num] = int(count)
    
    return nim_coverage

def generate_coverage_report(project_root):
    """Generate coverage report for Nim source files."""
    nimcache_dir = os.path.join(project_root, "nimcache")
    coverage_data = {}
    
    # Process all C files with coverage data
    for c_file in Path(nimcache_dir).glob("*.c"):
        gcda_file = c_file.with_suffix('.gcda')
        if gcda_file.exists():
            # Get file macros
            macros = find_file_macros(c_file)
            
            # Run gcov
            try:
                subprocess.run(['gcov', '-b', str(c_file), '-o', nimcache_dir], 
                             capture_output=True, text=True, check=True)
                
                # Process gcov output
                gcov_file = c_file.with_suffix('.c.gcov')
                if gcov_file.exists():
                    nim_data = process_gcov_output(gcov_file, macros)
                    for nim_file, lines in nim_data.items():
                        if nim_file not in coverage_data:
                            coverage_data[nim_file] = {}
                        coverage_data[nim_file].update(lines)
            except subprocess.CalledProcessError:
                pass
    
    return coverage_data

def create_simple_report(coverage_data, output_file):
    """Create a simple HTML coverage report."""
    html = """<!DOCTYPE html>
<html>
<head>
    <title>Niuv Coverage Report</title>
    <style>
        body { font-family: monospace; }
        .covered { background-color: #90EE90; }
        .uncovered { background-color: #FFB6C1; }
        .filename { font-weight: bold; margin-top: 20px; }
        .line { white-space: pre; }
    </style>
</head>
<body>
    <h1>Niuv Coverage Report</h1>
"""
    
    for nim_file, lines in sorted(coverage_data.items()):
        if not nim_file.startswith("/home/user/_Repository/github.com_jasagiri/niuv"):
            continue
            
        html += f'<div class="filename">{nim_file}</div>\n'
        html += '<div class="file-content">\n'
        
        if os.path.exists(nim_file):
            with open(nim_file, 'r') as f:
                for i, line in enumerate(f, 1):
                    if i in lines:
                        if lines[i] > 0:
                            html += f'<div class="line covered">{i:4d}: {line.rstrip()}</div>\n'
                        else:
                            html += f'<div class="line uncovered">{i:4d}: {line.rstrip()}</div>\n'
                    else:
                        html += f'<div class="line">{i:4d}: {line.rstrip()}</div>\n'
        
        html += '</div>\n'
    
    html += """
</body>
</html>
"""
    
    with open(output_file, 'w') as f:
        f.write(html)

if __name__ == "__main__":
    project_root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    
    print("Processing coverage data...")
    coverage_data = generate_coverage_report(project_root)
    
    # Save as JSON
    with open(os.path.join(project_root, 'coverage', 'nim_coverage.json'), 'w') as f:
        json.dump(coverage_data, f, indent=2)
    
    # Create HTML report
    create_simple_report(coverage_data, os.path.join(project_root, 'coverage', 'nim_coverage.html'))
    
    print(f"Coverage report generated: {os.path.join(project_root, 'coverage', 'nim_coverage.html')}")
    
    # Print summary
    total_files = len([f for f in coverage_data if f.startswith(project_root)])
    print(f"Processed {total_files} Nim source files")