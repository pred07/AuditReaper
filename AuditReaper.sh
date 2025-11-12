#!/usr/bin/env bash
# AuditReaper v2.5 - System Audit Tool
# Author: 0xbrijith
# Repo: https://github.com/pred07/AuditReaper
# Version: 2.5
set -euo pipefail
IFS=$'\n\t'

#####################################
# Configuration / Defaults
#####################################
SCRIPT_VERSION="2.5"
AUTHOR="0xbrijith"
REPO="https://github.com/pred07/AuditReaper"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
HOST="$(hostname -s 2>/dev/null || echo "unknown-host")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OUTDIR="${SCRIPT_DIR}/AuditReaper-Results/${HOST}_${TIMESTAMP}"
SECTIONS_DIR=""
DATA_DIR=""
OUT_ALL=""
OUT_JSON=""
OUT_HTML=""
ERRFILE=""

# Flags (defaults)
VERBOSE=1
ASK_CONSENT=1
INSTALL_DEPS=0
FULL_SCAN=0
REDACT=0
GENERATE_HTML=1

# Counters
FAIL_COUNT=0
WARN_COUNT=0
OK_COUNT=0
INFO_COUNT=0
CRITICAL_COUNT=0
TOTAL_CHECKS=14

# Arrays
declare -a FAIL_NOTES=()
declare -a WARN_NOTES=()
declare -a CRITICAL_FINDINGS=()
declare -a SECURITY_FINDINGS=()

JSON_OBJ=""

# Required / optional tools
readonly REQ_TOOLS=(jq curl ss awk sed grep find stat uname date hostname)
readonly OPT_TOOLS=(debsums docker podman rkhunter chkrootkit netstat getcap lsb_release)

# Colors (if tty)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  GRAY='\033[0;90m'
  NC='\033[0m'
  BOLD='\033[1m'
else
  RED=''; YELLOW=''; GREEN=''; BLUE=''; CYAN=''; GRAY=''; NC=''; BOLD=''
fi

#####################################
# Utility functions
#####################################
spinner() {
  local pid=$1; local msg="$2"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r${CYAN}[${frames[$i]}]${NC} %s" "$msg"
    i=$(( (i + 1) % 10 ))
    sleep 0.08
  done
  printf "\r"
}

progress_bar() {
  local current=$1
  local total=$2
  local width=40
  local filled=0
  local empty=0
  local percentage=0

  if [[ $total -eq 0 ]]; then
    total=1
  fi

  percentage=$(( current * 100 / total ))
  filled=$(( width * current / total ))
  empty=$(( width - filled ))

  printf "${GRAY}[${NC}"
  for ((i=0; i<filled; i++)); do printf "${GREEN}=${NC}"; done
  for ((i=0; i<empty; i++)); do printf "${GRAY}-${NC}"; done
  printf "${GRAY}] ${CYAN}%3d%%%s" "$percentage" "${NC}"
}

log() {
  local level="$1"; shift; local msg="$*"; local ts; ts="$(date '+%H:%M:%S')"
  case "$level" in
    INFO) printf "${GRAY}[%s]${NC} ${BLUE}[i]${NC} %s\n" "$ts" "$msg"; INFO_COUNT=$((INFO_COUNT+1));;
    SUCCESS) printf "${GRAY}[%s]${NC} ${GREEN}[+]${NC} %s\n" "$ts" "$msg"; OK_COUNT=$((OK_COUNT+1));;
    WARN) printf "${GRAY}[%s]${NC} ${YELLOW}[!]${NC} %s\n" "$ts" "$msg"; WARN_COUNT=$((WARN_COUNT+1));;
    ERROR) printf "${GRAY}[%s]${NC} ${RED}[x]${NC} %s\n" "$ts" "$msg"; FAIL_COUNT=$((FAIL_COUNT+1));;
    CRITICAL) printf "${GRAY}[%s]${NC} ${RED}${BOLD}[X]${NC} %s\n" "$ts" "$msg"; CRITICAL_COUNT=$((CRITICAL_COUNT+1));;
    *) printf "[%s] %s\n" "$ts" "$msg";;
  esac
  if [[ -n "${OUT_ALL:-}" ]]; then
    echo "[$(date -Iseconds)] [$level] $msg" >> "$OUT_ALL" 2>/dev/null || true
  fi
}

