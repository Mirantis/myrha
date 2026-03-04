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
cat <<EOF > "$HTML_REPORT"
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
    
    .sidebar h3 { border-bottom: 2px solid var(--accent); padding-bottom: 10px; font-size: 1.1rem; margin-top: 0; color: white; }
    .sidebar ul { list-style: none; padding: 0; }
    .sidebar a { 
        color: var(--sidebar-link); text-decoration: none; font-size: 0.85rem; 
        display: block; padding: 8px 12px; border-radius: 4px; transition: 0.2s; margin-bottom: 2px;
    }
    .sidebar a:hover { background: rgba(255, 255, 255, 0.1); color: var(--sidebar-hover); padding-left: 15px; }
    
    .main-content { flex: 1; padding: 40px; box-sizing: border-box; overflow-x: hidden; transition: width 0.3s; }
    .header { background: white; padding: 25px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); margin-bottom: 30px; border-left: 8px solid var(--accent); position: relative; }
    
    /* Fixed Toggle Sidebar Button */
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
    .card { background: white; border-radius: 12px; padding: 25px; margin-bottom: 35px; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); }
    h2 { color: var(--primary); margin: 0 0 15px 0; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #eee; padding-bottom: 10px; }

    /* Action Buttons in Card Header */
    .card-header-actions { display: flex; align-items: center; gap: 8px; }
    
    .btn-tool {
        font-size: 0.7rem; background: #eee; color: #666; 
        padding: 4px 10px; border-radius: 4px; border: 1px solid #ddd;
        cursor: pointer; transition: 0.2s; font-weight: bold; user-select: none;
    }
    .btn-tool:hover { background: #e0e0e0; border-color: #ccc; }
    .btn-tool.active { background: var(--accent); color: white; border-color: var(--accent); }
    .btn-copy.success { background: #27ae60 !important; color: white !important; border-color: #2ecc71 !important; }

    .back-to-top { 
        font-size: 0.7rem; background: var(--accent); color: white !important; 
        padding: 5px 10px; border-radius: 4px; text-decoration: none !important; font-weight: bold;
    }

    /* Force Wrapping Override Logic */
    pre[class*="language-"].raw-code { white-space: pre !important; word-break: normal !important; overflow-x: auto !important; }
    pre[class*="language-"].wrapped-code { white-space: pre-wrap !important; word-break: break-all !important; overflow-x: hidden !important; }
    pre[class*="language-"] code { white-space: inherit !important; word-break: inherit !important; }

    .card { scroll-margin-top: 20px; }
</style>

<script>
    function toggleSidebar() {
        document.body.classList.toggle('sidebar-hidden');
    }

    function toggleBlockWrap(btn, anchor) {
        const card = document.getElementById(anchor);
        const codeBlock = card.querySelector('pre');
        
        if (codeBlock.classList.contains('wrapped-code')) {
            codeBlock.classList.remove('wrapped-code');
            codeBlock.classList.add('raw-code');
            btn.classList.remove('active');
            btn.innerText = 'Wrap: OFF';
        } else {
            codeBlock.classList.remove('raw-code');
            codeBlock.classList.add('wrapped-code');
            btn.classList.add('active');
            btn.innerText = 'Wrap: ON';
        }
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
        } catch (err) {
            console.error('Failed to copy: ', err);
        }
    }
</script>
</head>
<body>
    <nav class="sidebar">
        <h3>AUDIT SECTIONS</h3>
        <ul id="sidebarList">
EOF

# Helper function to sync YAML content to HTML
#add_to_html() {
#    local title="$1"
#    local content="$2"
#    local anchor="$(echo "$title" | tr ' ' '-')"
#    [[ -z "$content" ]] && return
#    echo "<div class='card' id='$anchor'>
#            <a href='#' class='back-to-top'>↑ Top</a>
#            <h2>$title</h2>
#            <pre>$content</pre>
#          </div>" >> "$HTML_REPORT"
#}

# --- Cert audit function ---
audit_k8s_secret() {
    local YAML_FILE="$1"
    
    if [[ -z "$YAML_FILE" || ! -f "$YAML_FILE" ]]; then
        echo "❌ Error: File '$YAML_FILE' not found."
        return 1
    fi

    local TMP_DIR=$(mktemp -d)
    local IS_WRAPPED=$(yq eval 'has("Object")' "$YAML_FILE" 2>/dev/null)
    local DATA_PATH=".data"
    [[ "$IS_WRAPPED" == "true" ]] && DATA_PATH=".Object.data"

    local KEYS=$(yq eval "$DATA_PATH | keys | .[]" "$YAML_FILE" 2>/dev/null)
    [[ -z "$KEYS" ]] && { rm -rf "$TMP_DIR"; return 1; }

    echo "===================================================="
    echo "🔍 AUDIT REPORT: $(basename "$YAML_FILE")"
    echo "===================================================="

    local LEAF_CERT=""
    local CA_CERT=""
    local PRIVATE_KEY=""

    for KEY in $KEYS; do
        local VAL=$(yq eval "$DATA_PATH.\"$KEY\"" "$YAML_FILE" | tr -d '[:space:]')
        local TARGET_FILE="$TMP_DIR/$KEY"
        echo "$VAL" | base64 -d > "$TARGET_FILE" 2>/dev/null
        
        local CONTENT_TYPE=$(grep -m 1 "BEGIN" "$TARGET_FILE")
        echo "--- Field: [$KEY] ---" 
        
        if [[ "$CONTENT_TYPE" == *"PRIVATE KEY"* ]]; then
            PRIVATE_KEY="$TARGET_FILE"
            cat "$TARGET_FILE"
            echo -e "\n----------------------------------------------------"
            local K_MD5=$(openssl rsa -noout -modulus -in "$TARGET_FILE" 2>/dev/null | openssl md5 | awk '{print $NF}')
            echo "🔑 Key Modulus MD5: $K_MD5"

        elif [[ "$CONTENT_TYPE" == *"CERTIFICATE"* ]]; then
            cat "$TARGET_FILE"
            echo -e "\n----------------------------------------------------"
            
            local CN=$(openssl x509 -noout -subject -in "$TARGET_FILE" -nameopt RFC2253 | sed 's/.*CN=//;s/,.*//')
            local EXPIRY=$(openssl x509 -noout -enddate -in "$TARGET_FILE" | cut -d= -f2)
            local ISSUER=$(openssl x509 -noout -issuer -in "$TARGET_FILE" -nameopt RFC2253)
            local SUBJECT=$(openssl x509 -noout -subject -in "$TARGET_FILE" -nameopt RFC2253)
            local C_MD5=$(openssl x509 -noout -modulus -in "$TARGET_FILE" | openssl md5 | awk '{print $NF}')
            local SAN=$(openssl x509 -noout -ext subjectAltName -in "$TARGET_FILE" 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//')

            echo "📋 CN:      $CN"
            echo "🌐 SAN:     ${SAN:-None}"
            echo "📅 Expires: $EXPIRY"
            echo "🔢 Cert Modulus MD5: $C_MD5"

            if [[ "$KEY" == *"ca"* || "$ISSUER" == "$SUBJECT" ]]; then
                CA_CERT="$TARGET_FILE"
                echo "🏢 Role:    CA/Root Certificate"
            else
                LEAF_CERT="$TARGET_FILE"
                echo "🌿 Role:    Leaf/Server Certificate"
            fi
        fi
        echo ""
    done

    echo "===================================================="
    echo "⚖️  FINAL VALIDATIONS"
    echo "===================================================="

    # 1. Private Key vs Leaf Certificate Match
    printf "Match (Key <-> Leaf): "
    if [[ -n "$LEAF_CERT" && -n "$PRIVATE_KEY" ]]; then
        local FINAL_C_MD5=$(openssl x509 -noout -modulus -in "$LEAF_CERT" | openssl md5 | awk '{print $NF}')
        local FINAL_K_MD5=$(openssl rsa -noout -modulus -in "$PRIVATE_KEY" 2>/dev/null | openssl md5 | awk '{print $NF}')
        [[ "$FINAL_C_MD5" == "$FINAL_K_MD5" ]] && echo "✅ VALID" || echo "❌ MISMATCH"
    else
        echo "ℹ️  SKIPPED (Missing either Private Key or Leaf Cert)"
    fi

    # 2. Trust Chain Validation
    printf "Chain (Leaf <-> CA):  "
    if [[ -n "$LEAF_CERT" && -n "$CA_CERT" ]]; then
        local VERIFY_OUT=$(openssl verify -CAfile "$CA_CERT" "$LEAF_CERT" 2>&1)
        [[ "$VERIFY_OUT" == *"OK"* ]] && echo "✅ VERIFIED" || echo "❌ FAILED ($VERIFY_OUT)"
    else
        echo "ℹ️  SKIPPED (Missing either CA Cert or Leaf Cert)"
    fi

    rm -rf "$TMP_DIR"
    echo "===================================================="
    echo ""
}


echo "Generating report. This operation may take several minutes... Please wait."

# List all files on logs:
echo "🚀 Indexing files and starting analysis..."
find . -not -path '$LOGPATH' -type f -name '*' >$LOGPATH/files

# Discover MCC and MOS cluster name and namespace:
if ls */objects/namespaced/default/cluster.k8s.io/clusters/*.yaml 2>/dev/null 1>/dev/null; then
  MCC_FILE=$(ls */objects/namespaced/default/cluster.k8s.io/clusters/*.yaml 2>/dev/null | head -n 1)
  MCCNAME=$(grep -m1 "    name: " "$MCC_FILE" | awk '{print $2}')
  MCCNAMESPACE=$(grep -m1 "    namespace: " "$MCC_FILE" | awk '{print $2}')
fi
if ls -d */objects/namespaced/openstack 2>/dev/null 1>/dev/null; then
  MOSNAME=$(ls -d */objects/namespaced/openstack | awk -F "/" '{print $1}' | head -n 1)
fi
if [[ -n "$MCCNAME" ]]; then
  MOSNAMESPACE=$(grep -m1 "    namespace: " $(ls ./"$MCCNAME"/objects/namespaced/*/cluster.k8s.io/clusters/*.yaml | grep -v default 2>/dev/null) | awk '{print $2}')
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_cluster"
  echo "Gathering MOS cluster details..."
  echo "################# [MOS CLUSTER DETAILS] #################" > "$OUT"
  
  MOS_STATUS_FILE=$(ls ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml 2>/dev/null | head -n 1)
  
  if [[ -n "$MOS_STATUS_FILE" ]]; then
    # Unified split for MOS (e.g., 21.0.0+25.2.9)
    REL_RAW=$(grep -m1 "    release: " "$MOS_STATUS_FILE" | sed -e 's/.*release: //' -e 's/[[:space:]]//g' -e 's/+/./g')
    IFS='.' read -r -a V <<< "$REL_RAW"
    # V[0]=VER1, V[1]=VER2, V[2]=VER3, V[3]=VER4, V[4]=VER5, V[5]=VER6
    
    printf "## MOS release details (Managed): ${V[0]}.${V[1]}.${V[2]}+${V[3]}.${V[4]}.${V[5]}" >> "$OUT"
    echo "" >> "$OUT"

    if (( $(echo "${V[3]}.${V[4]} >= 25.2" | bc -l) )); then
      echo "https://docs.mirantis.com/mosk/25.2/release-notes/25.2-series/25.2.${V[5]}.html" | sed 's/\.\././' >> "$OUT"
    else
      echo "https://docs.mirantis.com/mosk/25.1-and-earlier/release-notes/release-notes-mosk-old/${V[3]}.${V[4]}-series/${V[3]}.${V[4]}.${V[5]}.html" | sed 's/\.\././' >> "$OUT"
    fi
    echo "" >> "$OUT"
    
    MOS_BUG_VER="${V[3]}.${V[4]}.${V[5]}"
    printf "## MOS Bugs - $MOS_BUG_VER:" >> "$OUT"
    echo "" >> "$OUT"

    # Full Jira Restoration (MOS)
    [[ "$MOS_BUG_VER" == "23.1.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.2%20%2F%20MOSK%2023.1.1%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.1.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.3%20%2F%20MOSK%2023.1.2%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.1.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.4%20%2F%20MOSK%2023.1.3%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.1.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.5%20%2F%20MOSK%2023.1.4%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.2.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.3%20%2F%20MOSK%2023.2.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.2.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.4%20%2F%20MOSK%2023.2.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.2.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.5%20%2F%20MOSK%2023.2.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.3."* ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.25%20%2F%20MOSK%2023.3%22%2C%20%22KaaS%202.25.x%20%2F%20MOSK%2023.3.x%22%29" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.3.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.1%20%2F%20MOSK%2023.3.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.3.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.2%20%2F%20MOSK%2023.3.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.3.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.3%20%2F%20MOSK%2023.3.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "23.3.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.4%20%2F%20MOSK%2023.3.4%20%28Patch%20release4%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1."* ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26%20%2F%20MOSK%2024.1%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.1%20%2F%20MOSK%2024.1.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.2%20%2F%20MOSK%2024.1.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.3%20%2F%20MOSK%2024.1.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.4%20%2F%20MOSK%2024.1.4%20%28Patch%20release4%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.5%20%2F%20MOSK%2024.1.5%20%28Patch%20release5%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1.6" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.1%20%2F%20MOSK%2024.1.6%20%28Patch%20release6%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.1.7" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.2%20%2F%20MOSK%2024.1.7%20%28Patch%20release7%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.2."* ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.27%20%2F%20MOSK%2024.2%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.2.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.3%20%2F%20MOSK%2024.2.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.2.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.4%20%2F%20MOSK%2024.2.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.2.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28.1%20%2F%20MOSK%2024.2.3%20(Patch%20release3)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.2.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28.2%20%2F%20MOSK%2024.2.4%20(Patch%20release4)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.2.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28.3%20%2F%20MOSK%2024.2.5%20(Patch%20release5)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.3" ]]   && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28%20%2F%20MOSK%2024.3%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.3.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.4%20%2F%20MOSK%2024.3.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.3.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.5%20%2F%20MOSK%2024.3.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.3.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29.1%20%2F%20MOSK%2024.3.3%20(Patch%20release3)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.3.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.2%20%2F%20MOSK%2024.3.4%20%28Patch%20release4%29%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.3.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29.3%20%2F%20MOSK%2024.3.5%20(Patch%20release5)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "24.3.6" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29.4%20%2F%20MOSK%2024.3.6%20(Patch%20release6)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.1."* ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.1.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.2."* ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30%20%2F%20MOSK%2025.2%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.2.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.1%20%2F%20MOSK%2025.2.1%20(Patch%20release1)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.2.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.2%20%2F%20MOSK%2025.2.2%20(Patch%20release2)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.2.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.3%20%2F%20MOSK%2025.2.3%20(Patch%20release3)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.2.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.4%20%2F%20MOSK%2025.2.4%20(Patch%20release4)%22" >> "$OUT"
    [[ "$MOS_BUG_VER" == "25.2.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >> "$OUT"

    echo "" >> "$OUT"
    echo "## Details and versions:" >> "$OUT"
    printf '# ' >> "$OUT"
    ls $MOS_STATUS_FILE >> "$OUT"
    grep -m1 "      release:" $MOS_STATUS_FILE >> "$OUT"
    grep -m1 "      openstack_version:" $MOS_STATUS_FILE >> "$OUT"
    sed -n '/    services:/,$p' $MOS_STATUS_FILE >> "$OUT"
    
    if [[ -n "$MCCNAME" ]]; then
      echo "## LCM status:" >> "$OUT"
      printf '# ' >> "$OUT"
      LCM_YAML="./$MCCNAME/objects/namespaced/$MOSNAMESPACE/lcm.mirantis.com/lcmclusters/$MOSNAME.yaml"
      [[ -f "$LCM_YAML" ]] && ls $LCM_YAML >> "$OUT"
      [[ -f "$LCM_YAML" ]] && sed -n '/  status:/,/    requestedNodes:/p' $LCM_YAML >> "$OUT"
    
    echo "" >> "$OUT"
    echo "Gathering Node Conditions..."
    echo "################# [NODE CONDITIONS] #################" >> "$OUT"
    for nf in $(grep "/core/nodes" "$LOGPATH/files" | grep "$MOSNAME"); do
        N_NAME=$(basename "$nf" .yaml)
        # We use sed to grab the block for the specific type, then find the status within it
        READY=$(grep -B 5 'type: Ready' "$nf" | grep "status:" | head -n 1 | awk '{print $NF}' | tr -d '", ')
        DISK=$(grep -B 5 'type: DiskPressure' "$nf" | grep "status" | head -n 1 | awk '{print $NF}' | tr -d '", ')
        
        # Default to Unknown if extraction failed
        [[ -z "$READY" ]] && READY="Unknown"
        [[ -z "$DISK" ]] && DISK="Unknown"

        printf "Node: %-50s | Ready: %-8s | DiskPressure: %-8s\n" "$N_NAME" "$READY" "$DISK" >> "$OUT"
    done
    fi
    #add_to_html "Node Health Status" "$(cat "$OUT")"
  fi
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_events"
  echo "Gathering MOS cluster events..."
  echo "################# [MOS EVENTS (WARNING+ERRORS)] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Analyzed files:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/events.log >>"$OUT"
  grep -E "Warning|Error" ./$MOSNAME/objects/events.log | sort -M >>"$OUT"
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
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $7}' | sed 's|\.yaml||g'
  done <$LOGPATH/mos-nodes >>"$OUT"
  while read -r line; do
    echo ""
    printf "# $line:"
    echo ""
    grep -E "      kaas.mirantis.com/machine-name:" $line
    sed -n '/    nodeInfo:/,/      systemUUID:/p' $line
    sed -n '/    conditions:/,/    daemonEndpoints:/p' $line | head -n -1
  done <$LOGPATH/mos-nodes >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_lcmmachine"
  echo "Gathering MOS LCM machine details..."
  echo "################# [MOS LCM MACHINE DETAILS] #################" >"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/lcm.mirantis.com/lcmmachines $LOGPATH/files >$LOGPATH/mos-lcmmachine
  echo "" >>"$OUT"
  printf '## Machines' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-lcmmachine))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mos-lcmmachine >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  status:/,/    tokenSecret:/p' $line
    echo ""
  done <$LOGPATH/mos-lcmmachine >>"$OUT"
  echo "" >>"$OUT"
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_ceph"
  echo "Gathering MOS Ceph details..."
  echo "################# [MOS CEPH DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Rook-ceph details:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/rook-ceph/ceph.rook.io/cephclusters/rook-ceph.yaml >>"$OUT"
  sed -n '/    ceph:/,/    version:/p' "./$MOSNAME/objects/namespaced/rook-ceph/ceph.rook.io/cephclusters/rook-ceph.yaml" | head -n -1 >>"$OUT"
  echo "" >>"$OUT"
  echo "## Mgr node logs (Warnings/Errors):" >>"$OUT"
  grep "/mgr.log" $LOGPATH/files >$LOGPATH/ceph-mgr
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -iE 'error|fail|warn' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/ceph-mgr >>"$OUT"
  echo "## Mon node logs (Warnings/Errors):" >>"$OUT"
  grep "/mon.log" $LOGPATH/files >$LOGPATH/ceph-mon
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -iE 'error|fail|warn' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/ceph-mon >>"$OUT"
  echo "## Osd node logs (Warnings/Errors):" >>"$OUT"
  grep "/osd.log" $LOGPATH/files >$LOGPATH/ceph-osd
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -iE 'error|fail|warn' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/ceph-osd >>"$OUT"
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_openstack"
  echo "Gathering MOS Openstack details and logs..."
  echo "################# [MOS OPENSTACK DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## OSDPL LCM status details:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml >>"$OUT"
  sed -n '/    osdpl:/,/    services:/p' ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml | head -n -1 >>"$OUT"
  echo "" >>"$OUT"
  echo "## OSDPL details:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeployments/*.yaml >>"$OUT"
  sed -n '/  spec:/,/  status:/p' ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeployments/*.yaml | head -n -1 >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from neutron-server pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'neutron-server.log' $LOGPATH/files >$LOGPATH/mos-openstack-neutron-server
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-neutron-server >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from nova-compute pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'nova-compute.log' $LOGPATH/files >$LOGPATH/mos-openstack-nova-compute
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-nova-compute >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from nova-scheduler pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'nova-scheduler.log' $LOGPATH/files >$LOGPATH/mos-openstack-nova-scheduler
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-nova-scheduler >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from libvirt pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'libvirt.log' $LOGPATH/files >$LOGPATH/mos-openstack-libvirt
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-libvirt >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from keystone-api pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'keystone-api.log' $LOGPATH/files >$LOGPATH/mos-openstack-keystone-api
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-keystone-api >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from cinder-api pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'cinder-api.log' $LOGPATH/files >$LOGPATH/mos-openstack-cinder-api
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-cinder-api >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from glance-api pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep '/glance-api.log' $LOGPATH/files >$LOGPATH/mos-openstack-glance-api
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-glance-api >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from cinder-api pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'cinder-api.log' $LOGPATH/files >$LOGPATH/mos-openstack-cinder-api
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-cinder-api >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from cinder-volume pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'cinder-volume.log' $LOGPATH/files >$LOGPATH/mos-openstack-cinder-volume
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-cinder-volume >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from horizon pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep 'horizon.log' $LOGPATH/files >$LOGPATH/mos-openstack-horizon
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-horizon >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from rabbitmq pods (Errors/Warnings - last 100 lines):" >>"$OUT"
  grep '/rabbitmq.log' $LOGPATH/files >$LOGPATH/mos-openstack-rabbitmq
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E '\[warning\]|\[error\]' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-openstack-rabbitmq >>"$OUT"
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_mariadb"
  echo "Gathering MOS Mariadb details and logs..."
  echo "################# [MOS MARIADB DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Configmap:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/configmaps/openstack-mariadb-mariadb-state.yaml >>"$OUT"
  sed -n '/  data:/,/    creationTimestamp:/p' ./$MOSNAME/objects/namespaced/openstack/core/configmaps/openstack-mariadb-mariadb-state.yaml >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from controller pod (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-controller-*/controller.log >>"$OUT"
  grep -iE 'error|fail|warn' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-controller-*/controller.log | sed -r '/^\s*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-0 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-0/mariadb.log >>"$OUT"
  grep -E 'ERR|WARN' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-0/mariadb.log | sed -r '/^\s*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-1 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-1/mariadb.log >>"$OUT"
  grep -E 'ERR|WARN' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-1/mariadb.log | sed -r '/^\s*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-2 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log >>"$OUT"
  grep -E 'ERR|WARN' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log | sed -r '/^\s*$/d' >>"$OUT"
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_certs"
  echo "Gathering MOS certificates..."
  echo "################# [MOS CERTIFICATE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## TF certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/tf/core/secrets/tungstenfabric-operator-webhook-server-cert.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/tf/core/secrets/tungstenfabric-operator-webhook-server-cert.yaml" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/tf/core/secrets/tfwebui-tls-public.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/tf/core/secrets/tfwebui-tls-public.yaml" >>"$OUT"
  echo "" >>"$OUT"
  echo "## OIDC certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/secrets/oidc-cert.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/openstack/core/secrets/oidc-cert.yaml" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Octavia certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/secrets/octavia-amphora-tls-certs.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/openstack/core/secrets/octavia-amphora-tls-certs.yaml" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Horizon certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/secrets/horizon-tls-public.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/openstack/core/secrets/horizon-tls-public.yaml" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Keystone certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/openstack/core/secrets/keystone-tls-public.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/openstack/core/secrets/keystone-tls-public.yaml" >>"$OUT"
  echo "" >>"$OUT"
  echo "## CEPH RGW certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/rook-ceph/core/secrets/rgw-ssl-certificate.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/rook-ceph/core/secrets/rgw-ssl-certificate.yaml" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Stacklight certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MOSNAME/objects/namespaced/stacklight/core/secrets/oidc-cert.yaml >>"$OUT"
  audit_k8s_secret "./$MOSNAME/objects/namespaced/stacklight/core/secrets/oidc-cert.yaml" >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_ipamhost"
  echo "Gathering MOS Ipamhost details..."
  echo "################# [MOS IPAMHOST DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/ipamhosts/ $LOGPATH/files >$LOGPATH/mos-ipamhost
  printf '## Ipamhosts' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-ipamhost))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mos-ipamhost >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mos-ipamhost >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_l2template"
  echo "Gathering MOS L2template details..."
  echo "################# [MOS L2TEMPLATE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/l2templates/ $LOGPATH/files >$LOGPATH/mos-l2template
  printf '## L2templates' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-l2template))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mos-l2template >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mos_subnet"
  echo "Gathering MOS subnet details..."
  echo "################# [MOS SUBNET DETAILS] #################" >"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files >$LOGPATH/mos-subnet
  echo "" >>"$OUT"
  printf '## Subnets' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-subnet))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mos-subnet >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  status:/,/    tokenSecret:/p' $line
    echo ""
  done <$LOGPATH/mos-subnet >>"$OUT"
  echo "" >>"$OUT"
