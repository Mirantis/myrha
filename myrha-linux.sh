#!/bin/bash
# Declare variables
DATE=$(date +"%d-%m-%Y-%H-%M-%S")
GREP="grep --color=auto"
LOGPATH=myrha
HTML_REPORT="$LOGPATH/report_$DATE.html"
FULL_CWD=$(pwd)
mkdir $LOGPATH 2>/dev/null
rm -f "$LOGPATH"/* 2>/dev/null
for cmd in rg nvim subl yq bc; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Installing $cmd..."
    sudo apt-get install "$cmd" -y 2>/dev/null || sudo dnf install "$cmd" -y 2>/dev/null
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
</style>
<script>
    function toggleSidebar() {
        document.body.classList.toggle('sidebar-hidden');
    }
    let currentFilter = 'all';
    function filterType(type) {
        currentFilter = type;
        document.querySelectorAll('.filter-btn').forEach(btn => {
            const btnType = btn.getAttribute('onclick').match(/'([^']+)'/)[1];
            btn.classList.toggle('active', btnType === type);
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
            const matchesFilter = currentFilter === 'all' || category === currentFilter || category === 'cluster';
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
    function performSearch(anchor, query) {
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
        </div>
        <input type="text" class="search-box" id="sidebarSearch" placeholder="Filter sections..." onkeyup="filterSidebar()">
        <ul id="sidebarList">
EOF
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

  local TMP_DIR=$(mktemp -d)
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
        cat "$TARGET_FILE"
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

        # --- Expiry Alert Logic ---
        EXPIRY_SEC=$(date -d "$EXPIRY" +%s 2>/dev/null)
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
find "$BASE_DIR" -not -path "$LOGPATH/*" -type f -name '*' >"$LOGPATH/files"

# Discover MCC and MOS cluster directories
MCC_DIR=$(find "$BASE_DIR" -type d -name "kaas-mgmt" | head -n 1)
MOS_DIR=$(find "$BASE_DIR" -type d -name "mos" | head -n 1)

if [[ -n "$MCC_DIR" ]]; then
  MCC_FILE=$(ls "$MCC_DIR"/objects/namespaced/default/cluster.k8s.io/clusters/*.yaml 2>/dev/null | head -n 1)
  if [[ -f "$MCC_FILE" ]]; then
    MCCNAME=$(yq eval '.Object.metadata.name // .metadata.name' "$MCC_FILE" 2>/dev/null)
    MCCNAMESPACE=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$MCC_FILE" 2>/dev/null)
  fi
fi

if [[ -n "$MOS_DIR" ]]; then
  MOSNAME=$(basename "$MOS_DIR")
fi

if [[ -n "$MCCNAME" && -n "$MOS_DIR" ]]; then
  MOS_CLUSTER_FILE=$(ls "$MCC_DIR"/objects/namespaced/*/cluster.k8s.io/clusters/*.yaml 2>/dev/null | grep -v default | head -n 1)
  if [[ -f "$MOS_CLUSTER_FILE" ]]; then
    MOSNAMESPACE=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$MOS_CLUSTER_FILE" 2>/dev/null)
  fi
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_cluster"
  echo "Gathering MOS cluster details..."
  echo "################# [MOS CLUSTER DETAILS] #################" >"$OUT"
  MOS_STATUS_FILE=$(ls $MOS_DIR/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml 2>/dev/null | head -n 1)
  if [[ -n "$MOS_STATUS_FILE" ]]; then
    # Unified split for MOS (e.g., 21.0.0+25.2.9)
    REL_RAW=$(grep -m1 "    release: " "$MOS_STATUS_FILE" | sed -e 's/.*release: //' -e 's/[[:space:]]//g' -e 's/+/./g')
    IFS='.' read -r -a V <<<"$REL_RAW"
    # V[0]=VER1, V[1]=VER2, V[2]=VER3, V[3]=VER4, V[4]=VER5, V[5]=VER6
    printf "## MOS release details (Managed): ${V[0]}.${V[1]}.${V[2]}+${V[3]}.${V[4]}.${V[5]}" >>"$OUT"
    echo "" >>"$OUT"
    if (($(echo "${V[3]}.${V[4]} >= 25.2" | bc -l))); then
      echo "https://docs.mirantis.com/mosk/25.2/release-notes/25.2-series/25.2.${V[5]}.html" | sed 's/\.\././' >>"$OUT"
    else
      echo "https://docs.mirantis.com/mosk/25.1-and-earlier/release-notes/release-notes-mosk-old/${V[3]}.${V[4]}-series/${V[3]}.${V[4]}.${V[5]}.html" | sed 's/\.\././' >>"$OUT"
    fi
    echo "" >>"$OUT"
    MOS_BUG_VER="${V[3]}.${V[4]}.${V[5]}"
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
    echo "" >>"$OUT"
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
      [[ -f "$LCM_YAML" ]] && ls $LCM_YAML >>"$OUT"
      [[ -f "$LCM_YAML" ]] && sed -n '/  status:/,/    requestedNodes:/p' $LCM_YAML >>"$OUT"
      echo "" >>"$OUT"
      echo "Gathering Node Conditions..."
      echo "################# [NODE CONDITIONS] #################" >>"$OUT"
      for nf in $(grep "/core/nodes" "$LOGPATH/files" | grep "$MOSNAME"); do
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
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_events"
  echo "Gathering MOS cluster events..."
  echo "################# [MOS EVENTS (WARNING+ERRORS)] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Analyzed files:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/events.log >>"$OUT"
  grep -E "Warning|Error" $MOS_DIR/objects/events.log | sort -M >>"$OUT"
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
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/rook-ceph/ceph.rook.io/cephclusters/rook-ceph.yaml >>"$OUT"
  sed -n '/    ceph:/,/    version:/p' "$MOS_DIR/objects/namespaced/rook-ceph/ceph.rook.io/cephclusters/rook-ceph.yaml" | head -n -1 >>"$OUT"
  echo "" >>"$OUT"
  echo "## Mgr node logs (Warnings/Errors):" >>"$OUT"
  grep "/mgr.log" $LOGPATH/files >$LOGPATH/ceph-mgr
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -iE 'error|fail|warn' "$line" | sed -r '/^\s*$/d' >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/ceph-mgr
  echo "## Mon node logs (Warnings/Errors):" >>"$OUT"
  grep "/mon.log" $LOGPATH/files >$LOGPATH/ceph-mon
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -iE 'error|fail|warn' "$line" | sed -r '/^\s*$/d' >>"$OUT"
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
    grep -iE 'error|fail|warn' "$line" | sed -r '/^\s*$/d' >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/ceph-osd
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack"
  echo "Gathering MOS Openstack OSDPL details..."
  echo "################# [MOS OPENSTACK OSDPL DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## OSDPL LCM status details:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml >>"$OUT"
  sed -n '/    osdpl:/,/    services:/p' $MOS_DIR/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml | head -n -1 >>"$OUT"
  echo "" >>"$OUT"
  echo "## OSDPL details:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/lcm.mirantis.com/openstackdeployments/*.yaml >>"$OUT"
  sed -n '/  spec:/,/  status:/p' $MOS_DIR/objects/namespaced/openstack/lcm.mirantis.com/openstackdeployments/*.yaml | head -n -1 >>"$OUT"
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
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
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
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-nova-compute
  echo "" >>"$OUT"
  echo "## Logs from nova-scheduler pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'nova-scheduler.log' $LOGPATH/files >$LOGPATH/mos-openstack-nova-scheduler
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-nova-scheduler
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
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
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
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
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
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-cinder-api
  echo "" >>"$OUT"
  echo "## Logs from cinder-volume pods (Errors/Warnings - last 150 lines):" >>"$OUT"
  grep 'cinder-volume.log' $LOGPATH/files >$LOGPATH/mos-openstack-cinder-volume
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
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
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
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
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
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
    grep -E '\[warning\]|\[error\]' $line | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-openstack-rabbitmq
fi
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_mariadb"
  echo "Gathering MOS Mariadb details and logs..."
  echo "################# [MOS MARIADB DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Configmap:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/core/configmaps/openstack-mariadb-mariadb-state.yaml >>"$OUT"
  sed -n '/  data:/,/    creationTimestamp:/p' $MOS_DIR/objects/namespaced/openstack/core/configmaps/openstack-mariadb-mariadb-state.yaml >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from controller pod (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-controller-*/controller.log >>"$OUT"
  grep -iE 'error|fail|warn' $MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-controller-*/controller.log | sed -r '/^\s*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-0 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-server-0/mariadb.log >>"$OUT"
  awk '/ERR|WARN/ && !/WARNING - Collision writing configmap/ && NF' "$MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-1 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-server-1/mariadb.log >>"$OUT"
  awk '/ERR|WARN/ && !/WARNING - Collision writing configmap/ && NF' "$MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-2 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log >>"$OUT"
  awk '/ERR|WARN/ && !/WARNING - Collision writing configmap/ && NF' "$MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log" >>"$OUT"
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
  echo "################# [MCC SUBNET DETAILS] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files >$LOGPATH/mcc-subnet
  echo "" >>"$OUT"
  printf '## Subnets' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-subnet))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml >>"$OUT"
  done <$LOGPATH/mcc-subnet >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo ""
  done <$LOGPATH/mcc-subnet >>"$OUT"
  echo "" >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_subnet"
  echo "Gathering MOS subnet details..."
  echo "################# [MOS SUBNET DETAILS] #################" >"$OUT"
  grep $MCC_DIR/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files >$LOGPATH/mos-subnet
  echo "" >>"$OUT"
  printf '## Subnets' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-subnet))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    basename "$line" .yaml >>"$OUT"
  done <$LOGPATH/mos-subnet >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    yq eval '.Object.spec // .spec' "$line" 2>/dev/null >>"$OUT"
    yq eval '.Object.status // .status' "$line" 2>/dev/null >>"$OUT"
    echo ""
  done <$LOGPATH/mos-subnet >>"$OUT"
  echo "" >>"$OUT"