section_header() {
  local title="$1"; local output_file="${2:-$OUT_ALL}"
  {
    echo ""
    echo "============================================================"
    echo "  $title"
    echo "============================================================"
    echo ""
  } >> "$output_file"
}

note_finding() {
  local severity="$1"; local category="$2"; local message="$3"; local context="${4:-}"
  case "$severity" in
    CRITICAL) log CRITICAL "[$category] $message"; CRITICAL_FINDINGS+=("[$category] $message");;
    HIGH|ERROR) log ERROR "[$category] $message"; FAIL_NOTES+=("[$category] $message");;
    MEDIUM|WARN) log WARN "[$category] $message"; WARN_NOTES+=("[$category] $message");;
    INFO) log INFO "[$category] $message";;
    *) log INFO "[$category] $message";;
  esac
  SECURITY_FINDINGS+=("{\"severity\":\"$severity\",\"category\":\"$category\",\"message\":\"$(printf '%s' "$message" | sed 's/"/\\"/g')\",\"context\":\"$(printf '%s' "$context" | sed 's/"/\\"/g')\",\"timestamp\":\"$(date -Iseconds)\"}")
}

redact_sensitive() {
  if [[ "$REDACT" -eq 0 ]]; then
    cat
  else
    sed -E \
      -e 's/(AKIA[0-9A-Z]{16})/[REDACTED_AWS_KEY]/g' \
      -e 's/(-----BEGIN[[:space:]]+(RSA|OPENSSH|ENCRYPTED|EC|DSA)[[:space:]]+PRIVATE[[:space:]]+KEY-----)/[REDACTED_PRIVATE_KEY]/g' \
      -e 's/(password[[:space:]]*[:=][[:space:]]*)[^[:space:]\n]*/\1[REDACTED]/gi' \
      -e 's/(token[[:space:]]*[:=][[:space:]]*)[^[:space:]\n]*/\1[REDACTED]/gi' \
      -e 's/([0-9]{13,16})/[REDACTED_NUMBER]/g' \
      -e 's/([0-9a-f]{64})/[REDACTED_HASH64]/g'
  fi
}

#####################################
# Initialization
#####################################
init_outputs() {
  mkdir -p "$OUTDIR" 2>/dev/null || { echo "ERROR: cannot create $OUTDIR"; exit 1; }
  SECTIONS_DIR="${OUTDIR}/sections"
  DATA_DIR="${OUTDIR}/data"
  mkdir -p "$SECTIONS_DIR" "$DATA_DIR"
  OUT_ALL="${OUTDIR}/auditreaper_${HOST}_${TIMESTAMP}.txt"
  OUT_JSON="${DATA_DIR}/audit_results.json"
  OUT_HTML="${OUTDIR}/audit_dashboard.html"
  ERRFILE="${OUTDIR}/errors.log"
  : > "$OUT_ALL"
  : > "$ERRFILE"
  JSON_OBJ="$(mktemp)"
  echo '{"meta":{},"system":{},"findings":[],"summary":{}}' > "$JSON_OBJ"
}

check_dependencies() {
  local missing=()
  for t in "${REQ_TOOLS[@]}"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log ERROR "Missing required tools: ${missing[*]}"
    echo "${YELLOW}Install with:${NC} sudo apt-get install -y ${missing[*]}"
    return 1
  fi
  log SUCCESS "Dependencies ok"
  return 0
}

