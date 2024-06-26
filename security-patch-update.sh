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
export LOG="security-patch-log-${DT}"

[ -f ${LOG} ] && . ${LOG}

export _INFO_FLAG="[ INFO ]"
export _ERROR_FLAG="<< ERROR >>"
export _DEBUG_FLAG=" + < DEBUG >"
export _QUESTION_FLAG="< Question >"

ECHO_INFO()
{
    if [ X"$1" == X"-n" ]; then
        shift 1
        echo -ne "\033[1;32m${_INFO_FLAG} $@\033[00m"
    else
        echo -e "\033[1;32m${_INFO_FLAG} $@\033[00m"
    fi
}

ECHO_QUESTION()
{
    if [ X"$1" == X"-n" ]; then
        shift 1
        echo -ne "${_QUESTION_FLAG} $@"
    else
        echo -e "${_QUESTION_FLAG} $@"
    fi
}

ECHO_ERROR()
{
    echo -e "${_ERROR_FLAG} $@"
}

ECHO_DEBUG()
{
    echo -e "${_DEBUG_FLAG} $@"
}


ECHO_INFO "Running the apt-get update command" | tee -a ${LOG}
sleep 1
sudo apt-get update | tee -a ${LOG}
if [ X"$?" == X"0" ]; then

ECHO_INFO "Running apt upgradable to list the packages" | tee -a ${LOG}
sleep 1
sudo apt list --upgradable | tee -a ${LOG}
if [ X"$?" == X"0" ]; then 

ECHO_INFO "Running the apt-get upgrade command" | tee -a ${LOG}
sleep 1
DEBIAN_FRONTEND=noninteractive \
  apt-get \
 -o Dpkg::Options::="--force-confdef" \
 -o Dpkg::Options::="--force-confold" \
  upgrade -y | tee -a ${LOG}
if [ X"$?" == X"0" ]; then
ECHO_INFO "Running the apt-get autoremove command" | tee -a ${LOG}
sleep 1
sudo apt-get autoremove -y
ECHO_INFO "Security patch update was completed"
else 
ECHO_ERROR "Their is a issue on running the command. Retrying again" | tee -a ${LOG}
sudo dpkg --reconfigure -a | tee -a ${LOG}
DEBIAN_FRONTEND=noninteractive \
  apt-get \
 -o Dpkg::Options::="--force-confdef" \
 -o Dpkg::Options::="--force-confold" \
  upgrade -y | tee -a ${LOG}
fi
else 
ECHO_ERROR "Their is a issue on running the command please check ..." | tee -a ${LOG}
fi
else
ECHO_ERROR "Unable to complete the APT-UPDATE. Please check Log...." | tee -a ${LOG}
fi