fi

if [[ -n "$MOSNAME" ]] && [[ -d $MOSNAME/objects/namespaced/tf ]]; then
  OUT="$LOGPATH/mos_tf"
  echo "Gathering MOS TF details..."
  echo "################# [MOS TF DETAILS] #################" >"$OUT"
  grep ./$MOSNAME/objects/namespaced/tf $LOGPATH/files >$LOGPATH/mos-tf
  echo "" >>"$OUT"
  echo '## TF Operator' >>"$OUT"
  printf '# ' >>"$OUT"
  grep "/openstack-tf.yaml" $LOGPATH/files >>"$OUT"
  sed -n '/  spec:/,/$p/p' $(grep "/openstack-tf.yaml" $LOGPATH/files) >>"$OUT"
  echo "" >>"$OUT"
  echo '## TF control logs (Errors/Warnings)' >>"$OUT"
  grep tf-control- $LOGPATH/files | grep log >$LOGPATH/mos-tf-control
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/mos-tf-control >>"$OUT"
  echo "" >>"$OUT"
  echo '## TF config logs (Errors/Warnings)' >>"$OUT"
  grep tf-config- $LOGPATH/files | grep log >$LOGPATH/mos-tf-config
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/mos-tf-config >>"$OUT"
  echo "" >>"$OUT"
  echo '## TF vrouter logs (Errors/Warnings)' >>"$OUT"
  grep tf-vrouter- $LOGPATH/files | grep log >$LOGPATH/mos-tf-vrouter
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/mos-tf-vrouter >>"$OUT"
  echo "" >>"$OUT"
  echo '## TF redis logs (Errors/Warnings)' >>"$OUT"
  grep tf-redis $LOGPATH/files | grep log >$LOGPATH/mos-tf-redis
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -Ei 'ERR|WARN' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/mos-tf-redis >>"$OUT"
  echo "" >>"$OUT"
  echo '## TF cassandra-config logs (Errors/Warnings)' >>"$OUT"
  grep tf-cassandra-config $LOGPATH/files | grep log >$LOGPATH/mos-tf-cassandra-config
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/mos-tf-cassandra-config >>"$OUT"
  echo "" >>"$OUT"
  echo '## TF cassandra-operator logs (Errors/Warnings)' >>"$OUT"
  grep cassandra-operator $LOGPATH/files | grep log >$LOGPATH/mos-tf-cassandra-operator
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E 'ERR|WARN' $line | sed -r '/^\s*$/d'
    echo ""
  done <$LOGPATH/mos-tf-cassandra-operator >>"$OUT"
  echo "" >>"$OUT"
  echo '## TF rabbitmq logs (Errors/Warnings - last 100 lines):' >>"$OUT"
  grep /rabbitmq.log $LOGPATH/files >$LOGPATH/mos-tf-rabbitmq
  while read -r line; do
    printf "# $line:"
    echo ""
    grep -E '\[warning\]|\[error\]' $line | sed -r '/^\s*$/d' | tail -n 100
    echo ""
  done <$LOGPATH/mos-tf-rabbitmq >>"$OUT"
  echo "" >>"$OUT"
