#!/bin/bash
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
cat <<EOF >"$HTML_REPORT"
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
    .sidebar { width: var(--sidebar-width); height: 100vh; background: var(--primary); color: white; position: sticky; top: 0; overflow-y: auto; padding: 20px; box-sizing: border-box; flex-shrink: 0; border-right: 1px solid rgba(0,0,0,0.1); transition: margin-left 0.3s; }
    body.sidebar-hidden .sidebar { margin-left: calc(var(--sidebar-width) * -1); }
    .search-box { width: 100%; padding: 10px; border-radius: 6px; border: 1px solid rgba(255,255,255,0.1); margin-bottom: 20px; background: rgba(255,255,255,0.05); color: white; font-size: 0.85rem; outline: none; transition: 0.2s; }
    .sidebar h3 { border-bottom: 2px solid var(--accent); padding-bottom: 10px; font-size: 1.1rem; margin-top: 0; color: white; }
    .sidebar ul { list-style: none; padding: 0; }
    .sidebar a { color: var(--sidebar-link); text-decoration: none; font-size: 0.85rem; display: block; padding: 8px 12px; border-radius: 4px; transition: 0.2s; margin-bottom: 2px; }
    .sidebar a:hover { background: rgba(255, 255, 255, 0.1); color: var(--sidebar-hover); padding-left: 15px; }
    .sidebar li.hidden { display: none; }
    .main-content { flex: 1; padding: 40px; box-sizing: border-box; overflow-x: hidden; transition: width 0.3s; }
    .header { background: white; padding: 25px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); margin-bottom: 30px; border-left: 8px solid var(--accent); position: relative; }
    .card { background: white; border-radius: 12px; padding: 25px; margin-bottom: 35px; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); min-height: 200px; border-left: 5px solid transparent; content-visibility: auto; contain-intrinsic-size: 1px 500px; }
    h2 { color: var(--primary); margin: 0 0 15px 0; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #eee; padding-bottom: 10px; }
    .card-header-actions { display: flex; align-items: center; gap: 8px; }
    .btn-tool { font-size: 0.7rem; background: #eee; color: #666; padding: 4px 10px; border-radius: 4px; border: 1px solid #ddd; cursor: pointer; transition: 0.2s; font-weight: bold; user-select: none; text-decoration: none; display: inline-block; }
    .btn-copy.success { background: #27ae60 !important; color: white !important; border-color: #2ecc71 !important; }
    .card.fullscreen { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; z-index: 3000; margin: 0; border-radius: 0; overflow-y: auto; box-sizing: border-box; background: white; }
    body.has-fullscreen { overflow: hidden; }
    .card.fullscreen pre { max-height: calc(100vh - 120px); }
    pre[class*="language-"] { max-height: 500px; border-radius: 8px; }
    pre[class*="language-"].raw-code { white-space: pre !important; word-break: normal !important; overflow-x: auto !important; }
    pre[class*="language-"].wrapped-code { white-space: pre-wrap !important; word-break: break-all !important; overflow-x: hidden !important; }
    .filter-tabs { display: flex; gap: 5px; margin-bottom: 15px; }
    .filter-btn { flex: 1; padding: 6px; font-size: 0.75rem; background: rgba(255,255,255,0.1); color: white; border: 1px solid rgba(255,255,255,0.2); border-radius: 4px; cursor: pointer; transition: 0.2s; }
    .filter-btn.active { background: var(--accent); border-color: var(--accent); }
</style>
<script>
    function toggleSidebar() { document.body.classList.toggle('sidebar-hidden'); }
    let currentFilter = 'all';
    function filterType(type) {
        currentFilter = type;
        document.querySelectorAll('.filter-btn').forEach(btn => {
            const btnType = btn.getAttribute('onclick').match(/'([^']+)'/)[1];
            btn.classList.toggle('active', btnType === type);
        });
        applyFilters();
    }
    function filterSidebar() { applyFilters(); }
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
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const codeBlock = entry.target.querySelector('pre code');
                if (codeBlock && !entry.target.dataset.highlighted) {
                    Prism.highlightElement(codeBlock);
                    entry.target.dataset.highlighted = "true";
                }
            }
        });
    }, { threshold: 0.1 });
    window.onload = () => { document.querySelectorAll('.card').forEach(card => observer.observe(card)); };
    function toggleBlockWrap(btn, anchor) {
        const card = document.getElementById(anchor);
        const codeBlock = card.querySelector('pre');
        codeBlock.classList.toggle('wrapped-code');
        codeBlock.classList.toggle('raw-code');
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
            setTimeout(() => { btn.innerText = originalText; btn.classList.remove('success'); }, 2000);
        } catch (err) { console.error('Copy failed:', err); }
    }
    function toggleFullScreen(btn, anchor) {
        const card = document.getElementById(anchor);
        const isFS = card.classList.toggle('fullscreen');
        document.body.classList.toggle('has-fullscreen', isFS);
        btn.innerText = isFS ? 'Exit Full Screen' : 'Full Screen';
    }
