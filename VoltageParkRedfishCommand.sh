#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Banner function
print_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "██╗   ██╗ ██████╗ ██╗  ████████╗ █████╗  ██████╗ ███████╗██████╗  █████╗ ██████╗ ██╗  ██╗"
    echo "██║   ██║██╔═══██╗██║  ╚══██╔══╝██╔══██╗██╔════╝ ██╔════╝██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝"
    echo "██║   ██║██║   ██║██║     ██║   ███████║██║  ███╗█████╗  ██████╔╝███████║██████╔╝█████╔╝ "
    echo "╚██╗ ██╔╝██║   ██║██║     ██║   ██╔══██║██║   ██║██╔══╝  ██╔═══╝ ██╔══██║██╔══██╗██╔═██╗ "
    echo " ╚████╔╝ ╚██████╔╝███████╗██║   ██║  ██║╚██████╔╝███████╗██║     ██║  ██║██║  ██║██║  ██╗"
    echo "  ╚═══╝   ╚═════╝ ╚══════╝╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${CYAN}Redfish Command Interface${NC}"
    echo -e "${YELLOW}===============================================${NC}\n"
}

get_creds_redfish() {
    if [ -f ~/.redfish_creds ]; then
        export redfish_creds=$(cat ~/.redfish_creds)
        echo -e "${GREEN}Using saved credentials${NC}"
        return 0
    fi

    echo -e "${YELLOW}Please enter your credentials:${NC}"
    read -p "$(echo -e "${CYAN}Username: ${NC}")" username
    read -s -p "$(echo -e "${CYAN}Password: ${NC}")" password
    echo
    export redfish_creds="${username}:${password}"
    
    read -p "$(echo -e "${YELLOW}Save these credentials? [Y/n]: ${NC}")" save_creds
    if [[ -z "$save_creds" || "$save_creds" =~ ^[Yy]$ ]]; then
        echo "$redfish_creds" > ~/.redfish_creds
        chmod 600 ~/.redfish_creds
        echo -e "${GREEN}✔ Credentials saved${NC}"
    fi
    return 0
}

check_acs() {
    local ip=$1
    nc -nvz -w 3 -G 3 "$ip" 443 > /dev/null 2>&1
    if [ $? -eq 0 ]; then 
        echo -e "\n${CYAN}Checking ACS status for $ip${NC}"
        echo -e "${YELLOW}------------------------${NC}"
        echo -n "Current Setting: "
        local current=$(curl -m 10 -s -k -L -u "$redfish_creds" "https://$ip/redfish/v1/Systems/System.Embedded.1/Bios" | jq -r '.Attributes.ProcVirtualization')
        if [[ "$current" == "Enabled" ]]; then
            echo -e "${GREEN}$current${NC}"
        else
            echo -e "${RED}$current${NC}"
        fi
        
        echo -n "Staged Changes: "
        local staged=$(curl -m 10 -s -k -L -u "$redfish_creds" "https://$ip/redfish/v1/Systems/System.Embedded.1/Bios/Settings" | jq -r '.Attributes.ProcVirtualization')
        if [[ "$staged" == "Enabled" ]]; then
            echo -e "${GREEN}$staged${NC}"
        else
            echo -e "${RED}$staged${NC}"
        fi
    else
        echo -e "${RED}Unable to connect to BMC HTTPS port: $ip:443. Skipping.${NC}"
    fi
}

set_fan_speed() {
    local ip=$1
    local speed=$2
    echo -e "\n${CYAN}Setting fan speed to $speed for $ip${NC}"
    echo -e "${YELLOW}------------------------${NC}"
    if curl -m 2 -s -k -u "$redfish_creds" \
        -X PATCH \
        -H "Content-Type: application/json" \
        -d "{\"Attributes\": {\"ThermalSettings.1.FanSpeedOffset\": \"$speed\"}}" \
        "https://$ip/redfish/v1/Managers/iDRAC.Embedded.1/Oem/Dell/DellAttributes/System.Embedded.1" > /dev/null; then
        echo -e "${GREEN}✔ Fan speed change requested${NC}"
    else
        echo -e "${RED}✘ Failed to set fan speed${NC}"
    fi
}

set_acs() {
    local ip=$1
    local setting=$2
    echo -e "\n${CYAN}Setting ACS to $setting for $ip${NC}"
    echo -e "${YELLOW}------------------------${NC}"
    if curl -skL -u "$redfish_creds" -X PATCH -H "Content-Type: application/json" \
        -d "{
            \"Attributes\": {
                \"ProcVirtualization\": \"$setting\"
            },
            \"@Redfish.SettingsApplyTime\": {
                \"@odata.type\": \"#Settings.v1_1_0.PreferredApplyTime\",
                \"ApplyTime\": \"OnReset\"
            }
        }" \
        "https://$ip/redfish/v1/Systems/System.Embedded.1/Bios/Settings" > /dev/null; then
        
        echo -e "${GREEN}✔ ACS setting change requested${NC}"
        echo -e "\n${YELLOW}Initiating reboot...${NC}"
        
        if curl -skL -u "$redfish_creds" -X POST -H "Content-Type: application/json" \
            -d '{"ResetType": "ForceRestart"}' \
            "https://$ip/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset" > /dev/null; then
            echo -e "${GREEN}✔ Reboot initiated${NC}"
        else
            echo -e "${RED}✘ Failed to initiate reboot${NC}"
        fi
    else
        echo -e "${RED}✘ Failed to set ACS${NC}"
    fi
}

# Initialize credentials
if [ -z "${redfish_creds}" ]; then
    get_creds_redfish
fi

# Print banner
print_banner

# Get IP input
echo -e "${CYAN}${BOLD}IP Address Input${NC}"
echo -e "${YELLOW}---------------${NC}"
echo -e "${CYAN}Enter IP addresses (one per line, press CTRL+D/CMD+D when done):${NC}"
input_ips=()
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -n "$line" ]]; then
        input_ips+=("$line")
    fi
done

# Show the IPs we're working with
echo -e "\n${CYAN}Processing these IPs:${NC}"
for ip in "${input_ips[@]}"; do
    echo -e "${GREEN}✔ $ip${NC}"
done

# Main menu loop
while true; do
    echo -e "\n${CYAN}${BOLD}VoltagePark Command Menu${NC}"
    echo -e "${YELLOW}=====================${NC}"
    echo -e "1. ${GREEN}Check ACS Status${NC}"
    echo -e "2. ${BLUE}Set ACS Enabled and Reboot${NC}"
    echo -e "3. ${BLUE}Set ACS Disabled and Reboot${NC}"
    echo -e "4. ${YELLOW}Set Fan Speed Low${NC}"
    echo -e "5. ${YELLOW}Set Fan Speed Medium${NC}"
    echo -e "6. ${RED}Set Fan Speed High${NC}"
    echo -e "7. ${RED}Exit${NC}"
    read -p "Select an option (1-7): " choice

    case $choice in
        1)
            for ip in "${input_ips[@]}"; do
                check_acs "$ip"
            done
            ;;
        2)
            for ip in "${input_ips[@]}"; do
                set_acs "$ip" "Enabled"
            done
            ;;
        3)
            for ip in "${input_ips[@]}"; do
                set_acs "$ip" "Disabled"
            done
            ;;
        4)
            for ip in "${input_ips[@]}"; do
                set_fan_speed "$ip" "Low"
            done
            ;;
        5)
            for ip in "${input_ips[@]}"; do
                set_fan_speed "$ip" "Medium"
            done
            ;;
        6)
            for ip in "${input_ips[@]}"; do
                set_fan_speed "$ip" "High"
            done
            ;;
        7)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
done 