fi

if [[ -n "$MOSNAME" ]]; then
  OUT="$LOGPATH/mos_pv_pvc"
  echo "Gathering MOS PV and PVC details..."
  echo "################# [MOS PV AND PVC DETAILS] #################" >"$OUT"
  grep ./$MOSNAME/objects/cluster/core/persistentvolumes/ $LOGPATH/files >$LOGPATH/mos-pv
  echo "" >>"$OUT"
  printf '## Persistent Volumes' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-pv))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $7}' | sed 's|\.yaml||g'
  done <$LOGPATH/mos-pv >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mos-pv >>"$OUT"
  echo "" >>"$OUT"
  grep persistentvolumeclaims $LOGPATH/files | grep $MOSNAME >$LOGPATH/mos-pvc
  printf '## Persistent Volume Claims' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mos-pvc))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mos-pvc >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mos-pvc >>"$OUT"
fi

# MCC Analysis
if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_cluster"
  echo "Gathering MCC cluster details..."
  echo "################# [MCC CLUSTER DETAILS] #################" > "$OUT"
  MCC_YAML="./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml"
  
if [[ -f "$MCC_YAML" ]]; then
    K_RAW=$(grep -m1 "release: kaas-" "$MCC_YAML" | sed -e 's/.*kaas-//' -e 's/[[:space:]]//g' -e 's/-/./g')
    IFS='.' read -r -a M <<< "$K_RAW"
    
    printf "## MCC Version release details: ${M[0]}.${M[1]}.${M[2]}" >> "$OUT"
    echo "" >> "$OUT"
    echo "https://docs.mirantis.com/container-cloud/latest/release-notes/releases/${M[0]}-${M[1]}-${M[2]}.html" >> "$OUT"
    echo "https://docs.mirantis.com/container-cloud/latest/release-notes/releases/${M[0]}-${M[1]}-${M[2]}/known-${M[0]}-${M[1]}-${M[2]}.html" >> "$OUT"
    
    MCC_BUG_VER="${M[0]}.${M[1]}.${M[2]}"
    echo "" >> "$OUT"
    printf "## MCC Bugs - $MCC_BUG_VER:" >> "$OUT"
    echo "" >> "$OUT"

    # Jira (MCC)
    [[ "$MCC_BUG_VER" == "2.23.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.2%20%2F%20MOSK%2023.1.1%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.23.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.3%20%2F%20MOSK%2023.1.2%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.23.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.4%20%2F%20MOSK%2023.1.3%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.23.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.5%20%2F%20MOSK%2023.1.4%20%28Patch%20release%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.24.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.3%20%2F%20MOSK%2023.2.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.24.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.4%20%2F%20MOSK%2023.2.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.24.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.5%20%2F%20MOSK%2023.2.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.25" ]]   && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.25%20%2F%20MOSK%2023.3%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.25.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.1%20%2F%20MOSK%2023.3.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.25.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.2%20%2F%20MOSK%2023.3.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.25.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.3%20%2F%20MOSK%2023.3.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.25.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.4%20%2F%20MOSK%2023.3.4%20%28Patch%20release4%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.26" ]]   && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26%20%2F%20MOSK%2024.1%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.26.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.1%20%2F%20MOSK%2024.1.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.26.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.2%20%2F%20MOSK%2024.1.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.26.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.3%20%2F%20MOSK%2024.1.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.26.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.4%20%2F%20MOSK%2024.1.4%20%28Patch%20release4%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.26.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.5%20%2F%20MOSK%2024.1.5%20%28Patch%20release5%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.27" ]]   && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.27%20%2F%20MOSK%2024.2%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.27.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.1%20%2F%20MOSK%2024.1.6%20%28Patch%20release6%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.27.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.2%20%2F%20MOSK%2024.1.7%20%28Patch%20release7%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.27.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.3%20%2F%20MOSK%2024.2.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.27.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.4%20%2F%20MOSK%2024.2.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.28" ]]   && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.28%20%2F%20MOSK%2024.3%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.28.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.1%20%2F%20MOSK%2024.2.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.28.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.2%20%2F%20MOSK%2024.2.4%20%28Patch%20release4%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.28.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.3%20%2F%20MOSK%2024.2.5%20%28Patch%20release5%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.28.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.4%20%2F%20MOSK%2024.3.1%20%28Patch%20release1%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.28.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.5%20%2F%20MOSK%2024.3.2%20%28Patch%20release2%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.29" ]]   && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.29%20%2F%20MOSK%2025.1%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.29.1" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.1%20%2F%20MOSK%2024.3.3%20%28Patch%20release3%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.29.2" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.2%20%2F%20MOSK%2024.3.4%20%28Patch%20release4%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.29.3" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.3%20%2F%20MOSK%2024.3.5%20%28Patch%20release5%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.29.4" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.4%20%2F%20MOSK%2024.3.6%20%28Patch%20release6%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.29.5" ]] && echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.5%20%2F%20MOSK%2024.3.7%20%28Patch%20release7%29%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.30" ]]   && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30%20%2F%20MOSK%2025.2%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.30.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.1%20%2F%20MOSK%2025.2.1%20(Patch%20release1)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.30.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.2%20%2F%20MOSK%2025.2.2%20(Patch%20release2)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.30.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.3%20%2F%20MOSK%2025.2.3%20(Patch%20release3)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.30.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.4%20%2F%20MOSK%2025.2.4%20(Patch%20release4)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.30.5" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.31" ]]   && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31%20%2F%20MOSK%2026.1%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.31.1" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.1%20%2F%20MOSK%2025.2.6%20(Patch%20release6)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.31.2" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.2%20%2F%20MOSK%2025.2.7%20(Patch%20release7)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.31.3" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.3%20%2F%20MOSK%2025.2.8%20(Patch%20release8)%22" >> "$OUT"
    [[ "$MCC_BUG_VER" == "2.31.4" ]] && echo "https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.31.4%20%2F%20MOSK%2025.2.9%20(Patch%20release9)%22" >> "$OUT"

    # Improved MKE Extraction
    MKE_RAW=$(grep -m1 "release: mke-" "$MCC_YAML" | sed -e 's/.*mke-//' -e 's/[[:space:]]//g' -e 's/-/./g')
    IFS='.' read -r -a E <<< "$MKE_RAW"
    # E[0].E[1].E[2] = MKEVER4, MKEVER5, MKEVER6
    MKE_SHORT="${E[3]}.${E[4]}"
    MKE_FULL="${E[3]}-${E[4]}-${E[5]}"
    echo "" >> "$OUT"
    printf "## MKE Version release details: ${E[3]}.${E[4]}.${E[5]}" >> "$OUT"
    echo "" >> "$OUT"
    echo "https://docs.mirantis.com/mke/$MKE_SHORT/release-notes/$MKE_FULL.html" >> "$OUT"
    echo "https://docs.mirantis.com/mke/$MKE_SHORT/release-notes/$MKE_FULL/known-issues.html" >> "$OUT"

    echo "" >> "$OUT"
    echo "## Details and versions:" >> "$OUT"
    printf '# ' >> "$OUT"
    ls $MCC_YAML >> "$OUT"
    grep -E "release: kaas-|release: mke-|      - message" "$MCC_YAML" >> "$OUT"
    sed -n '/          stacklight:/,/      kind:/p' "$MCC_YAML" >> "$OUT"
    echo "" >> "$OUT"
    
    echo "## LCM status:" >> "$OUT"
    printf '# ' >> "$OUT"
    LCM_MCC="./$MCCNAME/objects/namespaced/$MCCNAMESPACE/lcm.mirantis.com/lcmclusters/$MCCNAME.yaml"
    if [[ -f "$LCM_MCC" ]]; then
        ls $LCM_MCC >> "$OUT"
        sed -n '/  status:/,/    requestedNodes:/p' $LCM_MCC >> "$OUT"
    fi
    echo "Gathering Node Conditions..."
    echo "" >> "$OUT"
    echo "################# [NODE CONDITIONS] #################" >> "$OUT"
    for nf in $(grep "/core/nodes" "$LOGPATH/files" | grep "$MCCNAME"); do
        N_NAME=$(basename "$nf" .yaml)
        # We use sed to grab the block for the specific type, then find the status within it
        READY=$(grep -B 5 'type: Ready' "$nf" | grep "status:" | head -n 1 | awk '{print $NF}' | tr -d '", ')
        DISK=$(grep -B 5 'type: DiskPressure' "$nf" | grep "status" | head -n 1 | awk '{print $NF}' | tr -d '", ')
        
        # Default to Unknown if extraction failed
        [[ -z "$READY" ]] && READY="Unknown"
        [[ -z "$DISK" ]] && DISK="Unknown"

        printf "Node: %-50s | Ready: %-8s | DiskPressure: %-8s\n" "$N_NAME" "$READY" "$DISK" >> "$OUT"
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
  ls ./$MCCNAME/objects/events.log >>"$OUT"
  grep -E "Warning|Error" ./$MCCNAME/objects/events.log | sort -M >>"$OUT"
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
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $7}' | sed 's|\.yaml||g'
  done <$LOGPATH/mcc-nodes >>"$OUT"
  while read -r line; do
    echo ""
    printf "# $line:"
    echo ""
    grep -E "      kaas.mirantis.com/machine-name:" $line
    sed -n '/    nodeInfo:/,/      systemUUID:/p' $line
    sed -n '/    conditions:/,/    daemonEndpoints:/p' $line | head -n -1
  done <$LOGPATH/mcc-nodes >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_lcmmachine"
  echo "Gathering MCC LCM machine details..."
  echo "################# [MCC LCM MACHINE DETAILS] #################" >"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/lcm.mirantis.com/lcmmachines $LOGPATH/files >$LOGPATH/mcc-lcmmachine
  echo "" >>"$OUT"
  printf '## Machines' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-lcmmachine))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mcc-lcmmachine >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  status:/,/    tokenSecret:/p' $line
    echo ""
  done <$LOGPATH/mcc-lcmmachine >>"$OUT"
  echo "" >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_mariadb"
  echo "Gathering MCC Mariadb details and logs..."
  echo "################# [MCC MARIADB DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## Configmap:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/configmaps/iam-mariadb-state.yaml >>"$OUT"
  sed -n '/  data:/,/    creationTimestamp:/p' ./$MCCNAME/objects/namespaced/kaas/core/configmaps/iam-mariadb-state.yaml >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from controller pod (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-controller-*/controller.log >>"$OUT"
  grep -iE 'error|fail|warn' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-controller-*/controller.log | sed -r '/^\s*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-0 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log >>"$OUT"
  grep -E 'ERR|WARN' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log | sed -r '/^\s*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-1 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-1/mariadb.log >>"$OUT"
  grep -E 'ERR|WARN' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-1/mariadb.log | sed -r '/^\s*$/d' >>"$OUT"
  echo "" >>"$OUT"
  echo "## Logs from server-2 pods (Errors/Warnings):" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-2/mariadb.log >>"$OUT"
  grep -E 'ERR|WARN' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-2/mariadb.log | sed -r '/^\s*$/d' >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_certs"
  echo "Gathering MCC certificates..."
  echo "################# [MCC CERTIFICATE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  echo "## UI certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/ui-tls-certs.yaml >>"$OUT"
  audit_k8s_secret "./$MCCNAME/objects/namespaced/kaas/core/secrets/ui-tls-certs.yaml" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/mcc-ca-cert.yaml >>"$OUT"
  audit_k8s_secret "./$MCCNAME/objects/namespaced/kaas/core/secrets/mcc-ca-cert.yaml" >>"$OUT"
  echo "" >>"$OUT"
  echo "## Keycloak certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/keycloak-tls-certs.yaml >>"$OUT"
  audit_k8s_secret "./$MCCNAME/objects/namespaced/kaas/core/secrets/keycloak-tls-certs.yaml" >>"$OUT"
  echo "## OIDC certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/oidc-ca-cert.yaml >>"$OUT"
  audit_k8s_secret "./$MCCNAME/objects/namespaced/kaas/core/secrets/oidc-ca-cert.yaml" >>"$OUT"
  echo "## Policy controller certificates:" >>"$OUT"
  printf '# ' >>"$OUT"
  ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/policy-tls-certs.yaml >>"$OUT"
  audit_k8s_secret "./$MCCNAME/objects/namespaced/kaas/core/secrets/policy-tls-certs.yaml" >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_ipamhost"
  echo "Gathering MCC Ipamhost details..."
  echo "################# [MCC IPAMHOST DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/ipamhosts/ $LOGPATH/files >$LOGPATH/mcc-ipamhost
  printf '## Ipamhosts' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-ipamhost))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mcc-ipamhost >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mcc-ipamhost >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_l2template"
  echo "Gathering MCC L2template details..."
  echo "################# [MCC L2TEMPLATE DETAILS] #################" >"$OUT"
  echo "" >>"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/l2templates/ $LOGPATH/files >$LOGPATH/mcc-l2template
  printf '## L2 templates' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-l2template))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mcc-l2template >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_subnet"
  echo "Gathering MCC subnet details..."
  echo "################# [MCC SUBNET DETAILS] #################" >"$OUT"
  grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files >$LOGPATH/mcc-subnet
  echo "" >>"$OUT"
  printf '## Subnets' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-subnet))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mcc-subnet >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  status:/,/    tokenSecret:/p' $line
    echo ""
  done <$LOGPATH/mcc-subnet >>"$OUT"
  echo "" >>"$OUT"