install_dependencies() {
  [[ $INSTALL_DEPS -ne 1 ]] && return 0
  if [[ $EUID -ne 0 ]]; then log ERROR "Root required to install deps"; return 1; fi
  local apt_cmd="apt-get"
  command -v apt >/dev/null 2>&1 && apt_cmd="apt"
  log INFO "Updating package cache..."
  $apt_cmd update >> "$OUT_ALL" 2>>"$ERRFILE" &
  local pid=$!
  spinner $pid "Updating package cache"
  wait $pid
  local packages=(jq curl iproute2 lsb-release debsums rkhunter chkrootkit net-tools libcap2-bin)
  log INFO "Installing: ${packages[*]}"
  $apt_cmd install -y "${packages[@]}" >> "$OUT_ALL" 2>>"$ERRFILE" &
  pid=$!
  spinner $pid "Installing packages"
  wait $pid
  log SUCCESS "Dependencies installed"
}

get_user_consent() {
  [[ $ASK_CONSENT -eq 0 ]] && return 0
  cat <<-CONS >> "$OUT_ALL"
============================================================
  CONSENT NOTICE
============================================================

This audit will collect system information, logs, shell histories, SSH keys, network config and installed packages.
Output will be saved under: $OUTDIR

CONS
  read -r -p "$(printf "${YELLOW}[?]${NC} Proceed? (yes/no): ")" resp
  case "$resp" in y|Y|yes|YES) log INFO "Consent granted";; *) log WARN "Consent denied"; exit 0;; esac
}

#####################################
# Collection modules
#####################################

collect_system_info() {
  local outfile="${SECTIONS_DIR}/01_system_info.txt"; section_header "SYSTEM INFORMATION" "$outfile"
  {
    echo "Hostname: $(hostname -f 2>/dev/null || hostname)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Date: $(date -R)"
    echo ""
    cat /etc/os-release 2>/dev/null || true
    echo ""
    free -h || true
    echo ""
    df -h | head -n 20 || true
    echo ""
    lscpu 2>/dev/null | head -n 30 || true
  } >> "$outfile" 2>>"$ERRFILE"
  jq -n --arg host "$(hostname -f 2>/dev/null || hostname)" --arg kernel "$(uname -r)" --arg arch "$(uname -m)" --arg date "$(date -Iseconds)" '{host:$host,kernel:$kernel,arch:$arch,date:$date}' > "${DATA_DIR}/system_info.json" 2>>"$ERRFILE" || true
  log SUCCESS "System information"
}

