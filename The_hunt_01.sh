#!/bin/bash

# --- STYLING ---
G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
B='\033[0;34m'
NC='\033[0m'

echo -e "${B}######## # # # # # # # # # # # # # ########################"
echo -e "#             THE HUNT: SHIN CONTROL                          #"
echo -e "#   Interactive: Deep Attack Surface Mapping                  #"
echo -e "# # # # # # # # # # # # # # # # # # # # # # # ############${NC}"

# --- INITIALIZATION ---
read -p "Enter Target Domain (e.g., target.gov): " TARGET
BASE_DIR="The_Hunt_$TARGET"

if [ ! -d "$BASE_DIR" ]; then
    read -p "Create workspace directory at $BASE_DIR? [y/N]: " mkdir_choice
    [[ "$mkdir_choice" =~ ^[Yy]$ ]] && mkdir -p "$BASE_DIR"/{subs,ports,js,endpoints,secrets,vulns,logs}
fi

# --- CORE UTILITY: COMMAND RUNNER ---
# This function handles the "Control" aspect.
run_tool() {
    local tool_name=$1
    local default_cmd=$2

    echo -e "\n${Y}[ MODULE: $tool_name ]${NC}"
    echo -e "Default Option: $default_cmd"
    echo -e "1) Run Default"
    echo -e "2) Run Custom Command (Type it yourself)"
    echo -e "3) Skip Module"
    read -p "Choice: " tool_choice

    case $tool_choice in
        1) eval $default_cmd ;;
        2) read -p "Enter Full Command: " custom_cmd && eval $custom_cmd ;;
        *) echo -e "${R}Skipping $tool_name...${NC}" ;;
    esac
}

# --- STAGE 1: PASSIVE ENUMERATION ---
echo -e "\n${B}--- STAGE 1: SUBDOMAIN DISCOVERY ---${NC}"

# Subfinder
run_tool "Subfinder" "subfinder -d $TARGET -all -silent -o $BASE_DIR/subs/subfinder.txt"

# Assetfinder
run_tool "Assetfinder" "assetfinder --subs-only $TARGET | anew $BASE_DIR/subs/assets.txt"

# BBOT (Deep Passive)
run_tool "BBOT" "bbot -t $TARGET -p subdomain-enum -rf passive -o $BASE_DIR/subs/bbot_passive"

# --- STAGE 2: INFRASTRUCTURE & LIVE HOSTS ---
echo -e "\n${B}--- STAGE 2: INFRA & ALIVE CHECKS ---${NC}"

# Httpx Validation
run_tool "Httpx" "cat $BASE_DIR/subs/*.txt | sort -u | httpx -title -status-code -tech-detect -o $BASE_DIR/subs/live_hosts.txt"

# Naabu (Port Scan)
run_tool "Naabu" "naabu -list $BASE_DIR/subs/live_hosts.txt -top-ports 1000 -o $BASE_DIR/ports/open_ports.txt"

# --- STAGE 3: ENDPOINT & CONTENT DISCOVERY ---
echo -e "\n${B}--- STAGE 3: ARCHIVES & SPIDERING ---${NC}"

# GAU / Wayback
run_tool "GAU/Wayback" "gau --subs $TARGET | anew $BASE_DIR/endpoints/urls.txt"

# Katana (Crawl)
run_tool "Katana" "katana -u $BASE_DIR/subs/live_hosts.txt -jc -o $BASE_DIR/endpoints/katana.txt"

# Sensitive File Leak Check (Using your list of extensions)
EXTS="xls|xml|xlsx|json|pdf|sql|bak|log|db|backup|yml|yaml|env|git|config|pfx"
run_tool "Secret Hunter" "cat $BASE_DIR/endpoints/*.txt | grep -iE '\.($EXTS)$' | httpx -mc 200 -o $BASE_DIR/secrets/leaked_files.txt"

# --- STAGE 4: JAVASCRIPT & LINK FINDING ---
echo -e "\n${B}--- STAGE 4: JS ANALYSIS ---${NC}"

# Linkfinder (Requires Path)
echo -e "${Y}Linkfinder requires a specific path.${NC}"
read -p "Enter path to linkfinder.py: " LF_PATH
run_tool "Linkfinder" "cat $BASE_DIR/endpoints/urls.txt | grep '.js' | xargs -I {} python3 $LF_PATH -i {} -o cli | tee $BASE_DIR/endpoints/js_links.txt"

# --- STAGE 5: VULNERABILITY SPECIFIC ---
echo -e "\n${B}--- STAGE 5: VULNERABILITY SCANNING ---${NC}"

# XSS Hunting (Gxss + Dalfox)
run_tool "XSS Scanning" "cat $BASE_DIR/endpoints/urls.txt | gf xss | Gxss | dalfox pipe -o $BASE_DIR/vulns/xss_results.txt"

# Nuclei (The Big Gun)
run_tool "Nuclei" "nuclei -l $BASE_DIR/subs/live_hosts.txt -t exposures/ -t misconfiguration/ -o $BASE_DIR/vulns/nuclei_results.txt"

# GraphQL / Parameter Discovery
run_tool "Arjun/ParamSpider" "paramspider -d $TARGET && cat results/*.txt | arjun -m GET -o $BASE_DIR/vulns/params.txt"

# --- FINAL WRAP UP ---
echo -e "\n${G}[+] Hunt Complete for $TARGET.${NC}"
echo -e "${G}[+] All data structured in $BASE_DIR/${NC}"