</script>
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

# --- Cert audit function (macOS native) ---
audit_k8s_secret() {
  local YAML_FILE="$1"
  [[ -f "$YAML_FILE" ]] || return 1
  local TMP_DIR=$(mktemp -d -t myrha)
  local DATA_EXPR='(.Object.data // .data // .Object.stringData // .stringData)'
  local KEYS=$(yq eval "$DATA_EXPR | keys | .[]" "$YAML_FILE" 2>/dev/null)
  for KEY in $KEYS; do
    local VAL=$(yq eval "$DATA_EXPR.\"$KEY\"" "$YAML_FILE" | tr -d '[:space:]')
    local TARGET_FILE="$TMP_DIR/$KEY"
    echo "$VAL" | base64 -d >"$TARGET_FILE" 2>/dev/null
    if ! grep -q "BEGIN" "$TARGET_FILE" 2>/dev/null; then echo "$VAL" >"$TARGET_FILE"; fi
    if grep -q "BEGIN" "$TARGET_FILE" 2>/dev/null; then
      echo "--- Field: [$KEY] ---"
      if [[ $(grep -m 1 "BEGIN" "$TARGET_FILE") == *"CERTIFICATE"* ]]; then
        local CN=$(openssl x509 -noout -subject -in "$TARGET_FILE" -nameopt RFC2253 | sed 's/.*CN=//;s/,.*//')
        local EXPIRY=$(openssl x509 -noout -enddate -in "$TARGET_FILE" | cut -d= -f2)
        local SAN=$(openssl x509 -noout -ext subjectAltName -in "$TARGET_FILE" 2>/dev/null | grep -v "Subject Alternative Name" | xargs)
        echo "📋 CN: $CN | 🌐 SAN: ${SAN:-None} | 📅 Expires: $EXPIRY"
      fi
    fi
  done
  rm -rf "$TMP_DIR"
}