fi

if [[ -n "$MCCNAME" ]]; then
  OUT="$LOGPATH/mcc_pv_pvc"
  echo "Gathering MCC PV and PVC details..."
  echo "################# [MCC PV AND PVC DETAILS] #################" >"$OUT"
  grep ./$MCCNAME/objects/cluster/core/persistentvolumes/ $LOGPATH/files >$LOGPATH/mcc-pv
  echo "" >>"$OUT"
  printf '## Persistent Volumes' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-pv))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $7}' | sed 's|\.yaml||g'
  done <$LOGPATH/mcc-pv >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mcc-pv >>"$OUT"
  echo "" >>"$OUT"
  grep persistentvolumeclaims $LOGPATH/files | grep $MCCNAME >$LOGPATH/mcc-pvc
  printf '## Persistent Volume Claims' >>"$OUT"
  printf " (Total: $(wc -l <$LOGPATH/mcc-pvc))" >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# "
    printf "$line" | awk -F "/" -v 'OFS=/' '{print $8}' | sed 's|\.yaml||g'
  done <$LOGPATH/mcc-pvc >>"$OUT"
  echo "" >>"$OUT"
  while read -r line; do
    printf "# $line:"
    echo ""
    sed -n '/  spec:/,/    state:/p' $line
    echo ""
  done <$LOGPATH/mcc-pvc >>"$OUT"
