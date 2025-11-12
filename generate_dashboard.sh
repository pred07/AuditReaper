#!/usr/bin/env bash
# Dashboard Generator for AuditReaper
# Generates HTML dashboard from existing audit results
# Usage: ./generate_dashboard.sh <path-to-audit-results-folder>
# Version: 1.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║         AuditReaper Dashboard Generator v1.0           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check arguments
if [[ $# -lt 1 ]]; then
    echo -e "${RED}[x] Error: No results folder specified${NC}"
    echo ""
    echo "Usage: $0 <audit-results-folder>"
    echo ""
    echo "Examples:"
    echo "  $0 ./AuditReaper-Results/bumblebee_20251109_130830"
    echo "  $0 ~/AuditReaper-Results/bumblebee_20251109_130830"
    echo ""
    echo "Available results:"
    if [[ -d "./AuditReaper-Results" ]]; then
        ls -1 ./AuditReaper-Results/ | head -n 5
    else
        echo "  (no results found in ./AuditReaper-Results/)"
    fi
    exit 1
fi

RESULTS_DIR="$1"

# Validate results directory
if [[ ! -d "$RESULTS_DIR" ]]; then
    echo -e "${RED}[x] Error: Directory not found: $RESULTS_DIR${NC}"
    exit 1
fi

SECTIONS_DIR="${RESULTS_DIR}/sections"
DATA_DIR="${RESULTS_DIR}/data"
TEMPLATE_FILE="./dashboard_template.html"
OUTPUT_HTML="${RESULTS_DIR}/audit_dashboard.html"

echo -e "${BLUE}[i] Results directory: $RESULTS_DIR${NC}"

# Check required files
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo -e "${RED}[x] Error: Template file not found: $TEMPLATE_FILE${NC}"
    echo -e "${YELLOW}[!] Make sure dashboard_template.html is in the current directory${NC}"
    exit 1
fi

if [[ ! -d "$DATA_DIR" ]]; then
    echo -e "${RED}[x] Error: Data directory not found: $DATA_DIR${NC}"
    echo -e "${YELLOW}[!] This doesn't appear to be a valid AuditReaper results folder${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Found template file${NC}"
echo -e "${GREEN}[+] Found data directory${NC}"

# Read JSON data
if [[ -f "${DATA_DIR}/audit_results.json" ]]; then
    AUDIT_DATA=$(cat "${DATA_DIR}/audit_results.json")
    echo -e "${GREEN}[+] Loaded audit_results.json${NC}"
else
    echo -e "${YELLOW}[!] Warning: audit_results.json not found, using defaults${NC}"
    AUDIT_DATA='{"meta":{"host":"unknown","timestamp":"unknown","version":"1.0"},"summary":{"counts":{"success":0,"warnings":0,"failures":0,"critical":0}}}'
fi

# Read findings
if [[ -f "${DATA_DIR}/findings.json" ]]; then
    FINDINGS_DATA=$(cat "${DATA_DIR}/findings.json")
    echo -e "${GREEN}[+] Loaded findings.json${NC}"
else
    echo -e "${YELLOW}[!] Warning: findings.json not found, using empty array${NC}"
    FINDINGS_DATA='[]'
fi

# Generate dashboard
echo ""
echo -e "${BLUE}[i] Generating HTML dashboard...${NC}"

# Check if Python is available
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}[x] Error: python3 is required but not installed${NC}"
    exit 1
fi

# Use Python to safely inject data into template
python3 <<PYEOF
import json
import sys

try:
    # Read template
    with open('${TEMPLATE_FILE}', 'r', encoding='utf-8') as f:
        template = f.read()

    # Read actual data
    audit_data = '''${AUDIT_DATA}'''
    findings_data = '''${FINDINGS_DATA}'''
    
    # Validate JSON
    try:
        json.loads(audit_data)
        json.loads(findings_data)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON data - {e}", file=sys.stderr)
        sys.exit(1)

    # Replace placeholders
    output = template.replace('{{AUDIT_DATA}}', audit_data)
    output = output.replace('{{FINDINGS_DATA}}', findings_data)

    # Write output
    with open('${OUTPUT_HTML}', 'w', encoding='utf-8') as f:
        f.write(output)

    print('[+] Dashboard generated successfully!')

except Exception as e:
    print(f'[x] Error: {e}', file=sys.stderr)
    sys.exit(1)
PYEOF

if [[ $? -eq 0 ]]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║           Dashboard Generated Successfully!            ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}✓ Location: $OUTPUT_HTML${NC}"
    echo ""
    echo "Open with:"
    echo ""
    echo "  1. Direct open (if GUI available):"
    echo -e "     ${BLUE}firefox $OUTPUT_HTML${NC}"
    echo -e "     ${BLUE}google-chrome $OUTPUT_HTML${NC}"
    echo ""
    echo "  2. Python web server:"
    echo -e "     ${BLUE}cd $(dirname "$OUTPUT_HTML")${NC}"
    echo -e "     ${BLUE}python3 -m http.server 8080${NC}"
    echo -e "     Then visit: ${GREEN}http://localhost:8080/audit_dashboard.html${NC}"
    echo ""
    echo "  3. Copy to your machine (if remote):"
    echo -e "     ${BLUE}scp user@server:$OUTPUT_HTML ~/Downloads/${NC}"
    echo ""
    
    # Show summary
    if command -v jq >/dev/null 2>&1 && [[ -f "${DATA_DIR}/audit_results.json" ]]; then
        echo "Quick Summary:"
        echo "─────────────────────────────────────────────────────────"
        jq -r '.summary.counts | "  Success:  \(.success)\n  Warnings: \(.warnings)\n  Failures: \(.failures)\n  Critical: \(.critical)"' "${DATA_DIR}/audit_results.json" 2>/dev/null || true
        echo "─────────────────────────────────────────────────────────"
        echo ""
    fi
else
    echo ""
    echo -e "${RED}[x] Error generating dashboard${NC}"
    echo -e "${YELLOW}[!] Check the error message above${NC}"
    exit 1
fi
