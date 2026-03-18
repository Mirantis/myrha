#!/bin/bash
# Check if running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "ERROR: This script MUST be run with bash. Please run it as: bash $0"
    exit 1
fi

# Declare variables
DATE=$(date +"%d-%m-%Y-%H-%M-%S")
GREP="grep --color=auto"
LOGPATH=myrha
HTML_REPORT="$LOGPATH/report_$DATE.html"
FULL_CWD=$(pwd)
mkdir $LOGPATH 2>/dev/null
rm -f "$LOGPATH"/* 2>/dev/null

# macOS Package Installation (Homebrew)
for cmd in rg nvim subl yq bc; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Installing $cmd..."
    brew install "$cmd" 2>/dev/null
  fi
done

# --- HTML Initialization ---
cat <<'EOF' >"$HTML_REPORT"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Mirantis Audit Report</title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css" rel="stylesheet" />
<style>
    :root { 
        --primary: #24292e;   /* Modern Charcoal */
        --accent: #3498db; 
        --bg: #f4f7f6; 
        --text: #333; 
        --sidebar-width: 300px;
        --sidebar-link: #ffffff;
        --sidebar-hover: #3498db;
        --danger: #e74c3c;
    }
    body { font-family: 'Segoe UI', sans-serif; background: var(--bg); color: var(--text); margin: 0; display: flex; min-height: 100vh; transition: all 0.3s; }
    /* Sidebar Styling */
    .sidebar { 
        width: var(--sidebar-width); height: 100vh; background: var(--primary); 
        color: white; position: sticky; top: 0; overflow-y: auto; padding: 20px; 
        box-sizing: border-box; flex-shrink: 0; border-right: 1px solid rgba(0,0,0,0.1); 
        transition: margin-left 0.3s; 
    }
    body.sidebar-hidden .sidebar { margin-left: calc(var(--sidebar-width) * -1); }
    .search-box {
        width: 100%; padding: 10px; border-radius: 6px; border: 1px solid rgba(255,255,255,0.1);
        margin-bottom: 20px; background: rgba(255,255,255,0.05); color: white;
        font-size: 0.85rem; outline: none; transition: 0.2s;
    }
    .search-box:focus { background: rgba(255,255,255,0.15); border-color: var(--accent); }
    .sidebar h3 { border-bottom: 2px solid var(--accent); padding-bottom: 10px; font-size: 1.1rem; margin-top: 0; color: white; }
    .sidebar ul { list-style: none; padding: 0; }
    .sidebar a { 
        color: var(--sidebar-link); text-decoration: none; font-size: 0.85rem; 
        display: block; padding: 8px 12px; border-radius: 4px; transition: 0.2s; margin-bottom: 2px;
    }
    .sidebar a:hover { background: rgba(255, 255, 255, 0.1); color: var(--sidebar-hover); padding-left: 15px; }
    .sidebar li.hidden { display: none; }
    .sidebar a.active { background: var(--accent); color: white; font-weight: bold; }
    .main-content { flex: 1; padding: 40px; box-sizing: border-box; overflow-x: hidden; transition: width 0.3s; position: relative; }
    .placeholder-msg { 
        text-align: center; margin-top: 100px; color: #666; font-size: 1.2rem; 
        padding: 40px; border: 2px dashed #ccc; border-radius: 12px;
    }
    .header { background: white; padding: 25px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); margin-bottom: 30px; border-left: 8px solid var(--accent); position: relative; }
    .toggle-sidebar-btn { 
        position: fixed; left: 275px; top: 20px; 
        background: var(--accent); color: white; border: none; 
        width: 35px; height: 35px; border-radius: 8px; cursor: pointer; 
        box-shadow: 0 2px 10px rgba(0,0,0,0.3); z-index: 1100; 
        font-weight: bold; transition: all 0.3s;
        display: flex; align-items: center; justify-content: center;
    }
    body.sidebar-hidden .toggle-sidebar-btn { left: 15px; transform: rotate(180deg); }
    /* Card Styling */
    .card { 
        display: none; /* Hidden by default */
        background: white; 
        border-radius: 12px; 
        padding: 25px; 
        margin-bottom: 35px; 
        box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); 
        min-height: 200px; 
        border-left: 5px solid transparent; 
    }
    .card.visible { display: block; }
    /* Alert Card Highlight - Targets the summary card specifically */
    .card[id*="CERTIFICATE-ALERTS"] { border-left: 8px solid var(--danger); background: #fffcfc; }
    .card[id*="CERTIFICATE-ALERTS"] h2 { color: var(--danger); }
    h2 { color: var(--primary); margin: 0 0 15px 0; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #eee; padding-bottom: 10px; }
    .card-header-actions { display: flex; align-items: center; gap: 8px; }
    .btn-tool {
        font-size: 0.7rem; background: #eee; color: #666; 
        padding: 4px 10px; border-radius: 4px; border: 1px solid #ddd;
        cursor: pointer; transition: 0.2s; font-weight: bold; user-select: none;
        text-decoration: none; display: inline-block;
    }
    .btn-tool:hover { background: #e0e0e0; border-color: #ccc; color: #333; }
    .btn-tool.active { background: var(--accent); color: white; border-color: var(--accent); }
    .btn-copy.success { background: #27ae60 !important; color: white !important; border-color: #2ecc71 !important; }
    .btn-close:hover { background: #e74c3c !important; color: white !important; border-color: #c0392b !important; }
    .card-search {
        font-size: 0.75rem; padding: 4px 10px; border-radius: 4px; border: 1px solid #ddd;
        outline: none; width: 120px; transition: 0.3s; margin-right: 5px;
    }
    .card-search:focus { border-color: var(--accent); width: 180px; box-shadow: 0 0 5px rgba(52, 152, 219, 0.3); }
    mark { background: #ffeb3b; color: black; border-radius: 2px; padding: 0 2px; }
    mark.current { background: #ff9800; font-weight: bold; outline: 2px solid #e65100; }
    .search-nav-container { display: inline-flex; align-items: center; }
    .search-count { font-size: 0.7rem; color: #666; margin: 0 5px; min-width: 35px; text-align: center; }
    .back-to-top { 
        font-size: 0.7rem; background: var(--accent); color: white !important; 
        padding: 5px 10px; border-radius: 4px; text-decoration: none !important; font-weight: bold;
    }
    /* Full Screen Card Logic */
    .card.fullscreen {
        position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
        z-index: 3000; margin: 0; border-radius: 0; overflow-y: auto;
        box-sizing: border-box; background: white;
    }
    .card.fullscreen .back-to-top { display: none; }
    body.has-fullscreen { overflow: hidden; }
    .card.fullscreen pre { max-height: calc(100vh - 120px); }

    pre[class*="language-"] { max-height: 500px; border-radius: 8px; }
    pre[class*="language-"].raw-code { white-space: pre !important; word-break: normal !important; overflow-x: auto !important; }
    pre[class*="language-"].wrapped-code { white-space: pre-wrap !important; word-break: break-all !important; overflow-x: hidden !important; }
    pre[class*="language-"] code { white-space: inherit !important; word-break: inherit !important; }
    .card { scroll-margin-top: 20px; }
    /* Sidebar Filter Tabs */
    .filter-tabs { display: flex; gap: 5px; margin-bottom: 15px; }
    .filter-btn { 
        flex: 1; padding: 6px; font-size: 0.75rem; background: rgba(255,255,255,0.1); 
        color: white; border: 1px solid rgba(255,255,255,0.2); border-radius: 4px; 
        cursor: pointer; transition: 0.2s; 
    }
    .filter-btn:hover { background: rgba(255,255,255,0.2); }
    .filter-btn.active { background: var(--accent); border-color: var(--accent); }
    
    .analyzed-files-wrapper {
        margin-bottom: 15px; padding: 10px; background: #f8f9fa; border-radius: 6px; border: 1px solid #e9ecef; font-size: 0.85rem;
        position: relative;
    }
    .analyzed-files-container {
        max-height: 1.5rem; overflow: hidden; transition: max-height 0.3s ease;
        padding-right: 80px; /* Space for the more button */
    }
    .analyzed-files-container.expanded { max-height: 1000px; padding-right: 0; }
    .more-files-btn {
        position: absolute; right: 10px; top: 8px; 
        background: #eee; border: 1px solid #ccc; border-radius: 4px; 
        padding: 2px 8px; font-size: 0.7rem; cursor: pointer; color: #666;
        font-weight: bold; transition: 0.2s;
    }
    .more-files-btn:hover { background: #ddd; color: #333; }
</style>
<script>
    function toggleSidebar() {
        document.body.classList.toggle('sidebar-hidden');
    }
    function toggleAnalyzedFiles(btn) {
        const container = btn.previousElementSibling;
        const isExpanded = container.classList.toggle('expanded');
        btn.innerText = isExpanded ? 'less' : 'more...';
        if (isExpanded) {
            btn.style.position = 'static';
            btn.style.display = 'block';
            btn.style.marginTop = '10px';
            btn.style.width = 'fit-content';
        } else {
            btn.style.position = 'absolute';
            btn.style.display = 'inline';
            btn.style.marginTop = '0';
        }
    }
    let currentFilter = 'all';
    function filterType(type) {
        currentFilter = type;
        document.querySelectorAll('.filter-btn').forEach(btn => {
            const match = btn.getAttribute('onclick').match(/'([^']+)'/);
            if (match) {
                btn.classList.toggle('active', match[1] === type);
            }
        });
        applyFilters();
    }
    function filterSidebar() {
        applyFilters();
    }
    function applyFilters() {
        const query = document.getElementById('sidebarSearch').value.toLowerCase();
        const items = document.querySelectorAll('#sidebarList li');
        items.forEach(item => {
            const text = item.innerText.toLowerCase();
            const category = item.dataset.category;
            const matchesSearch = text.includes(query);
            const matchesFilter = currentFilter === 'all' || category === currentFilter || category === 'cluster' || category === 'all';
            item.classList.toggle('hidden', !matchesSearch || !matchesFilter);
        });
    }
    function toggleCard(link, anchor) {
        const card = document.getElementById(anchor);
        const isActive = link.classList.toggle('active');
        card.classList.toggle('visible', isActive);
        
        // Lazy load highlighting
        if (isActive && !card.dataset.highlighted) {
            const codeBlock = card.querySelector('pre code');
            if (codeBlock) {
                Prism.highlightElement(codeBlock);
                card.dataset.highlighted = "true";
            }
        }
        
        const placeholder = document.getElementById('placeholder');
        const visibleCards = document.querySelectorAll('.card.visible').length;
        placeholder.style.display = visibleCards > 0 ? 'none' : 'block';
    }
    function clearAllCards() {
        document.querySelectorAll('.sidebar li a.active').forEach(link => link.classList.remove('active'));
        document.querySelectorAll('.card.visible').forEach(card => card.classList.remove('visible'));
        document.getElementById('placeholder').style.display = 'block';
    }
    function closeCard(anchor) {
        const card = document.getElementById(anchor);
        card.classList.remove('visible');
        document.querySelectorAll('.sidebar li a').forEach(link => {
            if (link.getAttribute('onclick').includes(`'${anchor}'`)) {
                link.classList.remove('active');
            }
        });
        const placeholder = document.getElementById('placeholder');
        const visibleCards = document.querySelectorAll('.card.visible').length;
        placeholder.style.display = visibleCards > 0 ? 'none' : 'block';
    }
    function toggleBlockWrap(btn, anchor) {
        const card = document.getElementById(anchor);
        const codeBlock = card.querySelector('pre');
        codeBlock.classList.toggle('wrapped-code');
        codeBlock.classList.toggle('raw-code');
        btn.classList.toggle('active');
        btn.innerText = codeBlock.classList.contains('wrapped-code') ? 'Wrap: ON' : 'Wrap: OFF';
    }
    async function copyToClipboard(btn, anchor) {
        const card = document.getElementById(anchor);
        const code = card.querySelector('code').innerText;
        try {
            await navigator.clipboard.writeText(code);
            const originalText = btn.innerText;
            btn.innerText = 'Copied!';
            btn.classList.add('success');
            setTimeout(() => {
                btn.innerText = originalText;
                btn.classList.remove('success');
            }, 2000);
        } catch (err) { console.error('Copy failed:', err); }
    }
    function toggleFullScreen(btn, anchor) {
        const card = document.getElementById(anchor);
        const isFS = card.classList.toggle('fullscreen');
        document.body.classList.toggle('has-fullscreen', isFS);
        btn.innerText = isFS ? 'Exit Full Screen' : 'Full Screen';
        btn.classList.toggle('active', isFS);
    }
    function scrollToLimit(anchor, limit) {
        const card = document.getElementById(anchor);
        const pre = card.querySelector('pre');
        if (pre) {
            pre.scrollTo({
                top: limit === 'top' ? 0 : pre.scrollHeight,
                behavior: 'smooth'
            });
        }
    }
    const searchStates = {};
    const searchDebounce = {};

    function performSearch(anchor, query) {
        clearTimeout(searchDebounce[anchor]);
        searchDebounce[anchor] = setTimeout(() => executeSearch(anchor, query), 300);
    }

    function executeSearch(anchor, query) {
        const card = document.getElementById(anchor);
        const code = card.querySelector('code');
        const counter = card.querySelector('.search-count');
        const instance = new Mark(code);
        
        searchStates[anchor] = { index: -1, marks: [] };
        instance.unmark({
            done: function() {
                if (query.length >= 2) {
                    instance.mark(query, {
                        "accuracy": "partially",
                        "separateWordSearch": false,
                        "acrossElements": true,
                        done: function() {
                            const found = card.querySelectorAll('mark');
                            searchStates[anchor].marks = found;
                            if (found.length > 0) {
                                searchStates[anchor].index = 0;
                                navigateSearch(anchor, 0);
                            } else {
                                counter.innerText = "0/0";
                            }
                        }
                    });
                } else {
                    counter.innerText = "0/0";
                }
            }
        });
    }
    function navigateSearch(anchor, direction) {
        const state = searchStates[anchor];
        if (!state || state.marks.length === 0) return;

        state.marks.forEach(m => m.classList.remove('current'));
        
        if (direction === 'next') {
            state.index = (state.index + 1) % state.marks.length;
        } else if (direction === 'prev') {
            state.index = (state.index - 1 + state.marks.length) % state.marks.length;
        } else {
            state.index = direction; // Absolute index
        }

        const currentMark = state.marks[state.index];
        currentMark.classList.add('current');
        currentMark.scrollIntoView({ behavior: 'smooth', block: 'center' });
        
        const card = document.getElementById(anchor);
        card.querySelector('.search-count').innerText = `${state.index + 1}/${state.marks.length}`;
    }
</script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/mark.js/8.11.1/mark.min.js"></script>
</head>
<body>
    <nav class="sidebar">
        <h3>AUDIT SECTIONS</h3>
        <div class="filter-tabs">
            <button class="filter-btn active" onclick="filterType('all')">Both</button>
            <button class="filter-btn" onclick="filterType('mcc')">MCC</button>
            <button class="filter-btn" onclick="filterType('mos')">MOS</button>
            <button class="filter-btn" onclick="clearAllCards()" style="background: rgba(255, 69, 58, 0.2); border-color: rgba(255, 69, 58, 0.4);">Clear All</button>
        </div>
        <input type="text" class="search-box" id="sidebarSearch" placeholder="Filter sections..." onkeyup="filterSidebar()">
        <ul id="sidebarList">
EOF
# --- KNOWN ISSUES AUTO-DIAGNOSTIC ---
check_known_issues() {
  local MOS_VER_RAW="$1"
  local MCC_VER_RAW="$2"
  local OUT="$LOGPATH/cluster_known_issues"
  
  # Extract versions
  local MOS_VER="0.0.0"
  if [[ "$MOS_VER_RAW" =~ ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+(\.[0-9]+)*) ]]; then
      MOS_VER="${BASH_REMATCH[2]}"
  elif [[ "$MOS_VER_RAW" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
      MOS_VER="${BASH_REMATCH[1]}"
  fi

  local MCC_VER="$MCC_VER_RAW"
  [[ -z "$MCC_VER" || "$MCC_VER" == "0.0.0" ]] && if [[ -f "$LOGPATH/mcc_upgrade_audit.yaml" ]]; then
    MCC_VER=$(grep "KaaS Release:" "$LOGPATH/mcc_upgrade_audit.yaml" | awk '{print $NF}' | sed 's/kaas-//' | tr '-' '.')
  fi
  [[ -z "$MCC_VER" ]] && MCC_VER="0.0.0"

  echo "Running Version-Specific Known Issues Diagnostic..."
  echo "MOS Version: $MOS_VER, MCC Version: $MCC_VER"
  
  echo "################# [CLUSTER KNOWN ISSUES AUTO-DIAGNOSTIC] #################" >"$OUT"
  echo "MOS Version: $MOS_VER" >>"$OUT"
  echo "MCC Version: $MCC_VER" >>"$OUT"
  echo "----------------------------------------------------" >>"$OUT"

  # Define issues as: ID | Product (MOS/MCC/ALL) | MinVer | MaxVer | Title | Pattern | SearchPath | URL
  ISSUES=(
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-49078 | MOS | 0.0.0 | 25.1 | [49078] Migration to containerd is stuck due to orphaned Docker containers | Orphaned Docker containers found after migration. Unable to proceed, please | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-47695 | MOS | 0.0.0 | 25.1.1 | [47695] Cinder database sync job fails during upgrade from Antelope to Caracal | <TIMESTAMP> 1 ERROR cinder pymysql.err.DataError: (1265, "Data truncated for column '\''use_quota'\'' at row 24") | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3.5 | 24.3.5 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3.5 | 24.3.5 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-49078 | MOS | 0.0.0 | 25.1 | [49078] Migration to containerd is stuck due to orphaned Docker containers | Orphaned Docker containers found after migration. Unable to proceed, please | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3.7 | 24.3.7 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3.7 | 24.3.7 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-47695 | MOS | 0.0.0 | 25.1.1 | [47695] Cinder database sync job fails during upgrade from Antelope to Caracal | <TIMESTAMP> 1 ERROR cinder pymysql.err.DataError: (1265, "Data truncated for column '\''use_quota'\'' at row 24") | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3.2 | 24.3.2 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3.2 | 24.3.2 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-49078 | MOS | 0.0.0 | 25.1 | [49078] Migration to containerd is stuck due to orphaned Docker containers | Orphaned Docker containers found after migration. Unable to proceed, please | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-49078 | MOS | 0.0.0 | 25.1 | [49078] Migration to containerd is stuck due to orphaned Docker containers | Orphaned Docker containers found after migration. Unable to proceed, please | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-47695 | MOS | 0.0.0 | 25.1.1 | [47695] Cinder database sync job fails during upgrade from Antelope to Caracal | <TIMESTAMP> 1 ERROR cinder pymysql.err.DataError: (1265, "Data truncated for column '\''use_quota'\'' at row 24") | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3.3 | 24.3.3 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3.3 | 24.3.3 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-49078 | MOS | 0.0.0 | 25.1 | [49078] Migration to containerd is stuck due to orphaned Docker containers | Orphaned Docker containers found after migration. Unable to proceed, please | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3.6 | 24.3.6 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3.6 | 24.3.6 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-47603 | MOS | 0.0.0 | 24.3.1 | [47603] Masakari fails during the OpenStack upgrade to Caracal | masakari_db_sync: docker-dev-kaas-local.docker.mirantis.net/openstack/masakari:caracal-jammy-20241028141054 | $MOS_DIR/objects'
    'KI-47695 | MOS | 0.0.0 | 25.1.1 | [47695] Cinder database sync job fails during upgrade from Antelope to Caracal | <TIMESTAMP> 1 ERROR cinder pymysql.err.DataError: (1265, "Data truncated for column '\''use_quota'\'' at row 24") | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3 | 24.3 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3 | 24.3 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-47602 | MOS | 0.0.0 | 24.3.1 | [47602] Failed `designate-zone-setup` job blocks cluster update | Client Error for url: http://designate-api.openstack.svc.cluster.local:9001/v2/zones, | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-49078 | MOS | 0.0.0 | 25.1 | [49078] Migration to containerd is stuck due to orphaned Docker containers | Orphaned Docker containers found after migration. Unable to proceed, please | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-47695 | MOS | 0.0.0 | 25.1.1 | [47695] Cinder database sync job fails during upgrade from Antelope to Caracal | <TIMESTAMP> 1 ERROR cinder pymysql.err.DataError: (1265, "Data truncated for column '\''use_quota'\'' at row 24") | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3.4 | 24.3.4 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3.4 | 24.3.4 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-47695 | MOS | 0.0.0 | 25.1.1 | [47695] Cinder database sync job fails during upgrade from Antelope to Caracal | <TIMESTAMP> 1 ERROR cinder pymysql.err.DataError: (1265, "Data truncated for column '\''use_quota'\'' at row 24") | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.3.1 | 24.3.1 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.3.1 | 24.3.1 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-49078 | MOS | 0.0.0 | 25.1 | [49078] Migration to containerd is stuck due to orphaned Docker containers | Orphaned Docker containers found after migration. Unable to proceed, please | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1.3 | 24.1.3 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-39768 | MOS | 0.0.0 | 24.2 | [39768] OpenStack Controller exporter fails to start | OSCTL_EXPORTER_MAX_POLL_TIMEOUT: 900 | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1.1 | 24.1.1 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1.5 | 24.1.5 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.1.5 | 24.1.5 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-42903 | MOS | 0.0.0 | 24.2 | [42903] Inconsistent handling of missing pools by ceph-controller | ceph auth get client.nova -o /tmp/nova.key | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1.6 | 24.1.6 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.1.6 | 24.1.6 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-42903 | MOS | 0.0.0 | 24.2 | [42903] Inconsistent handling of missing pools by ceph-controller | ceph auth get client.nova -o /tmp/nova.key | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1.4 | 24.1.4 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-39768 | MOS | 0.0.0 | 24.2 | [39768] OpenStack Controller exporter fails to start | OSCTL_EXPORTER_MAX_POLL_TIMEOUT: 900 | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1 | 24.1 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1.7 | 24.1.7 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.1.7 | 24.1.7 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-42903 | MOS | 0.0.0 | 24.2 | [42903] Inconsistent handling of missing pools by ceph-controller | ceph auth get client.nova -o /tmp/nova.key | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.1.2 | 24.1.2 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 25.1.1 | 25.1.1 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 25.1.1 | 25.1.1 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-47396 | MOS | 25.1.1 | 25.1.1 | [47396] Exceeding the number of Cassandra tombstone | ALTER TABLE config_db_uuid.obj_uuid_table WITH gc_grace_seconds = 10; | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-47695 | MOS | 0.0.0 | 25.1.1 | [47695] Cinder database sync job fails during upgrade from Antelope to Caracal | <TIMESTAMP> 1 ERROR cinder pymysql.err.DataError: (1265, "Data truncated for column '\''use_quota'\'' at row 24") | $MOS_DIR/objects'
    'KI-13755 | MOS | 25.1 | 25.1 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 25.1 | 25.1 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-47396 | MOS | 25.1 | 25.1 | [47396] Exceeding the number of Cassandra tombstone | ALTER TABLE config_db_uuid.obj_uuid_table WITH gc_grace_seconds = 10; | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'KI-53802,52253 | MOS | 0.0.0 | 25.2 | [53802, 52253] `telegrafDsSmart` causes OOM while scanning remote volumes | telegrafDsSmart: | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.2.2 | 24.2.2 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.2.2 | 24.2.2 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-46220 | MOS | 0.0.0 | 24.2.3 | [46220] ClusterMaintenanceRequest stuck with Tungsten Fabric API v2 | creationTimestamp: "<TIMESTAMP>" | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.2.5 | 24.2.5 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.2.5 | 24.2.5 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-47602 | MOS | 0.0.0 | 24.3.1 | [47602] Failed `designate-zone-setup` job blocks cluster update | Client Error for url: http://designate-api.openstack.svc.cluster.local:9001/v2/zones, | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-45879 | MOS | 0.0.0 | 24.2.1 | [45879] [Antelope] Incorrect packet handling between instance and its gateway | neutron_openvswitch_agent: mirantis.azurecr.io/openstack/neutron:antelope-jammy-20240816113600 | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.2 | 24.2 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-40900 | MOS | 0.0.0 | 24.2.1 | [40900] Cassandra DB infinite table creation/changing state in Tungsten Fabric | Type     Reason     Age                  From     Message | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.2 | 24.2 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.2.1 | 24.2.1 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.2.1 | 24.2.1 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-46220 | MOS | 0.0.0 | 24.2.3 | [46220] ClusterMaintenanceRequest stuck with Tungsten Fabric API v2 | creationTimestamp: "<TIMESTAMP>" | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.2.4 | 24.2.4 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.2.4 | 24.2.4 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-47602 | MOS | 0.0.0 | 24.3.1 | [47602] Failed `designate-zone-setup` job blocks cluster update | Client Error for url: http://designate-api.openstack.svc.cluster.local:9001/v2/zones, | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-13755 | MOS | 24.2.3 | 24.2.3 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 24.2.3 | 24.2.3 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-46671 | MOS | 0.0.0 | 25.1.1 | [46671] Cluster update fails with the `tf-config` pods crashed | tf-config-<ID>                            [0-9]/[0-9]     CrashLoopBackOff   [0-9]+ (<ID> ago)   <ID> | $MOS_DIR/objects'
    'KI-47602 | MOS | 0.0.0 | 24.3.1 | [47602] Failed `designate-zone-setup` job blocks cluster update | Client Error for url: http://designate-api.openstack.svc.cluster.local:9001/v2/zones, | $MOS_DIR/objects'
    'KI-51524 | MOS | 0.0.0 | 24.3.5 | [51524] `sf-notifier` creates big amount of relogins to Salesforce | mirantis.azurecr.io/stacklight/sf-notifier:v0.4-20250113023013 | $MOS_DIR/objects'
    'BUG-8013 | MCC | 2.0.0 | 2.10.0 | [8013] Managed cluster deployment requiring PVs may fail | -o jsonpath='\''{.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}'\'' | $MCC_DIR/objects'
    'BUG-2757 | MCC | 2.0.0 | 2.4.0 | [2757] IAM fails to start during management cluster deployment | -o jsonpath='\''{.data.MYSQL_DBADMIN_PASSWORD}'\'' | base64 -d ; echo | $MCC_DIR/objects'
    'BUG-15698 | MCC | 2.8.0 | 2.11.0 | [15698] VIP is assigned to each manager node instead of a single node | firewall-cmd --add-rich-rule='\''rule protocol value="vrrp" accept'\'' --permanent | $MCC_DIR/objects'
    'BUG-14080 | MCC | 0.0.0 | 0.0.0 | [14080] Node leaves the cluster after IP address change | Error: rpc error: code = Unknown desc = The swarm does not have a leader. | $MCC_DIR/objects'
    'BUG-14458 | MCC | 2.7.0 | 2.9.0 | [14458] Failure to create a container for pod: cannot allocate memory | State:        Waiting | $MCC_DIR/objects'
    'BUG-10424 | MCC | 0.0.0 | 0.0.0 | [10424] Regional cluster cleanup fails by timeout | ./bin/kind delete cluster --name clusterapi | $MCC_DIR/objects'
    'BUG-10050 | MCC | 2.3.0 | 2.11.0 | [10050] Ceph OSD pod is in the CrashLoopBackOff state after disk replacement | ceph auth del osd.<ID> | $MCC_DIR/objects'
    'BUG-13402 | MCC | 2.6.0 | 2.10.0 | [13402] Cluster fails with error: no space left on device | "default-ulimits": { | $MCC_DIR/objects'
    'BUG-13845 | MCC | 2.7.0 | 2.11.0 | [13845] Cluster update fails during the LCM Agent upgrade with x509 error | lcmAgentUpgradeStatus:.*x509: certificate signed by unknown authority | $MCC_DIR/objects'
    'BUG-6066 | MCC | 2.4.0 | 0.0.0 | [6066] Helm releases get stuck in FAILED or UNKNOWN state | finishedAt: "<TIMESTAMP>" | $MCC_DIR/objects'
    'BUG-14125 | MCC | 2.8.0 | 2.10.0 | [14125] Inaccurate nodes readiness status on a managed cluster | ssh -i <sshPrivateKey> root@<controlPlaneNodeIP> | $MCC_DIR/objects'
    'BUG-13292 | MCC | 2.7.0 | 0.0.0 | [13292] Local volume provisioner pod stuck in Terminating status after upgrade | kuebctl -n default delete pod <LVPPodName> --force | $MCC_DIR/objects'
    'BUG-9899 | MCC | 2.3.0 | 2.14.0 | [9899] Helm releases get stuck in PENDING_UPGRADE during cluster update | ./helm --host=localhost:44134 history openstack-operator | $MCC_DIR/objects'
    'BUG-8112 | MCC | 0.0.0 | 0.0.0 | [8112] Nodes occasionally become Not Ready on long-running clusters | ctr -n com.docker.ucp snapshot rm ucp-kubelet | $MCC_DIR/objects'
    'BUG-17792 | MCC | 0.0.0 | 0.0.0 | [17792] Full preflight fails with a timeout waiting for BareMetalHost | preflight check failed: preflight full check failed: | $MCC_DIR/objects'
    'BUG-18962 | MCC | 0.0.0 | 0.0.0 | [18962] Machine provisioning issues during cluster deployment | NAME                STATE       CONSUMER             BOOTMODE ONLINE ERROR REGION | $MCC_DIR/objects'
    'BUG-19737 | MCC | 2.14.0 | 2.15.0 | [19737] The vSphere VM template build hangs with an empty kickstart file | Kickstart file /run/install/ks.cfg is missing | $MCC_DIR/objects'
    'BUG-19468 | MCC | 2.13.0 | 2.15.0 | [19468] '\''Failed to remove finalizer from machine'\'' error during cluster deletion | Failed to remove finalizer from machine ... | $MCC_DIR/objects'
    'BUG-18933 | MCC | 2.14.0 | 2.15.0 | [18933] Alerta pods fail to pass the readiness check | <TIMESTAMP>,865 DEBG '\''nginx'\'' stdout output: | $MCC_DIR/objects'
    'BUG-20312 | MCC | 2.12.0 | 0.0.0 | [20312] Creation of ceph-based PVs gets stuck in *Pending* state | CSI_PROVISIONER_TOLERATIONS: \| | $MCC_DIR/objects'
    'BUG-20298 | MCC | 2.14.0 | 2.15.0 | [20298] Spec validation failing during KaaSCephOperationRequest creation | spec in body should have at most 1 properties | $MCC_DIR/objects'
    'BUG-20455 | MCC | 2.14.0 | 0.0.0 | [20455] Cluster upgrade fails on the LCMMachine CRD update | following error | $MCC_DIR/objects'
    'BUG-4288 | MCC | 0.0.0 | 0.0.0 | [4288] Equinix and MOS managed clusters update failure | ctr -n com.docker.ucp snapshot rm ucp-kubelet | $MCC_DIR/objects'
    'BUG-16379,23865 | MCC | 2.10.0 | 2.19.0 | [16379,23865] Cluster update fails with the FailedMount warning | -o jsonpath='\''{.items[?(@.spec.nodeName == "<nodeName>")].metadata.name}'\'' | $MCC_DIR/objects'
    'BUG-9875 | MCC | 2.3.0 | 2.6.0 | [9875] Full preflight fails with a timeout waiting for BareMetalHost | failed to create BareMetal objects: failed to wait for objects of kinds BareMetalHost | $MCC_DIR/objects'
    'BUG-10060 | MCC | 2.3.0 | 2.7.0 | [10060] Ceph OSD node removal fails | rook-ceph-mon-<ID>                              [0-9]/[0-9]  Running    [0-9]+  <ID> | $MCC_DIR/objects'
    'BUG-9928 | MCC | 2.3.0 | 2.5.0 | [9928] Ceph rebalance during a managed cluster update | ceph osd set noout | $MCC_DIR/objects'
    'BUG-11001 | MCC | 2.4.0 | 2.6.0 | [11001] Patroni pod fails to start | Local timeline=4 lsn=0/A000000 | $MCC_DIR/objects'
    'BUG-11633 | MCC | 2.5.0 | 2.6.0 | [11633] A vSphere-based project cannot be cleaned up | - kaas.mirantis.com/credentials-secret | $MCC_DIR/objects'
    'BUG-11468 | MCC | 2.5.0 | 2.6.0 | [11468] Pods using LVP PV are not mounted to LVP disk | findmnt /mnt/local-volumes/stacklight/elasticsearch-data/vol00 | $MCC_DIR/objects'
    'BUG-10829 | MCC | 2.5.0 | 2.6.0 | [10829] Keycloak pods fail to start during a management cluster bootstrap | -Djboss.as.management.blocking.timeout=<RequiredValue> | $MCC_DIR/objects'
    'BUG-12683 | MCC | 2.6.0 | 2.7.0 | [12683] The kaas-ipam pods restart on the vSphere region with IPAM disabled | Waiting for CRDs. [baremetalhosts.metal3.io clusters.cluster.k8s.io machines.cluster.k8s.io | $MCC_DIR/objects'
    'BUG-13176 | MCC | 2.6.0 | 2.7.0 | [13176] ClusterNetwork settings may disappear from the cluster provider spec | version: 1.18.3 | $MCC_DIR/objects'
    'BUG-13078 | MCC | 2.6.0 | 2.7.0 | [13078] Elasticsearch does not receive data from Fluentd | curl -XPUT -H "content-type: application/json" | $MCC_DIR/objects'
    'BUG-8367 | MCC | 2.9.0 | 2.12.0 | [8367] Adding of a new manager node to a managed cluster hangs on Deploy stage | Status code was -1 and not [200]: Request failed: <urlopen error [Errno 111] Connection refused> | $MCC_DIR/objects'
    'BUG-16718 | MCC | 2.10.0 | 2.12.0 | [16718] Equinix Metal provider fails to create machines with SSH keys error | Failed to create machine "kaas-mgmt-controlplane-0"... | $MCC_DIR/objects'
    'BUG-16959 | MCC | 2.11.0 | 2.12.0 | [16959] Proxy-based regional cluster creation fails | ./bootstrap.sh deploy_regional | $MCC_DIR/objects'
    'BUG-16146 | MCC | 0.0.0 | 0.0.0 | [16146] Stuck kubelet on the Cluster release 5.x.x series | an error on the server ("") has prevented the request from succeeding | $MCC_DIR/objects'
    'BUG-16843 | MCC | 2.10.0 | 2.12.0 | [16843] Inability to override default route matchers for Salesforce notifier | Warning: Merging destination map for chart '\''stacklight'\''. Overwriting table | $MCC_DIR/objects'
    'BUG-17771 | MCC | 2.10.0 | 2.13.0 | [17771] Watchdog alert missing in Salesforce route | Warning: Merging destination map for chart '\''stacklight'\''. Overwriting table | $MCC_DIR/objects'
    'BUG-16873 | MCC | 2.10.0 | 2.12.0 | [16873] Bootstrap fails with '\''failed to establish connection with tiller'\'' error | clusterdeployer.go:164] Initialize Tiller in bootstrap cluster. | $MCC_DIR/objects'
    'BUG-17477 | MCC | 2.11.0 | 2.12.0 | [17477] StackLight in HA mode is not deployed or cluster update is blocked | cluster release version upgrade is forbidden: | $MCC_DIR/objects'
    'BUG-17412 | MCC | 2.11.0 | 0.0.0 | [17412] Cluster upgrade fails on the KaaSCephCluster CRD update | Upgrade "kaas-public-api" failed: | $MCC_DIR/objects'
    'BUG-17069 | MCC | 2.11.0 | 2.12.0 | [17069] Cluster upgrade fails with the '\''Failed to configure Ceph cluster'\'' error | - message: '\''Failed to configure Ceph cluster: ceph cluster verification is failed: | $MCC_DIR/objects'
    'BUG-17007 | MCC | 2.11.0 | 2.12.0 | [17007] False-positive '\''release: "squid-proxy" not found'\'' error | Helm charts not installed yet: squid-proxy | $MCC_DIR/objects'
    'BUG-16964 | MCC | 2.11.0 | 2.12.0 | [16964] Management cluster upgrade gets stuck | mons are allowing insecure global_id reclaim | $MCC_DIR/objects'
    'BUG-18076 | MCC | 2.11.0 | 2.13.0 | [18076] StackLight update failure | Upgrade "stacklight" failed: Job.batch "stacklight-delete-logging-pvcs-*" is invalid: spec.template: Invalid value: ... | $MCC_DIR/objects'
    'BUG-16233 | MCC | 2.10.0 | 2.11.0 | [16233] Bare metal pods fail during upgrade due to Ceph not unmounting RBD | NAME                              READY   UP-TO-DATE   AVAILABLE   AGE | $MCC_DIR/objects'
    'BUG-15766 | MCC | 2.10.0 | 2.11.0 | [15766] Cluster upgrade failure | error when evicting pods/"patroni-12-2" -n "stacklight" (will retry after 5s): | $MCC_DIR/objects'
    'BUG-18752 | MCC | 0.0.0 | 0.0.0 | [18752] Bare metal hosts in '\''provisioned registration error'\'' state after update | errorMessage: '\''Host adoption failed: Error while attempting to adopt node  <UUID>: | $MCC_DIR/objects'
    'BUG-18708 | MCC | 2.13.0 | 2.14.0 | [18708] '\''Pending'\'' state of machines during a cluster deployment or attachment | - lastTransitionTime: "<TIMESTAMP>" | $MCC_DIR/objects'
    'BUG-17981 | MCC | 2.12.0 | 2.13.0 | [17981] Failure to redeploy a bare metal node with RAID 1 | sudo mdadm --detail --scan --verbose | $MCC_DIR/objects'
    'BUG-17960 | MCC | 2.12.0 | 2.13.0 | [17960] Overflow of the Ironic storage volume | Filesystem                 Size  Used Avail Use% Mounted on | $MCC_DIR/objects'
    'BUG-17359 | MCC | 2.12.0 | 2.13.0 | [17359] Deletion of AWS-based regional cluster credential fails | ./bin/kind get kubeconfig --name clusterapi > kubeconfig-bootstrap | $MCC_DIR/objects'
    'BUG-42386 | MCC | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MCC_DIR/objects'
    'BUG-24005 | MCC | 2.18.0 | 0.0.0 | [24005] Deletion of a node with ironic Pod is stuck in the *Terminating* state | related bare metal host is stuck in the ``deprovisioning`` | $MCC_DIR/objects'
    'BUG-50566 | MCC | 2.27.0 | 2.29.3 | [50566] Ceph upgrade is very slow during patch or major cluster update | Warning  Unhealthy  57s (x16 over 3m27s)  kubelet  Startup probe failed: | $MCC_DIR/objects'
    'BUG-26441 | MCC | 2.20.0 | 0.0.0 | [26441] Cluster update fails with the *MountDevice failed for volume* warning | -o jsonpath='\''{.items[?(@.spec.nodeName == "<nodeName>")].metadata.name}'\'' | $MCC_DIR/objects'
    'BUG-31186,34132 | MCC | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MCC_DIR/objects'
    'BUG-44193 | MCC | 2.26.0 | 2.29.0 | [44193] OpenSearch reaches 85% disk usage watermark affecting the cluster state | 0.8 × OpenSearch_PVC_Size_GB + Prometheus_PVC_Size_GB > 0.85 × Total_Storage_Capacity_GB | $MCC_DIR/objects'
    'BUG-50637 | MCC | 2.29.0 | 0.0.0 | [50637] Ceph creates second *miracephnodedisable* object during node disabling | NAME                                               AGE   NODE NAME                                        STATE      LAST CHECK             ISSUE | $MCC_DIR/objects'
    'BUG-50561 | MCC | 2.29.0 | 0.0.0 | [50561] The *local-volume-provisioner* pod switches to *CrashLoopBackOff* | local-volume-provisioner-h5lrc   0/1   CrashLoopBackOff   7 (5m12s ago)   14m   <IP>   <K8S-NODE-NAME>   <none>   <none> | $MCC_DIR/objects'
    'BUG-35429 | MCC | 2.24.0 | 2.25.0 | [35429] The WireGuard interface does not have the IPv4 address assigned | ip a show wireguard.cali | $MCC_DIR/objects'
    'BUG-34280 | MCC | 2.24.0 | 2.24.3 | [34280] No reconcile events generated during cluster update | Helm charts are not installed(upgraded) yet. Not ready releases: managed-lcm-api | $MCC_DIR/objects'
    'BUG-34210 | MCC | 2.24.0 | 0.0.0 | [34210] Helm charts installation failure during cluster update | Helm charts are not installed(upgraded) yet. | $MCC_DIR/objects'
    'BUG-33936 | MCC | 2.24.0 | 2.25.1 | [33936] Deletion failure of a controller node during machine replacement | Resolving dependency Service dhcp-lb in namespace kaas failed: | $MCC_DIR/objects'
    'BUG-32761 | MCC | 2.23.5 | 2.26.0 | [32761] Node cleanup fails due to remaining devices | 88621.log:7389:<TIMESTAMP> 88621 ERROR ansible.plugins.callback.ironic_log | $MCC_DIR/objects'
    'BUG-34247 | MCC | 2.24.0 | 0.0.0 | [34247] MKE backup fails during cluster update | chown -R nobody:nogroup /var/lib/docker/volumes/ucp-backup/_data | $MCC_DIR/objects'
    'BUG-30294 | MCC | 2.23.0 | 2.28.4 | [30294] Replacement of a *master* node is stuck on the *calico-node* Pod start | alias calicoctl=" | $MCC_DIR/objects'
    'BUG-35089 | MCC | 2.25.0 | 2.25.1 | [35089] Calico does not set up networking for a pod | felix/route_table.go 898: Syncing routes: found unexpected route; ignoring due to grace period. dest=<IP>/32 ifaceName="cali9731b965838" ifaceRegex="^cali." ipVersion=0x4 tableIndex=254 | $MCC_DIR/objects'
    'BUG-5981 | MCC | 0.0.0 | 2.24.0 | [5981] Upgrade gets stuck on the cluster with more that 120 nodes | ID             NAME                     MODE         REPLICAS   IMAGE                          PORTS | $MCC_DIR/objects'
    'BUG-27797 | MCC | 0.0.0 | 23.2 | [27797] A cluster '\''kubeconfig'\'' stops working during MKE minor version update | -o yaml <affectedClusterName>-kubeconfig \| awk '\''/admin.conf/ {print $2}'\'' \| | $MCC_DIR/objects'
    'BUG-29604 | MCC | 2.22.0 | 2.24.0 | [29604] The '\''failed to get kubeconfig'\'' error during TLS configuration | "expirationTime": "<TIMESTAMP>", | $MCC_DIR/objects'
    'BUG-30857 | MCC | 2.23.0 | 2.24.0 | [30857] Irrelevant error during Ceph OSD deployment on removable devices | shortClusterInfo: | $MCC_DIR/objects'
    'BUG-30635 | MCC | 2.23.0 | 2.24.0 | [30635] Ceph '\''pg_autoscaler'\'' is stuck with the '\''overlapping roots'\'' error | failureDomain: host | $MCC_DIR/objects'
    'BUG-31485 | MCC | 2.23.0 | 2.24.0 | [31485] Elasticsearch Curator does not delete indices as per retention period | -o custom-columns=CLUSTER:.metadata.name,NAMESPACE:.metadata.namespace,VERSION:.spec.providerSpec.value.release | $MCC_DIR/objects'
    'BUG-29296 | MCC | 2.22.0 | 2.22.0 | [29296] Deployment of a managed cluster fails during provisioning | InspectionError: Failed to obtain hardware details. | $MCC_DIR/objects'
    'BUG-30040 | MCC | 2.22.0 | 2.23.0 | [30040] OpenSearch is not in the '\''deployed'\'' status during cluster update | The stacklight/opensearch release of the stacklight/stacklight-bundle HelmBundle | $MCC_DIR/objects'
    'BUG-29329 | MCC | 2.21.0 | 2.23.0 | [29329] Recreation of the Patroni container replica is stuck | INFO: doing crash recovery in a single user mode | $MCC_DIR/objects'
    'BUG-46245 | MCC | 2.26.0 | 2.28.0 | [46245] Lack of access permissions for *HOC* and *HOCM* objects | - apiGroups: [kaas.mirantis.com] | $MCC_DIR/objects'
    'BUG-41305 | MCC | 2.26.0 | 2.28.0 | [41305] DHCP responses are lost between *dnsmasq* and *dhcp-relay* pods | dhcp-relay-<ID>   [0-9]/[0-9]   Running   [0-9]+ (<ID> ago)   <ID>   <IP>     kaas-node-<UUID> | $MCC_DIR/objects'
    'BUG-43164 | MCC | 2.27.0 | 2.28.0 | [43164] Rollover policy is not added to indicies created without a policy | <TIMESTAMP>,459 ERROR   Failed to complete action: delete_indices. | $MCC_DIR/objects'
    'BUG-41540 | MCC | 2.26.0 | 2.26.5 | [41540] LCM Agent cannot grab storage information on a host | {"level":"error","ts":"<TIMESTAMP>","logger":"agent", | $MCC_DIR/objects'
    'BUG-41819 | MCC | 2.26.0 | 2.27.0 | [41819] Graceful cluster reboot is blocked by the Ceph *ClusterWorkloadLocks* | message: ClusterMaintenanceRequest found, Ceph Cluster is not ready to upgrade, | $MCC_DIR/objects'
    'BUG-42304 | MCC | 2.26.0 | 2.27.1 | [42304] Failure of shard relocation in the OpenSearch cluster | {created_by_kind="StatefulSet",created_by_name="opensearch-master",namespace="stacklight"} | $MCC_DIR/objects'
    'BUG-40020 | MCC | 2.26.0 | 2.27.1 | [40020] Rollover policy update is not appllied to the current index | <TIMESTAMP>,459 ERROR   Failed to complete action: delete_indices.  <class '\''curator.exceptions.FailedExecution'\''>: Exception encountered.  Rerun with loglevel DEBUG and/or check Elasticsearch logs for more information. Exception: RequestError(400, '\''illegal_argument_exception'\'', '\''index [.ds-audit-000001] is the write index for data stream [audit] and cannot be deleted'\'') | $MCC_DIR/objects'
    'BUG-50287 | MCC | 2.29.0 | 2.29.1 | [50287] BareMetalHost with a Redfish BMC address is stuck on registering phase | address: redfish://<IP>/redfish/v1/Systems/1 | $MCC_DIR/objects'
    'BUG-50768 | MCC | 2.29.0 | 2.29.1 | [50768] Failure to update the *MCCUpgrade* object | HTTP response body: {"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure", | $MCC_DIR/objects'
    'BUG-20651 | MCC | 2.15.0 | 2.21.0 | [20651] A cluster deployment or update fails with not ready compose deployments | '\''not ready: deployments: kube-system/compose got 0/0 replicas, kube-system/compose-api | $MCC_DIR/objects'
    'BUG-26070 | MCC | 2.20.0 | 2.21.0 | [26070] RHEL system cannot be registered in Red Hat portal over MITM proxy | Unable to verify server'\''s identity: [SSL: CERTIFICATE_VERIFY_FAILED] | $MCC_DIR/objects'
    'BUG-28134 | MCC | 2.21.0 | 2.22.0 | [28134] Failure to update a cluster with nodes in the '\''Prepare'\'' state | Error: error when evicting pods/"patroni-13-2" -n "stacklight": global timeout reached: 10m0s | $MCC_DIR/objects'
    'BUG-27732-1 | MCC | 2.18.0 | 2.22.0 | [27732-1] OpenSearch PVC size custom settings are dismissed during deployment | -n <affectedClusterProjectName> | $MCC_DIR/objects'
    'BUG-27732-2 | MCC | 2.18.0 | 2.22.0 | [27732-2] Custom settings for |ESlogstashRetentionTime| are dismissed | notifications: 10 | $MCC_DIR/objects'
    'BUG-28783 | MCC | 2.21.0 | 2.22.0 | [28783] Ceph conditon stuck in absence of Ceph cluster secrets info | Failed to configure Ceph cluster: ceph cluster status info is not | $MCC_DIR/objects'
    'BUG-26740 | MCC | 2.20.0 | 2.21.0 | [26740] Failure to upgrade a management cluster with a custom certificate | failed to update management cluster: | $MCC_DIR/objects'
    'BUG-23853 | MCC | 2.17.0 | 2.18.0 | [23853] Replacement of a regional master node fails on bare metal and |EM| | osdRemoveStatus: | $MCC_DIR/objects'
    'BUG-21810 | MCC | 2.15.0 | 0.0.0 | [21810] Upgrade to Cluster releases 5.22.0 and 7.5.0 may get stuck | containerd --version | $MCC_DIR/objects'
    'BUG-24075 | MCC | 2.17.0 | 2.18.0 | [24075] Ubuntu 20.04 does not display for |aws-em| | NAME           AGE | $MCC_DIR/objects'
    'BUG-22563 | MCC | 2.16.0 | 2.17.0 | [22563] Failure to deploy a bare metal node with RAID 1 | sudo mdadm --detail --scan --verbose | $MCC_DIR/objects'
    'BUG-24806 | MCC | 2.18.0 | 2.19.0 | [24806] The dnsmasq parameters are not applied on multi-rack clusters | KUBECONFIG=kaas-mgmt-kubeconfig kubectl -n kaas logs --tail 50 deployment/dnsmasq -c dnsmasq-controller | $MCC_DIR/objects'
    'BUG-20467 | MCC | 2.15.0 | 2.16.0 | [20467] Failure to deploy an Equinix Metal based management cluster | 0/3 nodes are available: 3 pod has unbound immediate PersistentVolumeClaims. | $MCC_DIR/objects'
    'BUG-20189 | MCC | 2.15.0 | 2.16.0 | [20189] Container Cloud web UI reports upgrade while running previous release | Ceph public network address validation failed for cluster default/kaas-mgmt: invalid address '\''<IP>/0'\'' | $MCC_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-54430 | MOS | 25.2 | 25.2 | [54430] AMQP message delivery fails when message size exceeds RabbitMQ limit | oslo_messaging.exceptions.MessageDeliveryFailure: Unable to connect to AMQP server on openstack-neutron-rabbitmq-rabbitmq-0.rabbitmq-neutron.openstack.svc.cluster.local:5672 after inf tries: Basic.publish: (406) PRECONDITION_FAILED - message size 40744975 is larger than configured max size 16777216 | $MOS_DIR/objects'
    'KI-13755 | MOS | 25.2 | 25.2 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 25.2 | 25.2 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-54195 | MOS | 25.2 | 25.2 | [54195] Ceph OSD experiencing slow operations in BlueStore during |mosk| | Failed to configure Ceph cluster: ceph cluster verification is failed: | $MOS_DIR/objects'
    'KI-24005 | MOS | 2.18.0 | 0.0.0 | [24005] Deletion of a node with ironic Pod is stuck in the *Terminating* state | related bare metal host is stuck in the ``deprovisioning`` | $MOS_DIR/objects'
    'KI-54944 | MOS | 25.2 | 25.2 | [54944] Management cluster update may get stuck during host OS upgrade | dpkg-divert: error: cannot divert directories | $MOS_DIR/objects'
    'KI-54981 | MOS | 25.2 | 25.2 | [54981] |mgmt-upd| is stuck due to the invalid `BareMetalHostProfile` spec | {"level":"error","ts":"...","logger":"bm.manager","caller":"..." | $MOS_DIR/objects'
    'KI-7947 | MOS | 0.0.0 | 25.2.2 | [7947] Docker panic causes its service restarts every 24 hours | Oct 12 21:20:11 kaas-node-<ID> dockerd[...]: created by github.com/docker/docker/internal/mirantis/telemetry.(*Telemetry).start in goroutine 1 | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-54430 | MOS | 25.2.3 | 25.2.3 | [54430] AMQP message delivery fails when message size exceeds RabbitMQ limit | oslo_messaging.exceptions.MessageDeliveryFailure: Unable to connect to AMQP server on openstack-neutron-rabbitmq-rabbitmq-0.rabbitmq-neutron.openstack.svc.cluster.local:5672 after inf tries: Basic.publish: (406) PRECONDITION_FAILED - message size 40744975 is larger than configured max size 16777216 | $MOS_DIR/objects'
    'KI-13755 | MOS | 25.2.3 | 25.2.3 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 25.2.3 | 25.2.3 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-54195 | MOS | 25.2.3 | 25.2.3 | [54195] Ceph OSD experiencing slow operations in BlueStore during |mosk| | Failed to configure Ceph cluster: ceph cluster verification is failed: | $MOS_DIR/objects'
    'KI-24005 | MOS | 2.18.0 | 0.0.0 | [24005] Deletion of a node with ironic Pod is stuck in the *Terminating* state | related bare metal host is stuck in the ``deprovisioning`` | $MOS_DIR/objects'
    'KI-54981 | MOS | 25.2.3 | 25.2.3 | [54981] |mgmt-upd| is stuck due to the invalid `BareMetalHostProfile` spec | {"level":"error","ts":"...","logger":"bm.manager","caller":"..." | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-54430 | MOS | 25.2.2 | 25.2.2 | [54430] AMQP message delivery fails when message size exceeds RabbitMQ limit | oslo_messaging.exceptions.MessageDeliveryFailure: Unable to connect to AMQP server on openstack-neutron-rabbitmq-rabbitmq-0.rabbitmq-neutron.openstack.svc.cluster.local:5672 after inf tries: Basic.publish: (406) PRECONDITION_FAILED - message size 40744975 is larger than configured max size 16777216 | $MOS_DIR/objects'
    'KI-13755 | MOS | 25.2.2 | 25.2.2 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 25.2.2 | 25.2.2 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-54195 | MOS | 25.2.2 | 25.2.2 | [54195] Ceph OSD experiencing slow operations in BlueStore during |mosk| | Failed to configure Ceph cluster: ceph cluster verification is failed: | $MOS_DIR/objects'
    'KI-24005 | MOS | 2.18.0 | 0.0.0 | [24005] Deletion of a node with ironic Pod is stuck in the *Terminating* state | related bare metal host is stuck in the ``deprovisioning`` | $MOS_DIR/objects'
    'KI-54981 | MOS | 25.2.2 | 25.2.2 | [54981] |mgmt-upd| is stuck due to the invalid `BareMetalHostProfile` spec | {"level":"error","ts":"...","logger":"bm.manager","caller":"..." | $MOS_DIR/objects'
    'KI-31186,34132 | MOS | 2.24.0 | 0.0.0 | [31186,34132] Pods get stuck during MariaDB operations | [ERROR] WSREP: Corrupt buffer header: | $MOS_DIR/objects'
    'KI-42386 | MOS | 2.24.0 | 0.0.0 | [42386] A load balancer service does not obtain the external IP address | stacklight  iam-proxy-prometheus  LoadBalancer  <IP>  <pending>  443:30430/TCP | $MOS_DIR/objects'
    'KI-54430 | MOS | 25.2.1 | 25.2.1 | [54430] AMQP message delivery fails when message size exceeds RabbitMQ limit | oslo_messaging.exceptions.MessageDeliveryFailure: Unable to connect to AMQP server on openstack-neutron-rabbitmq-rabbitmq-0.rabbitmq-neutron.openstack.svc.cluster.local:5672 after inf tries: Basic.publish: (406) PRECONDITION_FAILED - message size 40744975 is larger than configured max size 16777216 | $MOS_DIR/objects'
    'KI-13755 | MOS | 25.2.1 | 25.2.1 | [13755] TF pods switch to CrashLoopBackOff after a simultaneous reboot | Datacenter: DC1 | $MOS_DIR/objects'
    'KI-42896 | MOS | 25.2.1 | 25.2.1 | [42896] Cassandra cluster contains extra node | Datacenter: dc1 | $MOS_DIR/objects'
    'KI-54195 | MOS | 25.2.1 | 25.2.1 | [54195] Ceph OSD experiencing slow operations in BlueStore during |mosk| | Failed to configure Ceph cluster: ceph cluster verification is failed: | $MOS_DIR/objects'
    'KI-24005 | MOS | 2.18.0 | 0.0.0 | [24005] Deletion of a node with ironic Pod is stuck in the *Terminating* state | related bare metal host is stuck in the ``deprovisioning`` | $MOS_DIR/objects'
    'KI-54981 | MOS | 25.2.1 | 25.2.1 | [54981] |mgmt-upd| is stuck due to the invalid `BareMetalHostProfile` spec | {"level":"error","ts":"...","logger":"bm.manager","caller":"..." | $MOS_DIR/objects'
    'KI-7947 | MOS | 0.0.0 | 25.2.2 | [7947] Docker panic causes its service restarts every 24 hours | Oct 12 21:20:11 kaas-node-<ID> dockerd[...]: created by github.com/docker/docker/internal/mirantis/telemetry.(*Telemetry).start in goroutine 1 | $MOS_DIR/objects'
  )


  # Helper function for version comparison
  version_ge() { [[ "$(printf '%s\n%s' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }
  version_le() { [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$1" ]]; }

  local FOUND_ANY=false
  for issue in "${ISSUES[@]}"; do
    IFS="|" read -r ID PROD MIN_VER MAX_VER TITLE PATTERN SEARCH_PATH ISSUE_URL <<< "$issue"
    # Trim whitespace
    ID=$(echo "$ID" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); PROD=$(echo "$PROD" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); MIN_VER=$(echo "$MIN_VER" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    MAX_VER=$(echo "$MAX_VER" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); TITLE=$(echo "$TITLE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); PATTERN=$(echo "$PATTERN" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    SEARCH_PATH=$(echo "$SEARCH_PATH" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); ISSUE_URL=$(echo "$ISSUE_URL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    [[ -z "$ID" ]] && continue

    # Version Filtering
    local CURRENT_VER="0.0.0"
    [[ "$PROD" == "MOS" ]] && CURRENT_VER="$MOS_VER"
    [[ "$PROD" == "MCC" ]] && CURRENT_VER="$MCC_VER"
    [[ "$PROD" == "ALL" ]] && CURRENT_VER="$MOS_VER"
    
    if [[ "$PROD" != "ALL" && "$MIN_VER" != "0.0.0" ]]; then
        if ! version_ge "$CURRENT_VER" "$MIN_VER" || ! version_le "$CURRENT_VER" "$MAX_VER"; then
            continue
        fi
    fi

    [[ ! -d "$SEARCH_PATH" ]] && continue
    [[ -z "$PATTERN" ]] && continue

    # Replace placeholders with regex patterns
    local FINAL_PATTERN="$PATTERN"
    # IP Address
    FINAL_PATTERN=$(echo "$FINAL_PATTERN" | sed -E 's/<IP>/([0-9]{1,3}\.){3}[0-9]{1,3}/g')
    # Timestamp (various formats)
    FINAL_PATTERN=$(echo "$FINAL_PATTERN" | sed -E 's/<TIMESTAMP>/[0-9]{4}-[0-9]{2}-[0-9]{2}[ T,][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{3})?/g')
    # UUID
    FINAL_PATTERN=$(echo "$FINAL_PATTERN" | sed -E 's/<UUID>/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g')
    # ID (short suffix or identifier)
    FINAL_PATTERN=$(echo "$FINAL_PATTERN" | sed -E 's/<ID>/[a-z0-9-]+/g')

    MATCHES=$(grep -rEi "$FINAL_PATTERN" "$SEARCH_PATH" 2>/dev/null | head -n 5)
    if [[ -n "$MATCHES" ]]; then
      FOUND_ANY=true
      echo "[!] POTENTIAL MATCH FOUND: $ID - $TITLE" >>"$OUT"
      [[ -n "$ISSUE_URL" ]] && echo "    URL: $ISSUE_URL" >>"$OUT"
      echo "    Pattern: $PATTERN" >>"$OUT"
      echo "    Evidence (last 5 matches):" >>"$OUT"
      echo "$MATCHES" | sed 's/^/      /' >>"$OUT"
      echo "----------------------------------------------------" >>"$OUT"
    fi
  done

  if [ "$FOUND_ANY" = false ]; then
    echo "No specific CLUSTER Known Issues were automatically detected for version $MOS_VER / $MCC_VER." >>"$OUT"
  fi
}

# --- IP Overlap Check Function ---
check_overlaps() {
  python3 - <<EOF
import ipaddress
import sys

def parse_range(r):
    r = r.strip()
    if not r or r == "None" or r == "null": return []
    try:
        if '-' in r:
            start, end = r.split('-')
            return list(ipaddress.summarize_address_range(
                ipaddress.ip_address(start.strip()), 
                ipaddress.ip_address(end.strip())
            ))
        return [ipaddress.ip_network(r, strict=False)]
    except Exception as e:
        return []

lines = sys.stdin.readlines()
networks = []
for line in lines:
    for item in line.replace('[','').replace(']','').split(','):
        networks.extend(parse_range(item))

overlaps = []
for i in range(len(networks)):
    for j in range(i + 1, len(networks)):
        if networks[i].overlaps(networks[j]):
            overlaps.append(f"Overlap: {networks[i]} <-> {networks[j]}")

if overlaps:
    print("\n🛑 ALERT: IP RANGE OVERLAPS DETECTED!")
    for o in set(overlaps): print(o)
else:
    print("\n✅ No IP overlaps detected in this audit.")
EOF
}

# --- Cert audit function (Hardened & Informative) ---
audit_k8s_secret() {
  local YAML_FILE="$1"
  if [[ -z "$YAML_FILE" || ! -f "$YAML_FILE" ]]; then return 1; fi

  local TMP_DIR=$(mktemp -d -t myrha)
  local DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
  local KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$YAML_FILE" 2>/dev/null)
  [[ -z "$KEYS" ]] && {
    rm -rf "$TMP_DIR"
    return 1
  }

  echo "===================================================="
  echo "🔍 AUDIT REPORT: $(basename "$YAML_FILE")"
  echo "===================================================="

  local LEAF_CERT=""
  local CA_CERT=""
  local PRIVATE_KEY=""

  for KEY in $KEYS; do
    local VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$YAML_FILE" | tr -d '[:space:]')
    local TARGET_FILE="$TMP_DIR/$KEY"

    # Try decoding
    echo "$VAL" | base64 -d >"$TARGET_FILE" 2>/dev/null
    # If not base64/PEM, treat as plain text
    if ! grep -q "BEGIN" "$TARGET_FILE" 2>/dev/null; then echo "$VAL" >"$TARGET_FILE"; fi

    local CONTENT_TYPE=$(grep -m 1 "BEGIN" "$TARGET_FILE" 2>/dev/null)
    [[ -z "$CONTENT_TYPE" ]] && continue

    echo "--- Field: [$KEY] ---"

    if [[ "$CONTENT_TYPE" == *"PRIVATE KEY"* ]]; then
      # Silent Probe: Only process if it's a valid key (RSA/EC)
      if openssl pkey -in "$TARGET_FILE" -text -noout &>/dev/null; then
        PRIVATE_KEY="$TARGET_FILE"
        echo "-----BEGIN PRIVATE KEY-----"
        echo "[REDACTED - SENSITIVE DATA]"
        echo "-----END PRIVATE KEY-----"
        echo -e "\n----------------------------------------------------"
        K_MOD=$(openssl rsa -noout -modulus -in "$TARGET_FILE" 2>/dev/null | openssl md5 | awk '{print $NF}')
        echo "🔢 RSA Modulus MD5: ${K_MOD:-[Non-RSA Key]}"
      fi

    elif [[ "$CONTENT_TYPE" == *"CERTIFICATE"* ]]; then
      if openssl x509 -in "$TARGET_FILE" -noout &>/dev/null; then
        cat "$TARGET_FILE"
        echo -e "\n----------------------------------------------------"

        local CN=$(openssl x509 -noout -subject -in "$TARGET_FILE" -nameopt RFC2253 | sed 's/.*CN=//;s/,.*//')
        local ISSUER=$(openssl x509 -noout -issuer -in "$TARGET_FILE" -nameopt RFC2253 | sed 's/^issuer=//')
        local SUBJECT=$(openssl x509 -noout -subject -in "$TARGET_FILE" -nameopt RFC2253 | sed 's/^subject=//')
        local EXPIRY=$(openssl x509 -noout -enddate -in "$TARGET_FILE" | cut -d= -f2)
        local IS_CA=$(openssl x509 -noout -text -in "$TARGET_FILE" 2>/dev/null | grep "CA:TRUE")
        local SAN=$(openssl x509 -noout -ext subjectAltName -in "$TARGET_FILE" 2>/dev/null | grep -v "Subject Alternative Name" | xargs)
        C_MOD=$(openssl x509 -noout -modulus -in "$TARGET_FILE" 2>/dev/null | openssl md5 | awk '{print $NF}')

        echo "📋 CN:      ${CN:-Unknown}"
        echo "🌐 SAN:     ${SAN:-None}"
        echo "📅 Expires: $EXPIRY"
        echo "🔢 Modulus MD5: ${C_MOD:-[Non-RSA Cert]}"

        # --- Expiry Alert Logic (macOS BSD date) ---
        # openssl expiry format: Mar 25 10:24:59 2025 GMT
        EXPIRY_SEC=$(date -j -f "%b %d %T %Y %Z" "$EXPIRY" +%s 2>/dev/null)
        NOW_SEC=$(date +%s)
        if [[ -n "$EXPIRY_SEC" ]]; then
          if [ "$EXPIRY_SEC" -lt "$NOW_SEC" ]; then
            echo "📅 ALERT:   🛑 EXPIRED"
          elif [ "$EXPIRY_SEC" -lt $((NOW_SEC + 2592000)) ]; then
            echo "📅 ALERT:   🚨 EXPIRING SOON (within 30 days)"
          fi
        fi

        if [[ "$ISSUER" == "$SUBJECT" ]]; then
          echo "🧬 Status:  ⚠️ ROOT CA (Self-Signed)"
          CA_CERT="$TARGET_FILE"
        elif [[ -n "$IS_CA" ]]; then
          echo "🧬 Status:  🔗 INTERMEDIATE CA"
          CA_CERT="$TARGET_FILE"
        else
          echo "🧬 Status:  📄 LEAF CERTIFICATE"
          LEAF_CERT="$TARGET_FILE"
        fi
      fi
    fi
    echo ""
  done

  # --- FINAL VALIDATIONS ---
  echo "===================================================="
  echo "⚖️  FINAL VALIDATIONS"
  echo "===================================================="

  local CHECKS_RUN=0

  # 1. Private Key vs Leaf Cert
  if [[ -n "$LEAF_CERT" && -n "$PRIVATE_KEY" ]]; then
    LM=$(openssl x509 -noout -modulus -in "$LEAF_CERT" 2>/dev/null | openssl md5)
    KM=$(openssl rsa -noout -modulus -in "$PRIVATE_KEY" 2>/dev/null | openssl md5)
    printf "Match (Key <-> Leaf): "
    if [[ -n "$LM" && "$LM" == "$KM" ]]; then
      echo "✅ VALID"
    else
      echo "❌ MISMATCH"
    fi
    CHECKS_RUN=1
  fi

  # 2. Leaf Cert vs CA Cert
  if [[ -n "$LEAF_CERT" && -n "$CA_CERT" ]]; then
    printf "Chain (Leaf <-> CA):  "
    if openssl verify -CAfile "$CA_CERT" "$LEAF_CERT" 2>/dev/null | grep -q "OK"; then
      echo "✅ VERIFIED"
    else
      echo "❌ FAILED"
    fi
    CHECKS_RUN=1
  fi

  # 3. Fallback message if no related pairs were found
  if [[ $CHECKS_RUN -eq 0 ]]; then
    if [[ -n "$CA_CERT" && -z "$LEAF_CERT" ]]; then
      echo "ℹ️  INFO: Standalone CA/Self-Signed cert (no chain to verify)."
    elif [[ -n "$PRIVATE_KEY" && -z "$LEAF_CERT" ]]; then
      echo "ℹ️  INFO: Standalone Private Key (no certificate to match)."
    else
      echo "ℹ️  INFO: No related crypto pairs found for validation."
    fi
  fi

  rm -rf "$TMP_DIR"
  echo ""
}

# Detect Log Source
if [[ -d "./logs" ]]; then
  BASE_DIR="./logs"
else
  BASE_DIR="."
fi

echo "Generating report. This operation may take several minutes... Please wait."
echo ""
# List all files on logs:
echo "🚀 Indexing files and starting analysis..."
find "$BASE_DIR" -not -path "$LOGPATH/*" -type f >"$LOGPATH/files"

# --- GLOBAL COUNTERS ---
MCC_RUNNING=0; MCC_NON_RUNNING=0; MCC_COMPLETED=0
MOS_RUNNING=0; MOS_NON_RUNNING=0; MOS_COMPLETED=0
MCC_NON_RUNNING_LIST=""
MOS_NON_RUNNING_LIST=""

# Discover MCC and MOS cluster directories
MCC_DIR=$(find "$BASE_DIR" -type d -name "kaas-mgmt" | head -n 1)
MOS_DIR=$(find "$BASE_DIR" -type d -name "mos" -not -path "*/objects/*" | head -n 1)

# Fallback robust discovery if standard names not found
if [[ -z "$MCC_DIR" ]]; then
  INDICATOR_MCC=$(grep "/objects/cluster/kaas.mirantis.com/kaasreleases/" "$LOGPATH/files" | head -n 1)
  [[ -n "$INDICATOR_MCC" ]] && MCC_DIR=$(echo "$INDICATOR_MCC" | sed 's|/objects/cluster/kaas.mirantis.com/kaasreleases/.*||')
fi
if [[ -z "$MOS_DIR" ]]; then
  INDICATOR_MOS=$(grep "/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/" "$LOGPATH/files" | head -n 1)
  [[ -n "$INDICATOR_MOS" ]] && MOS_DIR=$(echo "$INDICATOR_MOS" | sed 's|/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/.*||')
fi

# Detect MCC Version
MCC_VER_DETECTED="0.0.0"
if [[ -n "$MCC_DIR" ]]; then
  MCC_FILE=$(find "$MCC_DIR" -path "*/default/cluster.k8s.io/clusters/*.yaml" 2>/dev/null | head -n 1)
  if [[ -f "$MCC_FILE" ]]; then
     MCC_VER_DETECTED=$(yq eval '.Object.spec.providerSpec.value.kaas.release // .spec.providerSpec.value.kaas.release' "$MCC_FILE" 2>/dev/null | sed 's/kaas-//' | tr '-' '.')
  fi
fi

# Detect MOS Version
MOS_VER_DETECTED="0.0.0"
if [[ -n "$MOS_DIR" ]]; then
  MOS_STATUS_FILE=$(find "$MOS_DIR" -path "*/lcm.mirantis.com/openstackdeploymentstatus/*.yaml" 2>/dev/null | head -n 1)
  if [[ -n "$MOS_STATUS_FILE" ]]; then
    REL_RAW=$(grep -m1 "    release: " "$MOS_STATUS_FILE" | sed -e 's/.*release: //' -e 's/[[:space:]]//g' -e 's/+/./g' -e 's/\.$//')
    IFS='.' read -r -a V <<<"$REL_RAW"
    MOS_VER_DETECTED="${V[0]}.${V[1]}.${V[2]}+${V[3]}.${V[4]}${V[5]:+.${V[5]}}"
  fi
fi

# Run Known Issues Diagnostic EARLY
check_known_issues "$MOS_VER_DETECTED" "$MCC_VER_DETECTED"

if [[ -n "$MCC_DIR" ]]; then
  MCC_FILE=$(find "$MCC_DIR" -path "*/default/cluster.k8s.io/clusters/*.yaml" 2>/dev/null | head -n 1)
  if [[ -f "$MCC_FILE" ]]; then
    MCCNAME=$(yq eval '.Object.metadata.name // .metadata.name' "$MCC_FILE" 2>/dev/null)
    MCCNAMESPACE=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$MCC_FILE" 2>/dev/null)
  fi
fi

if [[ -n "$MOS_DIR" ]]; then
  MOSNAME=$(basename "$MOS_DIR")
fi

if [[ -n "$MCCNAME" && -n "$MOS_DIR" ]]; then
  MOS_CLUSTER_FILE=$(find "$MCC_DIR" -path "*/cluster.k8s.io/clusters/*.yaml" 2>/dev/null | grep -v default | head -n 1)
  if [[ -f "$MOS_CLUSTER_FILE" ]]; then
    MOSNAMESPACE=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$MOS_CLUSTER_FILE" 2>/dev/null)
  fi
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_cluster"
  echo "Gathering MOS cluster details..."
  echo "################# [MOS CLUSTER DETAILS] #################" >"$OUT"
  MOS_STATUS_FILE=$(find "$MOS_DIR" -path "*/lcm.mirantis.com/openstackdeploymentstatus/*.yaml" 2>/dev/null | head -n 1)
  if [[ -n "$MOS_STATUS_FILE" ]]; then
    # Unified split for MOS (e.g., 21.0.0+25.2.9)
    REL_RAW=$(grep -m1 "    release: " "$MOS_STATUS_FILE" | sed -e 's/.*release: //' -e 's/[[:space:]]//g' -e 's/+/./g' -e 's/\.$//')
    IFS='.' read -r -a V <<<"$REL_RAW"
    # V[0]=VER1, V[1]=VER2, V[2]=VER3, V[3]=VER4, V[4]=VER5, V[5]=VER6
    MOS_VER_FULL="${V[0]}.${V[1]}.${V[2]}+${V[3]}.${V[4]}${V[5]:+.${V[5]}}"
    printf "## MOS release details (Managed): $MOS_VER_FULL" >>"$OUT"
    echo "" >>"$OUT"
    if (($(echo "${V[3]}.${V[4]} >= 25.2" | bc -l))); then
      echo "https://docs.mirantis.com/mosk/25.2/release-notes/25.2-series/25.2.${V[5]}.html" | sed 's/\.\././' >>"$OUT"
    else
      echo "https://docs.mirantis.com/mosk/25.1-and-earlier/release-notes/release-notes-mosk-old/${V[3]}.${V[4]}-series/${V[3]}.${V[4]}.${V[5]}.html" | sed 's/\.\././' >>"$OUT"
    fi
    echo "" >>"$OUT"
    MOS_BUG_VER="${V[3]}.${V[4]}${V[5]:+.${V[5]}}"
    printf "## MOS Bugs - $MOS_BUG_VER:" >>"$OUT"
    echo "" >>"$OUT"
    # Full Jira Restoration (MOS)
    [[ "$MOS_BUG_VER" == "23.1.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.2%20%2F%20MOSK%2023.1.1%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.1.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.3%20%2F%20MOSK%2023.1.2%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.1.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.4%20%2F%20MOSK%2023.1.3%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.1.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.5%20%2F%20MOSK%2023.1.4%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.2.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.3%20%2F%20MOSK%2023.2.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.2.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.4%20%2F%20MOSK%2023.2.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.2.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.5%20%2F%20MOSK%2023.2.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.3."* ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.25%20%2F%20MOSK%2023.3%22%2C%20%22KaaS%202.25.x%20%2F%20MOSK%2023.3.x%22%29" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.3.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.1%20%2F%20MOSK%2023.3.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.3.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.2%20%2F%20MOSK%2023.3.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.3.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.3%20%2F%20MOSK%2023.3.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "23.3.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.4%20%2F%20MOSK%2023.3.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1."* ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26%20%2F%20MOSK%2024.1%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.1%20%2F%20MOSK%2024.1.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.2%20%2F%20MOSK%2024.1.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.3%20%2F%20MOSK%2024.1.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.4%20%2F%20MOSK%2024.1.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.5%20%2F%20MOSK%2024.1.5%20%28Patch%20release5%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1.6" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.1%20%2F%20MOSK%2024.1.6%20%28Patch%20release6%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.1.7" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.2%20%2F%20MOSK%2024.1.7%20%28Patch%20release7%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.2."* ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.27%20%2F%20MOSK%2024.2%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.2.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.3%20%2F%20MOSK%2024.2.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.2.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.4%20%2F%20MOSK%2024.2.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.2.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28.1%20%2F%20MOSK%2024.2.3%20(Patch%20release3)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.2.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28.2%20%2F%20MOSK%2024.2.4%20(Patch%20release4)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.2.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28.3%20%2F%20MOSK%2024.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.3."* ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28%20%2F%20MOSK%2024.3%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.3.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.4%20%2F%20MOSK%2024.3.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.3.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.5%20%2F%20MOSK%2024.3.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.3.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29.1%20%2F%20MOSK%2024.3.3%20(Patch%20release3)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.3.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.2%20%2F%20MOSK%2024.3.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.3.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29.3%20%2F%20MOSK%2024.3.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "24.3.6" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29.4%20%2F%20MOSK%2024.3.6%20(Patch%20release6)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.1."* ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.1.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.2."* ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30%20%2F%20MOSK%2025.2%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.2.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.1%20%2F%20MOSK%2025.2.1%20(Patch%20release1)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.2.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.2%20%2F%20MOSK%2025.2.2%20(Patch%20release2)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.2.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.3%20%2F%20MOSK%2025.2.3%20(Patch%20release3)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.2.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.4%20%2F%20MOSK%2025.2.4%20(Patch%20release4)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "25.2.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MOS_BUG_VER" == "26.1."* ]] && MOS_JIRA_URL="https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31%20%2F%20MOSK%2026.1%22"

    MOS_LINKS_HTML="<div style=\"margin-bottom: 10px;\"><strong>MOS Bugs - $MOS_BUG_VER:</strong><br><a href=\"$MOS_DOC_URL\" target=\"_blank\">Release Notes</a> | <a href=\"$MOS_JIRA_URL\" target=\"_blank\">Jira Bugs</a></div>"
    
    echo "## Details and versions:" >>"$OUT"
    printf '# ' >>"$OUT"
    ls $MOS_STATUS_FILE >>"$OUT"
    grep -m1 "      release:" $MOS_STATUS_FILE >>"$OUT"
    grep -m1 "      openstack_version:" $MOS_STATUS_FILE >>"$OUT"
    sed -n '/    services:/,$p' $MOS_STATUS_FILE >>"$OUT"
    if [[ -n "$MCCNAME" ]]; then
      echo "## LCM status:" >>"$OUT"
      printf '# ' >>"$OUT"
      LCM_YAML="$MCC_DIR/objects/namespaced/$MOSNAMESPACE/lcm.mirantis.com/lcmclusters/$MOSNAME.yaml"
      if [[ -f "$LCM_YAML" ]]; then
        ls $LCM_YAML >>"$OUT"
        # Extract full stuck message if exists
        STUCK_MSG=$(yq eval '.Object.status.lcmOperationStuckMessage // .status.lcmOperationStuckMessage' "$LCM_YAML" 2>/dev/null)
        if [[ -n "$STUCK_MSG" && "$STUCK_MSG" != "null" ]]; then
          echo "  lcmOperationStuckMessage: $STUCK_MSG" >>"$OUT"
        fi
        sed -n '/  status:/,/    requestedNodes:/p' $LCM_YAML >>"$OUT"
      fi
      echo "" >>"$OUT"
      echo "Gathering Node Conditions..."
      echo "################# [NODE CONDITIONS] #################" >>"$OUT"
      for nf in $(grep "/core/nodes" "$LOGPATH/files" | grep "$MOS_DIR" | grep "$MOSNAME"); do
        N_NAME=$(basename "$nf" .yaml)
        # Extract conditions using yq
        READY=$(yq eval '.Object.status.conditions[] | select(.type=="Ready") | .status' "$nf" 2>/dev/null)
        DISK=$(yq eval '.Object.status.conditions[] | select(.type=="DiskPressure") | .status' "$nf" 2>/dev/null)
        # Default to Unknown if extraction failed
        [[ -z "$READY" ]] && READY="Unknown"
        [[ -z "$DISK" ]] && DISK="Unknown"
        printf "Node: %-50s | Ready: %-8s | DiskPressure: %-8s\n" "$N_NAME" "$READY" "$DISK" >>"$OUT"
      done
    fi
  fi
fi
# 5. MOS Stacklight & Patroni Details Card
if [[ -d "$MOS_DIR/objects/namespaced/stacklight" ]]; then
  OUT="$LOGPATH/mos_stacklight"
  echo "Gathering MOS Stacklight details..."
  echo "################# [MOS STACKLIGHT & PATRONI DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"

  echo "## Patroni Cluster Status (from Pod annotations):" >>"$OUT"
  # Find all patroni pod YAMLs
  find "$MOS_DIR" -path "*/stacklight/core/pods/patroni-*.yaml" 2>/dev/null | sort | while read -r pf; do
    POD_NAME=$(basename "$pf" .yaml)
    # Extract the JSON status from annotations
    P_STATUS=$(yq eval '.Object.metadata.annotations.status // .metadata.annotations.status' "$pf" 2>/dev/null)
    if [[ -n "$P_STATUS" && "$P_STATUS" != "null" ]]; then
       # Format JSON-like string into readable output
       ROLE=$(echo "$P_STATUS" | grep -oE '"role":"[^"]+"' | cut -d'"' -f4)
       STATE=$(echo "$P_STATUS" | grep -oE '"state":"[^"]+"' | cut -d'"' -f4)
       REPL=$(echo "$P_STATUS" | grep -oE '"replication_state":"[^"]+"' | cut -d'"' -f4)
       printf "Pod: %-25s | Role: %-10s | State: %-10s | Repl: %s\n" "$POD_NAME" "$ROLE" "$STATE" "$REPL" >>"$OUT"
    else
       echo "Pod: $POD_NAME | Status annotation not found" >>"$OUT"
    fi
  done

  echo "## Stacklight Deployment Status:" >>"$OUT"
  HELMB_FILE=$(ls "$MOS_DIR/objects/namespaced/stacklight/lcm.mirantis.com/helmbundles/"*.yaml 2>/dev/null | head -n 1)
  if [[ -f "$HELMB_FILE" ]]; then
    echo "### File: $HELMB_FILE" >>"$OUT"
    yq eval '.Object.status // .status' "$HELMB_FILE" 2>/dev/null >>"$OUT"
  fi
fi

# 6. MOS Credentials Card
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_credentials"
  echo "Scanning MOS Secrets for Credentials..."
  TMP_CREDS="$LOGPATH/mos_creds_other"
  TMP_TOKENS="$LOGPATH/mos_creds_tokens"
  echo "################# [MOS CREDENTIALS (DECRYPTED)] #################" >"$OUT"
  echo "" > "$TMP_CREDS"
  echo "" > "$TMP_TOKENS"

  find "$MOS_DIR" -path "*/core/secrets/*.yaml" -type f | while read -r secret_file; do
    DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
    KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$secret_file" 2>/dev/null)
    
    # We'll use local temp buffers for each file to handle "## File:" header
    FILE_BUF_CREDS=""
    FILE_BUF_TOKENS=""

    for KEY in $KEYS; do
      if [[ "$KEY" =~ user|pass|login|account|creds|secret|token|key ]]; then
        VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$secret_file" 2>/dev/null)
        DECODED=$(echo "$VAL" | base64 -d 2>/dev/null)
        
        IS_TLS=false
        if [[ -n "$DECODED" ]]; then
           if echo "$DECODED" | grep -qEi "BEGIN CERTIFICATE|BEGIN .* PRIVATE KEY|BEGIN .* KEY|BEGIN PKCS7|BEGIN X509|SSH PRIVATE KEY"; then
             IS_TLS=true
           fi
        elif echo "$VAL" | grep -qEi "BEGIN CERTIFICATE|BEGIN .* PRIVATE KEY|BEGIN .* KEY|BEGIN PKCS7|BEGIN X509|SSH PRIVATE KEY"; then
             IS_TLS=true
        fi
        
        if [[ "$KEY" =~ (tls|cert|crt|ca|pem|key|pub|authorized_keys) ]]; then
           IS_TLS=true
        fi

        if [ "$IS_TLS" = true ]; then
           continue
        fi

        # Determine if it's a token
        TARGET_BUF="FILE_BUF_CREDS"
        [[ "$KEY" =~ token ]] && TARGET_BUF="FILE_BUF_TOKENS"

        ENTRY=""
        if [[ -n "$DECODED" ]]; then
           if [[ "$DECODED" =~ [^[:print:][:space:]] ]]; then
             ENTRY=$(printf "🔑 %-30s : [BINARY DATA]\n" "$KEY")
           else
             LINE_COUNT=$(echo "$DECODED" | wc -l)
             if [ "$LINE_COUNT" -le 1 ]; then
               ENTRY=$(printf "🔑 %-30s : %s\n" "$KEY" "$DECODED")
             else
               ENTRY=$(printf "🔑 %-30s :\n" "$KEY")
               ENTRY+="$(echo "$DECODED" | sed 's/^/    /')\n"
             fi
           fi
        else
           ENTRY=$(printf "🔑 %-30s : %s\n" "$KEY" "$VAL")
        fi

        if [[ "$TARGET_BUF" == "FILE_BUF_CREDS" ]]; then
           FILE_BUF_CREDS+="$ENTRY"
        else
           FILE_BUF_TOKENS+="$ENTRY"
        fi
      fi
    done

    if [[ -n "$FILE_BUF_CREDS" ]]; then
       echo "----------------------------------------------------" >> "$TMP_CREDS"
       echo "## File: $secret_file" >> "$TMP_CREDS"
       echo -e "$FILE_BUF_CREDS" >> "$TMP_CREDS"
    fi
    if [[ -n "$FILE_BUF_TOKENS" ]]; then
       echo "----------------------------------------------------" >> "$TMP_TOKENS"
       echo "## File: $secret_file" >> "$TMP_TOKENS"
       echo -e "$FILE_BUF_TOKENS" >> "$TMP_TOKENS"
    fi
  done

  echo -e "\n## 🛡️ GENERAL CREDENTIALS:" >> "$OUT"
  cat "$TMP_CREDS" >> "$OUT"
  echo -e "\n## 🎟️ TOKENS:" >> "$OUT"
  cat "$TMP_TOKENS" >> "$OUT"
  rm "$TMP_CREDS" "$TMP_TOKENS"
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_events"
  echo "Gathering MOS cluster events..."
  echo "################# [MOS EVENTS (WARNING+ERRORS)] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Analyzed files:" >>"$OUT"
  EVENTS_LOG=$(find "$MOS_DIR" -name "events.log" 2>/dev/null | head -n 1)
  if [[ -f "$EVENTS_LOG" ]]; then
    echo "# $EVENTS_LOG:" >>"$OUT"
    grep -E "Warning|Error" "$EVENTS_LOG" | sort -M >>"$OUT"
  fi
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_nodes"
  echo "Gathering MOS node details..."
  echo "################# [MOS NODE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep "/core/nodes" $LOGPATH/files | grep $MOSNAME >$LOGPATH/mos-nodes
  printf "## Nodes" >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-nodes))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf '# '
    basename "$line" .yaml
  done <$LOGPATH/mos-nodes >>"$OUT"
  while read -r line; do
    echo "" >>"$OUT"
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E "      kaas.mirantis.com/machine-name:" $line >>"$OUT"
    yq eval '.Object.status.nodeInfo // .status.nodeInfo' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status.conditions // .status.conditions' "$line" 2>/dev/null >>"$OUT"
  done <$LOGPATH/mos-nodes
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_lcmmachine"
  echo "Gathering MOS LCM machine details..."
  echo "################# [MOS LCM MACHINE DETAILS] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/$MOSNAMESPACE/lcm.mirantis.com/lcmmachines $LOGPATH/files >$LOGPATH/mos-lcmmachine
  echo "" >>"$OUT"
  printf '## Machines' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-lcmmachine))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mos-lcmmachine >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-lcmmachine
  echo "" >>"$OUT"
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_machine"
  echo "Gathering MOS machine details..."
  echo "################# [MOS MACHINE DETAILS] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/$MOSNAMESPACE/cluster.k8s.io/machines $LOGPATH/files >$LOGPATH/mos-machine
  echo "" >>"$OUT"
  printf '## Machines' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-machine))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mos-machine >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-machine
  echo "" >>"$OUT"
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_ceph_control"
  echo "Gathering MOS Ceph Control Plane details..."
  echo "################# [MOS CEPH CONTROL DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Rook-ceph details:" >>"$OUT"
  ROOK_CEPH=$(find "$MOS_DIR" -path "*/rook-ceph/ceph.rook.io/cephclusters/rook-ceph.yaml" 2>/dev/null | head -n 1)
  if [[ -f "$ROOK_CEPH" ]]; then
    echo "# $ROOK_CEPH:" >>"$OUT"
    sed -n '/    ceph:/,/    version:/p' "$ROOK_CEPH" | sed '$d' >>"$OUT"
  fi
  echo "" >>"$OUT"
  echo "## Mgr node logs (Warnings/Errors):" >>"$OUT"
  grep "/mgr.log" $LOGPATH/files >$LOGPATH/ceph-mgr
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -iE 'error|fail|warn' "$line" | sed -E '/^[[:space:]]*$/d' >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/ceph-mgr
  echo "## Mon node logs (Warnings/Errors):" >>"$OUT"
  grep "/mon.log" $LOGPATH/files >$LOGPATH/ceph-mon
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -iE 'error|fail|warn' "$line" | sed -E '/^[[:space:]]*$/d' >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/ceph-mon
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_ceph_osd"
  echo "Gathering MOS Ceph OSD details..."
  echo "################# [MOS CEPH OSD DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Osd node logs (Warnings/Errors):" >>"$OUT"
  grep "/osd.log" $LOGPATH/files >$LOGPATH/ceph-osd
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -iE 'error|fail|warn' "$line" | sed -E '/^[[:space:]]*$/d' >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/ceph-osd
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack"
  echo "Gathering MOS Openstack OSDPL details..."
  echo "################# [MOS OPENSTACK OSDPL DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## OSDPL LCM status details:" >>"$OUT"
  OSDPL_STATUS=$(find "$MOS_DIR" -path "*/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml" 2>/dev/null | head -n 1)
  if [[ -f "$OSDPL_STATUS" ]]; then
    echo "# $OSDPL_STATUS:" >>"$OUT"
    sed -n '/    osdpl:/,/    services:/p' "$OSDPL_STATUS" | sed '$d' >>"$OUT"
  fi
  echo "" >>"$OUT"
  echo "## OSDPL details:" >>"$OUT"
  OSDPL=$(find "$MOS_DIR" -path "*/openstack/lcm.mirantis.com/openstackdeployments/*.yaml" 2>/dev/null | head -n 1)
  if [[ -f "$OSDPL" ]]; then
    echo "# $OSDPL:" >>"$OUT"
    sed -n '/  spec:/,/  status:/p' "$OSDPL" | sed '$d' >>"$OUT"
  fi
  echo "" >>"$OUT"
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_neutron"
  echo "Gathering MOS Openstack Neutron logs..."
  echo "################# [MOS OPENSTACK NEUTRON DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from neutron-server pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'neutron-server.log' $LOGPATH/files >$LOGPATH/mos-openstack-neutron-server
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-neutron-server
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_nova"
  echo "Gathering MOS Openstack Nova logs..."
  echo "################# [MOS OPENSTACK NOVA DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from nova-compute pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'nova-compute.log' $LOGPATH/files >$LOGPATH/mos-openstack-nova-compute
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-nova-compute
  echo "" >>"$OUT"
  echo "## Logs from nova-scheduler pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'nova-scheduler.log' $LOGPATH/files >$LOGPATH/mos-openstack-nova-scheduler
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-nova-scheduler
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_etcd"
  echo "Gathering MOS Openstack ETCD details..."
  echo "################# [MOS OPENSTACK ETCD DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## ETCD Statefulset details:" >>"$OUT"
  find "$MOS_DIR" -path "*/namespaced/openstack/apps/statefulsets/etcd-etcd.yaml" -type f | while read -r f; do
    echo "### Path: /${f#./}" >>"$OUT"
    yq eval '"Replicas: " + (.Object.spec.replicas // .spec.replicas)' "$f" >>"$OUT"
    yq eval '"Ready Replicas: " + (.Object.status.readyReplicas // .status.readyReplicas)' "$f" >>"$OUT"
    yq eval '"Current Replicas: " + (.Object.status.currentReplicas // .status.currentReplicas)' "$f" >>"$OUT"
    echo "---" >>"$OUT"
    yq eval '"Image: " + (.Object.spec.template.spec.containers[0].image // .spec.template.spec.containers[0].image)' "$f" >>"$OUT"
    echo "" >>"$OUT"
  done
  echo "## ETCD Logs (Errors/Warnings):" >>"$OUT"
  find "$MOS_DIR" -path "*/namespaced/openstack/core/pods/etcd-etcd-*/etcd.log" -type f | sort | while read -r log; do
    echo "### Log Path: /${log#./}" >>"$OUT"
    grep -Ei "error|fail|warning|warn" "$log" | tail -n 50 >>"$OUT"
    echo "" >>"$OUT"
  done
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_libvirt"
  echo "Gathering MOS Openstack Libvirt logs..."
  echo "################# [MOS OPENSTACK LIBVIRT DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from libvirt pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'libvirt.log' $LOGPATH/files >$LOGPATH/mos-openstack-libvirt
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-libvirt
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_keystone"
  echo "Gathering MOS Openstack Keystone logs..."
  echo "################# [MOS OPENSTACK KEYSTONE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from keystone-api pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'keystone-api.log' $LOGPATH/files >$LOGPATH/mos-openstack-keystone-api
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-keystone-api
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_cinder"
  echo "Gathering MOS Openstack Cinder logs..."
  echo "################# [MOS OPENSTACK CINDER DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from cinder-api pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'cinder-api.log' $LOGPATH/files >$LOGPATH/mos-openstack-cinder-api
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-cinder-api
  echo "" >>"$OUT"
  echo "## Logs from cinder-volume pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'cinder-volume.log' $LOGPATH/files >$LOGPATH/mos-openstack-cinder-volume
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-cinder-volume
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_glance"
  echo "Gathering MOS Openstack Glance logs..."
  echo "################# [MOS OPENSTACK GLANCE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from glance-api pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep '/glance-api.log' $LOGPATH/files >$LOGPATH/mos-openstack-glance-api
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-glance-api
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_horizon"
  echo "Gathering MOS Openstack Horizon logs..."
  echo "################# [MOS OPENSTACK HORIZON DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from horizon pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'horizon.log' $LOGPATH/files >$LOGPATH/mos-openstack-horizon
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-horizon
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack_rabbitmq"
  echo "Gathering MOS Openstack RabbitMQ logs..."
  echo "################# [MOS OPENSTACK RABBITMQ DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from rabbitmq pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep '/rabbitmq.log' $LOGPATH/files >$LOGPATH/mos-openstack-rabbitmq
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E '\[warning\]|\[error\]' $line | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-rabbitmq
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_mariadb"
  echo "Gathering MOS Mariadb details and logs..."
  echo "################# [MOS MARIADB DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Configmap:" >>"$OUT"
  MARIADB_CM=$(find "$MOS_DIR" -name "openstack-mariadb-mariadb-state.yaml" 2>/dev/null | head -n 1)
  if [[ -f "$MARIADB_CM" ]]; then
    echo "# $MARIADB_CM:" >>"$OUT"
    sed -n '/  data:/,/    creationTimestamp:/p' "$MARIADB_CM" >>"$OUT"
  fi
  echo "" >>"$OUT"
  echo "## Logs from controller pod (Errors/Warnings):" >>"$OUT"
  CONTROLLER_LOG=$(find "$MOS_DIR" -path "*/mariadb-controller-*/controller.log" 2>/dev/null | head -n 1)
  if [[ -f "$CONTROLLER_LOG" ]]; then
    echo "# $CONTROLLER_LOG:" >>"$OUT"
    grep -iE 'error|fail|warn' "$CONTROLLER_LOG" | sed -E '/^[[:space:]]*$/d' >>"$OUT"
  fi
  echo "" >>"$OUT"
  
  for i in 0 1 2; do
    echo "## Logs from server-$i pods (Errors/Warnings):" >>"$OUT"
    SERVER_LOG=$(find "$MOS_DIR" -path "*/mariadb-server-$i/mariadb.log" 2>/dev/null | head -n 1)
    if [[ -f "$SERVER_LOG" ]]; then
      echo "# $SERVER_LOG:" >>"$OUT"
      awk '/ERR|WARN/ && !/WARNING - Collision writing configmap/ && NF' "$SERVER_LOG" >>"$OUT"
    fi
    echo "" >>"$OUT"
  done
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_ipamhost"
  echo "Gathering MOS Ipamhost details..."
  echo "################# [MOS IPAMHOST DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep $MCC_DIR/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/ipamhosts/ $LOGPATH/files >$LOGPATH/mos-ipamhost
  printf '## Ipamhosts' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-ipamhost))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mos-ipamhost >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-ipamhost
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_l2template"
  echo "Gathering MOS L2template details..."
  echo "################# [MOS L2TEMPLATE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep $MCC_DIR/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/l2templates/ $LOGPATH/files >$LOGPATH/mos-l2template
  printf '## L2templates' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-l2template))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mos-l2template >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-l2template
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_subnet"
  echo "Gathering MCC subnet details..."
  echo "################# [MCC SUBNET DETAILS & AUDIT] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files >$LOGPATH/mcc-subnet
  
  echo "## IPAM SUBNETS (Ranges Resume):" >>"$OUT"
  while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      CIDR=$(yq eval "${PREFIX}.spec.cidr" "$f" 2>/dev/null)
      INC=$(yq eval "${PREFIX}.spec.includeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      EXC=$(yq eval "${PREFIX}.spec.excludeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      echo "----------------------------------------------------" >>"$OUT"
      printf "Subnet:  %s\n" "$NAME" >>"$OUT"
      printf "CIDR:    %s\n" "$CIDR" >>"$OUT"
      printf "Include: [%s]\n" "${INC:-None}" >>"$OUT"
      printf "Exclude: [%s]\n" "${EXC:-None}" >>"$OUT"
      echo "$CIDR,$INC" >>"$LOGPATH/mcc_ip_collect"
    fi
  done <$LOGPATH/mcc-subnet

  # Audit IPAddressPools (MetalLB)
  echo -e "\n## METALLB IP POOLS:" >>"$OUT"
  grep "$MCCNAME" "$LOGPATH/files" | grep "ipaddresspools/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      ADDR=$(yq eval "${PREFIX}.spec.addresses[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      printf "Pool: %-20s | Ranges: [%s]\n" "$NAME" "$ADDR" >>"$OUT"
      echo "$ADDR" >>"$LOGPATH/mcc_ip_collect"
    fi
  done

  if [[ -f "$LOGPATH/mcc_ip_collect" ]]; then
    echo -e "\n## OVERLAP VERIFICATION:" >>"$OUT"
    check_overlaps <"$LOGPATH/mcc_ip_collect" >>"$OUT"
    rm "$LOGPATH/mcc_ip_collect"
  fi

  echo -e "\n## Full Subnet YAML Details:" >>"$OUT"
  while read -r line; do
    echo "----------------------------------------------------" >>"$OUT"
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mcc-subnet
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_subnet"
  echo "Gathering MOS subnet details..."
  echo "################# [MOS SUBNET DETAILS & AUDIT] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files >$LOGPATH/mos-subnet
  
  echo "## IPAM SUBNETS (Ranges Resume):" >>"$OUT"
  while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      CIDR=$(yq eval "${PREFIX}.spec.cidr" "$f" 2>/dev/null)
      INC=$(yq eval "${PREFIX}.spec.includeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      EXC=$(yq eval "${PREFIX}.spec.excludeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      echo "----------------------------------------------------" >>"$OUT"
      printf "Subnet:  %s\n" "$NAME" >>"$OUT"
      printf "CIDR:    %s\n" "$CIDR" >>"$OUT"
      printf "Include: [%s]\n" "${INC:-None}" >>"$OUT"
      printf "Exclude: [%s]\n" "${EXC:-None}" >>"$OUT"
      echo "$CIDR,$INC" >>"$LOGPATH/mos_ip_collect"
    fi
  done <$LOGPATH/mos-subnet

  # Audit IPAddressPools (MetalLB)
  echo -e "\n## METALLB IP POOLS:" >>"$OUT"
  grep "$MOSNAME" "$LOGPATH/files" | grep "ipaddresspools/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      ADDR=$(yq eval "${PREFIX}.spec.addresses[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      printf "Pool: %-20s | Ranges: [%s]\n" "$NAME" "$ADDR" >>"$OUT"
      echo "$ADDR" >>"$LOGPATH/mos_ip_collect"
    fi
  done

  if [[ -f "$LOGPATH/mos_ip_collect" ]]; then
    echo -e "\n## OVERLAP VERIFICATION:" >>"$OUT"
    check_overlaps <"$LOGPATH/mos_ip_collect" >>"$OUT"
    rm "$LOGPATH/mos_ip_collect"
  fi

  echo -e "\n## Full Subnet YAML Details:" >>"$OUT"
  while read -r line; do
    echo "----------------------------------------------------" >>"$OUT"
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-subnet
fi

if [[ -n "$MOSNAME" ]] && [[ -d "$MOS_DIR/objects/namespaced/tf" ]]; then
  OUT="$LOGPATH/mos_tf_status"
  echo "Gathering MOS TF Status..."
  echo "################# [MOS TF COMPONENT STATUS] #################" >"$OUT"
  TF_FILES=$(find "$MOS_DIR/objects/namespaced/tf" -name "*.yaml" -maxdepth 3 2>/dev/null)
  for f in $TF_FILES; do
    KIND=$(yq eval '.Object.kind // .kind' "$f" 2>/dev/null)
    [[ "$KIND" == "Pod" || "$KIND" == "Endpoints" || "$KIND" == "Service" ]] && continue
    echo "----------------------------------------------------" >>"$OUT"
    echo "# [FILE]: $f" >>"$OUT"
    echo "### Component: $(basename "$f" .yaml) ($KIND)" >>"$OUT"
    yq eval '.Object.status // .status' "$f" 2>/dev/null >>"$OUT"
  done

  OUT="$LOGPATH/mos_tf_logs"
  echo "Gathering MOS TF logs..."
  echo "################# [MOS TF LOGS DETAILS] #################" >"$OUT"

  echo '## TF control logs (Errors/Warnings - last 150 lines)' >>"$OUT"
  grep tf-control- "$LOGPATH/files" | grep log >$LOGPATH/mos-tf-control
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' "$line" | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-tf-control

  echo '## TF config logs (Errors/Warnings - last 150 lines)' >>"$OUT"
  grep tf-config- "$LOGPATH/files" | grep log >$LOGPATH/mos-tf-config
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' "$line" | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-tf-config

  echo '## TF vrouter logs (Errors/Warnings - last 150 lines)' >>"$OUT"
  grep tf-vrouter- "$LOGPATH/files" | grep log >$LOGPATH/mos-tf-vrouter
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' "$line" | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-tf-vrouter

  echo '## TF rabbitmq logs (Errors/Warnings - last 150 lines):' >>"$OUT"
  grep /rabbitmq.log "$LOGPATH/files" | grep tf >$LOGPATH/mos-tf-rabbitmq
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E '\[warning\]|\[error\]' "$line" | sed -E '/^[[:space:]]*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-tf-rabbitmq
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_upgrade_audit"
  echo "Gathering MCC Upgrade details..."
  echo "################# [MCC UPGRADE AUDIT] #################" >"$OUT"

  # 1. MCCUpgrade Object status
  echo "## MCC UPGRADE STATUS:" >>"$OUT"
  MCC_UPGRADE_FILE=$(grep "kaas.mirantis.com/mccupgrades/mcc-upgrade.yaml" "$LOGPATH/files")
  if [[ -f "$MCC_UPGRADE_FILE" ]]; then
    yq eval '.Object.status // .status' "$MCC_UPGRADE_FILE" 2>/dev/null >>"$OUT"
  else
    echo "mcc-upgrade.yaml not found." >>"$OUT"
  fi

  # 2. ClusterUpdatePlans (MOS Upgrade Status)
  echo -e "\n## CLUSTER UPDATE PLANS (MOS Upgrade Status):" >>"$OUT"
  grep "kaas.mirantis.com/clusterupdateplans/" "$LOGPATH/files" | while read -r f; do
    if [[ -f "$f" ]]; then
      PLAN_NAME=$(basename "$f" .yaml)
      echo "----------------------------------------------------" >>"$OUT"
      echo "### Plan: $PLAN_NAME" >>"$OUT"
      
      # Check if any step has commence: true
      ACTIVE_STEPS=$(yq eval '.Object.spec.steps[] | select(.commence == true) | .id' "$f" 2>/dev/null)
      if [[ -n "$ACTIVE_STEPS" ]]; then
        echo ">>> [!] MOS UPGRADE IS CURRENTLY ONGOING!" >>"$OUT"
        echo ">>> Active steps: $(echo "$ACTIVE_STEPS" | tr '\n' ' ')" >>"$OUT"
      else
        echo ">>> [ ] Upgrade is INACTIVE (All steps set to commence: false)" >>"$OUT"
      fi
      
      echo -e "\nFull Plan Spec:" >>"$OUT"
      yq eval '.Object.spec // .spec' "$f" 2>/dev/null >>"$OUT"
      echo -e "\nPlan Status:" >>"$OUT"
      yq eval '.Object.status // .status' "$f" 2>/dev/null >>"$OUT"
    fi
  done

  # 3. Release Controller Health (RBAC/Discovery)
  echo -e "\n## RELEASE CONTROLLER HEALTH (Logs Analysis):" >>"$OUT"
  REL_POD_LOGS=$(grep "release-controller" "$LOGPATH/files" | grep ".log")
  if [[ -n "$REL_POD_LOGS" ]]; then
    for log in $REL_POD_LOGS; do
      echo "### Log: $(basename "$log")" >>"$OUT"
      grep -iE "error|fail|rbac|permission|denied|forbidden" "$log" | tail -n 20 >>"$OUT"
    done
  else
    echo "No release-controller logs found." >>"$OUT"
  fi

  # 4. Identify Common Blockers (Ceph missing devices, Webhook failures)
  echo -e "\n## UPGRADE BLOCKERS (Ceph/Webhooks):" >>"$OUT"
  # Check for Ceph device issues
  grep -r "doesn't have specified device" "$MCC_DIR/objects" 2>/dev/null | head -n 10 >>"$OUT"
  # Check for Webhook validation failures
  grep -r "validations.kaas.mirantis.com" "$MCC_DIR/objects" 2>/dev/null | grep -i "denied" | head -n 10 >>"$OUT"
  # Check Admission Controller logs
  ADM_POD_LOGS=$(grep "admission-controller" "$LOGPATH/files" | grep ".log")
  for log in $ADM_POD_LOGS; do
     echo "### Log: $(basename "$log")" >>"$OUT"
     grep -iE "mos-21.0.5|denied|failed to call webhook" "$log" | tail -n 10 >>"$OUT"
  done
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_pv_pvc"
  echo "Gathering MOS PV and PVC Correlation details..."
  echo "################# [MOS PV AND PVC CORRELATION] #################" >"$OUT"

  PV_FILES=$(grep "$MOS_DIR/objects/cluster/core/persistentvolumes/" "$LOGPATH/files")
  PVC_FILES=$(grep "persistentvolumeclaims" "$LOGPATH/files" | grep "$MOSNAME")

  echo "## Bound PV-PVC Pairs:" >>"$OUT"
  PROCESSED_PVC=$(mktemp -t myrha_pvc)

  for pv in $PV_FILES; do
    PV_NAME=$(basename "$pv" .yaml)
    CLAIM_NS=$(yq eval '.Object.spec.claimRef.namespace // .spec.claimRef.namespace' "$pv" 2>/dev/null)
    CLAIM_NAME=$(yq eval '.Object.spec.claimRef.name // .spec.claimRef.name' "$pv" 2>/dev/null)

    if [[ -n "$CLAIM_NAME" && "$CLAIM_NAME" != "null" ]]; then
      echo "----------------------------------------------------" >>"$OUT"
      echo "### PV: $PV_NAME <-> PVC: $CLAIM_NS/$CLAIM_NAME" >>"$OUT"
      echo "#### PV Details ($pv):" >>"$OUT"
      yq eval '.Object.spec // .spec' "$pv" 2>/dev/null >>"$OUT"
      yq eval '.Object.status // .status' "$pv" 2>/dev/null >>"$OUT"

      MATCHING_PVC=$(echo "$PVC_FILES" | grep "/$CLAIM_NS/" | grep "/$CLAIM_NAME.yaml" | head -n 1)
      if [[ -n "$MATCHING_PVC" ]]; then
        echo -e "\n#### Bound PVC Details ($MATCHING_PVC):" >>"$OUT"
        yq eval '.Object.spec // .spec' "$MATCHING_PVC" 2>/dev/null >>"$OUT"
        yq eval '.Object.status // .status' "$MATCHING_PVC" 2>/dev/null >>"$OUT"
        echo "$MATCHING_PVC" >>"$PROCESSED_PVC"
      else
        echo -e "\n#### Bound PVC: $CLAIM_NS/$CLAIM_NAME (YAML NOT FOUND IN DUMP)" >>"$OUT"
      fi
    fi
  done

  echo -e "\n## Unbound or Standalone PVs:" >>"$OUT"
  for pv in $PV_FILES; do
    CLAIM_NAME=$(yq eval '.Object.spec.claimRef.name // .spec.claimRef.name' "$pv" 2>/dev/null)
    if [[ -z "$CLAIM_NAME" || "$CLAIM_NAME" == "null" ]]; then
      echo "----------------------------------------------------" >>"$OUT"
      echo "### PV: $(basename "$pv" .yaml) (Unbound)" >>"$OUT"
      yq eval '.Object.spec // .spec' "$pv" 2>/dev/null >>"$OUT"
    fi
  done

  echo -e "\n## Unbound or Remaining PVCs:" >>"$OUT"
  for pvc in $PVC_FILES; do
    if ! grep -q "$pvc" "$PROCESSED_PVC"; then
      echo "----------------------------------------------------" >>"$OUT"
      echo "### PVC: $(basename "$pvc" .yaml) ($(yq eval '.Object.metadata.namespace // .metadata.namespace' "$pvc" 2>/dev/null))" >>"$OUT"
      yq eval '.Object.spec // .spec' "$pvc" 2>/dev/null >>"$OUT"
      yq eval '.Object.status // .status' "$pvc" 2>/dev/null >>"$OUT"
    fi
  done

  # --- SUMMARY RESUME ---
  echo -e "\n################# [PV <-> PVC SUMMARY RESUME] #################" >>"$OUT"
  printf "%-50s | %-50s\n" "PERSISTENT VOLUME" "BOUND PVC (NAMESPACE/NAME)" >>"$OUT"
  echo "------------------------------------------------------------------------------------------------------" >>"$OUT"
  for pv in $PV_FILES; do
    PV_NAME=$(basename "$pv" .yaml)
    CLAIM_NS=$(yq eval '.Object.spec.claimRef.namespace // .spec.claimRef.namespace' "$pv" 2>/dev/null)
    CLAIM_NAME=$(yq eval '.Object.spec.claimRef.name // .spec.claimRef.name' "$pv" 2>/dev/null)
    if [[ -n "$CLAIM_NAME" && "$CLAIM_NAME" != "null" ]]; then
      printf "%-50s | %-50s\n" "$PV_NAME" "$CLAIM_NS/$CLAIM_NAME" >>"$OUT"
    else
      printf "%-50s | %-50s\n" "$PV_NAME" "[UNBOUND]" >>"$OUT"
    fi
  done
  rm "$PROCESSED_PVC"
fi

# --- STORAGE & CSI AUDIT ---
OUT="$LOGPATH/cluster_storage_csi"
echo "Gathering Storage Class and CSI details..."
echo "################# [STORAGE CLASS & CSI AUDIT] #################" >"$OUT"
echo "## Storage Classes:" >>"$OUT"
find "$BASE_DIR" -path "*/storage.k8s.io/storageclasses/*.yaml" 2>/dev/null | while read -r f; do
  echo "### SC: $(basename "$f" .yaml)" >>"$OUT"
  yq eval '.Object.provisioner // .provisioner' "$f" 2>/dev/null | xargs printf "  Provisioner: %s\n" >>"$OUT"
  yq eval '.Object.parameters // .parameters' "$f" 2>/dev/null >>"$OUT"
done

echo -e "\n## CSI Nodes Status:" >>"$OUT"
find "$BASE_DIR" -path "*/storage.k8s.io/csinodes/*.yaml" 2>/dev/null | while read -r f; do
  echo "### Node: $(basename "$f" .yaml)" >>"$OUT"
  yq eval '.Object.spec.drivers[] | .name' "$f" 2>/dev/null | xargs printf "  Active Drivers: %s\n" >>"$OUT"
done

# MCC Analysis
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_cluster"
  echo "Gathering MCC cluster details..."
  echo "################# [MCC CLUSTER DETAILS] #################" >"$OUT"
  MCC_YAML="$MCC_DIR/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml"
  if [[ -f "$MCC_YAML" ]]; then
    K_RAW=$(grep -m1 "release: kaas-" "$MCC_YAML" | sed -e 's/.*kaas-//' -e 's/[[:space:]]//g' -e 's/-/./g')
    IFS='.' read -r -a M <<<"$K_RAW"
    printf "## MCC Version release details: ${M[0]}.${M[1]}.${M[2]}" >>"$OUT"
    echo "" >>"$OUT"
    echo "https://docs.mirantis.com/container-cloud/latest/release-notes/releases/${M[0]}-${M[1]}-${M[2]}.html" >>"$OUT"
    echo "https://docs.mirantis.com/container-cloud/latest/release-notes/releases/${M[0]}-${M[1]}-${M[2]}/known-${M[0]}-${M[1]}-${M[2]}.html" >>"$OUT"
    MCC_BUG_VER="${M[0]}.${M[1]}.${M[2]}"
    echo "" >>"$OUT"
    printf "## MCC Bugs - $MCC_BUG_VER:" >>"$OUT"
    echo "" >>"$OUT"
    # Jira (MCC)
    [[ "$MCC_BUG_VER" == "2.23.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.2%20%2F%20MOSK%2023.1.1%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.23.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.3%20%2F%20MOSK%2023.1.2%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.23.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.4%20%2F%20MOSK%2023.1.3%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.23.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.5%20%2F%20MOSK%2023.1.4%20%28Patch%20release%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.24.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.3%20%2F%20MOSK%2023.2.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.24.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.4%20%2F%20MOSK%2023.2.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.24.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.5%20%2F%20MOSK%2023.2.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.25%20%2F%20MOSK%2023.3%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.1%20%2F%20MOSK%2023.3.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.2%20%2F%20MOSK%2023.3.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.3%20%2F%20MOSK%2023.3.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.4%20%2F%20MOSK%2023.3.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26%20%2F%20MOSK%2024.1%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.1%20%2F%20MOSK%2024.1.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.2%20%2F%20MOSK%2024.1.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.3%20%2F%20MOSK%2024.1.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.4%20%2F%20MOSK%2024.1.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.5%20%2F%20MOSK%2024.1.5%20%28Patch%20release5%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.27%20%2F%20MOSK%2024.2%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.1%20%2F%20MOSK%2024.1.6%20%28Patch%20release6%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.2%20%2F%20MOSK%2024.1.7%20%28Patch%20release7%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.3%20%2F%20MOSK%2024.2.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.4%20%2F%20MOSK%2024.2.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28%20%2F%20MOSK%2024.3%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.1%20%2F%20MOSK%2024.2.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.2%20%2F%20MOSK%2024.2.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.3%20%2F%20MOSK%2024.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.4%20%2F%20MOSK%2024.3.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.5%20%2F%20MOSK%2024.3.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29%20%2F%20MOSK%2025.1%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.1%20%2F%20MOSK%2024.3.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.2%20%2F%20MOSK%2024.3.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.3%20%2F%20MOSK%2024.3.5%20%28Patch%20release5%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.4%20%2F%20MOSK%2024.3.6%20%28Patch%20release6%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.5%20%2F%20MOSK%2024.3.7%20%28Patch%20release7%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30%20%2F%20MOSK%2025.2%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.1%20%2F%20MOSK%2025.2.1%20(Patch%20release1)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.2%20%2F%20MOSK%2025.2.2%20(Patch%20release2)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.3%20%2F%20MOSK%2025.2.3%20(Patch%20release3)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.4%20%2F%20MOSK%2025.2.4%20(Patch%20release4)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31%20%2F%20MOSK%2026.1%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.1%20%2F%20MOSK%2025.2.6%20(Patch%20release6)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.2%20%2F%20MOSK%2025.2.7%20(Patch%20release7)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.3%20%2F%20MOSK%2025.2.8%20(Patch%20release8)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.4%20%2F%20MOSK%2025.2.9%20(Patch%20release9)%22" >>"$OUT"
    # Improved MKE Extraction
    MKE_RAW=$(grep -m1 "release: mke-" "$MCC_YAML" | sed -e 's/.*mke-//' -e 's/[[:space:]]//g' -e 's/-/./g')
    IFS='.' read -r -a E <<<"$MKE_RAW"
    MKE_VER_FULL="${E[3]}.${E[4]}.${E[5]}"
    MKE_SHORT="${E[3]}.${E[4]}"
    MKE_FULL_FILE="${E[3]}-${E[4]}-${E[5]}"
    
    MKE_DOC_URL="https://docs.mirantis.com/mke/$MKE_SHORT/release-notes/$MKE_FULL_FILE.html"
    MKE_KNOWN_URL="https://docs.mirantis.com/mke/$MKE_SHORT/release-notes/$MKE_FULL_FILE/known-issues.html"

    MCC_LINKS_HTML="<div style=\"margin-bottom: 10px;\"><strong>MCC Bugs - $MCC_BUG_VER:</strong><br><a href=\"$MCC_DOC_URL\" target=\"_blank\">Release Notes</a> | <a href=\"$MCC_JIRA_URL\" target=\"_blank\">Jira Bugs</a></div><div><strong>MKE Version: $MKE_VER_FULL</strong><br><a href=\"$MKE_DOC_URL\" target=\"_blank\">Release Notes</a> | <a href=\"$MKE_KNOWN_URL\" target=\"_blank\">Known Issues</a></div>"

    echo "## Details and versions:" >>"$OUT"
    printf '# ' >>"$OUT"
    ls $MCC_YAML >>"$OUT"
    grep -E "release: kaas-|release: mke-|      - message" "$MCC_YAML" >>"$OUT"
    sed -n '/          stacklight:/,/      kind:/p' "$MCC_YAML" >>"$OUT"
    echo "" >>"$OUT"
    echo "## LCM status:" >>"$OUT"
    printf '# ' >>"$OUT"
    LCM_MCC="$MCC_DIR/objects/namespaced/$MCCNAMESPACE/lcm.mirantis.com/lcmclusters/$MCCNAME.yaml"
    if [[ -f "$LCM_MCC" ]]; then
      ls $LCM_MCC >>"$OUT"
      # Extract full stuck message if exists
      STUCK_MSG=$(yq eval '.Object.status.lcmOperationStuckMessage // .status.lcmOperationStuckMessage' "$LCM_MCC" 2>/dev/null)
      if [[ -n "$STUCK_MSG" && "$STUCK_MSG" != "null" ]]; then
        echo "  lcmOperationStuckMessage: $STUCK_MSG" >>"$OUT"
      fi
      sed -n '/  status:/,/    requestedNodes:/p' $LCM_MCC >>"$OUT"
    fi

    # Logs from lcm-lcm-controller
    echo -e "\n## LCM Controller Logs (Errors/Warnings):" >>"$OUT"
    find "$MCC_DIR" -path "*/kaas/core/pods/lcm-lcm-controller-*/controller.log" | sort | while read -r log; do
      echo "### Pod: /${log#./}" >>"$OUT"
      grep -Ei "error|fail|warning|warn" "$log" | tail -n 20 >>"$OUT"
    done

    echo "Gathering Node Conditions..."
    echo "" >>"$OUT"
    echo "################# [NODE CONDITIONS] #################" >>"$OUT"
    for nf in $(grep "/core/nodes" "$LOGPATH/files" | grep "$MCC_DIR"); do
      N_NAME=$(basename "$nf" .yaml)
      # Extract conditions using yq
      READY=$(yq eval '.Object.status.conditions[] | select(.type=="Ready") | .status' "$nf" 2>/dev/null)
      DISK=$(yq eval '.Object.status.conditions[] | select(.type=="DiskPressure") | .status' "$nf" 2>/dev/null)
      # Default to Unknown if extraction failed
      [[ -z "$READY" ]] && READY="Unknown"
      [[ -z "$DISK" ]] && DISK="Unknown"
      printf "Node: %-50s | Ready: %-8s | DiskPressure: %-8s\n" "$N_NAME" "$READY" "$DISK" >>"$OUT"
    done
  #add_to_html "MCC Cluster Details" "$(cat "$OUT")"
  fi
fi
# 5. MCC Stacklight & Patroni Details Card
if [[ -d "$MCC_DIR/objects/namespaced/stacklight" ]]; then
  OUT="$LOGPATH/mcc_stacklight"
  echo "Gathering MCC Stacklight details..."
  echo "################# [MCC STACKLIGHT & PATRONI DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"

  echo "## Patroni Cluster Status (from Pod annotations):" >>"$OUT"
  # Find all patroni pod YAMLs
  find "$MCC_DIR" -path "*/stacklight/core/pods/patroni-*.yaml" 2>/dev/null | sort | while read -r pf; do
    POD_NAME=$(basename "$pf" .yaml)
    # Extract the JSON status from annotations
    P_STATUS=$(yq eval '.Object.metadata.annotations.status // .metadata.annotations.status' "$pf" 2>/dev/null)
    if [[ -n "$P_STATUS" && "$P_STATUS" != "null" ]]; then
       # Format JSON-like string into readable output
       ROLE=$(echo "$P_STATUS" | grep -oE '"role":"[^"]+"' | cut -d'"' -f4)
       STATE=$(echo "$P_STATUS" | grep -oE '"state":"[^"]+"' | cut -d'"' -f4)
       REPL=$(echo "$P_STATUS" | grep -oE '"replication_state":"[^"]+"' | cut -d'"' -f4)
       printf "Pod: %-25s | Role: %-10s | State: %-10s | Repl: %s\n" "$POD_NAME" "$ROLE" "$STATE" "$REPL" >>"$OUT"
    else
       echo "Pod: $POD_NAME | Status annotation not found" >>"$OUT"
    fi
  done

  echo -e "\n## Stacklight Deployment Status:" >>"$OUT"
  HELMB_FILE=$(ls "$MCC_DIR/objects/namespaced/stacklight/lcm.mirantis.com/helmbundles/"*.yaml 2>/dev/null | head -n 1)
  if [[ -f "$HELMB_FILE" ]]; then
    echo "### File: $HELMB_FILE" >>"$OUT"
    yq eval '.Object.status // .status' "$HELMB_FILE" 2>/dev/null >>"$OUT"
  fi
fi

# 6. MCC Credentials Card
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_credentials"
  echo "Scanning MCC Secrets for Credentials..."
  TMP_CREDS="$LOGPATH/mcc_creds_other"
  TMP_TOKENS="$LOGPATH/mcc_creds_tokens"
  echo "################# [MCC CREDENTIALS (DECRYPTED)] #################" >"$OUT"
  echo "" > "$TMP_CREDS"
  echo "" > "$TMP_TOKENS"

  find "$MCC_DIR" -path "*/core/secrets/*.yaml" -type f | while read -r secret_file; do
    DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
    KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$secret_file" 2>/dev/null)
    
    FILE_BUF_CREDS=""
    FILE_BUF_TOKENS=""

    for KEY in $KEYS; do
      if [[ "$KEY" =~ user|pass|login|account|creds|secret|token|key ]]; then
        VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$secret_file" 2>/dev/null)
        DECODED=$(echo "$VAL" | base64 -d 2>/dev/null)
        
        IS_TLS=false
        if [[ -n "$DECODED" ]]; then
           if echo "$DECODED" | grep -qEi "BEGIN CERTIFICATE|BEGIN .* PRIVATE KEY|BEGIN .* KEY|BEGIN PKCS7|BEGIN X509|SSH PRIVATE KEY"; then
             IS_TLS=true
           fi
        elif echo "$VAL" | grep -qEi "BEGIN CERTIFICATE|BEGIN .* PRIVATE KEY|BEGIN .* KEY|BEGIN PKCS7|BEGIN X509|SSH PRIVATE KEY"; then
             IS_TLS=true
        fi
        
        if [[ "$KEY" =~ (tls|cert|crt|ca|pem|key|pub|authorized_keys) ]]; then
           IS_TLS=true
        fi

        if [ "$IS_TLS" = true ]; then
           continue
        fi

        TARGET_BUF="FILE_BUF_CREDS"
        [[ "$KEY" =~ token ]] && TARGET_BUF="FILE_BUF_TOKENS"

        ENTRY=""
        if [[ -n "$DECODED" ]]; then
           if [[ "$DECODED" =~ [^[:print:][:space:]] ]]; then
             ENTRY=$(printf "🔑 %-30s : [BINARY DATA]\n" "$KEY")
           else
             LINE_COUNT=$(echo "$DECODED" | wc -l)
             if [ "$LINE_COUNT" -le 1 ]; then
               ENTRY=$(printf "🔑 %-30s : %s\n" "$KEY" "$DECODED")
             else
               ENTRY=$(printf "🔑 %-30s :\n" "$KEY")
               ENTRY+="$(echo "$DECODED" | sed 's/^/    /')\n"
             fi
           fi
        else
           ENTRY=$(printf "🔑 %-30s : %s\n" "$KEY" "$VAL")
        fi

        if [[ "$TARGET_BUF" == "FILE_BUF_CREDS" ]]; then
           FILE_BUF_CREDS+="$ENTRY"
        else
           FILE_BUF_TOKENS+="$ENTRY"
        fi
      fi
    done

    if [[ -n "$FILE_BUF_CREDS" ]]; then
       echo "----------------------------------------------------" >> "$TMP_CREDS"
       echo "## File: $secret_file" >> "$TMP_CREDS"
       echo -e "$FILE_BUF_CREDS" >> "$TMP_CREDS"
    fi
    if [[ -n "$FILE_BUF_TOKENS" ]]; then
       echo "----------------------------------------------------" >> "$TMP_TOKENS"
       echo "## File: $secret_file" >> "$TMP_TOKENS"
       echo -e "$FILE_BUF_TOKENS" >> "$TMP_TOKENS"
    fi
  done

  echo -e "\n## 🛡️ GENERAL CREDENTIALS:" >> "$OUT"
  cat "$TMP_CREDS" >> "$OUT"
  echo -e "\n## 🎟️ TOKENS:" >> "$OUT"
  cat "$TMP_TOKENS" >> "$OUT"
  rm "$TMP_CREDS" "$TMP_TOKENS"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_events"
  echo "Gathering MCC events..."
  echo "################# [MCC EVENTS (WARNING+ERRORS)] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Analyzed files:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MCC_DIR/objects/events.log >>"$OUT"
  grep -E "Warning|Error" $MCC_DIR/objects/events.log | sort -M >>"$OUT"
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_nodes"
  echo "Gathering MCC node details..."
  echo "################# [MCC NODE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep "/core/nodes" $LOGPATH/files | grep $MCCNAME >$LOGPATH/mcc-nodes
  printf "## Nodes" >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-nodes))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf '# '
    basename "$line" .yaml
  done <$LOGPATH/mcc-nodes >>"$OUT"
  while read -r line; do
    echo "" >>"$OUT"
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E "      kaas.mirantis.com/machine-name:" $line >>"$OUT"
    yq eval '.Object.status.nodeInfo // .status.nodeInfo' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status.conditions // .status.conditions' "$line" 2>/dev/null >>"$OUT"
  done <$LOGPATH/mcc-nodes
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_lcmmachine"
  echo "Gathering MCC LCM machine details..."
  echo "################# [MCC LCM MACHINE DETAILS] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/$MCCNAMESPACE/lcm.mirantis.com/lcmmachines $LOGPATH/files >$LOGPATH/mcc-lcmmachine
  echo "" >>"$OUT"
  printf '## Machines' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-lcmmachine))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mcc-lcmmachine >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mcc-lcmmachine
  echo "" >>"$OUT"
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_machine"
  echo "Gathering MCC machine details..."
  echo "################# [MCC MACHINE DETAILS] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/default/cluster.k8s.io/machines $LOGPATH/files >$LOGPATH/mcc-machine
  echo "" >>"$OUT"
  printf '## Machines' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-machine))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mcc-machine >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mcc-machine
  echo "" >>"$OUT"
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_mariadb"
  echo "Gathering MCC Mariadb details and logs..."
  echo "################# [MCC MARIADB DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Configmap:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MCC_DIR/objects/namespaced/kaas/core/configmaps/iam-mariadb-state.yaml >>"$OUT"
  sed -n '/  data:/,/    creationTimestamp:/p' $MCC_DIR/objects/namespaced/kaas/core/configmaps/iam-mariadb-state.yaml >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from controller pod (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-controller-*/controller.log >>"$OUT"
  grep -iE 'error|fail|warn' $MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-controller-*/controller.log | sed -E '/^[[:space:]]*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-0 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log >>"$OUT"
  awk '/ERR|WARN/ && !/WARNING - Collision writing configmap/ && NF' "$MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-1 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-server-1/mariadb.log >>"$OUT"
  awk '/ERR|WARN/ && !/WARNING - Collision writing configmap/ && NF' "$MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-2 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-server-2/mariadb.log >>"$OUT"
  awk '/ERR|WARN/ && !/WARNING - Collision writing configmap/ && NF' "$MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log" >>"$OUT"
fi
# --- MCC CERTIFICATE AUTO-SCAN ---
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_certs"
  echo "Scanning MCC Secrets for PEM data..."
  echo "################# [MCC CERTIFICATE & KEY] #################" >"$OUT"
  find "$MCC_DIR" -path "*/core/secrets/*.yaml" -type f | while read -r secret_file; do
    DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
    KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$secret_file" 2>/dev/null)
    FOUND_IN_FILE=false
    FILE_ALERTS=""
    for KEY in $KEYS; do
      VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$secret_file" 2>/dev/null)
      [[ -z "$VAL" ]] && continue
      RAW_PEM=$( (
        echo "$VAL" | base64 -d 2>/dev/null
        echo "$VAL"
      ) | grep -iE "BEGIN CERTIFICATE|BEGIN PRIVATE KEY")
      if [[ -n "$RAW_PEM" ]]; then
        FOUND_IN_FILE=true
        # Check for Self-Signed or Expiry to flag it early
        if [[ "$RAW_PEM" == *"BEGIN CERTIFICATE"* ]]; then
          CERT_CONT=$(echo "$VAL" | base64 -d 2>/dev/null)
          ISSUER=$(echo "$CERT_CONT" | openssl x509 -noout -issuer 2>/dev/null)
          SUBJECT=$(echo "$CERT_CONT" | openssl x509 -noout -subject 2>/dev/null)
          [[ "$ISSUER" == "$SUBJECT" ]] && FILE_ALERTS+=$'\n'"⚠️  ALERT: SELF-SIGNED detected in $KEY"
        fi
      fi
    done
    if [ "$FOUND_IN_FILE" = true ]; then
      echo "----------------------------------------------------" >>"$OUT"
      [[ -n "$FILE_ALERTS" ]] && echo "$FILE_ALERTS" >>"$OUT"
      echo "## File: $secret_file" >>"$OUT"
      audit_k8s_secret "$secret_file" >>"$OUT"
    fi
  done
fi
# --- MOS CERTIFICATE AUTO-SCAN ---
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_certs"
  echo "Scanning MOS Secrets for PEM data..."
  echo "################# [MOS CERTIFICATE & KEY] #################" >"$OUT"
  find "$MOS_DIR" -path "*/core/secrets/*.yaml" -type f | while read -r secret_file; do
    DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
    KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$secret_file" 2>/dev/null)
    FOUND_IN_FILE=false
    FILE_ALERTS=""
    for KEY in $KEYS; do
      VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$secret_file" 2>/dev/null)
      [[ -z "$VAL" ]] && continue
      RAW_PEM=$( (
        echo "$VAL" | base64 -d 2>/dev/null
        echo "$VAL"
      ) | grep -iE "BEGIN CERTIFICATE|BEGIN PRIVATE KEY")
      if [[ -n "$RAW_PEM" ]]; then
        FOUND_IN_FILE=true
        # Check for Self-Signed or Expiry to flag it early
        if [[ "$RAW_PEM" == *"BEGIN CERTIFICATE"* ]]; then
          CERT_CONT=$(echo "$VAL" | base64 -d 2>/dev/null)
          ISSUER=$(echo "$CERT_CONT" | openssl x509 -noout -issuer 2>/dev/null)
          SUBJECT=$(echo "$CERT_CONT" | openssl x509 -noout -subject 2>/dev/null)
          [[ "$ISSUER" == "$SUBJECT" ]] && FILE_ALERTS+=$'\n'"⚠️  ALERT: SELF-SIGNED detected in $KEY"
        fi
      fi
    done
    if [ "$FOUND_IN_FILE" = true ]; then
      echo "----------------------------------------------------" >>"$OUT"
      [[ -n "$FILE_ALERTS" ]] && echo "$FILE_ALERTS" >>"$OUT"
      echo "## File: $secret_file" >>"$OUT"
      audit_k8s_secret "$secret_file" >>"$OUT"
    fi
  done
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_ipamhost"
  echo "Gathering MCC Ipamhost details..."
  echo "################# [MCC IPAMHOST DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep $MCC_DIR/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/ipamhosts/ $LOGPATH/files >$LOGPATH/mcc-ipamhost
  printf '## Ipamhosts' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-ipamhost))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mcc-ipamhost >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mcc-ipamhost
fi
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_l2template"
  echo "Gathering MCC L2template details..."
  echo "################# [MCC L2TEMPLATE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep $MCC_DIR/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/l2templates/ $LOGPATH/files >$LOGPATH/mcc-l2template
  printf '## L2 templates' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-l2template))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mcc-l2template >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mcc-l2template
fi
# --- MCC NETWORKING (Subnets & IPPools) ---
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_networking_audit"
  echo "Gathering MOS Networking details..."
  echo "################# [MOS SUBNET & IPPOOL RESUME] #################" >"$OUT"

  # 1. Audit Subnets (usually found in MCC management namespace for MOS)
  echo "## IPAM SUBNETS (Ranges Resume):" >>"$OUT"
  grep "/$MOSNAMESPACE/" "$LOGPATH/files" | grep "ipam.mirantis.com/subnets/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      CIDR=$(yq eval "${PREFIX}.spec.cidr" "$f" 2>/dev/null)
      INC=$(yq eval "${PREFIX}.spec.includeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      EXC=$(yq eval "${PREFIX}.spec.excludeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

      echo "----------------------------------------------------" >>"$OUT"
      printf "Subnet:  %s\n" "$NAME" >>"$OUT"
      printf "CIDR:    %s\n" "$CIDR" >>"$OUT"
      printf "Include: [%s]\n" "${INC:-None}" >>"$OUT"
      printf "Exclude: [%s]\n" "${EXC:-None}" >>"$OUT"

      echo "$CIDR,$INC" >>"$LOGPATH/mos_ip_collect"
    fi
  done

  # 2. Audit IPAddressPools (MetalLB - inside MOS cluster)
  echo -e "\n## METALLB IP POOLS:" >>"$OUT"
  grep "$MOS_DIR" "$LOGPATH/files" | grep "ipaddresspools/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      ADDR=$(yq eval "${PREFIX}.spec.addresses[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      printf "Pool: %-20s | Ranges: [%s]\n" "$NAME" "$ADDR" >>"$OUT"

      echo "$ADDR" >>"$LOGPATH/mos_ip_collect"
    fi
  done

  # 3. Perform Overlap Check
  if [[ -f "$LOGPATH/mos_ip_collect" ]]; then
    echo -e "\n## OVERLAP VERIFICATION:" >>"$OUT"
    check_overlaps <"$LOGPATH/mos_ip_collect" >>"$OUT"
    rm "$LOGPATH/mos_ip_collect"
  fi

  # 4. Netchecker component audit (inside MOS cluster)
  echo -e "\n## NETCHECKER COMPONENTS STATUS (MOS):" >>"$OUT"
  find "$MOS_DIR" -path "*/netchecker/apps/*/*.yaml" 2>/dev/null | sort | while read -r f; do
    KIND=$(yq eval '.Object.kind // .kind' "$f" 2>/dev/null)
    [[ "$KIND" =~ ReplicaSet|ControllerRevision ]] && continue
    [[ -z "$KIND" || "$KIND" == "null" ]] && continue
    NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
    echo "----------------------------------------------------" >>"$OUT"
    echo "### $KIND: $NAME" >>"$OUT"
    IMAGE=$(yq eval '.Object.spec.template.spec.containers[0].image // .spec.template.spec.containers[0].image' "$f" 2>/dev/null)
    echo "  Image: $IMAGE" >>"$OUT"
    echo "  Status:" >>"$OUT"
    yq eval '.Object.status // .status' "$f" 2>/dev/null | sed 's/^/    /' >>"$OUT"
  done
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_networking_audit"
  echo "Gathering MCC Networking details..."
  echo "################# [MCC SUBNET & IPPOOL RESUME] #################" >"$OUT"

  # 1. Audit Subnets
  echo "## IPAM SUBNETS (Ranges Resume):" >>"$OUT"
  grep "$MCCNAME" "$LOGPATH/files" | grep "ipam.mirantis.com/subnets/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      CIDR=$(yq eval "${PREFIX}.spec.cidr" "$f" 2>/dev/null)
      # Extract arrays and format as single line
      INC=$(yq eval "${PREFIX}.spec.includeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      EXC=$(yq eval "${PREFIX}.spec.excludeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

      echo "----------------------------------------------------" >>"$OUT"
      printf "Subnet:  %s\n" "$NAME" >>"$OUT"
      printf "CIDR:    %s\n" "$CIDR" >>"$OUT"
      printf "Include: [%s]\n" "${INC:-None}" >>"$OUT"
      printf "Exclude: [%s]\n" "${EXC:-None}" >>"$OUT"

      # Collect for overlap check
      echo "$CIDR,$INC" >>"$LOGPATH/mcc_ip_collect"
    fi
  done

  # 2. Audit IPAddressPools (MetalLB)
  echo -e "\n## METALLB IP POOLS:" >>"$OUT"
  grep "$MCCNAME" "$LOGPATH/files" | grep "ipaddresspools/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      ADDR=$(yq eval "${PREFIX}.spec.addresses[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      printf "Pool: %-20s | Ranges: [%s]\n" "$NAME" "$ADDR" >>"$OUT"

      # Collect for overlap check
      echo "$ADDR" >>"$LOGPATH/mcc_ip_collect"
    fi
  done

  # 3. Perform Overlap Check
  if [[ -f "$LOGPATH/mcc_ip_collect" ]]; then
    echo -e "\n## OVERLAP VERIFICATION:" >>"$OUT"
    check_overlaps <"$LOGPATH/mcc_ip_collect" >>"$OUT"
    rm "$LOGPATH/mcc_ip_collect"
  fi

  # 4. Netchecker component audit (inside MCC cluster)
  echo -e "\n## NETCHECKER COMPONENTS STATUS (MCC):" >>"$OUT"
  find "$MCC_DIR" -path "*/netchecker/apps/*/*.yaml" 2>/dev/null | sort | while read -r f; do
    KIND=$(yq eval '.Object.kind // .kind' "$f" 2>/dev/null)
    [[ "$KIND" =~ ReplicaSet|ControllerRevision ]] && continue
    [[ -z "$KIND" || "$KIND" == "null" ]] && continue
    NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
    echo "----------------------------------------------------" >>"$OUT"
    echo "### $KIND: $NAME" >>"$OUT"
    IMAGE=$(yq eval '.Object.spec.template.spec.containers[0].image // .spec.template.spec.containers[0].image' "$f" 2>/dev/null)
    echo "  Image: $IMAGE" >>"$OUT"
    echo "  Status:" >>"$OUT"
    yq eval '.Object.status // .status' "$f" 2>/dev/null | sed 's/^/    /' >>"$OUT"
  done
fi

# --- BAREMETAL PROVIDER AUDIT ---
if [[ -n "$MCC_DIR" ]]; then
  OUT="$LOGPATH/mcc_baremetal_provider.yaml"
  echo "Gathering Baremetal Provider details..."
  echo "################# [BAREMETAL PROVIDER AUDIT] #################" >"$OUT"

  # 1. Deployment and Status
  BM_DEPLOY=$(find "$MCC_DIR" -path "*/kaas/apps/deployments/baremetal-provider.yaml" | head -n 1)
  if [[ -f "$BM_DEPLOY" ]]; then
    echo "# [FILE]: $BM_DEPLOY" >>"$OUT"
    echo "## Deployment Status:" >>"$OUT"
    yq eval '.Object.status // .status' "$BM_DEPLOY" 2>/dev/null | sed 's/^/  /' >>"$OUT"
    IMAGE=$(yq eval '.Object.spec.template.spec.containers[0].image // .spec.template.spec.containers[0].image' "$BM_DEPLOY" 2>/dev/null)
    echo "  Image: $IMAGE" >>"$OUT"
  fi

  # 2. Leader Election
  BM_LEASE=$(find "$MCC_DIR" -path "*/kaas/coordination.k8s.io/leases/baremetal-provider-leader-election.yaml" | head -n 1)
  if [[ -f "$BM_LEASE" ]]; then
    echo -e "\n## Leader Election:" >>"$OUT"
    HOLDER=$(yq eval '.Object.spec.holderIdentity // .spec.holderIdentity' "$BM_LEASE" 2>/dev/null)
    RENEW=$(yq eval '.Object.spec.renewTime // .spec.renewTime' "$BM_LEASE" 2>/dev/null)
    echo "  Current Leader: $HOLDER" >>"$OUT"
    echo "  Renew Time:     $RENEW" >>"$OUT"
  fi

  # 3. Config Details
  BM_CONFIG=$(find "$MCC_DIR" -path "*/kaas/core/configmaps/baremetal-provider-config.yaml" | head -n 1)
  if [[ -f "$BM_CONFIG" ]]; then
    echo -e "\n## Configuration (baremetal-provider-config):" >>"$OUT"
    yq eval '.Object.data // .data' "$BM_CONFIG" 2>/dev/null | sed 's/^/  /' >>"$OUT"
  fi

  # 4. Logs Audit (Errors/Warnings)
  echo -e "\n## Recent Log Errors/Warnings:" >>"$OUT"
  find "$MCC_DIR" -path "*/kaas/core/pods/baremetal-provider-*/manager.log" | sort | while read -r log; do
    POD_NAME=$(basename $(dirname "$log"))
    echo "----------------------------------------------------" >>"$OUT"
    echo "### Pod: $POD_NAME" >>"$OUT"
    grep -Ei "error|warning|warn|fail" "$log" | tail -n 20 >>"$OUT"
  done
fi

# --- HELPER: FORMAT POD LINE ---
get_age() {
  local f="$1"
  local CREATED=$(yq eval '.Object.metadata.creationTimestamp // .metadata.creationTimestamp' "$f" 2>/dev/null)
  local AGE="N/A"
  if [[ -n "$CREATED" && "$CREATED" != "null" ]]; then
    local NOW_SEC=$(date +%s)
    # macOS date expects -j -f for parsing
    local CREATED_SEC=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED" +%s 2>/dev/null)
    if [[ -n "$CREATED_SEC" ]]; then
      local DIFF=$((NOW_SEC - CREATED_SEC))
      if [ $DIFF -lt 0 ]; then DIFF=0; fi
      if [ $DIFF -ge 86400 ]; then
        AGE="$((DIFF / 86400))d"
      elif [ $DIFF -ge 3600 ]; then
        AGE="$((DIFF / 3600))h"
      elif [ $DIFF -ge 60 ]; then
        AGE="$((DIFF / 60))m"
      else
        AGE="${DIFF}s"
      fi
    fi
  fi
  echo "$AGE"
}

get_deployment_line() {
  local f="$1"
  local NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f" 2>/dev/null)
  local NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
  local READY=$(yq eval '.Object.status.readyReplicas // 0' "$f" 2>/dev/null)
  local TOTAL=$(yq eval '.Object.spec.replicas // 0' "$f" 2>/dev/null)
  local UPDATED=$(yq eval '.Object.status.updatedReplicas // 0' "$f" 2>/dev/null)
  local AVAILABLE=$(yq eval '.Object.status.availableReplicas // 0' "$f" 2>/dev/null)
  local AGE=$(get_age "$f")
  printf "%-25s %-50s %-8s %-12s %-12s %-10s\n" "$NS" "$NAME" "$READY/$TOTAL" "$UPDATED" "$AVAILABLE" "$AGE"
}

get_statefulset_line() {
  local f="$1"
  local NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f" 2>/dev/null)
  local NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
  local READY=$(yq eval '.Object.status.readyReplicas // 0' "$f" 2>/dev/null)
  local TOTAL=$(yq eval '.Object.spec.replicas // 0' "$f" 2>/dev/null)
  local AGE=$(get_age "$f")
  printf "%-25s %-50s %-8s %-10s\n" "$NS" "$NAME" "$READY/$TOTAL" "$AGE"
}

get_daemonset_line() {
  local f="$1"
  local NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f" 2>/dev/null)
  local NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
  local DESIRED=$(yq eval '.Object.status.desiredNumberScheduled // 0' "$f" 2>/dev/null)
  local CURRENT=$(yq eval '.Object.status.currentNumberScheduled // 0' "$f" 2>/dev/null)
  local READY=$(yq eval '.Object.status.numberReady // 0' "$f" 2>/dev/null)
  local UPDATED=$(yq eval '.Object.status.updatedNumberScheduled // 0' "$f" 2>/dev/null)
  local AVAILABLE=$(yq eval '.Object.status.numberAvailable // 0' "$f" 2>/dev/null)
  local NODE_SEL=$(yq eval '.Object.spec.template.spec.nodeSelector // {} | to_entries | map(.key + "=" + .value) | join(",")' "$f" 2>/dev/null | cut -c1-20)
  local AGE=$(get_age "$f")
  printf "%-25s %-50s %-8s %-8s %-8s %-10s %-10s %-22s %-10s\n" "$NS" "$NAME" "$DESIRED" "$CURRENT" "$READY" "$UPDATED" "$AVAILABLE" "${NODE_SEL:-<none>}" "$AGE"
}

get_pod_line() {
  local f="$1"
  local NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f" 2>/dev/null)
  local NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
  
  local READY_COUNT=$(yq eval '.Object.status.containerStatuses // [] | map(select(.ready == true)) | length' "$f" 2>/dev/null)
  local TOTAL_COUNT=$(yq eval '.Object.status.containerStatuses // [] | length' "$f" 2>/dev/null)
  
  local PHASE=$(yq eval '.Object.status.phase // .status.phase' "$f" 2>/dev/null)
  [[ "$PHASE" == "null" ]] && PHASE=""
  
  local REASON=$(yq eval '.Object.status.reason // .status.reason' "$f" 2>/dev/null)
  [[ "$REASON" == "null" ]] && REASON=""
  
  # Check for container waiting reasons (e.g. CrashLoopBackOff, ImagePullBackOff)
  local WAITING_REASON=$(yq eval '.Object.status.containerStatuses[] | select(.state.waiting != null) | .state.waiting.reason' "$f" 2>/dev/null | head -n 1)
  [[ "$WAITING_REASON" == "null" ]] && WAITING_REASON=""

  local STATUS="${REASON:-${WAITING_REASON:-$PHASE}}"
  [[ -z "$STATUS" || "$STATUS" == "null" ]] && STATUS="Unknown"
  
  # Calculate restarts
  local RESTARTS=$(yq eval '.Object.status.containerStatuses[].restartCount' "$f" 2>/dev/null | awk '{sum+=$1} END {print sum+0}')

  local NODE=$(yq eval '.Object.spec.nodeName // .spec.nodeName' "$f" 2>/dev/null)
  [[ "$NODE" == "null" ]] && NODE="N/A"

  # Calculate AGE (macOS version)
  local CREATED=$(yq eval '.Object.metadata.creationTimestamp // .metadata.creationTimestamp' "$f" 2>/dev/null)
  local AGE="N/A"
  if [[ -n "$CREATED" && "$CREATED" != "null" ]]; then
    local NOW_SEC=$(date +%s)
    # macOS date expects -j -f for parsing
    local CREATED_SEC=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED" +%s 2>/dev/null)
    if [[ -n "$CREATED_SEC" ]]; then
      local DIFF=$((NOW_SEC - CREATED_SEC))
      if [ $DIFF -lt 0 ]; then DIFF=0; fi
      if [ $DIFF -ge 86400 ]; then
        AGE="$((DIFF / 86400))d"
      elif [ $DIFF -ge 3600 ]; then
        AGE="$((DIFF / 3600))h"
      elif [ $DIFF -ge 60 ]; then
        AGE="$((DIFF / 60))m"
      else
        AGE="${DIFF}s"
      fi
    fi
  fi

  printf "%-25s %-50s %-8s %-20s %-10s %-10s %-25s\n" "$NS" "$NAME" "${READY_COUNT}/${TOTAL_COUNT}" "$STATUS" "$RESTARTS" "$AGE" "$NODE"
  }

# --- MCC POD AUDIT ---
if [[ -n "$MCC_DIR" ]]; then
  OUT_RUNNING="$LOGPATH/mcc_running_pods.yaml"
  OUT_FAILED="$LOGPATH/mcc_failed_completed_pods.yaml"

  echo "Auditing MCC Pods..."

  # Buffers
  BUF_RUNNING=$(mktemp -t myrha)
  BUF_FAILED=$(mktemp -t myrha)

  COUNT_RUNNING=0
  COUNT_FAILED=0

  HEADER=$(printf "%-25s %-50s %-8s %-20s %-10s %-10s %-25s\n" "NAMESPACE" "NAME" "READY" "STATUS" "RESTARTS" "AGE" "NODE")
  echo "$HEADER" >>"$BUF_RUNNING"
  echo "$HEADER" >>"$BUF_FAILED"
  echo "----------------------------------------------------" >>"$BUF_FAILED"

  # 1. Collect all files for the links at the top
  find "$MCC_DIR" -path "*/core/pods/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_RUNNING"
    echo "# [FILE]: $f" >>"$OUT_FAILED"
  done

  while read -r f; do
    PHASE=$(yq eval '.Object.status.phase // .status.phase' "$f" 2>/dev/null)
    LINE=$(get_pod_line "$f")
    NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
    NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f" 2>/dev/null)

    if [[ "$PHASE" == "Running" ]]; then
      ((MCC_RUNNING++))
      echo "$LINE" >>"$BUF_RUNNING"
    else
      if [[ "$PHASE" == "Succeeded" ]] || [[ "$PHASE" == "Completed" ]]; then
        ((MCC_COMPLETED++))
      else
        ((MCC_NON_RUNNING++))
        MCC_NON_RUNNING_LIST+="    - $NS/$NAME ($PHASE)\n"
      fi

      ((COUNT_FAILED++))
      echo "$LINE" >>"$BUF_FAILED"

      # Only gather logs for FAILED pods (not Succeeded/Completed)
      if [[ "$PHASE" != "Succeeded" && "$PHASE" != "Completed" ]]; then
        POD_LOG_DIR="${f%.yaml}"
        if [[ -d "$POD_LOG_DIR" ]]; then
          echo "#### Container Logs for $NAME:" >>"$BUF_FAILED"
          for logfile in "$POD_LOG_DIR"/*.log; do
            [[ -e "$logfile" ]] || continue
            echo "Log: $(basename "$logfile") (last 150 lines)" >>"$BUF_FAILED"
            tail -n 150 "$logfile" >>"$BUF_FAILED"
            echo "" >>"$BUF_FAILED"
          done
          echo "----------------------------------------------------" >>"$BUF_FAILED"
        fi
      fi
    fi
  done < <(find "$MCC_DIR" -path "*/core/pods/*.yaml" -type f)

  # Finalize files
  COUNT_RUNNING=$MCC_RUNNING
  echo "################# [MCC RUNNING PODS] (Total: $COUNT_RUNNING) #################" >"$OUT_RUNNING"
  cat "$BUF_RUNNING" >>"$OUT_RUNNING"

  echo "################# [MCC FAILED/COMPLETED PODS] (Total: $COUNT_FAILED) #################" >"$OUT_FAILED"
  cat "$BUF_FAILED" >>"$OUT_FAILED"

  rm "$BUF_RUNNING" "$BUF_FAILED"
fi

# --- MOS POD AUDIT ---
if [[ -n "$MOS_DIR" ]]; then
  OUT_RUNNING="$LOGPATH/mos_running_pods.yaml"
  OUT_FAILED="$LOGPATH/mos_failed_completed_pods.yaml"

  echo "Auditing MOS Pods..."

  # Buffers
  BUF_RUNNING=$(mktemp -t myrha)
  BUF_FAILED=$(mktemp -t myrha)

  COUNT_RUNNING=0
  COUNT_FAILED=0

  HEADER=$(printf "%-25s %-50s %-8s %-20s %-10s %-10s %-25s\n" "NAMESPACE" "NAME" "READY" "STATUS" "RESTARTS" "AGE" "NODE")
  echo "$HEADER" >>"$BUF_RUNNING"
  echo "$HEADER" >>"$BUF_FAILED"
  echo "----------------------------------------------------" >>"$BUF_FAILED"

  # 1. Collect all files for the links at the top
  find "$MOS_DIR" -path "*/core/pods/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_RUNNING"
    echo "# [FILE]: $f" >>"$OUT_FAILED"
  done

  while read -r f; do
    PHASE=$(yq eval '.Object.status.phase // .status.phase' "$f" 2>/dev/null)
    LINE=$(get_pod_line "$f")
    NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f" 2>/dev/null)
    NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f" 2>/dev/null)

    if [[ "$PHASE" == "Running" ]]; then
      ((MOS_RUNNING++))
      echo "$LINE" >>"$BUF_RUNNING"
    else
      if [[ "$PHASE" == "Succeeded" ]] || [[ "$PHASE" == "Completed" ]]; then
        ((MOS_COMPLETED++))
      else
        ((MOS_NON_RUNNING++))
        MOS_NON_RUNNING_LIST+="    - $NS/$NAME ($PHASE)\n"
      fi

      ((COUNT_FAILED++))
      echo "$LINE" >>"$BUF_FAILED"

      # Only gather logs for FAILED pods (not Succeeded/Completed)
      if [[ "$PHASE" != "Succeeded" && "$PHASE" != "Completed" ]]; then
        POD_LOG_DIR="${f%.yaml}"
        if [[ -d "$POD_LOG_DIR" ]]; then
          echo "#### Container Logs for $NAME:" >>"$BUF_FAILED"
          for logfile in "$POD_LOG_DIR"/*.log; do
            [[ -e "$logfile" ]] || continue
            echo "Log: $(basename "$logfile") (last 150 lines)" >>"$BUF_FAILED"
            tail -n 150 "$logfile" >>"$BUF_FAILED"
            echo "" >>"$BUF_FAILED"
          done
          echo "----------------------------------------------------" >>"$BUF_FAILED"
        fi
      fi
    fi
  done < <(find "$MOS_DIR" -path "*/core/pods/*.yaml" -type f)

  # Finalize files
  COUNT_RUNNING=$MOS_RUNNING
  echo "################# [MOS RUNNING PODS] (Total: $COUNT_RUNNING) #################" >"$OUT_RUNNING"
  cat "$BUF_RUNNING" >>"$OUT_RUNNING"

  echo "################# [MOS FAILED/COMPLETED PODS] (Total: $COUNT_FAILED) #################" >"$OUT_FAILED"
  cat "$BUF_FAILED" >>"$OUT_FAILED"

  rm "$BUF_RUNNING" "$BUF_FAILED"
fi
  # --- MCC DEPLOYMENT, STATEFULSET, DAEMONSET AUDIT ---
  if [[ -n "$MCC_DIR" ]]; then
  echo "Auditing MCC Deployments, StatefulSets, and DaemonSets..."

  # Deployments
  OUT_DEP="$LOGPATH/mcc_deployments.yaml"
  echo "################# [MCC DEPLOYMENTS] #################" >"$OUT_DEP"
  # List files at the top
  find "$MCC_DIR" -path "*/apps/deployments/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_DEP"
  done
  printf "%-25s %-50s %-8s %-12s %-12s %-10s\n" "NAMESPACE" "NAME" "READY" "UP-TO-DATE" "AVAILABLE" "AGE" >>"$OUT_DEP"
  while read -r f; do
    get_deployment_line "$f" >>"$OUT_DEP"
  done < <(find "$MCC_DIR" -path "*/apps/deployments/*.yaml" -type f)

  # StatefulSets
  OUT_STS="$LOGPATH/mcc_statefulsets.yaml"
  echo "################# [MCC STATEFULSETS] #################" >"$OUT_STS"
  # List files at the top
  find "$MCC_DIR" -path "*/apps/statefulsets/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_STS"
  done
  printf "%-25s %-50s %-8s %-10s\n" "NAMESPACE" "NAME" "READY" "AGE" >>"$OUT_STS"
  while read -r f; do
    get_statefulset_line "$f" >>"$OUT_STS"
  done < <(find "$MCC_DIR" -path "*/apps/statefulsets/*.yaml" -type f)

  # DaemonSets
  OUT_DS="$LOGPATH/mcc_daemonsets.yaml"
  echo "################# [MCC DAEMONSETS] #################" >"$OUT_DS"
  # List files at the top
  find "$MCC_DIR" -path "*/apps/daemonsets/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_DS"
  done
  printf "%-25s %-50s %-8s %-8s %-8s %-10s %-10s %-22s %-10s\n" "NAMESPACE" "NAME" "DESIRED" "CURRENT" "READY" "UP-TO-DATE" "AVAILABLE" "NODE-SELECTOR" "AGE" >>"$OUT_DS"
  while read -r f; do
    get_daemonset_line "$f" >>"$OUT_DS"
  done < <(find "$MCC_DIR" -path "*/apps/daemonsets/*.yaml" -type f)
  fi

  # --- MOS DEPLOYMENT, STATEFULSET, DAEMONSET AUDIT ---
  if [[ -n "$MOS_DIR" ]]; then
  echo "Auditing MOS Deployments, StatefulSets, and DaemonSets..."

  # Deployments
  OUT_DEP="$LOGPATH/mos_deployments.yaml"
  echo "################# [MOS DEPLOYMENTS] #################" >"$OUT_DEP"
  # List files at the top
  find "$MOS_DIR" -path "*/apps/deployments/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_DEP"
  done
  printf "%-25s %-50s %-8s %-12s %-12s %-10s\n" "NAMESPACE" "NAME" "READY" "UP-TO-DATE" "AVAILABLE" "AGE" >>"$OUT_DEP"
  while read -r f; do
    get_deployment_line "$f" >>"$OUT_DEP"
  done < <(find "$MOS_DIR" -path "*/apps/deployments/*.yaml" -type f)

  # StatefulSets
  OUT_STS="$LOGPATH/mos_statefulsets.yaml"
  echo "################# [MOS STATEFULSETS] #################" >"$OUT_STS"
  # List files at the top
  find "$MOS_DIR" -path "*/apps/statefulsets/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_STS"
  done
  printf "%-25s %-50s %-8s %-10s\n" "NAMESPACE" "NAME" "READY" "AGE" >>"$OUT_STS"
  while read -r f; do
    get_statefulset_line "$f" >>"$OUT_STS"
  done < <(find "$MOS_DIR" -path "*/apps/statefulsets/*.yaml" -type f)

  # DaemonSets
  OUT_DS="$LOGPATH/mos_daemonsets.yaml"
  echo "################# [MOS DAEMONSETS] #################" >"$OUT_DS"
  # List files at the top
  find "$MOS_DIR" -path "*/apps/daemonsets/*.yaml" -type f | while read -r f; do
    echo "# [FILE]: $f" >>"$OUT_DS"
  done
  printf "%-25s %-50s %-8s %-8s %-8s %-10s %-10s %-22s %-10s\n" "NAMESPACE" "NAME" "DESIRED" "CURRENT" "READY" "UP-TO-DATE" "AVAILABLE" "NODE-SELECTOR" "AGE" >>"$OUT_DS"
  while read -r f; do
    get_daemonset_line "$f" >>"$OUT_DS"
  done < <(find "$MOS_DIR" -path "*/apps/daemonsets/*.yaml" -type f)
  fi

# --- MCC LICENSE & RELEASES ---
OUT="$LOGPATH/mcc_license_releases"
echo "Gathering License and Releases..."
echo "################# [LICENSE & RELEASE DETAILS] #################" >"$OUT"
LICENSE_FILE=$(grep "kaas.mirantis.com/licenses/license.yaml" "$LOGPATH/files" | head -n 1)
if [[ -f "$LICENSE_FILE" ]]; then
  echo "## License Details:" >>"$OUT"
  echo "# $LICENSE_FILE:" >>"$OUT"
  echo "### Spec:" >>"$OUT"
  yq eval '.Object.spec // .spec' "$LICENSE_FILE" 2>/dev/null >>"$OUT"
  echo -e "\n### Status:" >>"$OUT"
  yq eval '.Object.status // .status' "$LICENSE_FILE" 2>/dev/null >>"$OUT"
else
  echo "## License file not found in kaas.mirantis.com/licenses/" >>"$OUT"
fi
echo -e "\n## Available KaasReleases:" >>"$OUT"
ls "$BASE_DIR/kaas-mgmt/objects/cluster/kaas.mirantis.com/kaasreleases/" 2>/dev/null | sed 's/.yaml//' >>"$OUT"

# --- MCC UPGRADE & RELEASE AUDIT ---
if [[ -n "$MCC_DIR" ]]; then
  OUT="$LOGPATH/mcc_upgrade_audit"
  echo "Auditing MCC Upgrade and Release status..."
  echo "################# [MCC UPGRADE & RELEASE AUDIT] #################" >"$OUT"

  # 1. Current Cluster Release Status
  echo "## Current Release Health:" >>"$OUT"
  # Find the Cluster object for management cluster (default/kaas-mgmt or first one)
  CLUSTER_FILE=$(find "$MCC_DIR" -path "*/default/cluster.k8s.io/clusters/*.yaml" | head -n 1)
  [[ -z "$CLUSTER_FILE" ]] && CLUSTER_FILE=$(find "$MCC_DIR" -path "*/clusters/*.yaml" | head -n 1)

  if [[ -f "$CLUSTER_FILE" ]]; then
    echo "# $CLUSTER_FILE:" >>"$OUT"
    CUR_VER=$(yq eval '.Object.spec.providerSpec.value.kaas.release // .spec.providerSpec.value.kaas.release' "$CLUSTER_FILE" 2>/dev/null)
    MKE_VER=$(yq eval '.Object.spec.providerSpec.value.release // .spec.providerSpec.value.release' "$CLUSTER_FILE" 2>/dev/null)

    echo "KaaS Release: ${CUR_VER:-N/A}" >>"$OUT"
    echo "MKE Release: ${MKE_VER:-N/A}" >>"$OUT"

    echo -e "\n### Cluster Release Status:" >>"$OUT"
    yq eval '.Object.status.providerStatus.releaseRefs // .status.providerStatus.releaseRefs' "$CLUSTER_FILE" 2>/dev/null >>"$OUT"

    echo -e "\n### Cluster Health Conditions:" >>"$OUT"
    yq eval '.Object.status.providerStatus.conditions // .status.providerStatus.conditions' "$CLUSTER_FILE" 2>/dev/null >>"$OUT"

    # Check for the actual release files
    if [[ -n "$CUR_VER" && "$CUR_VER" != "null" ]]; then
      KREL_FILE=$(find "$MCC_DIR" -path "*/kaasreleases/$CUR_VER.yaml" 2>/dev/null | head -n 1)
      if [[ -f "$KREL_FILE" ]]; then
        echo -e "\n# $KREL_FILE:" >>"$OUT"
        echo "KaaS Release Details (Spec):" >>"$OUT"
        yq eval '.Object.spec // .spec' "$KREL_FILE" 2>/dev/null >>"$OUT"
      fi
    fi
  else
    echo "Management Cluster object not found." >>"$OUT"
  fi

  # 2. Upgrade History & Active Status
  echo -e "\n## Upgrade Attempts (History):" >>"$OUT"
  UPGRADE_FILES=$(find "$MCC_DIR" -path "*/mccupgrades/*.yaml" 2>/dev/null | sort -r)
  if [[ -n "$UPGRADE_FILES" ]]; then
    for f in $UPGRADE_FILES; do
      echo "# $f:" >>"$OUT"
      NAME=$(basename "$f" .yaml)
      PHASE=$(yq eval '.Object.status.phase // .status.phase // .Object.status.conditions[0].reason // .status.conditions[0].reason' "$f" 2>/dev/null)
      START=$(yq eval '.Object.status.startTime // .status.startTime // .Object.status.lastUpgrade.startedAt // .status.lastUpgrade.startedAt' "$f" 2>/dev/null)
      END=$(yq eval '.Object.status.completionTime // .status.completionTime // .Object.status.lastUpgrade.finishedAt // .status.lastUpgrade.finishedAt' "$f" 2>/dev/null)

      echo "----------------------------------------------------" >>"$OUT"
      printf "Upgrade: %-30s | Phase: %-12s\n" "$NAME" "${PHASE:-N/A}" >>"$OUT"
      printf "Started: %-30s | Ended: %-12s\n" "${START:-N/A}" "${END:-N/A}" >>"$OUT"

      # If not finished, show the detailed status of current components
      if [[ "$PHASE" != "Done" && "$PHASE" != "Success" ]]; then
        echo ">>> ACTIVE/FAILED/PENDING UPGRADE DETAILS:" >>"$OUT"
        yq eval '.Object.status // .status' "$f" 2>/dev/null >>"$OUT"
      fi
    done
  else
    echo "No MCCUpgrade history found." >>"$OUT"
  fi
fi

# --- HOSTOS CONFIGURATION STATUS ---
if [[ -n "$MCC_DIR" ]]; then
  OUT="$LOGPATH/mcc_hostos_config"
  echo "Gathering HostOS Configuration status..."
  echo "################# [HOSTOS CONFIGURATION STATUS] #################" >"$OUT"
  HOSTOS_FILES=$(find "$MCC_DIR" -path "*/hostosconfigurationmodules/*.yaml" 2>/dev/null)
  if [[ -n "$HOSTOS_FILES" ]]; then
    for f in $HOSTOS_FILES; do
      echo "----------------------------------------------------" >>"$OUT"
      echo "# $f:" >>"$OUT"
      echo "### Module: $(basename "$f" .yaml)" >>"$OUT"
      yq eval '.Object.status // .status' "$f" 2>/dev/null >>"$OUT"
    done
  else
    echo "No HostOSConfigurationModule objects found." >>"$OUT"
  fi
fi

# --- ADMISSION WEBHOOKS ---
OUT="$LOGPATH/cluster_webhooks"
echo "Auditing Admission Webhooks..."
echo "################# [MOS/MCC WEBHOOK CONFIGURATIONS] #################" >"$OUT"
find "$BASE_DIR" -path "*/admissionregistration.k8s.io/*" -name "*.yaml" -print >>"$OUT"
echo -e "\n## Failed calls from events logs:" >>"$OUT"
grep -rEi "failed calling webhook|webhook.*denied" "$BASE_DIR"/*/objects/events.log 2>/dev/null >>"$OUT"
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_pv_pvc"
  echo "Gathering MCC PV and PVC details..."
  echo "################# [MCC PV AND PVC DETAILS] #################" >"$OUT"
  grep $MCC_DIR/objects/cluster/core/persistentvolumes/ $LOGPATH/files >$LOGPATH/mcc-pv
  echo "" >>"$OUT"
  printf '## Persistent Volumes' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-pv))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mcc-pv >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mcc-pv
  echo "" >>"$OUT"
  grep persistentvolumeclaims $LOGPATH/files | grep $MCCNAME >$LOGPATH/mcc-pvc
  printf '## Persistent Volume Claims' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-pvc))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml
  done <$LOGPATH/mcc-pvc >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mcc-pvc

  # --- SUMMARY RESUME ---
  echo -e "\n################# [PV <-> PVC SUMMARY RESUME] #################" >>"$OUT"
  printf "%-50s | %-50s\n" "PERSISTENT VOLUME" "BOUND PVC (NAMESPACE/NAME)" >>"$OUT"
  echo "------------------------------------------------------------------------------------------------------" >>"$OUT"
  PV_FILES=$(grep $MCC_DIR/objects/cluster/core/persistentvolumes/ $LOGPATH/files)
  for pv in $PV_FILES; do
    PV_NAME=$(basename "$pv" .yaml)
    CLAIM_NS=$(yq eval '.Object.spec.claimRef.namespace // .spec.claimRef.namespace' "$pv" 2>/dev/null)
    CLAIM_NAME=$(yq eval '.Object.spec.claimRef.name // .spec.claimRef.name' "$pv" 2>/dev/null)
    if [[ -n "$CLAIM_NAME" && "$CLAIM_NAME" != "null" ]]; then
      printf "%-50s | %-50s\n" "$PV_NAME" "$CLAIM_NS/$CLAIM_NAME" >>"$OUT"
    else
      printf "%-50s | %-50s\n" "$PV_NAME" "[UNBOUND]" >>"$OUT"
    fi
  done
fi
# --- MCC SERVICES ---
if [[ -n "$MCC_DIR" ]]; then
  OUT="$LOGPATH/mcc_services"
  echo "Gathering MCC Service details..."
  echo "################# [MCC SERVICES SUMMARY] #################" >"$OUT"
  find "$MCC_DIR" -path "*/core/services/*.yaml" -type f | while read -r f; do
    NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f")
    NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f")
    TYPE=$(yq eval '.Object.spec.type // .spec.type' "$f")
    CIP=$(yq eval '.Object.spec.clusterIP // .spec.clusterIP' "$f")
    LBI=$(yq eval '.Object.status.loadBalancer.ingress[0].ip // .Object.status.loadBalancer.ingress[0].hostname // .status.loadBalancer.ingress[0].ip // .status.loadBalancer.ingress[0].hostname' "$f" 2>/dev/null)

    printf "Namespace: %-15s | Name: %-30s | Type: %-12s | ClusterIP: %-15s" "$NS" "$NAME" "$TYPE" "$CIP" >>"$OUT"
    [[ "$LBI" != "null" && -n "$LBI" ]] && printf " | LB Ingress: %s" "$LBI" >>"$OUT"
    echo "" >>"$OUT"
  done
fi

# --- MOS SERVICES ---
if [[ -n "$MOS_DIR" ]]; then
  OUT="$LOGPATH/mos_services"
  echo "Gathering MOS Service details..."
  echo "################# [MOS SERVICES SUMMARY] #################" >"$OUT"
  find "$MOS_DIR" -path "*/core/services/*.yaml" -type f | while read -r f; do
    NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f")
    NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f")
    TYPE=$(yq eval '.Object.spec.type // .spec.type' "$f")
    CIP=$(yq eval '.Object.spec.clusterIP // .spec.clusterIP' "$f")
    LBI=$(yq eval '.Object.status.loadBalancer.ingress[0].ip // .Object.status.loadBalancer.ingress[0].hostname // .status.loadBalancer.ingress[0].ip // .status.loadBalancer.ingress[0].hostname' "$f" 2>/dev/null)

    printf "Namespace: %-15s | Name: %-30s | Type: %-12s | ClusterIP: %-15s" "$NS" "$NAME" "$TYPE" "$CIP" >>"$OUT"
    [[ "$LBI" != "null" && -n "$LBI" ]] && printf " | LB Ingress: %s" "$LBI" >>"$OUT"
    echo "" >>"$OUT"
  done
fi

# --- EXECUTIVE SUMMARY GENERATION (Now runs after normalization) ---
echo "Generating Summary..."
OUT="$LOGPATH/summary.yaml"
echo "################# [EXECUTIVE SUMMARY & CRITICAL FINDINGS] #################" >"$OUT"

# 1. Cluster Status & Upgrades
echo "## 🚀 CLUSTER & UPGRADE OVERVIEW:" >>"$OUT"
if [[ -f "$LOGPATH/mcc_upgrade_audit.yaml" ]]; then
  grep -E "KaaS Release:|MKE Release:|Upgrade:|Phase:|>>>" "$LOGPATH/mcc_upgrade_audit.yaml" >>"$OUT"
fi

# Extract last messages from cluster YAMLs
echo -e "\n### LATEST CLUSTER MESSAGES:" >>"$OUT"
for f in "$LOGPATH"/*cluster.yaml; do
  [[ -f "$f" ]] || continue
  CL_TYPE=$(basename "$f" .yaml | tr '[:lower:]' '[:upper:]')
  echo "#### $CL_TYPE:" >>"$OUT"

  # 1. Stuck message (full)
  STUCK=$(grep "lcmOperationStuckMessage:" "$f" -A 5 | sed -n '/lcmOperationStuckMessage:/,/^[[:space:]]*[^[:space:]]/p')
  [[ -n "$STUCK" ]] && echo "$STUCK" | sed 's/^[[:space:]]*/  /' >>"$OUT"

  # 2. Latest 10 Events (Timeline ordered)
  if [[ "$CL_TYPE" == "MCC_CLUSTER" ]]; then
     # Get from mcc_events.yaml
     if [[ -f "$LOGPATH/mcc_events.yaml" ]]; then
       echo "  >> Latest 10 Events:" >>"$OUT"
       grep -E "^[0-9]{4}-|^[A-Z][a-z]{2}[[:space:]]+[0-9]" "$LOGPATH/mcc_events.yaml" | tail -n 10 | sed 's/^/      /' >>"$OUT"
     fi
     # 3. LCM Controller Logs for MCC
     echo -e "\n  >> LCM Controller Logs (Errors/Warnings):" >>"$OUT"
     find "$MCC_DIR" -path "*/kaas/core/pods/lcm-lcm-controller-*/controller.log" | sort | while read -r log; do
       echo "      Pod Path: /${log#./}" >>"$OUT"
       grep -Ei "error|fail|warning|warn" "$log" | tail -n 5 | sed 's/^/        /' >>"$OUT"
     done  elif [[ "$CL_TYPE" == "MOS_CLUSTER" ]]; then
     if [[ -f "$LOGPATH/mos_events.yaml" ]]; then
       echo "  >> Latest 10 Events:" >>"$OUT"
       grep -E "^[0-9]{4}-|^[A-Z][a-z]{2}[[:space:]]+[0-9]" "$LOGPATH/mos_events.yaml" | tail -n 10 | sed 's/^/      /' >>"$OUT"
     fi
  fi
  echo "" >>"$OUT"
  done

  # 2. Node Health (Grep from cluster details)
  echo -e "\n## 🖥️  NODE STATUS SUMMARY (Non-Ready):" >>"$OUT"
  NODES_NON_READY=$(grep -h "|" "$LOGPATH"/*cluster.yaml 2>/dev/null | grep -v "Ready: True" | grep "Node: " | sort | uniq -c)
  if [[ -n "$NODES_NON_READY" ]]; then
  echo "$NODES_NON_READY" >>"$OUT"
  else
  echo "All nodes are in Ready state" >>"$OUT"
  fi

# 3. Stacklight & Patroni Status
echo -e "\n## 📊 STACKLIGHT & PATRONI STATUS:" >>"$OUT"

# MCC Stacklight
if [[ -d "$MCC_DIR/objects/namespaced/stacklight" ]]; then
  echo "### [MCC] Patroni Cluster Status:" >>"$OUT"
  find "$MCC_DIR" -path "*/stacklight/core/pods/patroni-*.yaml" 2>/dev/null | sort | while read -r pf; do
    P_STATUS=$(yq eval '.Object.metadata.annotations.status // .metadata.annotations.status' "$pf" 2>/dev/null)
    if [[ -n "$P_STATUS" && "$P_STATUS" != "null" ]]; then
       ROLE=$(echo "$P_STATUS" | grep -oE '"role":"[^"]+"' | cut -d'"' -f4)
       STATE=$(echo "$P_STATUS" | grep -oE '"state":"[^"]+"' | cut -d'"' -f4)
       printf "      Pod: %-25s | Role: %-10s | State: %s\n" "$(basename "$pf" .yaml)" "$ROLE" "$STATE" >>"$OUT"
    fi
  done
  echo "" >>"$OUT"
fi

# MOS Stacklight
if [[ -d "$MOS_DIR/objects/namespaced/stacklight" ]]; then
  echo "### [MOS] Patroni Cluster Status:" >>"$OUT"
  find "$MOS_DIR" -path "*/stacklight/core/pods/patroni-*.yaml" 2>/dev/null | sort | while read -r pf; do
    P_STATUS=$(yq eval '.Object.metadata.annotations.status // .metadata.annotations.status' "$pf" 2>/dev/null)
    if [[ -n "$P_STATUS" && "$P_STATUS" != "null" ]]; then
       ROLE=$(echo "$P_STATUS" | grep -oE '"role":"[^"]+"' | cut -d'"' -f4)
       STATE=$(echo "$P_STATUS" | grep -oE '"state":"[^"]+"' | cut -d'"' -f4)
       printf "      Pod: %-25s | Role: %-10s | State: %s\n" "$(basename "$pf" .yaml)" "$ROLE" "$STATE" >>"$OUT"
    fi
  done
else
  echo "MOS Stacklight namespace not found." >>"$OUT"
fi# 4. Pod Status Summary
echo -e "\n## ⚠️  POD STATUS SUMMARY:" >>"$OUT"
if [[ -n "$MCC_DIR" ]]; then
  echo "Total MCC Pods: Running: ${MCC_RUNNING:-0} | Non-Running: ${MCC_NON_RUNNING:-0} | Completed: ${MCC_COMPLETED:-0}" >>"$OUT"
  if [[ -n "$MCC_NON_RUNNING_LIST" ]]; then
    echo -e "### Non-Running MCC Pods:\n$MCC_NON_RUNNING_LIST" >>"$OUT"
  fi
fi
if [[ -n "$MOS_DIR" ]]; then
  echo "Total MOS Pods: Running: ${MOS_RUNNING:-0} | Non-Running: ${MOS_NON_RUNNING:-0} | Completed: ${MOS_COMPLETED:-0}" >>"$OUT"
  if [[ -n "$MOS_NON_RUNNING_LIST" ]]; then
    echo -e "### Non-Running MOS Pods:\n$MOS_NON_RUNNING_LIST" >>"$OUT"
  fi
fi
# 4. Networking Issues
echo -e "\n## 🌐 NETWORKING & CONNECTIVITY:" >>"$OUT"
grep -h "🛑 ALERT: IP RANGE OVERLAPS DETECTED!" "$LOGPATH"/*subnet.yaml 2>/dev/null && echo ">>> [!] CRITICAL: IP Overlaps detected! Check Subnet cards." >>"$OUT" || echo "No IP overlaps detected." >>"$OUT"

# 5. Top Errors & Blockers
echo -e "\n## 🔍 TOP CRITICAL ERRORS & BLOCKERS:" >>"$OUT"
grep -hEi "doesn't have specified device|denied|forbidden|context deadline exceeded|failed to call webhook" "$LOGPATH"/*.yaml 2>/dev/null | sort | uniq -c | sort -nr | head -n 10 >>"$OUT"

# --- FINAL GENERATION BLOCK ---
if [[ -n "$MCCNAME" ]] || [[ -n "$MOSNAME" ]]; then
  echo "Finalizing Dashboard UI..."
  
  # 1. & 2. Strict Normalization (Move this BEFORE Summary)
  for f in "$LOGPATH"/*; do
    filename=$(basename "$f")
    [[ "$filename" == *.html || "$filename" == "files" ]] && continue
    # Skip summary if it's already there (shouldn't be yet in this new flow)
    [[ "$filename" == "summary" || "$filename" == "summary.yaml" ]] && continue
    
    if [[ "$filename" != *_* ]]; then
      rm "$f"
      continue
    fi
    [[ "$filename" != *.yaml ]] && mv "$f" "$f.yaml"
  done

  # Re-extract versions for header
  MCC_VER_STR=""
  if [[ -n "$MCCNAME" ]]; then
     MCC_FILE=$(grep "cluster.k8s.io/clusters/$MCCNAME.yaml" "$LOGPATH/files" | head -n 1)
     [[ -f "$MCC_FILE" ]] && MCC_VER_STR=" (KaaS: $(yq eval '.Object.spec.providerSpec.value.kaas.release // .spec.providerSpec.value.kaas.release' "$MCC_FILE" 2>/dev/null))"
  fi
  MOS_VER_STR=""
  if [[ -n "$MOSNAME" ]]; then
     MOS_STATUS_FILE=$(ls $MOS_DIR/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml 2>/dev/null | head -n 1)
     [[ -f "$MOS_STATUS_FILE" ]] && MOS_VER_STR=" (Rel: $(grep -m1 "    release: " "$MOS_STATUS_FILE" | sed 's/.*release: //; s/[[:space:]]//g; s/\.$//'))"
  fi

  # 3. BUILD SIDEBAR LINKS
  for yaml_file in $(ls "$LOGPATH"/*.yaml 2>/dev/null | sort); do
    [[ -e "$yaml_file" ]] || continue
    FILENAME=$(basename "$yaml_file")
    CATEGORY="cluster"
    [[ "$FILENAME" == mcc_* ]] && CATEGORY="mcc"
    [[ "$FILENAME" == mos_* ]] && CATEGORY="mos"
    [[ "$FILENAME" == summary.yaml ]] && CATEGORY="all"
    
    TITLE=$(basename "$yaml_file" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    ANCHOR=$(echo "$TITLE" | tr ' ' '-')
    echo "<li data-category='$CATEGORY'><a href='javascript:void(0)' onclick=\"toggleCard(this, '$ANCHOR')\">$TITLE</a></li>" >>"$HTML_REPORT"
  done

  # 4. TRANSITION FROM SIDEBAR TO MAIN
  printf "\n</ul>\n</nav>\n<main class=\"main-content\">\n" >>"$HTML_REPORT"
  cat <<EOF >>"$HTML_REPORT"
<button class="toggle-sidebar-btn" onclick="toggleSidebar()" title="Toggle Sidebar">◀</button>
<div class="header" style="display: flex; justify-content: space-between; align-items: flex-start;">
    <div>
        <h1>Myrha - Mirantis Supportdump Dashboard</h1>
        <p>
            <strong>Management (MCC):</strong> ${MCCNAME:-N/A}${MCC_VER_STR}
            ${MOSNAME:+ | <strong>Managed (MOSK):</strong> $MOSNAME}${MOS_VER_STR}
            <br>
            <small>Generated: $DATE</small>
        </p>
    </div>
    <div style="text-align: right; font-size: 0.8rem; line-height: 1.4; padding-right: 40px;">
        ${MCC_LINKS_HTML}
        ${MOS_LINKS_HTML}
    </div>
</div>
<div id="placeholder" class="placeholder-msg">
    <h2>Empty</h2>
    <p>Please select the fields you would like to analyze from the sidebar on the left.</p>
</div>
EOF

  # 5. BUILD CONTENT CARDS
  for yaml_file in $(ls "$LOGPATH"/*.yaml 2>/dev/null | sort); do
    [[ -e "$yaml_file" ]] || continue
    TITLE=$(basename "$yaml_file" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    ANCHOR=$(echo "$TITLE" | tr ' ' '-')

    # Extract files: check for '# [FILE]:' prefix first, fallback to general grep
    FILES=$(grep "^# \[FILE\]: " "$yaml_file" | cut -d' ' -f3- | sort -u)
    if [[ -z "$FILES" ]]; then
       FILES=$(grep -oE '(\.?/[-a-zA-Z0-9._/]+\.(log|yaml|json|txt|conf))' "$yaml_file" | sort -u)
    fi

    LINKS_HTML=""
    if [[ -n "$FILES" ]]; then
      FILE_COUNT=$(echo "$FILES" | wc -l)
      LINKS_HTML="<div class='analyzed-files-wrapper'>"
      LINKS_HTML+="<div class='analyzed-files-container'><strong>Analyzed files:</strong> "
      while read -r f; do
        # Create a relative link (one level up since report is in myrha/ subdir)
        REL_LINK="$f"
        # If it starts with / like /kaas-mgmt, the link should be ../kaas-mgmt
        [[ "$REL_LINK" == /* ]] && REL_LINK="..${REL_LINK}"
        # If it starts with ./ like ./kaas-mgmt, the link should be ../kaas-mgmt
        [[ "$REL_LINK" == ./* ]] && REL_LINK="../${REL_LINK#./}"
        
        # Differentiate names by including parent directory (e.g. pod name)
        FNAME=$(basename "$f")
        PDIR=$(basename "$(dirname "$f")")
        DISPLAY_NAME="$FNAME"
        if [[ "$PDIR" != "." && "$PDIR" != "/" && -n "$PDIR" ]]; then
            DISPLAY_NAME="$PDIR/$FNAME"
        fi

        LINKS_HTML+="<a href='$REL_LINK' type='text/plain' target='_blank' style='color: var(--accent); margin-right: 15px; text-decoration: underline; display: inline-block; white-space: nowrap;'>$DISPLAY_NAME</a>"
      done <<< "$FILES"
      LINKS_HTML+="</div>"
      # Only add the more button if there are many files (e.g., > 3) or if it overflows (handled by CSS roughly)
      if [[ $FILE_COUNT -gt 3 ]]; then
        LINKS_HTML+="<button class='more-files-btn' onclick='toggleAnalyzedFiles(this)'>more...</button>"
      fi
      LINKS_HTML+="</div>"
    fi

    {
      echo "<div class='card' id='$ANCHOR'>"
      echo "  <h2>$TITLE"
      echo "    <div class='card-header-actions'>"
      echo "      <div class='search-nav-container'>"
      echo "        <input type='text' class='card-search' placeholder='Search logs...' onkeyup=\"performSearch('$ANCHOR', this.value)\">"
      echo "        <span class='btn-tool' onclick=\"navigateSearch('$ANCHOR', 'prev')\">▲</span>"
      echo "        <span class='btn-tool' onclick=\"navigateSearch('$ANCHOR', 'next')\">▼</span>"
      echo "        <span class='search-count'>0/0</span>"
      echo "      </div>"
      echo "      <span class='btn-tool' onclick=\"scrollToLimit('$ANCHOR', 'top')\">↑ Log Top</span>"
      echo "      <span class='btn-tool' onclick=\"scrollToLimit('$ANCHOR', 'bottom')\">↓ Log Bottom</span>"
      echo "      <span class='btn-tool' onclick=\"toggleFullScreen(this, '$ANCHOR')\">Full Screen</span>"
      echo "      <span class='btn-tool btn-copy' onclick=\"copyToClipboard(this, '$ANCHOR')\">Copy</span>"
      echo "      <span class='btn-tool wrap-btn' onclick=\"toggleBlockWrap(this, '$ANCHOR')\">Wrap: OFF</span>"
      echo "      <span class='btn-tool btn-close' onclick=\"closeCard('$ANCHOR')\" title='Close Card'>✖</span>"
      echo "    </div>"
      echo "  </h2>"
      echo "$LINKS_HTML"
      echo "  <pre class='language-yaml raw-code'><code>"
      sed '/^# \[FILE\]: /d; s/\xc2\xa0/ /g; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$yaml_file"
      echo "  </code></pre>"
      echo "</div>"
    } >>"$HTML_REPORT"
  done


  # 6. CLOSE DOCUMENT
  printf "\n</main>\n" >>"$HTML_REPORT"
  cat <<EOF >>"$HTML_REPORT"
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js" data-manual></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-yaml.min.js"></script>
<script>
    window.onload = () => {
        // Auto-select Summary and Clusters by default
        ['SUMMARY', 'MCC-CLUSTER', 'MOS-CLUSTER', 'CLUSTER-KNOWN-ISSUES'].forEach(anchor => {
            const link = Array.from(document.querySelectorAll('#sidebarList a')).find(a => a.getAttribute('onclick').includes("'" + anchor + "'"));
            if (link) toggleCard(link, anchor);
        });

        // Force .yaml files to open as text
        document.querySelectorAll('a[href$=".yaml"]').forEach(link => {
            link.addEventListener('click', async (e) => {
                const url = link.href;
                // Chrome-based browsers allow view-source:
                if (window.chrome) {
                    e.preventDefault();
                    window.open('view-source:' + url, '_blank');
                } else {
                    // Firefox and others: try to fetch and open as a text blob
                    e.preventDefault();
                    try {
                        const response = await fetch(url);
                        if (!response.ok) throw new Error('Fetch failed');
                        const blob = await response.blob();
                        const textBlob = new Blob([blob], { type: 'text/plain' });
                        const blobUrl = URL.createObjectURL(textBlob);
                        window.open(blobUrl, '_blank');
                    } catch (err) {
                        // Fallback: open normally if fetch is blocked by CORS/file policy
                        window.open(url, '_blank');
                    }
                }
            });
        });
    };

</script>
</body>
</html>
EOF

  echo "✅ Dashboard ready: $HTML_REPORT"
  open "$HTML_REPORT" 2>/dev/null
fi
if [[ -z "$MCCNAME" ]] && [[ -z "$MOSNAME" ]]; then
  # Delete myrha folder as neither MCC and MOS clusters were found:
  rm -rf $LOGPATH 2>/dev/null
fi