fi

# --- MOS NETWORKING (Subnets & IPPools) ---
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_networking_audit"
  echo "Gathering MOS Networking details..."
  echo "################# [MOS SUBNET & IPPOOL RESUME] #################" >"$OUT"

  ALL_IP_DATA=""

  # 1. Audit Subnets
  echo "## IPAM SUBNETS (Ranges Resume):" >>"$OUT"
  grep "$MOSNAME" "$LOGPATH/files" | grep "ipam.mirantis.com/subnets/" | while read -r f; do
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

      # Collect for overlap check
      echo "$CIDR,$INC" >>"$LOGPATH/mos_ip_collect"
    fi
  done

  # 2. Audit IPAddressPools (MetalLB)
  echo -e "\n## METALLB IP POOLS:" >>"$OUT"
  grep "$MOSNAME" "$LOGPATH/files" | grep "ipaddresspools/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      ADDR=$(yq eval "${PREFIX}.spec.addresses[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      printf "Pool: %-20s | Ranges: [%s]\n" "$NAME" "$ADDR" >>"$OUT"

      # Collect for overlap check
      echo "$ADDR" >>"$LOGPATH/mos_ip_collect"
    fi
  done

  # 3. Perform Overlap Check
  if [[ -f "$LOGPATH/mos_ip_collect" ]]; then
    echo -e "\n## OVERLAP VERIFICATION:" >>"$OUT"
    check_overlaps <"$LOGPATH/mos_ip_collect" >>"$OUT"
    rm "$LOGPATH/mos_ip_collect"
  fi
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
    grep -E 'ERR|WARN' "$line" | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-tf-control

  echo '## TF config logs (Errors/Warnings - last 150 lines)' >>"$OUT"
  grep tf-config- "$LOGPATH/files" | grep log >$LOGPATH/mos-tf-config
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' "$line" | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-tf-config

  echo '## TF vrouter logs (Errors/Warnings - last 150 lines)' >>"$OUT"
  grep tf-vrouter- "$LOGPATH/files" | grep log >$LOGPATH/mos-tf-vrouter
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E 'ERR|WARN' "$line" | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
    echo "" >>"$OUT"
  done <$LOGPATH/mos-tf-vrouter

  echo '## TF rabbitmq logs (Errors/Warnings - last 150 lines):' >>"$OUT"
  grep /rabbitmq.log "$LOGPATH/files" | grep tf >$LOGPATH/mos-tf-rabbitmq
  while read -r line; do
    printf "# $line:" >>"$OUT"
    echo "" >>"$OUT"
    grep -E '\[warning\]|\[error\]' "$line" | sed -r '/^\s*$/d' | tail -n 150 >>"$OUT"
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
  PROCESSED_PVC=$(mktemp)

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
  rm "$PROCESSED_PVC"
fi

# --- NETCHECKER CONNECTIVITY AUDIT ---
OUT="$LOGPATH/cluster_netchecker"
echo "Gathering Netchecker connectivity reports..."
echo "################# [NETCHECKER CONNECTIVITY AUDIT] #################" >"$OUT"
NETCHECKER_CM=$(find "$BASE_DIR" -path "*/netchecker/core/configmaps/*.yaml" 2>/dev/null | grep "netchecker-status" | head -n 1)
if [[ -f "$NETCHECKER_CM" ]]; then
  echo "## Latest Connectivity Report ($NETCHECKER_CM):" >>"$OUT"
  yq eval '.Object.data // .data' "$NETCHECKER_CM" 2>/dev/null >>"$OUT"
else
  echo "No Netchecker status configmap found. Checking for agents..." >>"$OUT"
  find "$BASE_DIR" -path "*/netchecker/apps/daemonsets/*.yaml" -print >>"$OUT"
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
    [[ "$MCC_BUG_VER" == "2.25.0" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.25%20%2F%20MOSK%2023.3%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.1%20%2F%20MOSK%2023.3.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.2%20%2F%20MOSK%2023.3.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.3%20%2F%20MOSK%2023.3.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.25.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.4%20%2F%20MOSK%2023.3.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.0" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26%20%2F%20MOSK%2024.1%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.1%20%2F%20MOSK%2024.1.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.2%20%2F%20MOSK%2024.1.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.3%20%2F%20MOSK%2024.1.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.4%20%2F%20MOSK%2024.1.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.26.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.5%20%2F%20MOSK%2024.1.5%20%28Patch%20release5%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.0" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.27%20%2F%20MOSK%2024.2%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.1%20%2F%20MOSK%2024.1.6%20%28Patch%20release6%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.2%20%2F%20MOSK%2024.1.7%20%28Patch%20release7%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.3%20%2F%20MOSK%2024.2.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.27.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.4%20%2F%20MOSK%2024.2.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.0" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28%20%2F%20MOSK%2024.3%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.1%20%2F%20MOSK%2024.2.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.2%20%2F%20MOSK%2024.2.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.3%20%2F%20MOSK%2024.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.4%20%2F%20MOSK%2024.3.1%20%28Patch%20release1%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.28.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.5%20%2F%20MOSK%2024.3.2%20%28Patch%20release2%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.0" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29%20%2F%20MOSK%2025.1%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.1%20%2F%20MOSK%2024.3.3%20%28Patch%20release3%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.2%20%2F%20MOSK%2024.3.4%20%28Patch%20release4%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.3%20%2F%20MOSK%2024.3.5%20%28Patch%20release5%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.4%20%2F%20MOSK%2024.3.6%20%28Patch%20release6%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.29.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.5%20%2F%20MOSK%2024.3.7%20%28Patch%20release7%29%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.0" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30%20%2F%20MOSK%2025.2%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.1%20%2F%20MOSK%2025.2.1%20(Patch%20release1)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.2%20%2F%20MOSK%2025.2.2%20(Patch%20release2)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.3%20%2F%20MOSK%2025.2.3%20(Patch%20release3)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.4%20%2F%20MOSK%2025.2.4%20(Patch%20release4)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.30.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.0" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31%20%2F%20MOSK%2026.1%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.1%20%2F%20MOSK%2025.2.6%20(Patch%20release6)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.2%20%2F%20MOSK%2025.2.7%20(Patch%20release7)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.3%20%2F%20MOSK%2025.2.8%20(Patch%20release8)%22" >>"$OUT"
    [[ "$MCC_BUG_VER" == "2.31.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.4%20%2F%20MOSK%2025.2.9%20(Patch%20release9)%22" >>"$OUT"
    # Improved MKE Extraction
    MKE_RAW=$(grep -m1 "release: mke-" "$MCC_YAML" | sed -e 's/.*mke-//' -e 's/[[:space:]]//g' -e 's/-/./g')
    IFS='.' read -r -a E <<<"$MKE_RAW"
    # E[0].E[1].E[2] = MKEVER4, MKEVER5, MKEVER6
    MKE_SHORT="${E[3]}.${E[4]}"
    MKE_FULL="${E[3]}-${E[4]}-${E[5]}"
    echo "" >>"$OUT"
    printf "## MKE Version release details: ${E[3]}.${E[4]}.${E[5]}" >>"$OUT"
    echo "" >>"$OUT"
    echo "https://docs.mirantis.com/mke/$MKE_SHORT/release-notes/$MKE_FULL.html" >>"$OUT"
    echo "https://docs.mirantis.com/mke/$MKE_SHORT/release-notes/$MKE_FULL/known-issues.html" >>"$OUT"
    echo "" >>"$OUT"
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
      sed -n '/  status:/,/    requestedNodes:/p' $LCM_MCC >>"$OUT"
    fi
    echo "Gathering Node Conditions..."
    echo "" >>"$OUT"
    echo "################# [NODE CONDITIONS] #################" >>"$OUT"
    for nf in $(grep "/core/nodes" "$LOGPATH/files"); do
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
  grep -iE 'error|fail|warn' $MCC_DIR/objects/namespaced/kaas/core/pods/mariadb-controller-*/controller.log | sed -r '/^\s*$/d' >>"$OUT"
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
fi

# --- MCC FAILED PODS ---
if [[ -n "$MCC_DIR" ]]; then
  OUT="$LOGPATH/mcc_failed_pods"
  echo "Auditing MCC Failed Pods..."
  echo "################# [MCC NON-RUNNING PODS SUMMARY] #################" >"$OUT"
  find "$MCC_DIR" -path "*/core/pods/*.yaml" -type f | while read -r f; do
    PHASE=$(yq eval '.Object.status.phase // .status.phase' "$f" 2>/dev/null)
    if [[ "$PHASE" != "Running" && "$PHASE" != "Succeeded" ]]; then
      NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f")
      NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f")
      REASON=$(yq eval '.Object.status.reason // .status.reason' "$f")
      echo "----------------------------------------------------" >>"$OUT"
      echo "Namespace: $NS | Pod: $NAME | Phase: $PHASE | Reason: ${REASON:-N/A}" >>"$OUT"

      POD_LOG_DIR="${f%.yaml}"
      if [[ -d "$POD_LOG_DIR" ]]; then
        echo "#### Container Logs for $NAME:" >>"$OUT"
        for logfile in "$POD_LOG_DIR"/*.log; do
          [[ -e "$logfile" ]] || continue
          echo "Log: $(basename "$logfile") (last 150 lines)" >>"$OUT"
          tail -n 150 "$logfile" >>"$OUT"
          echo "" >>"$OUT"
        done
      fi
    fi
  done
fi

# --- MOS FAILED PODS ---
if [[ -n "$MOS_DIR" ]]; then
  OUT="$LOGPATH/mos_failed_pods"
  echo "Auditing MOS Failed Pods..."
  echo "################# [MOS NON-RUNNING PODS SUMMARY] #################" >"$OUT"
  find "$MOS_DIR" -path "*/core/pods/*.yaml" -type f | while read -r f; do
    PHASE=$(yq eval '.Object.status.phase // .status.phase' "$f" 2>/dev/null)
    if [[ "$PHASE" != "Running" && "$PHASE" != "Succeeded" ]]; then
      NAME=$(yq eval '.Object.metadata.name // .metadata.name' "$f")
      NS=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$f")
      REASON=$(yq eval '.Object.status.reason // .status.reason' "$f")
      echo "----------------------------------------------------" >>"$OUT"
      echo "Namespace: $NS | Pod: $NAME | Phase: $PHASE | Reason: ${REASON:-N/A}" >>"$OUT"

      POD_LOG_DIR="${f%.yaml}"
      if [[ -d "$POD_LOG_DIR" ]]; then
        echo "#### Container Logs for $NAME:" >>"$OUT"
        for logfile in "$POD_LOG_DIR"/*.log; do
          [[ -e "$logfile" ]] || continue
          echo "Log: $(basename "$logfile") (last 150 lines)" >>"$OUT"
          tail -n 150 "$logfile" >>"$OUT"
          echo "" >>"$OUT"
        done
      fi
    fi
  done
fi

# --- MCC LICENSE & RELEASES ---
OUT="$LOGPATH/mcc_license_releases"
echo "Gathering License and Releases..."
echo "################# [LICENSE & RELEASE DETAILS] #################" >"$OUT"
LICENSE_FILE=$(find "$BASE_DIR/kaas-mgmt" -name "license.yaml" 2>/dev/null)
if [[ -f "$LICENSE_FILE" ]]; then
  echo "## License Status:" >>"$OUT"
  echo "# $LICENSE_FILE:" >>"$OUT"
  yq eval '.Object.status // .status' "$LICENSE_FILE" 2>/dev/null >>"$OUT"
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

# --- FINAL GENERATION BLOCK ---
if [[ -n "$MCCNAME" ]] || [[ -n "$MOSNAME" ]]; then
  echo "Finalizing Dashboard UI..."
  # 1. & 2. Strict Normalization
  for f in "$LOGPATH"/*; do
    filename=$(basename "$f")
    [[ "$filename" == *.html || "$filename" == "files" ]] && continue
    if [[ "$filename" != *_* ]]; then
      rm "$f"
      continue
    fi
    [[ "$filename" != *.yaml ]] && mv "$f" "$f.yaml"
  done

  # 3. BUILD SIDEBAR LINKS
  for yaml_file in $(ls "$LOGPATH"/*_*.yaml 2>/dev/null | sort); do
    [[ -e "$yaml_file" ]] || continue
    FILENAME=$(basename "$yaml_file")
    CATEGORY="cluster"
    [[ "$FILENAME" == mcc_* ]] && CATEGORY="mcc"
    [[ "$FILENAME" == mos_* ]] && CATEGORY="mos"
    TITLE=$(basename "$yaml_file" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    ANCHOR=$(echo "$TITLE" | tr ' ' '-')
    echo "<li data-category='$CATEGORY'><a href='javascript:void(0)' onclick=\"toggleCard(this, '$ANCHOR')\">$TITLE</a></li>" >>"$HTML_REPORT"
  done

  # 4. TRANSITION FROM SIDEBAR TO MAIN
  printf "\n</ul>\n</nav>\n<main class=\"main-content\">\n" >>"$HTML_REPORT"
  cat <<EOF >>"$HTML_REPORT"
<button class="toggle-sidebar-btn" onclick="toggleSidebar()" title="Toggle Sidebar">◀</button>
<div class="header">
    <h1>Myrha - Mirantis Supportdump Dashboard</h1>
    <p>
        <strong>Management (MCC):</strong> ${MCCNAME:-N/A} 
        ${MOSNAME:+ | <strong>Managed (MOSK):</strong> $MOSNAME}
        <br>
        <small>Generated: $DATE</small>
    </p>
</div>
<div id="placeholder" class="placeholder-msg">
    <h2>Empty</h2>
    <p>Please select the fields you would like to analyze from the sidebar on the left.</p>
</div>
EOF

  # 5. BUILD CONTENT CARDS
  for yaml_file in $(ls "$LOGPATH"/*_*.yaml 2>/dev/null | sort); do
    [[ -e "$yaml_file" ]] || continue
    TITLE=$(basename "$yaml_file" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    ANCHOR=$(echo "$TITLE" | tr ' ' '-')
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
      echo "      <a href='#' class='back-to-top'>Top</a>"
      echo "    </div>"
      echo "  </h2>"
      echo "  <pre class='language-yaml raw-code'><code>"
      sed 's/\xc2\xa0/ /g; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$yaml_file"
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
        // Auto-select MCC and MOS clusters by default
        ['MCC-CLUSTER', 'MOS-CLUSTER'].forEach(anchor => {
            const link = document.querySelector(\`#sidebarList a[onclick*="'\${anchor}'"]\`);
            if (link) toggleCard(link, anchor);
        });
    };
</script>
</body>
</html>
EOF
  echo "✅ Dashboard ready: $HTML_REPORT"
  xdg-open "$HTML_REPORT" 2>/dev/null || open "$HTML_REPORT" 2>/dev/null
  #subl --new-window --command $LOGPATH/*.yaml 2> /dev/null
  #nvim -R -c 'silent argdo set syntax=yaml' -p $LOGPATH/*_*
  #nvim -R -p $LOGPATH/*.yaml
fi
if [[ -z "$MCCNAME" ]] && [[ -z "$MOSNAME" ]]; then
  # Delete myrha folder as neither MCC and MOS clusters were found:
  rm -rf $LOGPATH 2>/dev/null
fi