collect_user_accounts() {
  local outfile="${SECTIONS_DIR}/02_users_and_groups.txt"; section_header "USER ACCOUNTS & GROUPS" "$outfile"
  {
    awk -F: 'BEGIN{printf "%-20s %-8s %-8s %-30s %s\n","USERNAME","UID","GID","HOME","SHELL"} {printf "%-20s %-8s %-8s %-30s %s\n",$1,$3,$4,$6,$7}' /etc/passwd
    echo ""
    echo "=== UID 0 accounts ==="
    awk -F: '$3==0{print $1}' /etc/passwd
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "User accounts"
}

collect_network_config() {
  local outfile="${SECTIONS_DIR}/03_network_configuration.txt"; section_header "NETWORK CONFIGURATION" "$outfile"
  {
    ip -br addr show 2>/dev/null || ifconfig -a
    echo ""
    ss -tunlp 2>/dev/null | head -n 50 || netstat -tunlp 2>/dev/null | head -n 50
    echo ""
    cat /etc/resolv.conf 2>/dev/null || true
    echo ""
    ip route show 2>/dev/null || route -n 2>/dev/null
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Network config"
}

collect_firewall_rules() {
  local outfile="${SECTIONS_DIR}/04_firewall_rules.txt"; section_header "FIREWALL CONFIG" "$outfile"
  {
    if command -v ufw >/dev/null 2>&1; then ufw status verbose; else echo "UFW not installed"; fi
    echo ""
    if command -v nft >/dev/null 2>&1; then nft list ruleset; fi
    echo ""
    if command -v iptables >/dev/null 2>&1; then iptables -L -n -v; fi
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Firewall rules"
}

collect_installed_packages() {
  local outfile="${SECTIONS_DIR}/05_installed_packages.txt"; section_header "INSTALLED PACKAGES" "$outfile"
  {
    if command -v dpkg >/dev/null 2>&1; then
      echo "Total packages:"
      dpkg -l 2>/dev/null | grep "^ii" | wc -l || echo "0"
      echo ""
      echo "Top 30 packages by installed size:"
      dpkg-query -Wf '${Installed-Size}\t${Package}\t${Version}\n' 2>/dev/null | sort -rn | head -n 30 || true
      echo ""
      echo "All packages (first 500):"
      dpkg -l 2>/dev/null | head -n 500 || true
    else
      echo "dpkg not available"
    fi
  } >> "$outfile" 2>>"$ERRFILE"
  if command -v dpkg >/dev/null 2>&1; then dpkg -l 2>/dev/null > "${DATA_DIR}/packages_all.txt" || true; fi
  log SUCCESS "Packages"
}

collect_services() {
  local outfile="${SECTIONS_DIR}/06_services_and_processes.txt"; section_header "SERVICES & PROCESSES" "$outfile"
  {
    if command -v systemctl >/dev/null 2>&1; then systemctl list-units --type=service --state=running --no-pager | head -n 100; fi
    echo ""
    ps aux --sort=-%cpu | head -n 30
    echo ""
    ps aux --sort=-%mem | head -n 30
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Services"
}

collect_security_files() {
  local outfile="${SECTIONS_DIR}/07_security_sensitive_files.txt"; section_header "SECURITY-SENSITIVE FILES" "$outfile"
  {
    find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -ls 2>/dev/null | head -n 200
    if command -v getcap >/dev/null 2>&1; then getcap -r / 2>/dev/null | head -n 100; fi
    find /etc -xdev -type f -perm -002 -ls 2>/dev/null | head -n 100
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Security files"
}

collect_scheduled_tasks() {
  local outfile="${SECTIONS_DIR}/08_scheduled_tasks.txt"; section_header "SCHEDULED TASKS" "$outfile"
  {
    cat /etc/crontab 2>/dev/null || true
    echo ""
    ls -lah /etc/cron.d 2>/dev/null || true
    echo ""
    for u in $(cut -d: -f1 /etc/passwd); do crontab -u "$u" -l 2>/dev/null || true; done
    echo ""
    if command -v systemctl >/dev/null 2>&1; then systemctl list-timers --all --no-pager; fi
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Scheduled tasks"
}

collect_logs() {
  local outfile="${SECTIONS_DIR}/09_system_logs.txt"; section_header "SYSTEM LOGS" "$outfile"
  {
    for f in /var/log/auth.log /var/log/secure; do [[ -f $f ]] && { echo "=== $f ==="; tail -n 200 "$f"; echo ""; }; done
    echo "=== Recent logins ==="; last -n 100 2>/dev/null || true
    if command -v journalctl >/dev/null 2>&1; then journalctl -p err -n 100 --no-pager 2>/dev/null || true; fi
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "System logs"
}

collect_shell_histories() {
  local outfile="${SECTIONS_DIR}/10_shell_histories.txt"; section_header "SHELL HISTORIES" "$outfile"
  local collected=0
  while IFS=: read -r username _ uid _ _ homedir shell; do
    [[ $uid -lt 1000 && "$username" != "root" ]] && continue
    [[ ! -d "$homedir" ]] && continue
    echo "=== User: $username ===" >> "$outfile"
    for hist in .bash_history .zsh_history .sh_history; do
      local p="$homedir/$hist"
      if [[ -f "$p" && -r "$p" ]]; then echo "--- $hist ---" >> "$outfile"; tail -n 100 "$p" | redact_sensitive >> "$outfile"; collected=$((collected+1)); fi
    done
    if [[ -f "$homedir/.ssh/authorized_keys" && -r "$homedir/.ssh/authorized_keys" ]]; then echo "--- authorized_keys ---" >> "$outfile"; head -n 50 "$homedir/.ssh/authorized_keys" | redact_sensitive >> "$outfile"; fi
    echo "" >> "$outfile"
  done < /etc/passwd
  log SUCCESS "Shell histories ($collected files)"
}

collect_container_info() {
  local outfile="${SECTIONS_DIR}/11_containers.txt"; section_header "CONTAINERS" "$outfile"
  {
    if command -v docker >/dev/null 2>&1; then docker ps -a 2>/dev/null || true; docker images 2>/dev/null || true; fi
    if [[ -f "/.dockerenv" ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then echo "Running inside container"; note_finding INFO container "running in container"; fi
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Containers"
}

search_credentials() {
  local outfile="${SECTIONS_DIR}/12_credential_scan.txt"; section_header "CREDENTIAL SCAN" "$outfile"
  {
    local patterns=( "AKIA[0-9A-Z]{16}" "aws_secret_access_key" "BEGIN.*PRIVATE KEY" "password[[:space:]]*[:=]" "api[_-]?key" )
    local search_dirs=( "/home" "/root" "/etc" "/opt" )
    for p in "${patterns[@]}"; do
      echo "=== Pattern: $p ==="
      for d in "${search_dirs[@]}"; do
        [[ -d "$d" ]] || continue
        timeout 60 grep -r -I -n --max-count=30 --exclude-dir={proc,sys,dev,run} -E "$p" "$d" 2>/dev/null | head -n 30 | redact_sensitive || true
      done
      echo ""
    done
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Credential scan"
}

collect_recent_changes() {
  local outfile="${SECTIONS_DIR}/13_recent_changes.txt"; section_header "RECENT FILE MODIFICATIONS" "$outfile"
  {
    for d in /etc /usr/local/bin /opt /var/www; do
      [[ -d "$d" ]] || continue
      echo "=== Modified in $d (last 7d) ==="
      find "$d" -type f -mtime -7 -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -n 200
      echo ""
    done
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Recent changes"
}

collect_service_versions() {
  local outfile="${SECTIONS_DIR}/14_service_versions.txt"; section_header "SERVICE VERSIONS" "$outfile"
  {
    sshd -V 2>&1 | head -n 1 || true
    apache2 -v 2>/dev/null | head -n 1 || true
    nginx -v 2>&1 | head -n 1 || true
    mysql --version 2>/dev/null | head -n 1 || true
    php --version 2>/dev/null | head -n 1 || true
    python3 --version 2>/dev/null || true
    node --version 2>/dev/null || true
  } >> "$outfile" 2>>"$ERRFILE"
  log SUCCESS "Service versions"
}

perform_deep_scan() {
  [[ $FULL_SCAN -ne 1 ]] && return 0
  if command -v debsums >/dev/null 2>&1; then
    local outfile="${SECTIONS_DIR}/15_deep_package_integrity.txt"; section_header "PACKAGE INTEGRITY CHECK" "$outfile"
    debsums -s >> "$outfile" 2>>"$ERRFILE" || note_finding MEDIUM packages "Package files modified"
  fi
  if command -v rkhunter >/dev/null 2>&1; then
    local outfile="${SECTIONS_DIR}/16_deep_rkhunter.txt"; section_header "ROOTKIT DETECTION" "$outfile"
    rkhunter --check --skip-keypress --report-warnings-only >> "$outfile" 2>>"$ERRFILE" || note_finding HIGH rootkit "rkhunter detected issues"
  fi
  if command -v chkrootkit >/dev/null 2>&1; then
    local outfile="${SECTIONS_DIR}/17_deep_chkrootkit.txt"; section_header "ROOTKIT DETECTION" "$outfile"
    chkrootkit >> "$outfile" 2>>"$ERRFILE" || note_finding HIGH rootkit "chkrootkit detected issues"
  fi
  log SUCCESS "Deep scan"
}

#####################################
# HTML Dashboard generator
#####################################
generate_html_dashboard() {
  [[ $GENERATE_HTML -ne 1 ]] && return 0
  
  local template_file="${SCRIPT_DIR}/dashboard_template.html"
  
  if [[ ! -f "$template_file" ]]; then
    log WARN "Template not found: $template_file"
    log WARN "Skipping HTML generation. Run: ./generate_dashboard.sh $OUTDIR"
    return 0
  fi
  
  log INFO "Generating HTML dashboard..."
  
  # Save JSON files
  jq -n --arg host "$HOST" --arg timestamp "$TIMESTAMP" --arg version "$SCRIPT_VERSION" --argjson ok "$OK_COUNT" --argjson warn "$WARN_COUNT" --argjson fail "$FAIL_COUNT" --argjson critical "$CRITICAL_COUNT" '{
    meta:{host:$host,timestamp:$timestamp,version:$version},
    summary:{counts:{success:$ok,warnings:$warn,failures:$fail,critical:$critical}}
  }' > "$JSON_OBJ" 2>>"$ERRFILE" || true
  
  if [[ ${#SECURITY_FINDINGS[@]} -gt 0 ]]; then
    printf '%s\n' "${SECURITY_FINDINGS[@]}" | jq -s '.' > "${DATA_DIR}/findings.json" 2>>"$ERRFILE" || true
  else
    echo '[]' > "${DATA_DIR}/findings.json"
  fi
  
  cp "$JSON_OBJ" "$OUT_JSON"
  
  # Generate dashboard using Python
  python3 <<PYEOF
import json

# Read template
with open('${template_file}', 'r') as f:
    template = f.read()

# Read data
with open('${OUT_JSON}', 'r') as f:
    audit_data = f.read()

with open('${DATA_DIR}/findings.json', 'r') as f:
    findings_data = f.read()

# Replace placeholders
output = template.replace('{{AUDIT_DATA}}', audit_data)
output = output.replace('{{FINDINGS_DATA}}', findings_data)

# Write output
with open('${OUT_HTML}', 'w') as f:
    f.write(output)

print('Dashboard generated successfully')
PYEOF

  if [[ $? -eq 0 ]]; then
    log SUCCESS "HTML dashboard: $OUT_HTML"
  else
    log ERROR "Failed to generate HTML dashboard"
  fi
}

#####################################
# Usage / Argument parsing
#####################################
usage() {
  cat <<USAGE
============================================================
  AuditReaper v${SCRIPT_VERSION}
  Author: ${AUTHOR} | ${REPO}
============================================================

USAGE:
  sudo ./AuditReaper.sh [OPTIONS]

OPTIONS:
  --install-deps       Install dependencies (apt)
  --yes                Skip consent prompt
  --full               Run deep scan (debsums, rkhunter, chkrootkit)
  --redact             Redact sensitive data
  --no-html            Skip HTML dashboard
  -v                   Verbose
  -q                   Quiet
  -h, --help           Show help

EXAMPLES:
  sudo ./AuditReaper.sh --install-deps --yes
  sudo ./AuditReaper.sh --full --redact

OUTPUT:
  Results saved in: ${SCRIPT_DIR}/AuditReaper-Results/
  
  To generate dashboard separately:
    ./generate_dashboard.sh <path-to-results-folder>
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-deps) INSTALL_DEPS=1; shift ;;
      --yes) ASK_CONSENT=0; shift ;;
      --full) FULL_SCAN=1; shift ;;
      --redact) REDACT=1; shift ;;
      --no-html) GENERATE_HTML=0; shift ;;
      -v) VERBOSE=2; shift ;;
      -q) VERBOSE=0; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

finalize_report() {
  cat > "$OUT_ALL" <<EOF
AuditReaper Combined Report
Host: ${HOST}
Timestamp: ${TIMESTAMP}
Version: ${SCRIPT_VERSION}
EOF
  echo "" >> "$OUT_ALL"
  for f in "${SECTIONS_DIR}"/*.txt; do
    [[ -f "$f" ]] || continue
    printf "\n\n\n" >> "$OUT_ALL"
    cat "$f" >> "$OUT_ALL" 2>/dev/null || true
  done

  cp "$JSON_OBJ" "$OUT_JSON" 2>/dev/null || true
  generate_html_dashboard

  tar -czf "${OUTDIR}.tar.gz" -C "$(dirname "$OUTDIR")" "$(basename "$OUTDIR")" 2>>"$ERRFILE" &
  local pid=$!
  spinner $pid "Archiving results"
  wait $pid

  echo ""
  echo "============================================================"
  echo "  AUDIT SUMMARY"
  echo "============================================================"
  printf "  [+] Successful: %d\n" "$OK_COUNT"
  printf "  [!] Warnings:   %d\n" "$WARN_COUNT"
  printf "  [x] Failures:   %d\n" "$FAIL_COUNT"
  printf "  [X] Critical:   %d\n" "$CRITICAL_COUNT"
  echo ""
  echo "Output files:"
  echo "  Dashboard: $OUT_HTML"
  echo "  Combined:  $OUT_ALL"
  echo "  JSON:      $OUT_JSON"
  echo "  Sections:  $SECTIONS_DIR/"
  echo "  Archive:   ${OUTDIR}.tar.gz"
  echo ""
  echo "To regenerate dashboard:"
  echo "  ./generate_dashboard.sh $OUTDIR"
  echo ""
}

#####################################
# Main
#####################################
main() {
  parse_args "$@"
  init_outputs

  if [[ ! -t 0 && $ASK_CONSENT -eq 1 ]]; then
    ASK_CONSENT=0
    log INFO "Non-interactive mode"
  fi

  get_user_consent

  if [[ $INSTALL_DEPS -eq 1 ]]; then
    install_dependencies || log WARN "Continue with available tools"
  fi

  check_dependencies || { log ERROR "Missing dependencies"; exit 1; }

  local start_time
  start_time=$(date +%s)
  log INFO "Starting audit..."

  local current=0
  local pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " System Information\n"
  collect_system_info &
  pid=$!
  spinner $pid "Collecting system info"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " User Accounts\n"
  collect_user_accounts &
  pid=$!
  spinner $pid "Collecting users"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Network Config\n"
  collect_network_config &
  pid=$!
  spinner $pid "Collecting network"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Firewall Rules\n"
  collect_firewall_rules &
  pid=$!
  spinner $pid "Collecting firewall"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Installed Packages\n"
  collect_installed_packages &
  pid=$!
  spinner $pid "Collecting packages"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Services\n"
  collect_services &
  pid=$!
  spinner $pid "Collecting services"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Security Files\n"
  collect_security_files &
  pid=$!
  spinner $pid "Collecting security files"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Scheduled Tasks\n"
  collect_scheduled_tasks &
  pid=$!
  spinner $pid "Collecting scheduled tasks"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " System Logs\n"
  collect_logs &
  pid=$!
  spinner $pid "Collecting logs"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Shell Histories\n"
  collect_shell_histories &
  pid=$!
  spinner $pid "Collecting histories"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Containers\n"
  collect_container_info &
  pid=$!
  spinner $pid "Collecting containers"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Credentials\n"
  search_credentials &
  pid=$!
  spinner $pid "Searching credentials"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Recent Changes\n"
  collect_recent_changes &
  pid=$!
  spinner $pid "Collecting recent changes"
  wait $pid

  current=$((current + 1))
  progress_bar $current $TOTAL_CHECKS
  printf " Service Versions\n"
  collect_service_versions &
  pid=$!
  spinner $pid "Collecting versions"
  wait $pid

  if [[ $FULL_SCAN -eq 1 ]]; then
    perform_deep_scan &
    pid=$!
    spinner $pid "Performing deep scan"
    wait $pid
  fi

  log SUCCESS "All modules completed in $(( $(date +%s) - start_time ))s"
  finalize_report

  if [[ $CRITICAL_COUNT -gt 0 ]]; then
    exit 3
  elif [[ $FAIL_COUNT -gt 0 ]]; then
    exit 2
  elif [[ $WARN_COUNT -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

trap 'log ERROR "Script failed on line $LINENO"; exit 1' ERR
main "$@"