fi

# --- FINAL GENERATION BLOCK ---
if [[ -n "$MCCNAME" ]] || [[ -n "$MOSNAME" ]]; then
    echo "Finalizing UI Styling..."

# 1. & 2. Strict Normalization
    # Only process files that have an underscore (our intended output files)
    for f in "$LOGPATH"/*; do
        filename=$(basename "$f")
        
        # Skip the report and the index
        [[ "$filename" == *.html || "$filename" == "files" ]] && continue
        
        # If the file DOES NOT have an underscore, it's a temp file (like mcc-nodes)
        # We delete these to prevent duplicates
        if [[ "$filename" != *_* ]]; then
            rm "$f"
            continue
        fi

        # If it has an underscore but no extension, add .yaml
        if [[ "$filename" != *.yaml ]]; then
            mv "$f" "$f.yaml"
        fi
    done

# 3. BUILD SIDEBAR LINKS
    for yaml_file in $(ls "$LOGPATH"/*_*.yaml 2>/dev/null | sort); do
        [[ -e "$yaml_file" ]] || continue
        # Normalize Title: remove path, remove .yaml, underscores to spaces, uppercase
        TITLE=$(basename "$yaml_file" .yaml | tr '_' ' ' | tr '[:lower:]' '[:upper:]')
        # Create Anchor: spaces to dashes
        ANCHOR=$(echo "$TITLE" | tr ' ' '-')
        echo "<li><a href='#$ANCHOR'>$TITLE</a></li>" >> "$HTML_REPORT"
    done

# 4. TRANSITION FROM SIDEBAR TO MAIN
    printf "\n</ul>\n</nav>\n<main class=\"main-content\">\n" >> "$HTML_REPORT"

    cat <<EOF >> "$HTML_REPORT"
<button class="toggle-sidebar-btn" onclick="toggleSidebar()" title="Toggle Sidebar">◀</button>

<div class="header">
    <h1>Mirantis Diagnostic Dashboard</h1>
    <p>Cluster: <strong>${MOSNAME:-$MCCNAME}</strong> | Generated: $DATE</p>
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
            echo "      <span class='btn-tool btn-copy' onclick=\"copyToClipboard(this, '$ANCHOR')\">Copy</span>"
            echo "      <span class='btn-tool wrap-btn' onclick=\"toggleBlockWrap(this, '$ANCHOR')\">Wrap: OFF</span>"
            echo "      <a href='#' class='back-to-top'>Top</a>"
            echo "    </div>"
            echo "  </h2>"
            echo "  <pre class='language-yaml raw-code'><code>"
            
            # Simple, fast escaping of content
            sed 's/\xc2\xa0/ /g; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$yaml_file"
            
            echo "  </code></pre>"
            echo "</div>"
        } >> "$HTML_REPORT"
    done

# 6. CLOSE DOCUMENT
    printf "\n</main>\n" >> "$HTML_REPORT"
    printf "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js\"></script>\n" >> "$HTML_REPORT"
    printf "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-yaml.min.js\"></script>\n" >> "$HTML_REPORT"
    printf "</body>\n</html>" >> "$HTML_REPORT"

    echo "✅ Dashboard ready: $HTML_REPORT"
    xdg-open "$HTML_REPORT" 2>/dev/null || open "$HTML_REPORT" 2>/dev/null
fi
if [[ -z "$MCCNAME" ]] && [[ -z "$MOSNAME" ]]; then
  # Delete myrha folder as neither MCC and MOS clusters were found:
  rm -rf $LOGPATH 2>/dev/null
fi