# --- DISCOVERY ---
[[ -d "./logs" ]] && BASE_DIR="./logs" || BASE_DIR="."
find "$BASE_DIR" -not -path "$LOGPATH/*" -type f >"$LOGPATH/files"
MCC_DIR=$(find "$BASE_DIR" -type d -name "kaas-mgmt" | head -n 1)
MOS_DIR=$(find "$BASE_DIR" -type d -name "mos" | head -n 1)
if [[ -n "$MCC_DIR" ]]; then
  MCC_FILE=$(ls "$MCC_DIR"/objects/namespaced/default/cluster.k8s.io/clusters/*.yaml 2>/dev/null | head -n 1)
  [[ -f "$MCC_FILE" ]] && MCCNAME=$(yq eval '.Object.metadata.name // .metadata.name' "$MCC_FILE")
  [[ -f "$MCC_FILE" ]] && MCCNAMESPACE=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$MCC_FILE")
fi
[[ -n "$MOS_DIR" ]] && MOSNAME=$(basename "$MOS_DIR")
if [[ -n "$MCCNAME" && -n "$MOS_DIR" ]]; then
  MOS_CLUSTER_FILE=$(ls "$MCC_DIR"/objects/namespaced/*/cluster.k8s.io/clusters/*.yaml 2>/dev/null | grep -v default | head -n 1)
  [[ -f "$MOS_CLUSTER_FILE" ]] && MOSNAMESPACE=$(yq eval '.Object.metadata.namespace // .metadata.namespace' "$MOS_CLUSTER_FILE")
fi

# --- GATHERING ---
if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_cluster"; echo "################# [MOS CLUSTER DETAILS] #################" >"$OUT"
  MOS_STATUS_FILE=$(ls $MOS_DIR/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml 2>/dev/null | head -n 1)
  [[ -n "$MOS_STATUS_FILE" ]] && yq eval '.Object.status // .status' "$MOS_STATUS_FILE" >>"$OUT"
  
  for s in neutron nova keystone cinder glance horizon rabbitmq libvirt; do
    OUT="$LOGPATH/mos_openstack_$s"; echo "################# [MOS OPENSTACK ${s^^} LOGS] #################" >"$OUT"
    grep "$s" $LOGPATH/files | grep "\.log" | while read -r l; do
      echo "### $l:" >>"$OUT"; grep -E 'ERR|WARN|error|warning' "$l" | sed -E '/^\s*$/d' | tail -n 150 >>"$OUT"
    done
  done

  OUT="$LOGPATH/mos_mariadb"; echo "################# [MOS MARIADB DETAILS] #################" >"$OUT"
  ls $MOS_DIR/objects/namespaced/openstack/core/configmaps/openstack-mariadb-mariadb-state.yaml 2>/dev/null >>"$OUT"
  grep -iE 'error|fail|warn' $MOS_DIR/objects/namespaced/openstack/core/pods/mariadb-controller-*/controller.log 2>/dev/null | sed -E '/^\s*$/d' >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_cluster"; echo "################# [MCC CLUSTER DETAILS] #################" >"$OUT"
  yq eval '.Object.status // .status' "$MCC_DIR/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml" 2>/dev/null >>"$OUT"
  
  OUT="$LOGPATH/mcc_license_releases"; echo "################# [LICENSE & RELEASES] #################" >"$OUT"
  yq eval '.Object.status // .status' $(find "$MCC_DIR" -name "license.yaml") 2>/dev/null >>"$OUT"
  ls "$MCC_DIR/objects/cluster/kaas.mirantis.com/kaasreleases/" 2>/dev/null >>"$OUT"
fi

for c in "mcc" "mos"; do
  D="${c^^}_DIR"; [[ -n "${!D}" ]] || continue
  OUT="$LOGPATH/${c}_failed_pods"; echo "################# [${c^^} FAILED PODS] #################" >"$OUT"
  find "${!D}" -path "*/core/pods/*.yaml" | while read -r f; do
    P=$(yq eval '.Object.status.phase // .status.phase' "$f" 2>/dev/null)
    [[ "$P" != "Running" && "$P" != "Succeeded" ]] && {
      echo "### $(basename "$f" .yaml) ($P)" >>"$OUT"
      tail -n 150 "${f%.yaml}"/*.log >>"$OUT" 2>/dev/null
    }
  done
done

# --- NETWORKING AUDIT (MCC/MOS) ---
for cluster in "mcc" "mos"; do
  DIR_VAR="${cluster^^}_DIR"
  [[ -n "${!DIR_VAR}" ]] || continue
  OUT="$LOGPATH/${cluster}_networking_audit"
  echo "################# [${cluster^^} NETWORKING AUDIT] #################" >"$OUT"
  
  # 1. Audit Subnets
  echo "## IPAM SUBNETS (Ranges Resume):" >>"$OUT"
  grep "$cluster" "$LOGPATH/files" | grep "ipam.mirantis.com/subnets/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      CIDR=$(yq eval "${PREFIX}.spec.cidr" "$f" 2>/dev/null)
      INC=$(yq eval "${PREFIX}.spec.includeRanges[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      echo "----------------------------------------------------" >>"$OUT"
      printf "Subnet:  %s\nCIDR:    %s\nInclude: [%s]\n" "$NAME" "$CIDR" "${INC:-None}" >>"$OUT"
      echo "$CIDR,$INC" >> "$LOGPATH/${cluster}_ip_collect"
    fi
  done

  # 2. Audit IPAddressPools
  echo -e "\n## METALLB IP POOLS:" >>"$OUT"
  grep "$cluster" "$LOGPATH/files" | grep "ipaddresspools/" | while read -r f; do
    if [[ -f "$f" ]]; then
      PREFIX=$(yq eval 'has("Object")' "$f" 2>/dev/null | grep -q "true" && echo ".Object" || echo "")
      NAME=$(yq eval "${PREFIX}.metadata.name" "$f" 2>/dev/null)
      ADDR=$(yq eval "${PREFIX}.spec.addresses[]" "$f" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      printf "Pool: %-20s | Ranges: [%s]\n" "$NAME" "$ADDR" >>"$OUT"
      echo "$ADDR" >> "$LOGPATH/${cluster}_ip_collect"
    fi
  done

  # 3. Overlap Check
  if [[ -f "$LOGPATH/${cluster}_ip_collect" ]]; then
    echo -e "\n## OVERLAP VERIFICATION:" >>"$OUT"
    check_overlaps < "$LOGPATH/${cluster}_ip_collect" >> "$OUT"
    rm "$LOGPATH/${cluster}_ip_collect"
  fi
done

# --- DASHBOARD GENERATION ---
if [[ -n "$MCCNAME" ]] || [[ -n "$MOSNAME" ]]; then
  for f in "$LOGPATH"/*_*.yaml; do
    [[ -e "$f" ]] || mv "${f%.yaml}" "$f" 2>/dev/null
  done
  for f in $(ls "$LOGPATH"/*_*.yaml 2>/dev/null | sort); do
    T=$(basename "$f" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    A=$(echo "$T" | tr ' ' '-')
    [[ "$(basename "$f")" == mcc_* ]] && C="mcc" || C="mos"
    echo "<li data-category='$C'><a href='#$A'>$T</a></li>" >>"$HTML_REPORT"
  done
  printf "</ul></nav><main class='main-content'>" >>"$HTML_REPORT"
  cat <<EOF >>"$HTML_REPORT"
<button class="toggle-sidebar-btn" onclick="toggleSidebar()">◀</button>
<div class="header"><h1>Mirantis Diagnostic Dashboard (macOS)</h1><p>Generated: $DATE</p></div>
EOF
  for f in $(ls "$LOGPATH"/*_*.yaml 2>/dev/null | sort); do
    T=$(basename "$f" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
    A=$(echo "$T" | tr ' ' '-')
    { echo "<div class='card' id='$A'><h2>$T<div class='card-header-actions'><span class='btn-tool' onclick=\"toggleFullScreen(this, '$A')\">Full Screen</span><span class='btn-tool btn-copy' onclick=\"copyToClipboard(this, '$A')\">Copy</span><span class='btn-tool wrap-btn' onclick=\"toggleBlockWrap(this, '$A')\">Wrap: OFF</span></div></h2><pre class='language-yaml raw-code'><code>"; sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$f"; echo "</code></pre></div>"; } >>"$HTML_REPORT"
  done
  printf "</main><script src='https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js' data-manual></script><script src='https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-yaml.min.js'></script></body></html>" >>"$HTML_REPORT"
  echo "✅ Dashboard ready: $HTML_REPORT"; open "$HTML_REPORT" 2>/dev/null
fi
