#!/bin/bash

# --- MYRHA (Mirantis Supportdump Dashboard) ---
# Version: 2.1.0-MAC
# Description: Analysis and Visualization of Mirantis support dumps for macOS.

VERSION="2.1.0-MAC"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Check if yq and openssl are installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install it (e.g., brew install yq)."
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    echo "Error: openssl is not installed."
    exit 1
fi

# Usage info
show_usage() {
    echo "Usage: $0 [support-dump-directory]"
    echo "Example: $0 ./support-dump-2024-01-01"
    exit 1
}

if [[ $# -eq 0 ]]; then
    BASE_DIR="."
else
    BASE_DIR="$1"
fi

if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: Directory $BASE_DIR not found."
    show_usage
fi

LOGPATH="$BASE_DIR/myrha"
mkdir -p "$LOGPATH"
HTML_REPORT="$LOGPATH/dashboard.html"
# Ensure the report starts clean
rm -f "$HTML_REPORT"

# --- INTERNAL HELPERS ---
check_overlaps() {
  # Requires a list of CIDRs and Ranges in stdin
  # Returns warnings if overlaps are found
  python3 -c '
import ipaddress
import sys

def get_ips(entry):
    if "/" in entry:
        return list(ipaddress.ip_network(entry.strip(), strict=False))
    elif "-" in entry:
        start, end = entry.split("-")
        start_ip = ipaddress.ip_address(start.strip())
        end_ip = ipaddress.ip_address(end.strip())
        return [ipaddress.ip_address(start_ip + i) for i in range(int(end_ip) - int(start_ip) + 1)]
    else:
        return [ipaddress.ip_address(entry.strip())]

data = sys.stdin.read().split(",")
all_ranges = []
for item in data:
    if not item.strip(): continue
    try:
        all_ranges.append(get_ips(item))
    except:
        continue

overlaps = []
for i in range(len(all_ranges)):
    for j in range(i + 1, len(all_ranges)):
        set_i = set(all_ranges[i])
        set_j = set(all_ranges[j])
        intersect = set_i.intersection(set_j)
        if intersect:
            overlaps.append(f"OVERLAP: {list(intersect)[0]}... in blocks {data[i]} and {data[j]}")

if overlaps:
    print("🛑 ALERT: IP RANGE OVERLAPS DETECTED!")
    for o in overlaps[:10]: print(f"  - {o}")
' 2>/dev/null
}

audit_k8s_secret() {
  local f="$1"
  local DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
  local KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$f" 2>/dev/null)
  
  for KEY in $KEYS; do
    local VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$f" 2>/dev/null)
    [[ -z "$VAL" ]] && continue
    
    # Try decoding
    local DECODED=$(echo "$VAL" | base64 -d 2>/dev/null)
    local TARGET=""
    if [[ -n "$DECODED" ]]; then
       TARGET="$DECODED"
    else
       TARGET="$VAL"
    fi

    if [[ "$TARGET" == *"BEGIN CERTIFICATE"* ]]; then
       echo "### Key: $KEY (Certificate)"
       echo "$TARGET" | openssl x509 -noout -text 2>/dev/null | grep -E "Subject:|Issuer:|Not After|DNS:" | sed 's/^/  /'
       # Check expiry
       local END_DATE=$(echo "$TARGET" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
       if [[ -n "$END_DATE" ]]; then
          local END_SEC=$(date -j -f "%b %e %H:%M:%S %Y %Z" "$END_DATE" +%s 2>/dev/null)
          local NOW_SEC=$(date +%s)
          local DIFF=$((END_SEC - NOW_SEC))
          if [ $DIFF -lt 0 ]; then
             echo "  🔴 EXPIRED! ($END_DATE)"
          elif [ $DIFF -lt 2592000 ]; then
             echo "  🟠 WARNING: Expires in $((DIFF / 86400)) days ($END_DATE)"
          fi
       fi
    elif [[ "$TARGET" == *"BEGIN PRIVATE KEY"* ]]; then
       echo "### Key: $KEY (Private Key Detected)"
    fi
  done
}

# 1. SCAN AND MAP DUMP STRUCTURE
echo "Scanning support dump structure..."
find "$BASE_DIR" -type f \( -name "*.yaml" -o -name "*.log" -o -name "*.json" \) > "$LOGPATH/files"

# Identify Management (MCC) and Managed (MOS) clusters
MCC_DIR=$(grep "kaas-mgmt" "$LOGPATH/files" | head -n 1 | cut -d'/' -f1-2)
[[ -z "$MCC_DIR" ]] && MCC_DIR=$(grep "mgmt" "$LOGPATH/files" | head -n 1 | cut -d'/' -f1-2)
[[ -z "$MCC_DIR" ]] && MCC_DIR="."

MCCNAME=$(find "$MCC_DIR" -path "*/cluster.k8s.io/clusters/*.yaml" 2>/dev/null | grep -v default | xargs basename 2>/dev/null | sed 's/.yaml//' | head -n 1)
[[ -z "$MCCNAME" ]] && MCCNAME=$(grep -r "kind: Cluster" "$MCC_DIR" 2>/dev/null | head -n 1 | cut -d: -f1 | xargs basename 2>/dev/null | sed 's/.yaml//')

# Identify MOS Cluster
MOS_DIR=$(grep -vE "kaas-mgmt|mgmt" "$LOGPATH/files" | grep "cluster/core/nodes" | head -n 1 | cut -d'/' -f1-2)
MOSNAME=""
if [[ -n "$MOS_DIR" && "$MOS_DIR" != "$MCC_DIR" ]]; then
   MOSNAME=$(basename "$MOS_DIR")
fi

# Namespaces
MCCNAMESPACE="kaas"
MOSNAMESPACE="openstack"

echo "Detected Management Cluster: ${MCCNAME:-Unknown} (Path: $MCC_DIR)"
echo "Detected Managed Cluster:    ${MOSNAME:-None} (Path: $MOS_DIR)"

# --- DASHBOARD HTML HEADER ---
cat <<EOF >"$HTML_REPORT"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Myrha - Mirantis Supportdump Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">
    <style>
        :root {
            --bg: #0f172a;
            --sidebar-bg: #1e293b;
            --card-bg: #1e293b;
            --text: #e2e8f0;
            --accent: #38bdf8;
            --accent-hover: #7dd3fc;
            --border: #334155;
            --success: #22c55e;
            --warning: #f59e0b;
            --danger: #ef4444;
            --code-bg: #000000;
        }

        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: 'Inter', sans-serif;
            background-color: var(--bg);
            color: var(--text);
            display: flex;
            height: 100vh;
            overflow: hidden;
        }

        /* Sidebar Styles */
        .sidebar {
            width: 320px;
            background-color: var(--sidebar-bg);
            border-right: 1px solid var(--border);
            display: flex;
            flex-direction: column;
            transition: all 0.3s ease;
            flex-shrink: 0;
        }
        .sidebar.collapsed { width: 0; overflow: hidden; border-right: none; }
        .sidebar-header { padding: 20px; border-bottom: 1px solid var(--border); }
        .sidebar-header h2 { margin: 0; font-size: 1.2rem; color: var(--accent); }
        .search-box { padding: 15px; border-bottom: 1px solid var(--border); }
        .search-box input {
            width: 100%; padding: 10px; border-radius: 6px; border: 1px solid var(--border);
            background: var(--bg); color: white; outline: none;
        }
        .sidebar-nav { flex: 1; overflow-y: auto; padding: 10px; }
        .sidebar-nav ul { list-style: none; padding: 0; margin: 0; }
        .sidebar-nav li { margin-bottom: 4px; }
        .sidebar-nav a {
            display: block; padding: 10px 15px; border-radius: 6px;
            color: var(--text); text-decoration: none; font-size: 0.9rem;
            transition: background 0.2s;
        }
        .sidebar-nav a:hover { background: var(--border); }
        .sidebar-nav a.active { background: var(--accent); color: var(--bg); font-weight: 600; }
        .category-header {
            padding: 15px 15px 5px; font-size: 0.75rem; font-weight: 700;
            text-transform: uppercase; color: #64748b; letter-spacing: 0.05em;
        }

        /* Main Content Styles */
        .main-content { flex: 1; overflow-y: auto; padding: 30px; position: relative; scroll-behavior: smooth; }
        .header { margin-bottom: 30px; }
        .header h1 { margin: 0; font-weight: 300; font-size: 2rem; }
        .header p { color: #94a3b8; margin: 5px 0 0; }

        .card {
            background: var(--card-bg); border-radius: 12px; border: 1px solid var(--border);
            margin-bottom: 25px; display: none; flex-direction: column;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        .card.active { display: flex; }
        .card-header-actions { display: flex; align-items: center; gap: 10px; }
        .card h2 {
            padding: 20px; margin: 0; font-size: 1.1rem; border-bottom: 1px solid var(--border);
            display: flex; justify-content: space-between; align-items: center;
        }
        .card .raw-code {
            margin: 0; padding: 20px !important; background: var(--code-bg) !important;
            font-family: 'Fira Code', monospace; font-size: 0.85rem; line-height: 1.6;
            max-height: 600px; overflow: auto; border-radius: 0 0 12px 12px;
        }
        .card .raw-code.fullscreen {
            position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
            z-index: 9999; max-height: none; border-radius: 0;
        }

        /* Analysis Files Styles */
        .analyzed-files-wrapper {
          padding: 10px 20px; background: rgba(0,0,0,0.2); border-bottom: 1px solid var(--border);
          display: flex; justify-content: space-between; align-items: center;
        }
        .analyzed-files-container {
          font-size: 0.8rem; color: #94a3b8; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; flex: 1;
        }
        .analyzed-files-container.expanded { white-space: normal; }
        .more-files-btn {
          background: none; border: 1px solid var(--accent); color: var(--accent);
          font-size: 0.7rem; cursor: pointer; border-radius: 4px; padding: 2px 6px; margin-left: 10px;
        }

        .btn-tool {
            padding: 6px 12px; border-radius: 6px; font-size: 0.75rem; cursor: pointer;
            background: var(--bg); border: 1px solid var(--border); color: var(--text);
            transition: all 0.2s;
        }
        .btn-tool:hover { border-color: var(--accent); color: var(--accent); }
        .btn-close { color: var(--danger); }
        .btn-close:hover { background: var(--danger); color: white; border-color: var(--danger); }
        
        .toggle-sidebar-btn {
            position: fixed; bottom: 20px; left: 20px; z-index: 1000;
            width: 40px; height: 40px; border-radius: 50%; background: var(--accent);
            color: var(--bg); border: none; cursor: pointer; font-size: 1.2rem;
            box-shadow: 0 4px 10px rgba(0,0,0,0.3);
        }

        /* Search highlights */
        .search-match { background-color: rgba(245, 158, 11, 0.4); border-bottom: 2px solid var(--warning); }
        .search-match.current { background-color: var(--warning); color: black; }
        .card-search {
          background: var(--bg); border: 1px solid var(--border); color: white;
          padding: 4px 8px; border-radius: 4px; font-size: 0.8rem; width: 150px;
        }
        .search-nav-container { display: flex; align-items: center; gap: 5px; }
        .search-count { font-size: 0.7rem; color: #94a3b8; min-width: 40px; }

        .placeholder-msg {
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            height: 60%; color: #475569;
        }
        .placeholder-msg h2 { font-weight: 300; font-size: 2.5rem; margin-bottom: 10px; }
        
        ::-webkit-scrollbar { width: 8px; height: 8px; }
        ::-webkit-scrollbar-track { background: var(--bg); }
        ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: #475569; }

        @media print {
            .sidebar, .toggle-sidebar-btn, .card-header-actions, .analyzed-files-wrapper { display: none !important; }
            .card { display: block !important; break-inside: avoid; border: 1px solid #ccc; }
            .main-content { overflow: visible; padding: 0; }
        }
    </style>
    <script>
        function toggleCard(link, id) {
            const card = document.getElementById(id);
            if (card.classList.contains('active')) {
                card.classList.remove('active');
                link.classList.remove('active');
            } else {
                card.classList.add('active');
                link.classList.add('active');
                // Scroll to card
                card.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
            updatePlaceholder();
        }

        function closeCard(id) {
            document.getElementById(id).classList.remove('active');
            const links = document.querySelectorAll('.sidebar-nav a');
            links.forEach(l => {
                if (l.getAttribute('onclick').includes("'" + id + "'")) l.classList.remove('active');
            });
            updatePlaceholder();
        }

        function updatePlaceholder() {
            const activeCards = document.querySelectorAll('.card.active');
            document.getElementById('placeholder').style.display = activeCards.length === 0 ? 'flex' : 'none';
        }

        function toggleSidebar() {
            const sidebar = document.querySelector('.sidebar');
            const btn = document.querySelector('.toggle-sidebar-btn');
            sidebar.classList.toggle('collapsed');
            btn.innerHTML = sidebar.classList.contains('collapsed') ? '▶' : '◀';
        }

        function filterNav(val) {
            const links = document.querySelectorAll('.sidebar-nav li');
            links.forEach(li => {
                const text = li.textContent.toLowerCase();
                li.style.display = text.includes(val.toLowerCase()) ? 'block' : 'none';
            });
        }

        function copyToClipboard(btn, id) {
            const code = document.querySelector('#' + id + ' .raw-code').innerText;
            navigator.clipboard.writeText(code).then(() => {
                const oldText = btn.innerText;
                btn.innerText = 'Copied!';
                btn.style.borderColor = 'var(--success)';
                btn.style.color = 'var(--success)';
                setTimeout(() => {
                    btn.innerText = oldText;
                    btn.style.borderColor = '';
                    btn.style.color = '';
                }, 2000);
            });
        }

        function toggleFullScreen(btn, id) {
            const code = document.querySelector('#' + id + ' .raw-code');
            code.classList.toggle('fullscreen');
            btn.innerText = code.classList.contains('fullscreen') ? 'Exit Full Screen' : 'Full Screen';
            if (code.classList.contains('fullscreen')) {
                document.body.style.overflow = 'hidden';
            } else {
                document.body.style.overflow = '';
            }
        }

        function toggleBlockWrap(btn, id) {
            const code = document.querySelector('#' + id + ' .raw-code');
            const isWrapped = code.style.whiteSpace === 'pre-wrap';
            code.style.whiteSpace = isWrapped ? 'pre' : 'pre-wrap';
            btn.innerText = isWrapped ? 'Wrap: OFF' : 'Wrap: ON';
        }

        function scrollToLimit(id, limit) {
            const code = document.querySelector('#' + id + ' .raw-code');
            if (limit === 'top') code.scrollTop = 0;
            else code.scrollTop = code.scrollHeight;
        }

        function toggleAnalyzedFiles(btn) {
          const container = btn.previousElementSibling;
          container.classList.toggle('expanded');
          btn.innerText = container.classList.contains('expanded') ? 'less...' : 'more...';
        }

        // Search logic inside cards
        let searchIndices = {};

        function performSearch(cardId, query) {
            const card = document.getElementById(cardId);
            const codeBlock = card.querySelector('code');
            const countSpan = card.querySelector('.search-count');
            
            if (!query || query.length < 2) {
                codeBlock.innerHTML = codeBlock.textContent.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                countSpan.innerText = '0/0';
                searchIndices[cardId] = { current: -1, total: 0 };
                return;
            }

            const content = codeBlock.textContent;
            const regex = new RegExp(query.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&'), 'gi');
            let matches = [];
            let match;
            
            while ((match = regex.exec(content)) !== null) {
                matches.push(match.index);
            }

            if (matches.length === 0) {
                countSpan.innerText = '0/0';
                searchIndices[cardId] = { current: -1, total: 0 };
                return;
            }

            // Highlighting (expensive but works for reasonably sized blocks)
            let highlighted = content
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(regex, (m) => `<span class="search-match">${m}</span>`);
            
            codeBlock.innerHTML = highlighted;
            searchIndices[cardId] = { current: 0, total: matches.length };
            countSpan.innerText = `1/${matches.length}`;
            highlightMatch(cardId, 0);
        }

        function highlightMatch(cardId, index) {
            const card = document.getElementById(cardId);
            const matches = card.querySelectorAll('.search-match');
            matches.forEach(m => m.classList.remove('current'));
            if (matches[index]) {
                matches[index].classList.add('current');
                matches[index].scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }

        function navigateSearch(cardId, direction) {
            const state = searchIndices[cardId];
            if (!state || state.total === 0) return;

            if (direction === 'next') {
                state.current = (state.current + 1) % state.total;
            } else {
                state.current = (state.current - 1 + state.total) % state.total;
            }

            const countSpan = document.getElementById(cardId).querySelector('.search-count');
            countSpan.innerText = `${state.current + 1}/${state.total}`;
            highlightMatch(cardId, state.current);
        }
    </script>
</head>
<body>

<nav class="sidebar">
    <div class="sidebar-header">
        <h2>MYRHA Dashboard</h2>
        <small style="color: #64748b">Supportdump Analysis v$VERSION</small>
    </div>
    <div class="search-box">
        <input type="text" placeholder="Filter sections..." onkeyup="filterNav(this.value)">
    </div>
    <nav class="sidebar-nav">
        <ul id="sidebarList">
            <li class="category-header">Executive</li>
            <li data-category="all"><a href="javascript:void(0)" onclick="toggleCard(this, 'EXECUTIVE-SUMMARY-&amp;-CRITICAL-FINDINGS')">EXECUTIVE SUMMARY</a></li>
EOF

# --- CORE ANALYSIS LOGIC ---

# Identify Versions for sidebar/header
MCC_VER_STR=""
MCC_DOC_URL="#"
MCC_JIRA_URL="#"
if [[ -n "$MCCNAME" ]]; then
  MCC_YAML=$(find "$MCC_DIR" -path "*/cluster.k8s.io/clusters/$MCCNAME.yaml" | head -n 1)
  [[ -z "$MCC_YAML" ]] && MCC_YAML=$(find "$MCC_DIR" -path "*/clusters/*.yaml" | head -n 1)
  
  if [[ -f "$MCC_YAML" ]]; then
    # Extract version (e.g., release: kaas-2.26.1)
    K_RAW=$(grep -m1 "release: kaas-" "$MCC_YAML" | sed -e 's/.*kaas-//' -e 's/[[:space:]]//g' -e 's/-/./g')
    IFS='.' read -r -a M <<<"$K_RAW"
    MCC_BUG_VER="${M[0]}.${M[1]}.${M[2]}"
    MCC_VER_STR=" (KaaS: $MCC_BUG_VER)"
    
    MCC_DOC_URL="https://docs.mirantis.com/container-cloud/latest/release-notes/releases/${M[0]}-${M[1]}-${M[2]}.html"
    MCC_JIRA_URL="https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%20$MCC_BUG_VER%22"
  fi
fi

MOS_VER_STR=""
MOS_DOC_URL="#"
MOS_JIRA_URL="#"
if [[ -n "$MOSNAME" ]]; then
  MOS_STATUS_FILE=$(find "$MOS_DIR" -path "*/lcm.mirantis.com/openstackdeploymentstatus/*.yaml" 2>/dev/null | head -n 1)
  if [[ -f "$MOS_STATUS_FILE" ]]; then
     REL_RAW=$(grep -m1 "    release: " "$MOS_STATUS_FILE" | sed -e 's/.*release: //' -e 's/[[:space:]]//g' -e 's/+/./g' -e 's/\.$//')
     IFS='.' read -r -a V <<<"$REL_RAW"
     MOS_BUG_VER="${V[3]}.${V[4]}${V[5]:+.${V[5]}}"
     MOS_VER_STR=" (MOSK: $MOS_BUG_VER)"
     
     if (($(echo "${V[3]}.${V[4]} >= 24.2" | bc -l 2>/dev/null || echo 0))); then
        MOS_DOC_URL="https://docs.mirantis.com/mosk/latest/release-notes/${V[3]}.${V[4]}-series/${V[3]}.${V[4]}.${V[5]}.html"
     else
        MOS_DOC_URL="https://docs.mirantis.com/mosk/24.1-and-earlier/release-notes/release-notes-mosk-old/${V[3]}.${V[4]}-series/${V[3]}.${V[4]}.${V[5]}.html"
     fi
     MOS_JIRA_URL="https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22MOSK%20$MOS_BUG_VER%22"
  fi
fi

MCC_LINKS_HTML="<div style='margin-bottom: 5px;'><strong>MCC $MCC_BUG_VER:</strong> <a href='$MCC_DOC_URL' target='_blank'>RN</a> | <a href='$MCC_JIRA_URL' target='_blank'>Bugs</a></div>"
MOS_LINKS_HTML="${MOSNAME:+<div><strong>MOS $MOS_BUG_VER:</strong> <a href='$MOS_DOC_URL' target='_blank'>RN</a> | <a href='$MOS_JIRA_URL' target='_blank'>Bugs</a></div>}"

# --- COMPONENT SCANNING ---

# MOS Cluster
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_cluster.yaml"
  echo "Gathering MOS cluster details..."
  echo "################# [MOS CLUSTER DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  MOS_OSD=$(find "$MOS_DIR" -path "*/lcm.mirantis.com/openstackdeployments/*.yaml" | head -n 1)
  if [[ -f "$MOS_OSD" ]]; then
    echo "# [FILE]: $MOS_OSD" >>"$OUT"
    echo "## OpenStackDeployment Status:" >>"$OUT"
    yq eval '.Object.status // .status' "$MOS_OSD" 2>/dev/null >>"$OUT"
    STUCK_MSG=$(yq eval '.Object.status.lcmOperationStuckMessage // .status.lcmOperationStuckMessage' "$MOS_OSD" 2>/dev/null)
    if [[ -n "$STUCK_MSG" && "$STUCK_MSG" != "null" ]]; then
      echo "  lcmOperationStuckMessage: $STUCK_MSG" >>"$OUT"
    fi
  fi
  echo -e "\n## OpenStackDeploymentStatus Details:" >>"$OUT"
  find "$MOS_DIR" -path "*/lcm.mirantis.com/openstackdeploymentstatus/*.yaml" 2>/dev/null | while read -r f; do
    echo "### File: $f" >>"$OUT"
    yq eval '.Object.status // .status' "$f" 2>/dev/null >>"$OUT"
  done
  echo -e "\n## Node Conditions:" >>"$OUT"
  grep "/core/nodes" "$LOGPATH/files" | grep "$MOS_DIR" | while read -r nf; do
    N_NAME=$(basename "$nf" .yaml)
    READY=$(yq eval '.Object.status.conditions[] | select(.type=="Ready") | .status' "$nf" 2>/dev/null)
    printf "Node: %-50s | Ready: %s\n" "$N_NAME" "${READY:-Unknown}" >>"$OUT"
  done
fi

# MOS Events
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_events.yaml"
  echo "Gathering MOS events..."
  echo "################# [MOS EVENTS (WARNING+ERRORS)] #################" >"$OUT"
  printf '# ' >>"$OUT"
  ls "$MOS_DIR/objects/events.log" 2>/dev/null >>"$OUT"
  grep -E "Warning|Error" "$MOS_DIR/objects/events.log" 2>/dev/null | sort >>"$OUT"
fi

# MCC Cluster
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_cluster.yaml"
  echo "Gathering MCC cluster details..."
  echo "################# [MCC CLUSTER DETAILS] #################" >"$OUT"
  if [[ -f "$MCC_YAML" ]]; then
    echo "# [FILE]: $MCC_YAML" >>"$OUT"
    yq eval '.Object.status // .status' "$MCC_YAML" 2>/dev/null >>"$OUT"
  fi
  LCM_MCC=$(find "$MCC_DIR" -path "*/lcm.mirantis.com/lcmclusters/*.yaml" | head -n 1)
  if [[ -f "$LCM_MCC" ]]; then
    echo -e "\n# [FILE]: $LCM_MCC" >>"$OUT"
    yq eval '.Object.status // .status' "$LCM_MCC" 2>/dev/null >>"$OUT"
    STUCK_MSG=$(yq eval '.Object.status.lcmOperationStuckMessage // .status.lcmOperationStuckMessage' "$LCM_MCC" 2>/dev/null)
    [[ -n "$STUCK_MSG" && "$STUCK_MSG" != "null" ]] && echo "  lcmOperationStuckMessage: $STUCK_MSG" >>"$OUT"
  fi
  echo -e "\n## LCM Controller Logs (Errors/Warnings):" >>"$OUT"
  find "$MCC_DIR" -path "*/kaas/core/pods/lcm-lcm-controller-*/controller.log" | sort | while read -r log; do
    echo "### Pod: /${log#./}" >>"$OUT"
    grep -Ei "error|fail|warning|warn" "$log" | tail -n 10 >>"$OUT"
  done
fi

# MCC Events
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_events.yaml"
  echo "Gathering MCC events..."
  echo "################# [MCC EVENTS (WARNING+ERRORS)] #################" >"$OUT"
  printf '# ' >>"$OUT"
  ls "$MCC_DIR/objects/events.log" 2>/dev/null >>"$OUT"
  grep -E "Warning|Error" "$MCC_DIR/objects/events.log" 2>/dev/null | sort >>"$OUT"
fi

# Stacklight (Patroni)
if [[ -d "$MCC_DIR/objects/namespaced/stacklight" ]]; then
  OUT="$LOGPATH/mcc_stacklight.yaml"
  echo "Gathering MCC Stacklight details..."
  echo "################# [MCC STACKLIGHT & PATRONI DETAILS] #################" >"$OUT"
  echo "## Patroni Cluster Status:" >>"$OUT"
  find "$MCC_DIR" -path "*/stacklight/core/pods/patroni-*.yaml" 2>/dev/null | sort | while read -r pf; do
    P_STATUS=$(yq eval '.Object.metadata.annotations.status // .metadata.annotations.status' "$pf" 2>/dev/null)
    if [[ -n "$P_STATUS" && "$P_STATUS" != "null" ]]; then
       ROLE=$(echo "$P_STATUS" | grep -oE '"role":"[^"]+"' | cut -d'"' -f4)
       STATE=$(echo "$P_STATUS" | grep -oE '"state":"[^"]+"' | cut -d'"' -f4)
       printf "Pod: %-25s | Role: %-10s | State: %s\n" "$(basename "$pf" .yaml)" "$ROLE" "$STATE" >>"$OUT"
    fi
  done
fi

# Credentials
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_credentials.yaml"
  echo "Scanning MCC Secrets for Credentials..."
  echo "################# [MCC CREDENTIALS (DECRYPTED)] #################" >"$OUT"
  find "$MCC_DIR" -path "*/core/secrets/*.yaml" -type f | while read -r f; do
    DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
    KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$f" 2>/dev/null)
    FILE_BUF=""
    for KEY in $KEYS; do
      if [[ "$KEY" =~ user|pass|login|account|creds|secret|token|key ]]; then
        VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$f" 2>/dev/null)
        DECODED=$(echo "$VAL" | base64 -d 2>/dev/null)
        if [[ -n "$DECODED" && ! "$DECODED" =~ [^[:print:][:space:]] ]]; then
           FILE_BUF+=$(printf "🔑 %-30s : %s\n" "$KEY" "$DECODED")
        fi
      fi
    done
    if [[ -n "$FILE_BUF" ]]; then
       echo "----------------------------------------------------" >>"$OUT"
       echo "## File: $f" >>"$OUT"
       echo -e "$FILE_BUF" >>"$OUT"
    fi
  done
fi

# --- HELPER: FORMAT POD LINE (macOS) ---
get_age() {
  local f="$1"
  local CREATED=$(yq eval '.Object.metadata.creationTimestamp // .metadata.creationTimestamp' "$f" 2>/dev/null)
  local AGE="N/A"
  if [[ -n "$CREATED" && "$CREATED" != "null" ]]; then
    local NOW_SEC=$(date +%s)
    local CREATED_SEC=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED" +%s 2>/dev/null)
    if [[ -n "$CREATED_SEC" ]]; then
      local DIFF=$((NOW_SEC - CREATED_SEC))
      if [ $DIFF -lt 0 ]; then DIFF=0; fi
      if [ $DIFF -ge 86400 ]; then AGE="$((DIFF / 86400))d"
      elif [ $DIFF -ge 3600 ]; then AGE="$((DIFF / 3600))h"
      elif [ $DIFF -ge 60 ]; then AGE="$((DIFF / 60))m"
      else AGE="${DIFF}s"; fi
    fi
  fi
  echo "$AGE"
}

get_pod_line() {
  local f="$1"
  local NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f" 2>/dev/null)
  local NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
  local PHASE=$(yq eval '.Object.status.phase // .status.phase' "$f" 2>/dev/null)
  local RESTARTS=$(yq eval '.Object.status.containerStatuses[].restartCount' "$f" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
  local AGE=$(get_age "$f")
  local NODE=$(yq eval '.Object.spec.nodeName // .spec.nodeName' "$f" 2>/dev/null)
  printf "%-25s %-50s %-15s %-10s %-10s %-25s\n" "$NS" "$NAME" "$PHASE" "$RESTARTS" "$AGE" "$NODE"
}

# Pod Audit
for CL_DIR in "$MCC_DIR" "$MOS_DIR"; do
  [[ -z "$CL_DIR" || ! -d "$CL_DIR" ]] && continue
  CL_TYPE=$(basename "$CL_DIR" | tr '[:lower:]' '[:upper:]')
  OUT="$LOGPATH/${CL_TYPE,,}_pods.yaml"
  echo "Auditing $CL_TYPE Pods..."
  echo "################# [$CL_TYPE POD STATUS] #################" >"$OUT"
  HEADER=$(printf "%-25s %-50s %-15s %-10s %-10s %-25s\n" "NAMESPACE" "NAME" "PHASE" "RESTARTS" "AGE" "NODE")
  echo "$HEADER" >>"$OUT"
  find "$CL_DIR" -path "*/core/pods/*.yaml" -type f | while read -r f; do
    get_pod_line "$f" >>"$OUT"
  done
done

# --- EXECUTIVE SUMMARY ---
echo "Generating Summary..."
OUT="$LOGPATH/summary.yaml"
echo "################# [EXECUTIVE SUMMARY & CRITICAL FINDINGS] #################" >"$OUT"
echo "## 🚀 CLUSTER STATUS:" >>"$OUT"
[[ -f "$LOGPATH/mcc_cluster.yaml" ]] && grep "lcmOperationStuckMessage:" "$LOGPATH/mcc_cluster.yaml" -A 2 >>"$OUT"
[[ -f "$LOGPATH/mos_cluster.yaml" ]] && grep "lcmOperationStuckMessage:" "$LOGPATH/mos_cluster.yaml" -A 2 >>"$OUT"

echo -e "\n## 🖥️  NODE STATUS SUMMARY (Non-Ready):" >>"$OUT"
grep -h "|" "$LOGPATH"/*_cluster.yaml 2>/dev/null | grep -v "Ready: True" | grep "Node: " | sort | uniq -c >>"$OUT"

echo -e "\n## ⚠️  POD FAILURES (Top 10 Restarts):" >>"$OUT"
grep -h "|" "$LOGPATH"/*_pods.yaml 2>/dev/null | awk '$4 > 0' | sort -k4 -nr | head -n 10 >>"$OUT"

echo -e "\n## 🔍 TOP ERRORS & BLOCKERS:" >>"$OUT"
grep -hEi "error|fail|denied|forbidden|context deadline exceeded" "$LOGPATH"/*.yaml 2>/dev/null | sort | uniq -c | sort -nr | head -n 10 >>"$OUT"

# --- FINAL DASHBOARD ASSEMBLY ---
for yaml_file in $(ls "$LOGPATH"/*.yaml 2>/dev/null | sort); do
    TITLE=$(basename "$yaml_file" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    ANCHOR=$(echo "$TITLE" | tr ' ' '-')
    
    # Sidebar entry
    CATEGORY="cluster"
    [[ "$TITLE" == *SUMMARY* ]] && CATEGORY="all"
    [[ "$TITLE" == MCC* ]] && CATEGORY="mcc"
    [[ "$TITLE" == MOS* ]] && CATEGORY="mos"
    echo "<li data-category='$CATEGORY'><a href='javascript:void(0)' onclick=\"toggleCard(this, '$ANCHOR')\">$TITLE</a></li>" >>"$HTML_REPORT"
done

printf "\n</ul>\n</nav>\n<main class=\"main-content\">\n" >>"$HTML_REPORT"
cat <<EOF >>"$HTML_REPORT"
<button class="toggle-sidebar-btn" onclick="toggleSidebar()" title="Toggle Sidebar">◀</button>
<div class="header" style="display: flex; justify-content: space-between;">
    <div>
        <h1>Myrha Dashboard</h1>
        <p><strong>MCC:</strong> ${MCCNAME:-N/A}$MCC_VER_STR | <strong>MOS:</strong> ${MOSNAME:-N/A}$MOS_VER_STR</p>
    </div>
    <div style="text-align: right; font-size: 0.8rem;">
        $MCC_LINKS_HTML
        $MOS_LINKS_HTML
    </div>
</div>
<div id="placeholder" class="placeholder-msg">
    <h2>Select a section</h2>
    <p>Choose one or more sections from the sidebar to analyze the dump.</p>
</div>
EOF

for yaml_file in $(ls "$LOGPATH"/*.yaml 2>/dev/null | sort); do
    TITLE=$(basename "$yaml_file" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    ANCHOR=$(echo "$TITLE" | tr ' ' '-')
    {
      echo "<div class='card' id='$ANCHOR'>"
      echo "  <h2>$TITLE"
      echo "    <div class='card-header-actions'>"
      echo "      <div class='search-nav-container'>"
      echo "        <input type='text' class='card-search' placeholder='Search...' onkeyup=\"performSearch('$ANCHOR', this.value)\">"
      echo "        <span class='btn-tool' onclick=\"navigateSearch('$ANCHOR', 'prev')\">▲</span>"
      echo "        <span class='btn-tool' onclick=\"navigateSearch('$ANCHOR', 'next')\">▼</span>"
      echo "        <span class='search-count'>0/0</span>"
      echo "      </div>"
      echo "      <span class='btn-tool' onclick=\"scrollToLimit('$ANCHOR', 'top')\">Top</span>"
      echo "      <span class='btn-tool' onclick=\"scrollToLimit('$ANCHOR', 'bottom')\">Bottom</span>"
      echo "      <span class='btn-tool' onclick=\"toggleFullScreen(this, '$ANCHOR')\">Full Screen</span>"
      echo "      <span class='btn-tool btn-copy' onclick=\"copyToClipboard(this, '$ANCHOR')\">Copy</span>"
      echo "      <span class='btn-tool wrap-btn' onclick=\"toggleBlockWrap(this, '$ANCHOR')\">Wrap: OFF</span>"
      echo "      <span class='btn-tool btn-close' onclick=\"closeCard('$ANCHOR')\">✖</span>"
      echo "    </div>"
      echo "  </h2>"
      echo "  <pre class='language-yaml raw-code'><code>"
      sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$yaml_file"
      echo "  </code></pre>"
      echo "</div>"
    } >>"$HTML_REPORT"
done

cat <<EOF >>"$HTML_REPORT"
</main>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-yaml.min.js"></script>
<script>
    window.onload = () => {
        const summaryLink = Array.from(document.querySelectorAll('#sidebarList a')).find(a => a.innerText.includes('SUMMARY'));
        if (summaryLink) toggleCard(summaryLink, 'EXECUTIVE-SUMMARY-&-CRITICAL-FINDINGS');
    };
</script>
</body>
</html>
EOF

echo "✅ Dashboard ready: $HTML_REPORT"
open "$HTML_REPORT" 2>/dev/null
