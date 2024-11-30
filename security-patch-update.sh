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

# Define grouped servers
declare -A UAT_BCP_SERVERS=(
    ["uat"]="root@127.0.0.1:/root/key-file/ssh1:20202"
    ["bcp"]="root@127.0.0.1:/root/key-file/ssh2:22"

)

declare -A PROD_SERVERS=(
    ["prod"]="root@127.0.0.1:/root/key-file/ssh4:22"
    
)

# Create output directories
for dir in "${LOG_DIR}" "${UPGRADE_LIST_DIR}"; do
    if [ ! -d "${dir}" ]; then
        mkdir -p "${dir}"
        echo "[ INFO ] Created directory: ${dir}"
    fi
done

# Function to execute patch updates
run_remote_security_patch() {
    local server_name=$1
    local ssh_details=$2
    local username host key_path port log_file upgrade_list_file success_flag

    username=$(echo "${ssh_details}" | cut -d@ -f1)
    host=$(echo "${ssh_details}" | cut -d@ -f2 | cut -d: -f1)
    key_path=$(echo "${ssh_details}" | cut -d: -f2)
    port=$(echo "${ssh_details}" | cut -d: -f3)
    log_file="${LOG_DIR}/${server_name}-security-patch-log-${DT}.txt"
    upgrade_list_file="${UPGRADE_LIST_DIR}/${server_name}-upgrade-list-${DT}.txt"
    success_flag=0

    echo "[ INFO ] Starting security patch update on ${server_name} (${host})"
    ssh -i "${key_path}" -p "${port}" "${username}@${host}" <<EOF | tee "${log_file}"
        TEMP_UPGRADE_LIST="/tmp/${server_name}-upgrade-list.txt"
        sudo apt-get update && \
        sudo apt list --upgradable > "\${TEMP_UPGRADE_LIST}" && \
        DEBIAN_FRONTEND=noninteractive sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y && \
        sudo apt-get autoremove -y
EOF

    if [ $? -eq 0 ]; then
        success_flag=1
        scp -i "${key_path}" -P "${port}" "${username}@${host}:/tmp/${server_name}-upgrade-list.txt" "${upgrade_list_file}" >/dev/null 2>&1
        echo "[ INFO ] Security patch update completed successfully for ${server_name}"
    else
        echo "[ ERROR ] Security patch update failed for ${server_name}"
    fi

    return $success_flag
}

# Function to update servers in a group
update_group() {
    local group_name=$1
    local -n group_servers=$2

    echo "[ INFO ] Starting patch updates for ${group_name} environment"
    for server_name in "${!group_servers[@]}"; do
        run_remote_security_patch "${server_name}" "${group_servers[$server_name]}"
        if [ $? -ne 1 ]; then
            echo "[ ERROR ] ${group_name} patch update failed at ${server_name}. Aborting..."
            return 1
        fi
    done
    echo "[ INFO ] Completed patch updates for ${group_name} environment"
    return 0
}

# Update UAT and DR, then proceed to Prod if successful
update_group "UAT" UAT_SERVERS && \
update_group "DR" DR_SERVERS && \
update_group "Prod" PROD_SERVERS || \
echo "[ ERROR ] Patch update process aborted due to failures."
