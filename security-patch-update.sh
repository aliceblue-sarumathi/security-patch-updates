#!/usr/bin/env bash
#
#            "This is for authorized users only.
# Individual use of this code without authority, or in excess of your authority, 
#is strictly prohibited. Monitoring of transmissions or transactional information 
# may be conducted to ensure the proper functioning and security of electronic
# communication resources. Anyone using this code expressly consents to such 
# monitoring and is advised that if such monitoring reveals possible criminal
# activity or policy violation, system personnel may provide the evidence
# of such monitoring to law enforcement or to other senior officials for 
#                    disciplinary action. "
#
#
#########################################################################


export DT="$(/bin/date +%Y-%m-%d-%H-%M-%S)"
export YEAR="$(/bin/date +%Y)"
export MONTH="$(/bin/date +%m)"
export OUTPUT_DIR="output"
export LOG_DIR="${OUTPUT_DIR}/log/${YEAR}/${MONTH}"
export UPGRADE_LIST_DIR="${OUTPUT_DIR}/upgrade-list/${YEAR}/${MONTH}"

# Define servers with their respective SSH usernames, hostnames, SSH key paths, and custom SSH ports
declare -A SERVERS=(
    ["uat-1"]="root@192.168.40.33:/home/test/audit-bash/uat-1:22"
    ["uat-2"]="root@223.31.190.212:/home/test/audit-bash/uat-2:22"
)

# Create output directories if they don't exist
for dir in "${LOG_DIR}" "${UPGRADE_LIST_DIR}"; do
    if [ ! -d "${dir}" ]; then
        mkdir -p "${dir}"
        echo "[ INFO ] Created directory: ${dir}"
    fi
done

# Function to execute commands on a remote server
run_remote_security_patch() {
    local server_name=$1
    local ssh_details=$2

    # Extract username, hostname, path, and port from ssh_details
    local username=$(echo "${ssh_details}" | cut -d@ -f1)
    local host=$(echo "${ssh_details}" | cut -d@ -f2 | cut -d: -f1)
    local key_path=$(echo "${ssh_details}" | cut -d: -f2)
    local port=$(echo "${ssh_details}" | cut -d: -f3)

    local log_file="${LOG_DIR}/${server_name}-security-patch-log-${DT}.txt"
    local upgrade_list_file="${UPGRADE_LIST_DIR}/${server_name}-upgrade-list-${DT}.txt"

    echo "[ INFO ] Starting security patch update on ${server_name} (${host})"
    ssh -i "${key_path}" -p "${port}" "${username}@${host}" <<EOF | tee "${log_file}"
        TEMP_UPGRADE_LIST="/tmp/${server_name}-upgrade-list.txt"
        echo "[ INFO ] Running apt-get update"
        sudo apt-get update

        if [ X"\$?" == X"0" ]; then
            echo "[ INFO ] Listing upgradable packages"
            sudo apt list --upgradable > "\${TEMP_UPGRADE_LIST}"

            if [ X"\$?" == X"0" ]; then
                echo "[ INFO ] Running apt-get upgrade"
                DEBIAN_FRONTEND=noninteractive \
                sudo apt-get \
                -o Dpkg::Options::="--force-confdef" \
                -o Dpkg::Options::="--force-confold" \
                upgrade -y
                
                if [ X"\$?" == X"0" ]; then
                    echo "[ INFO ] Running apt-get autoremove"
                    sudo apt-get autoremove -y
                    echo "[ INFO ] Security patch update completed for ${server_name}"
                else
                    echo "[ ERROR ] Issue encountered during apt-get upgrade. Retrying..."
                    sudo dpkg --configure -a
                    DEBIAN_FRONTEND=noninteractive \
                    sudo apt-get \
                    -o Dpkg::Options::="--force-confdef" \
                    -o Dpkg::Options::="--force-confold" \
                    upgrade -y
                fi
            else
                echo "[ ERROR ] Unable to list upgradable packages. Exiting..."
            fi
        else
            echo "[ ERROR ] Unable to complete apt-get update. Exiting..."
        fi
EOF
    # Retrieve the upgrade-list file from the remote server
    scp -i "${key_path}" -P "${port}" "${username}@${host}:/tmp/${server_name}-upgrade-list.txt" "${upgrade_list_file}"
    echo "[ INFO ] Logs saved to: ${log_file}"
    echo "[ INFO ] Upgrade list saved to: ${upgrade_list_file}"
}

# Loop through servers and run the security patch update
for server_name in "${!SERVERS[@]}"; do
    run_remote_security_patch "${server_name}" "${SERVERS[$server_name]}"
done