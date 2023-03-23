#!/bin/bash

#*******************************************************************************
#
#       Version 3.1.8 | See the CHANGELOG.md for version information
#
#       See the ReadMe file for detailed configuration steps.
#
#       The "jumpcloud_bootstrap_template.sh" is a template file. Populate the
#       variables in this template file with your org specific settings and zero
#       touch requirements.
#
#       Find a detailed description of each variable within the General Settings.
#
#       Questions or feedback on the JumpCloud bootstrap workflow? Please
#       contact support@jumpcloud.com
#
#       Authors: Scott Reed | scott.reed@jumpcloud.com
#               Joe Workman | joe.workman@jumpcloud.com
#
#*******************************************************************************

################################################################################
# General Settings - INSERT-CONFIGURATION - POPULATE THE BELOW VARIABLES       #
################################################################################

### Bind user as admin or standard user ###
# Admin user: admin="true"
# Standard user: admin="false"
admin="false"

### Minimum password length ###
# Align this setting with the length settings configured in your JumpCloud admin console
minlength=8

### JumpCloud Connect Key ###
YOUR_CONNECT_KEY=""

### Encrypted API Key ###
## Use below SCRIPT FUNCTION: EncryptKey to encrypt key
ENCRYPTED_KEY=""

### Username of the JumpCloud user whose UID is used for decryption ###
DECRYPT_USER=""

### JumpCloud System Group ID For DEP Enrollment ###
DEP_ENROLLMENT_GROUP_ID=""

### JumpCloud System Group ID For DEP POST Enrollment ###
DEP_POST_ENROLLMENT_GROUP_ID=""

### DEPNotify Welcome Window Title ###
WELCOME_TITLE=""

### DEPNotify Welcome Window Text use \n for line breaks ###
WELCOME_TEXT=""

### Boolean to delete the enrollment user set through MDM ###
# Set to false to keep the enrollment users profile on the system
# Ex: DELETE_ENROLLMENT_USERS=false
DELETE_ENROLLMENT_USERS=true

### Username of the enrollment user account configured in the MDM.
### This account will be deleted if the above boolean is set to true.
ENROLLMENT_USER=""

### NTP server, set to time.apple.com by default, Ensure time is correct ###
NTP_SERVER="time.apple.com"

### Daemon Variable
DAEMON="com.jumpcloud.prestage.plist"

### User self identification parameter
# Update the SELF_ID variable with one of the below options to change the default option (Company Email)
# Company Email (default): SELF_ID="CE"
# lastname: SELF_ID="LN"
# personal email: SELF_ID="PE"
# NOTE for "personal email" the JumpCloud user field "description" is used
SELF_ID="CE"

### Include secret id (employee ID) ###
# Default setting is false
# Set to true to add "secret word" to user self identification screen
# This is recommended if "active" JumpCloud users will be enrolled
# NOTE for "secret word" the JumpCloud user field "employeeID" is used
# Ex: DELETE_ENROLLMENT_USERS=true
SELF_SECRET=false

### Password Update Settings ###
# This setting defines if active users will be forced to update their passwords
# Pending users will always be required to set a password during enrollment
# Default setting is false
# Update the SELF_ID SELF_PASSWD to modify this setting
# Ex: SELF_PASSWD=true
SELF_PASSWD=false

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END General Settings                                                         ~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#-------------------------------------------------------------------------------
# Script Functions                                                             -
#-------------------------------------------------------------------------------

# Used to create $ENCRYPTED_KEY
function EncryptKey() {
    # Usage: EncryptKey "API_KEY" "DECRYPT_USER_UID" "ORG_ID"
    local ENCRYPTION_KEY=${2}${3}
    local ENCRYPTED_KEY=$(echo "${1}" | /usr/bin/openssl enc -e -base64 -A -aes-128-ctr -md md5 -nopad -nosalt -k ${ENCRYPTION_KEY})
    echo "Encrypted key: ${ENCRYPTED_KEY}"
}

# Used to decrypt $ENCRYPTED_KEY
function DecryptKey() {
    # Usage: DecryptKey "ENCRYPTED_KEY" "DECRYPT_USER_UID" "ORG_ID"
    echo "${1}" | /usr/bin/openssl enc -d -base64 -aes-128-ctr -md md5 -nopad -A -nosalt -k "${2}${3}"
}

# Resets DEPNotify
function DEPNotifyReset() {
    ACTIVE_USER=$( ls -l /dev/console | awk '{print $3}' )
    rm /var/tmp/depnotify* >/dev/null 2>&1
    rm /var/tmp/com.depnotify.* >/dev/null 2>&1
    rm /Users/"$ACTIVE_USER"/Library/Preferences/menu.nomad.DEPNotify* >/dev/null 2>&1
    killall cfprefsd
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END Script Functions                                                         ~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#-------------------------------------------------------------------------------
# Script Variables                                                             -
#-------------------------------------------------------------------------------

WINDOW_TITLE="Welcome"
DEP_N_DEBUG="/var/tmp/debug_depnotify.log"
DEP_N_APP="/Applications/Utilities/DEPNotify.app"
DEP_N_LOG="/var/tmp/depnotify.log"
DEP_N_REGISTER_DONE="/var/tmp/com.depnotify.registration.done"
DEP_N_DONE="/var/tmp/com.depnotify.provisioning.done"
# Script Receipts Removed at workflow completion
DEP_N_GATE_INSTALLJC="/var/tmp/com.jumpcloud.gate.installjc"
DEP_N_GATE_SYSADD="/var/tmp/com.jumpcloud.gate.sysadd"
DEP_N_GATE_UI="/var/tmp/com.jumpcloud.gate.ui"
DEP_N_GATE_DONE="/var/tmp/com.jumpcloud.gate.done"
DEP_N_COUNTER="/var/tmp/com.jumpcloud.gate.counter.txt"
# System Versions
MacOSMajorVersion=$(sw_vers -productVersion | cut -d '.' -f 1)
MacOSMinorVersion=$(sw_vers -productVersion | cut -d '.' -f 2)
MacOSPatchVersion=$(sw_vers -productVersion | cut -d '.' -f 3)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END Script Variables                                                        ~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#*******************************************************************************
# Pre login bootstrap workflow                                                 *
#*******************************************************************************

CLIENT="mdm-zero-touch"
VERSION="3.1.8"
USER_AGENT="JumpCloud_${CLIENT}/${VERSION}"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# END Script Variables                                                        ~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#*******************************************************************************
# Pre login bootstrap workflow                                                 *
#*******************************************************************************
# First condition - is JC installed
if [[ ! -f $DEP_N_GATE_INSTALLJC ]]; then
    # Caffeinate this script
    caffeinate -d -i -m -u &
    caffeinatePID=$!

    # Install DEPNotify
    curl --silent --output /tmp/DEPNotify-1.1.6.pkg "https://files.nomad.menu/DEPNotify.pkg" >/dev/null
    installer -pkg /tmp/DEPNotify-1.1.6.pkg -target /

    # Create DEPNotify log files
    touch "$DEP_N_DEBUG"
    touch "$DEP_N_LOG"

    # Configure DEPNotify General Settings
    # echo "Command: QuitKey: x" >>"$DEP_N_LOG"
    echo "Command: WindowTitle: $WINDOW_TITLE" >>"$DEP_N_LOG"
    echo "Command: MainTitle: $WELCOME_TITLE" >>"$DEP_N_LOG"
    echo "Command: MainText: $WELCOME_TEXT" >>"$DEP_N_LOG"
    echo "Status: Installing the JumpCloud agent" >>"$DEP_N_LOG"

    # Wait for active user session
    FINDER_PROCESS=$(pgrep -l "Finder")
    until [ "$FINDER_PROCESS" != "" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Finder process not found. User session not active." >>"$DEP_N_DEBUG"
        sleep 1
        FINDER_PROCESS=$(pgrep -l "Finder")
    done

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # END Pre login bootstrap workflow                                             ~
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    #*******************************************************************************
    # Post login active session workflow                                           *
    #*******************************************************************************

    # Capture active user username
    ACTIVE_USER=$( ls -l /dev/console | awk '{print $3}' )

    # Captures active users UID
    uid=$(id -u "$ACTIVE_USER")
    DEP_N_USER_INPUT_PLIST="/Users/$ACTIVE_USER/Library/Preferences/menu.nomad.DEPNotifyUserInput.plist"
    DEP_N_CONFIG_PLIST="/Users/$ACTIVE_USER/Library/Preferences/menu.nomad.DEPNotify.plist"
    defaults write "$DEP_N_CONFIG_PLIST" pathToPlistFile "$DEP_N_USER_INPUT_PLIST"

    ################################################################################
    # DEPNotify PLIST Settings - INSERT-CONFIGURATION                              #
    ################################################################################
    #<--INSERT-CONFIGURATION for "DEPNotify PLIST Settings" below this line---------

    defaults write "$DEP_N_CONFIG_PLIST" registrationMainTitle "Activate Your Account"
    defaults write "$DEP_N_CONFIG_PLIST" registrationButtonLabel "Activate Your Account"

    if [[ $SELF_ID == "CE" ]]; then
        defaults write "$DEP_N_CONFIG_PLIST" textField1Label "Enter Your Company Email Address"
        defaults write "$DEP_N_CONFIG_PLIST" textField1Placeholder "enter email in all lowercase characters"
    elif [[ $SELF_ID == "PE" ]]; then
        defaults write "$DEP_N_CONFIG_PLIST" textField1Label "Enter Your Personal Email Address"
        defaults write "$DEP_N_CONFIG_PLIST" textField1Placeholder "enter email in all lowercase characters"
    elif [[ $SELF_ID == "LN" ]]; then
        defaults write "$DEP_N_CONFIG_PLIST" textField1Label "Enter Your Last Name"
        defaults write "$DEP_N_CONFIG_PLIST" textField1Placeholder "enter last name in all lowercase characters"
    fi

    if [[ $SELF_SECRET == true ]]; then
        defaults write "$DEP_N_CONFIG_PLIST" textField2Label "Enter Your Secret Word"
        defaults write "$DEP_N_CONFIG_PLIST" textField2Placeholder "enter secret in all lowercase characters"
    fi

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # END DEPNotify PLIST Settings                                                 ~
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    # Launch DEPNotify full screen

    # Set ownership of the plist file
    chown "$ACTIVE_USER":staff "$DEP_N_CONFIG_PLIST"
    chmod 600 "$DEP_N_CONFIG_PLIST"
    sudo -u "$ACTIVE_USER" open -a "$DEP_N_APP" --args -path "$DEP_N_LOG" -fullScreen

    # Download and install the JumpCloud agent
    # cat EOF can not be indented
    curl --silent --output /tmp/jumpcloud-agent.pkg "https://cdn02.jumpcloud.com/production/jumpcloud-agent.pkg" >/dev/null
    mkdir -p /opt/jc
    cat <<-EOF >/opt/jc/agentBootstrap.json
{
"publicKickstartUrl": "https://kickstart.jumpcloud.com:443",
"privateKickstartUrl": "https://private-kickstart.jumpcloud.com:443",
"connectKey": "$YOUR_CONNECT_KEY"
}
EOF

    # Below file created by POST install script using munkipkg
    # cat <<-EOF >/var/run/JumpCloud-SecureToken-Creds.txt
    # $ENROLLMENT_USER;$ENROLLMENT_USER_PASSWORD
    # EOF

    # Installs JumpCloud agent
    echo "$(date "+%Y-%m-%d %H:%M:%S"): User $ACTIVE_USER is logged in, installing JC" >>"$DEP_N_DEBUG"
    installer -pkg /tmp/jumpcloud-agent.pkg -target /

    # Validate JumpCloud agent install
    JCAgentConfPath='/opt/jc/jcagent.conf'

    while [ ! -f "$JCAgentConfPath" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for JC Agent to install" >>"$DEP_N_DEBUG"
        sleep 1
    done

    conf="$(cat /opt/jc/jcagent.conf)"
    regex='\"systemKey\":\"[a-zA-Z0-9]{24}\"'
    if [[ $conf =~ $regex ]]; then
        systemKey="${BASH_REMATCH[@]}"
    fi

    while [ -z "$systemKey" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for systemKey to register" >>"$DEP_N_DEBUG"
        sleep 1
        conf="$(cat /opt/jc/jcagent.conf)"
        if [[ $conf =~ $regex ]]; then
            systemKey="${BASH_REMATCH[@]}"
        fi

    done

    echo "$(date "+%Y-%m-%d %H:%M:%S"): JumpCloud agent installed!"

    Sleep 1

    echo "Status: JumpCloud agent installed!" >>"$DEP_N_LOG"

    # JumpCloud installed - add gate file
    kill $caffeinatePID
    touch $DEP_N_GATE_INSTALLJC
fi
# Check if the system has yet to be added to JumpCloud
if [[ ! -f $DEP_N_GATE_SYSADD ]]; then
    # Caffeinate this script
    caffeinate -d -i -m -u &
    caffeinatePID=$!

    sleep 1

    echo "Status: Pulling configuration settings from JumpCloud" >>"$DEP_N_LOG"

    # Add system to DEP_ENROLLMENT_GROUP_ID using System Context API Authentication
    conf="$(cat /opt/jc/jcagent.conf)"
    regex='\"systemKey\":\"[a-zA-Z0-9]{24}\"'

    if [[ $conf =~ $regex ]]; then
        systemKey="${BASH_REMATCH[@]}"
    fi

    echo "$(date "+%Y-%m-%d %H:%M:%S"): systemKey = $systemKey " >>"$DEP_N_DEBUG"

    regex='[a-zA-Z0-9]{24}'
    if [[ $systemKey =~ $regex ]]; then
        systemID="${BASH_REMATCH[@]}"
    fi

    echo "$(date "+%Y-%m-%d %H:%M:%S"): systemID = $systemID " >>"$DEP_N_DEBUG"

    now=$(date -u "+%a, %d %h %Y %H:%M:%S GMT")

    # create the string to sign from the request-line and the date
    signstr="POST /api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members HTTP/1.1\ndate: ${now}"

    # create the signature
    signature=$(printf "$signstr" | openssl dgst -sha256 -sign /opt/jc/client.key | openssl enc -e -a | tr -d '\n')

    DEPenrollmentGroupAdd=$(
        curl -s \
            -X 'POST' \
            -A "${USER_AGENT}" \
            -H 'Content-Type: application/json' \
            -H 'Accept: application/json' \
            -H "Date: ${now}" \
            -H "Authorization: Signature keyId=\"system/${systemID}\",headers=\"request-line date\",algorithm=\"rsa-sha256\",signature=\"${signature}\"" \
            -d '{"op": "add","type": "system","id": "'${systemID}'"}' \
            "https://console.jumpcloud.com/api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members"
    )

    # create the GET string to sign from the request-list and the date
    signstr_check="GET /api/v2/systems/${systemID}/memberof HTTP/1.1\ndate: ${now}"

    # create the GET signature
    signature_check=$(printf "$signstr_check" | openssl dgst -sha256 -sign /opt/jc/client.key | openssl enc -e -a | tr -d '\n')

    DEPenrollmentGroupGet=$(
        curl \
            -X 'GET' \
            -A "${USER_AGENT}" \
            -H 'Content-Type: application/json' \
            -H 'Accept: application/json' \
            -H "Date: ${now}" \
            -H "Authorization: Signature keyId=\"system/${systemID}\",headers=\"request-line date\",algorithm=\"rsa-sha256\",signature=\"${signature_check}\"" \
            --url "https://console.jumpcloud.com/api/v2/systems/${systemID}/memberof"
    )

    # check if the system was added to the DEP ENROLLMENT GROUP in JumpCloud
    groupCheck=$(echo $DEPenrollmentGroupGet | grep $DEP_ENROLLMENT_GROUP_ID)

    # given the case that the above POST request fails, system would not be in the enrollment group
    # while the groupCheck variable is empty, attempt to add the system to the enrollment group
    # then check if the group was added, if the system is in the enrollment group, exit the loop

    echo "$(date "+%Y-%m-%d %H:%M:%S"): Expected systemID: ${systemID} to be a member of group: ${DEP_ENROLLMENT_GROUP_ID}" >>"$DEP_N_DEBUG"
    while [[ -z $groupCheck ]]; do
        # log note
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for system to be added to the DEP ENROLLMENT GROUP" >>"$DEP_N_DEBUG"
        echo "Adding System to JumpCloud Enrollment Group" >>"$DEP_N_LOG"
        sleep 5

        # if system is 10.12 or newer, this command should work to set the system time
        if [[ ($MacOSMajorVersion -eq 10 && $MacOSMinorVersion -ge 12) || $MacOSMajorVersion -ge 11 ]]; then
            # only run this once - set system time (in testing restored images can be out of sync with a time server)
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Setting the correct system time" >>"$DEP_N_DEBUG"
            sntp -sS $NTP_SERVER
        fi

        # attempt to add system to enrollment group
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Attempting to add system to enrollment group again" >>"$DEP_N_DEBUG"
        now=$(date -u "+%a, %d %h %Y %H:%M:%S GMT")
        signstr="POST /api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members HTTP/1.1\ndate: ${now}"
        # create the signature with updated time and string
        signature=$(printf "$signstr" | openssl dgst -sha256 -sign /opt/jc/client.key | openssl enc -e -a | tr -d '\n')

        DEPenrollmentGroupAdd=$(
            curl -s \
                -X 'POST' \
                -A "${USER_AGENT}" \
                -H 'Content-Type: application/json' \
                -H 'Accept: application/json' \
                -H "Date: ${now}" \
                -H "Authorization: Signature keyId=\"system/${systemID}\",headers=\"request-line date\",algorithm=\"rsa-sha256\",signature=\"${signature}\"" \
                -d '{"op": "add","type": "system","id": "'${systemID}'"}' \
                "https://console.jumpcloud.com/api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members"
        )

        # check if the system is in the enrollment group
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Checking Status" >>"$DEP_N_DEBUG"
        now=$(date -u "+%a, %d %h %Y %H:%M:%S GMT")
        signstr_check="GET /api/v2/systems/${systemID}/memberof HTTP/1.1\ndate: ${now}"
        signature_check=$(printf "$signstr_check" | openssl dgst -sha256 -sign /opt/jc/client.key | openssl enc -e -a | tr -d '\n')
        DEPenrollmentGroupGet=$(
            curl \
                -X 'GET' \
                -A "${USER_AGENT}" \
                -H 'Content-Type: application/json' \
                -H 'Accept: application/json' \
                -H "Date: ${now}" \
                -H "Authorization: Signature keyId=\"system/${systemID}\",headers=\"request-line date\",algorithm=\"rsa-sha256\",signature=\"${signature_check}\"" \
                --url "https://console.jumpcloud.com/api/v2/systems/${systemID}/memberof"
        )

        groupCheck=$(echo $DEPenrollmentGroupGet | grep $DEP_ENROLLMENT_GROUP_ID)
    done

    # Set the receipt for the system add gate. The system was added to JumpCloud at this stage
    echo "$(date "+%Y-%m-%d %H:%M:%S"): System added, killing caffeinate process at PID: ${caffeinatePID}" >>"$DEP_N_DEBUG"
    kill $caffeinatePID
    touch $DEP_N_GATE_SYSADD
    echo "System added to JumpCloud Enrollment Group" >>"$DEP_N_LOG"
fi

# User interaction steps - check if user has completed these steps.
if [[ ! -f $DEP_N_GATE_UI ]]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Begin User Interaction steps" >>"$DEP_N_DEBUG"
    # Caffeinate this script
    caffeinate -d -i -m -u &
    caffeinatePID=$!
    echo "$(date "+%Y-%m-%d %H:%M:%S"): User Interaction steps, starting caffeinate process at PID: ${caffeinatePID}" >>"$DEP_N_DEBUG"
    # reboot check
    FINDER_PROCESS=$(pgrep -l "Finder")
    until [ "$FINDER_PROCESS" != "" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Finder process not found. User session not active." >>"$DEP_N_DEBUG"
        sleep 1
        FINDER_PROCESS=$(pgrep -l "Finder")
    done
    echo "$(date "+%Y-%m-%d %H:%M:%S"): User session active." >>"$DEP_N_DEBUG"
    # check if the DEPNotify process is running
    process=$(echo | ps aux | grep "\bDEPNotify\.app")
    if [[ -z $process ]]; then
        ACTIVE_USER=$( ls -l /dev/console | awk '{print $3}' )
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Expected DEPNotify.app to be in process list, process not found. Launching DEPNotify as $ACTIVE_USER" >>"$DEP_N_DEBUG"
        sudo -u "$ACTIVE_USER" open -a "$DEP_N_APP" --args -path "$DEP_N_LOG" -fullScreen
        process=$(echo | ps aux | grep "\bDEPNotify\.app")
        sleep 2
        echo "$(date "+%Y-%m-%d %H:%M:%S"): DEPNotify should be running on process: $process" >>"$DEP_N_DEBUG"
    fi
    # Waiting for DECRYPT_USER_ID to be bound to system
    echo "Status: Pulling Security Settings from JumpCloud" >>"$DEP_N_LOG"

    DECRYPT_USER_ID=$(dscl . -read /Users/$DECRYPT_USER | grep UniqueID | cut -d " " -f 2)

    while [ -z "$DECRYPT_USER_ID" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for DECRYPT_USER_ID for user $DECRYPT_USER" >>"$DEP_N_DEBUG"
        sleep 1
        DECRYPT_USER_ID=$(dscl . -read /Users/$DECRYPT_USER | grep UniqueID | cut -d " " -f 2)
    done

    echo "Status: Security Settings Configured" >>"$DEP_N_LOG"

    # Gather OrgID
    conf="$(cat /opt/jc/jcagent.conf)"
    regex='\"ldap_domain\":\"[a-zA-Z0-9]*'
    if [[ $conf =~ $regex ]]; then
        ORG_ID_RAW="${BASH_REMATCH[@]}"
    fi

    ORG_ID=$(echo $ORG_ID_RAW | cut -d '"' -f 4)

    APIKEY=$(DecryptKey $ENCRYPTED_KEY $DECRYPT_USER_ID $ORG_ID)

    ###
    # Recapture these variables - necessary if the system was restarted
    DEP_N_USER_INPUT_PLIST="/Users/$ACTIVE_USER/Library/Preferences/menu.nomad.DEPNotifyUserInput.plist"
    DEP_N_CONFIG_PLIST="/Users/$ACTIVE_USER/Library/Preferences/menu.nomad.DEPNotify.plist"
    ACTIVE_USER=$( ls -l /dev/console | awk '{print $3}' )
    uid=$(id -u "$ACTIVE_USER")
    ###
    if [[ -z "${APIKEY}" ]]; then

        echo "Command: Notification: Oh no we ran into an error. Tell your Admin that your system could not decrypt the key!" >>"$DEP_N_LOG"

        echo "Command: ContinueButtonRegister: EXIT WITH ERROR" >>"$DEP_N_LOG"

        exit 1

    fi

    ################################################################################
    # User Configuration Settings - INSERT-CONFIGURATION                           #
    ################################################################################
    #<--INSERT-CONFIGURATION for "User Configuration Settings" below this line-------

    ### variable assignments for completing the user module
    if [[ $SELF_ID == "CE" ]]; then
        id_type='"email"'
    elif [[ $SELF_ID == "PE" ]]; then
        id_type='"description"'
    elif [[ $SELF_ID == "LN" ]]; then
        id_type='"lastname"'
    fi

    echo "Command: ContinueButtonRegister: ACTIVATE YOUR ACCOUNT" >>"$DEP_N_LOG"

    sleep 1

    while [ ! -f "$DEP_N_REGISTER_DONE" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for user to fill in information." >>"$DEP_N_DEBUG"
        sleep 1
    done
    echo "$(date "+%Y-%m-%d %H:%M:%S"): User Selection is: $SELF_ID" >>"$DEP_N_DEBUG"
    if [[ $SELF_ID == "CE" ]]; then
        CompanyEmail=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Company Email Address")
    elif [[ $SELF_ID == "PE" ]]; then
        CompanyEmail=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Personal Email Address")
    elif [[ $SELF_ID == "LN" ]]; then
        CompanyEmail=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Last Name")
    fi
    if [[ $SELF_SECRET == true ]]; then
        Secret=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Secret Word")
    fi

    ## secret sauce
    if [[ $SELF_SECRET == true ]]; then
        injection='"employeeIdentifier":"'${Secret}'",'
    else
        injection=""
    fi

    # pending user search default to false
    sec='"activated":false'
    search_active=false
    search_step=0

    # default value for account located
    LOCATED_ACCOUNT='False'

    while [ "$LOCATED_ACCOUNT" == "False" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): User: $CompanyEmail entered information." >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Performing Search with the following parameters: " >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): =================================================" >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Activate status: $sec" >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Using Secret: $injection" >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): ID Type: $id_type" >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): ID Value: $CompanyEmail" >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): =================================================" >>"$DEP_N_DEBUG"

        userSearch=$(
            curl -s \
                -X 'POST' \
                -A "${USER_AGENT}" \
                -H 'Content-Type: application/json' \
                -H 'Accept: application/json' \
                -H "x-api-key: ${APIKEY}" \
                -d '{"filter":[{'$sec','$injection''${id_type}':"'${CompanyEmail}'"}],"fields":["username"]}' \
                "https://console.jumpcloud.com/api/search/systemusers"
        )
        #debug
        echo "$(date "+%Y-%m-%d %H:%M:%S"): DEBUG USER SEARCH $userSearch" >>"$DEP_N_DEBUG"
        regex='totalCount"*.*,"results"'
        if [[ $userSearch =~ $regex ]]; then
            userSearchRaw="${BASH_REMATCH[@]}"
        fi
        #debug
        echo "$(date "+%Y-%m-%d %H:%M:%S"): DEBUG USER SEARCH $userSearchRaw" >>"$DEP_N_DEBUG"
        totalCount=$(echo $userSearchRaw | cut -d ":" -f2 | cut -d "," -f1)

        sleep 1

        # switch to checking active users and increment search step int
        echo "$(date "+%Y-%m-%d %H:%M:%S"): active? $search_active, step $search_step, totalCount $totalCount" >>"$DEP_N_DEBUG"
        if [[ $search_active == false && $search_step -eq 0 && "$totalCount" != "1" ]]; then
            search_step=$((search_step + 1))
            echo "$(date "+%Y-%m-%d %H:%M:%S"): no pending users found. Searching for active users. Search step: $search_step" >>"$DEP_N_DEBUG"
            sec='"activated":true'
            search_active=true
            echo "$(date "+%Y-%m-%d %H:%M:%S"): User: $CompanyEmail entered information." >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Performing Search with the following parameters: " >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): =================================================" >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Activate status (should differ from): $sec" >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Using Secret: $injection" >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): ID Type: $id_type" >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): ID Value: $CompanyEmail" >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): =================================================" >>"$DEP_N_DEBUG"

            # rerun the search:
            userSearch=$(
                curl -s \
                    -X 'POST' \
                    -A "${USER_AGENT}" \
                    -H 'Content-Type: application/json' \
                    -H 'Accept: application/json' \
                    -H "x-api-key: ${APIKEY}" \
                    -d '{"filter":[{'$sec','$injection''${id_type}':"'${CompanyEmail}'"}],"fields":["username"]}' \
                    "https://console.jumpcloud.com/api/search/systemusers"
            )
            regex='totalCount"*.*,"results"'
            if [[ $userSearch =~ $regex ]]; then
                userSearchRaw="${BASH_REMATCH[@]}"
            fi
            #debug
            echo "$(date "+%Y-%m-%d %H:%M:%S"): DEBUG USER SEARCH $userSearchRaw" >>"$DEP_N_DEBUG"
            totalCount=$(echo $userSearchRaw | cut -d ":" -f2 | cut -d "," -f1)
        fi

        # success criteria
        if [ "$totalCount" == "1" ]; then
            search_step=$((search_step + 1))
            LOCATED_ACCOUNT='True'
            if [[ search_step -gt 1 && $search_active == true ]]; then
                pass_path=not_required
                echo "Status: Click CONTINUE" >>"$DEP_N_LOG"
                echo "Command: ContinueButton: CONTINUE" >>"$DEP_N_LOG"
            else
                pass_path=update_required
                echo "Status: Click SET PASSWORD" >>"$DEP_N_LOG"
                echo "Command: ContinueButton: SET PASSWORD" >>"$DEP_N_LOG"
            fi
        fi
        if [[ $search_step -ge 1 && "$totalCount" != "1" ]]; then
            echo "Status: Account Not Found" >>"$DEP_N_LOG"
            # search_step=$((search_step + 1))
            rm $DEP_N_REGISTER_DONE >/dev/null 2>&1
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Try again search step: $search_step" >>"$DEP_N_DEBUG"
            echo "Command: ContinueButtonRegister: Try Again" >>"$DEP_N_LOG"

            sleep 1
            while [ ! -f "$DEP_N_REGISTER_DONE" ]; do
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for user to fill in information." >>"$DEP_N_DEBUG"
                sleep 1
            done
            echo "$(date "+%Y-%m-%d %H:%M:%S"): User Selection is: $SELF_ID" >>"$DEP_N_DEBUG"
            if [[ $SELF_ID == "CE" ]]; then
                CompanyEmail=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Company Email Address")
            elif [[ $SELF_ID == "PE" ]]; then
                CompanyEmail=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Personal Email Address")
            elif [[ $SELF_ID == "LN" ]]; then
                CompanyEmail=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Last Name")
            fi
            if [[ $SELF_SECRET == true ]]; then
                Secret=$(defaults read $DEP_N_USER_INPUT_PLIST "Enter Your Secret Word")
                # update injection variable
                injection='"employeeIdentifier":"'${Secret}'",'
            fi
            # Reset search variables
            search_step=$((0))
            search_active=false
            sec='"activated":false'
            echo "$(date "+%Y-%m-%d %H:%M:%S"): no users found entering loop again search step: $search_step" >>"$DEP_N_DEBUG"
        fi

    done

    # Capture userID
    regex='[a-zA-Z0-9]{24}'
    if [[ $userSearch =~ $regex ]]; then
        # determine cases
        if [[ $SELF_PASSWD == true ]]; then
            pass_path="update_required"
        fi
        userID="${BASH_REMATCH[@]}"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): JumpCloud userID found userID: "$userID >>"$DEP_N_DEBUG"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"): No JumpCloud userID found." >>"$DEP_N_DEBUG"
        exit 1
    fi

    echo "Status: JumpCloud User Account Located" >>"$DEP_N_LOG"

    case $pass_path in
    update_required)
        echo "Status: Click SET PASSWORD" >>"$DEP_N_LOG"
        echo "Command: ContinueButton: SET PASSWORD" >>"$DEP_N_LOG"
        while [ ! -f "$DEP_N_DONE" ]; do
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for user to click Set Password." >>"$DEP_N_DEBUG"
            sleep 1
        done
        ;;
    not_required)
        echo "Status: Click CONTINUE" >>"$DEP_N_LOG"
        echo "Command: ContinueButton: CONTINUE" >>"$DEP_N_LOG"
        while [ ! -f "$DEP_N_DONE" ]; do
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for user to click Continue." >>"$DEP_N_DEBUG"
            sleep 1
        done
        ;;
    esac

    #### PASSWORD BLOCK ####
    case $pass_path in
    update_required)
        echo "doing password stuff"
        # DEPNotify reset
        DEPNotifyReset

        WINDOW_TITLE='Set a password'
        PASSWORD_TITLE="Please set a password"
        PASSWORD_TEXT='Your password must be 8 characters long and contain at least one number, upper case character, lower case character, and special character. \n The longer the better!'

        echo "Command: QuitKey: x" >>"$DEP_N_LOG"
        echo "Command: WindowTitle: $WINDOW_TITLE" >>"$DEP_N_LOG"
        echo "Command: MainTitle: $PASSWORD_TITLE" >>"$DEP_N_LOG"
        echo "Command: MainText: $PASSWORD_TEXT" >>"$DEP_N_LOG"
        echo "Status: Set a password" >>"$DEP_N_LOG"

        sudo -u "$ACTIVE_USER" open -a "$DEP_N_APP" --args -path "$DEP_N_LOG"

        Sleep 2

        # set the number of password pass checks to zero
        passCheck=0

        VALID_PASSWORD='False'

        while [ "$VALID_PASSWORD" == "False" ]; do

            VALID_PASSWORD='True'

            password=$(launchctl asuser "$uid" /usr/bin/osascript -e '
            Tell application "System Events"
                with timeout of 1800 seconds
                    display dialog "PASSWORD COMPLEXITY REQUIREMENTS:\n--------------------------------------------------------------\n * At least 8 characters long \n * Have at least 1 lowercase character \n * Have at least 1 uppercase character \n * Have at least 1 number \n * Have at least 1 special character'"$COMPLEXITY"'" with title "CREATE A SECURE PASSWORD"  buttons {"Continue"} default button "Continue" with hidden answer default answer ""' -e 'text returned of result 
                end timeout
            end tell' 2>/dev/null)
            # Length check
            lengthCheck='.{'$minlength',100}'
            if [[ $password =~ $lengthCheck ]]; then
                LENGTH=''
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password meets length requirements"
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password does not meet length requirements" >>"$DEP_N_DEBUG"
                LENGTH='\n* LENGTH'
                VALID_PASSWORD='False'
            fi

            # Upper case check
            upperCheck='[[:upper:]]+'
            if [[ $password =~ $upperCheck ]]; then
                UPPER=''
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password contains a upper case letter"
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password does not contain a upper case letter" >>"$DEP_N_DEBUG"
                UPPER='\n* UPPER CASE'
                VALID_PASSWORD='False'

            fi

            # Lower chase check
            lowerCheck='[[:lower:]]+'
            if [[ $password =~ $lowerCheck ]]; then
                LOWER=''
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password contains a lower case letter"
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password does not contain a lower case letter" >>"$DEP_N_DEBUG"
                LOWER='\n* LOWER CASE'
                VALID_PASSWORD='False'
            fi

            # Special character check
            specialCharCheck='[!@#$%^&*(),.?":{}|<>]'
            if [[ $password =~ $specialCharCheck ]]; then
                SPECIAL=''
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password contains a special character"
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password does not contains a special character" >>"$DEP_N_DEBUG"
                SPECIAL='\n* SPECIAL CHARACTER'
                VALID_PASSWORD='False'

            fi

            # Number check
            numberCheck='[0-9]'
            if [[ $password =~ $numberCheck ]]; then
                NUMBER=''
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password contains a number"
            else
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Password does not contain a number" >>"$DEP_N_DEBUG"
                NUMBER='\n* NUMBER'
                VALID_PASSWORD='False'

            fi

            # only display password match confirmation after all password is valid
            if [[ $passCheck == 0 ]]; then
                COMPLEXITY='\n\nCOMPLEXITY NOT SATISFIED:\n --------------------------------------------------------------'$LENGTH''$UPPER''$LOWER''$SPECIAL''$NUMBER' \n\n TRY AGAIN'
            else
                # Dialogue returned with password match status
                COMPLEXITY='\n\nCOMPLEXITY NOT SATISFIED:\n --------------------------------------------------------------'$LENGTH''$UPPER''$LOWER''$SPECIAL''$NUMBER''$passMatch' \n\n TRY AGAIN'
            fi

            if [[ $VALID_PASSWORD == 'True' ]]; then
                passCheck=$((passCheck + 1))
                passwordMatch=$(launchctl asuser "$uid" /usr/bin/osascript -e '
                Tell application "System Events"
                    with timeout of 1800 seconds
                        display dialog "CONFIRM PASSWORD:\n--------------------------------------------------------------\n" with title "CONFIRM A SECURE PASSWORD"  buttons {"Continue"} default button "Continue" with hidden answer default answer ""' -e 'text returned of result 
                    end timeout
                end tell' 2>/dev/null)

                # match Check
                passMatch="Passwords do not match"
                if [[ $password == "$passwordMatch" ]]; then
                    echo "$(date "+%Y-%m-%d %H:%M:%S"): Passwords Match"
                    passMatch="Passwords match"
                else
                    # Passwords do not match, reset passCheck counter
                    echo "$(date "+%Y-%m-%d %H:%M:%S"): Password does not contain a match"
                    passCheck=0
                    VALID_PASSWORD='False'
                fi

                COMPLEXITY='\n\nCOMPLEXITY NOT SATISFIED:\n --------------------------------------------------------------'$LENGTH''$UPPER''$LOWER''$SPECIAL''$NUMBER''$passMatch' \n\n TRY AGAIN'
            fi

        done

        echo "Status: Click CONTINUE" >>"$DEP_N_LOG"
        echo "Command: ContinueButton: CONTINUE" >>"$DEP_N_LOG"

        while [ ! -f "$DEP_N_DONE" ]; do
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for user to click CONTINUE" >>"$DEP_N_DEBUG"
            sleep 1
        done
        ;;
    not_required)
        echo "not required"
        ;;
    esac

    #### PASSWORD BLOCK ####

    # DEPnotify rest

    DEPNotifyReset

    touch "$DEP_N_LOG"

    WINDOW_TITLE='User Configuration'
    FINAL_TITLE="Almost to the finish line!"
    FINAL_TEXT='\n \n \n Working on account configuration'

    echo "Command: QuitKey: x" >>"$DEP_N_LOG"
    echo "Command: WindowTitle: $WINDOW_TITLE" >>"$DEP_N_LOG"
    echo "Command: MainTitle: $FINAL_TITLE" >>"$DEP_N_LOG"
    echo "Command: MainText: $FINAL_TEXT" >>"$DEP_N_LOG"
    echo "Status: Activating Account" >>"$DEP_N_LOG"

    sudo -u "$ACTIVE_USER" open -a "$DEP_N_APP" --args -path "$DEP_N_LOG" -fullScreen

    ## User creation

    userUpdate=$(
        curl -s \
            -X 'PUT' \
            -A "${USER_AGENT}" \
            -H 'Content-Type: application/json' \
            -H 'Accept: application/json' \
            -H "x-api-key: ${APIKEY}" \
            -d '{"password" : "'${password}'"}' \
            "https://console.jumpcloud.com/api/systemusers/${userID}"
    )

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # END User Configuration Settings                                              ~
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    # user interaction complete - add gate file
    kill $caffeinatePID
    touch $DEP_N_GATE_UI
fi
# Final steps to complete the install
if [[ ! -f $DEP_N_GATE_DONE ]]; then

    # Caffeinate this script
    caffeinate -d -i -m -u &
    caffeinatePID=$!
    ## Get the JumpCloud SystemID
    conf="$(cat /opt/jc/jcagent.conf)"
    regex='\"systemKey\":\"[a-zA-Z0-9]{24}\"'

    if [[ $conf =~ $regex ]]; then
        systemKey="${BASH_REMATCH[@]}"
    fi

    regex='[a-zA-Z0-9]{24}'
    if [[ $systemKey =~ $regex ]]; then
        systemID="${BASH_REMATCH[@]}"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): JumpCloud systemID found: "$systemID >>"$DEP_N_DEBUG"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"): No systemID found" >>"$DEP_N_DEBUG"
        exit 1
    fi

    ## Capture current logFile
    logLinesRaw=$(wc -l /var/log/jcagent.log)

    logLines=$(echo $logLinesRaw | head -n1 | awk '{print $1;}')

    echo "Status: Creating System Account" >>"$DEP_N_LOG"

    ## Bind JumpCloud user to JumpCloud system
    userBind=$(
        curl -s \
            -X 'POST' \
            -A "${USER_AGENT}" \
            -H 'Accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'x-api-key: '${APIKEY}'' \
            -d '{ "attributes": { "sudo": { "enabled": '${admin}',"withoutPassword": false}}   , "op": "add", "type": "user","id": "'${userID}'"}' \
            "https://console.jumpcloud.com/api/v2/systems/${systemID}/associations"
    )

    #Check and ensure user bound to system
    userBindCheck=$(
        curl -s \
            -X 'GET' \
            -A "${USER_AGENT}" \
            -H 'Accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'x-api-key: '${APIKEY}'' \
            "https://console.jumpcloud.com/api/v2/systems/${systemID}/associations?targets=user"
    )

    regex=''${userID}''

    if [[ $userBindCheck =~ $regex ]]; then
        userID="${BASH_REMATCH[@]}"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): JumpCloud user "$userID "bound to systemID: "$systemID >>"$DEP_N_DEBUG"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"): $userID : $userBindCheck : $regex error JumpCloud user not bound to system" >>"$DEP_N_DEBUG"
        # fail counter
        if [[ ! -f $DEP_N_COUNTER ]]; then
            touch $DEP_N_COUNTER
            "0" > $DEP_N_COUNTER
        else
            count=$(cat $DEP_N_COUNTER)
            if [[ $count == "3" ]]; then
                # Make script delete itself
                echo "Command: Quit: "Enrollment Failed, check the debug logs in /var/tmp/"" >>"$DEP_N_LOG"
                rm -- "$0"
            else
                echo $(($count + 1)) > $DEP_N_COUNTER
            fi
        fi
        exit 1
    fi

    #Wait to see local account takeover by the JumpCloud agent

    updateLog=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)

    Sleep 6

    echo "Status: Configuring System Account" >>"$DEP_N_LOG"

    accountTakeOverCheck=$(echo ${updateLog} | grep "User updates complete")

    logoutTimeoutCounter='0'

    while [[ -z "${accountTakeOverCheck}" ]]; do
        Sleep 6
        updateLog=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)
        accountTakeOverCheck=$(echo ${updateLog} | grep "User updates complete")
        logoutTimeoutCounter=$((${logoutTimeoutCounter} + 1))
        if [[ ${logoutTimeoutCounter} -eq 10 ]]; then
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Error during JumpCloud agent local account takeover" >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): JCAgent.log: ${updateLog}" >>"$DEP_N_DEBUG"
            exit 1
        fi
    done

    echo "Status: System Account Configured" >>"$DEP_N_LOG"

    echo "$(date "+%Y-%m-%d %H:%M:%S"): JumpCloud agent local account takeover complete" >>"$DEP_N_DEBUG"

    # Remove from DEP_ENROLLMENT_GROUP and add to DEP_POST_ENROLLMENT_GROUP
    removeGrp=$(
    curl \
        -X 'POST' \
        -A "${USER_AGENT}" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'x-api-key: '${APIKEY}'' \
        -d '{"op": "remove","type": "system","id": "'${systemID}'"}' \
        "https://console.jumpcloud.com/api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members"
    )
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Removing Enrollment Group $removeGrp" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Removed from DEP_ENROLLMENT_GROUP_ID: $DEP_ENROLLMENT_GROUP_ID" >>"$DEP_N_DEBUG"
    addGrp=$(
    curl \
        -X 'POST' \
        -A "${USER_AGENT}" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'x-api-key: '${APIKEY}'' \
        -d '{"op": "add","type": "system","id": "'${systemID}'"}' \
        "https://console.jumpcloud.com/api/v2/systemgroups/${DEP_POST_ENROLLMENT_GROUP_ID}/members"

    )
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Adding to Post Enrollment Group $addGrp" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Added to from DEP_POST_ENROLLMENT_GROUP_ID: $DEP_POST_ENROLLMENT_GROUP_ID" >>"$DEP_N_DEBUG"

    echo "Status: Applying Finishing Touches" >>"$DEP_N_LOG"

    FINISH_TEXT='This window will automatically close when onboarding is complete.\n\nYou will be taken directly to the log in screen. \n\n Log in with your new account! \n\n'

    echo "Command: MainText: $FINISH_TEXT" >>"$DEP_N_LOG"

    # Get JCAgent.log to ensure user updates have been processes on the system
    logLinesRaw=$(wc -l /var/log/jcagent.log)
    logLines=$(echo $logLinesRaw | head -n1 | awk '{print $1;}')
    groupSwitchCheck=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)
    groupTakeOverCheck=$(echo ${groupSwitchCheck} | grep "User updates complete")

    # Get current Time
    now=$(date "+%y/%m/%d %H:%M:%S")
    # Get last line of the JumpCloud Agent
    lstLine=$(tail -1 /var/log/jcagent.log)
    regexLine='([0-9][0-9])-([0-9][0-9])-([0-9][0-9]) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9])'
    if [[ $lstLine =~ $regexLine ]]; then
        # Get the time form the agent log
        lstTime=${BASH_REMATCH[0]}
    fi
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Current System Time       : $now" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): JCAgent Last Log Time     : $lstTime" >>"$DEP_N_DEBUG"
    # convert to Epoch time
    nowEpoch=$(date -j -f "%y/%m/%d %T" "${now}" +'%s')
    jclogEpoch=$(date -j -f "%y-%m-%d %T" "${lstTime}" +'%s')
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Current System Epoch Time : $nowEpoch" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Last JCAgent Epoch Time   : $jclogEpoch" >>"$DEP_N_DEBUG"
    # get the difference in time
    epochDiff=$(( (nowEpoch - jclogEpoch) ))
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Difference between logs is: $epochDiff seconds" >>"$DEP_N_DEBUG"

    # Check the JCAgent log, it should check in under 180s
    while [[ $epochDiff -le 180 ]]; do
        # wait a second and update all the variables
        Sleep 1
        groupSwitchCheck=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)
        groupTakeOverCheck=$(echo ${groupSwitchCheck} | grep "Processing user updates")
        lstLine=$(tail -1 /var/log/jcagent.log)
        regexLine='([0-9][0-9])-([0-9][0-9])-([0-9][0-9]) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9])'
        if [[ $lstLine =~ $regexLine ]]; then
            lstTime=${BASH_REMATCH[0]}
        fi
        jclogEpoch=$(date -j -f "%y-%m-%d %T" "${lstTime}" +'%s')
                now=$(date "+%y/%m/%d %H:%M:%S")
                nowEpoch=$(date -j -f "%y/%m/%d %T" "${now}" +'%s')
                epochDiff=$(( (nowEpoch - jclogEpoch) ))
        # if the log is empty continue while loop
        if [[ -z $groupTakeOverCheck ]]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for log sync, JCAgent last log was: $epochDiff seconds ago" >>"$DEP_N_DEBUG"
            # echo "$(date "+%Y-%m-%d %H:%M:%S"): JCAgent last line: $lstLine" >>"$DEP_N_DEBUG"
        else
            now=$(date "+%y/%m/%d %H:%M:%S")
            # log found, break out of the while loop
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Log Synced! User Updates Complete $now" >>"$DEP_N_DEBUG"
            # echo "$(date "+%Y-%m-%d %H:%M:%S"): $groupTakeOverCheck" >>"$DEP_N_DEBUG"
            break
        fi
        # if the time difference is greater than 90 seconds, restart the JumpCloud agent to begin logging again
        if [[ $epochDiff -eq 90 ]]; then
            echo "$(date "+%Y-%m-%d %H:%M:%S"): JumpCloud not reporting local account takeover" >>"$DEP_N_DEBUG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Restarting JumpCloud Agent" >>"$DEP_N_DEBUG"
            launchctl stop com.jumpcloud.darwin-agent
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for JCAgent..." >>"$DEP_N_DEBUG"
            sleep 5
        fi
    done

    # Check for errors
    now=$(date "+%y/%m/%d %H:%M:%S")
    nowEpoch=$(date -j -f "%y/%m/%d %T" "${now}" +'%s')
    epochDiff=$(( (nowEpoch - jclogEpoch) ))
    if [[ $epochDiff -gt 180 ]]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Error syncing JCAgent logs exiting Enrollment..." >>"$DEP_N_DEBUG"
        echo "Command: MainTitle: Enrollment Failed" >>"$DEP_N_LOG"
        echo "Command: MainText: Enrollment Encountered an Error" >>"$DEP_N_LOG"
        echo "Status: Check the debug logs" >>"$DEP_N_LOG"
        sleep 10
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Status: Removing LaunchDaemon" >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Status: Quitting Enrollment" >>"$DEP_N_DEBUG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Deleting the decrypt user: $DECRYPT_USER" >>"$DEP_N_DEBUG"
        sysadminctl -deleteUser $DECRYPT_USER >>"$DEP_N_DEBUG" 2>&1
        echo "Command: Quit: "Enrollment Failed, check the debug logs in /var/tmp/"" >>"$DEP_N_LOG"
        launchctl unload "/Library/LaunchDaemons/${DAEMON}"
        rm -- "$0"
    fi

    # Check for system details and log user agent to JumpCloud
    sysSearch=$(curl -X GET \
                -A "${USER_AGENT}" \
                -H 'Accept: application/json' \
                -H 'Content-Type: application/json' \
                -H 'x-api-key: '${APIKEY}'' \
                "https://console.jumpcloud.com/api/systems/${systemID}"
            )

    # Get details about the current system, log details
    regexSerial='("serialNumber":")([^"]*)(",)'
    regexName='("hostname":")([^"]*)(",)'
    regexServAcct='("hasServiceAccount":)([^"]*)(,)'
    if [[ $sysSearch =~ $regexSerial ]]; then
        sysSearchRawSerial="${BASH_REMATCH[2]}"
    fi
    if [[ $sysSearch =~ $regexName ]]; then
        sysSearchRawName="${BASH_REMATCH[2]}"
    fi
    if [[ $sysSearch =~ $regexServAcct ]]; then
        sysSearchRawServAcct="${BASH_REMATCH[2]}"
    fi

    # Print out system info to debug log
    echo "$(date "+%Y-%m-%d %H:%M:%S"): System Enrollment Complete:" >> "$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): =============== ENROLLMENT DETAILS ==============" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Serial Number: $sysSearchRawSerial" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Hostname: $sysSearchRawName" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): JumpCloud Service Account Status: $sysSearchRawServAcct" >>"$DEP_N_DEBUG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): =================================================" >>"$DEP_N_DEBUG"

    # User Agent Report
    SETTINGS=$(curl \
        -s \
        -X GET https://console.jumpcloud.com/api/settings \
        -A "${USER_AGENT}" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${JCAPI_KEY}"
    )
    REGEX='\"ORG_ID\":\"([a-zA-Z0-9_]+)\"'
    if [[ ${SETTINGS} =~ $REGEX ]]; then
        ORG_ID="${BASH_REMATCH[1]}"
    fi
    #echo "${ORG_ID}"
    curl \
        -s \
        -X PUT https://console.jumpcloud.com/api/organizations/${ORG_ID} \
        -A "${USER_AGENT}" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${JCAPI_KEY}"

    FINISH_TITLE="All Done"

    echo "Command: MainTitle: $FINISH_TITLE" >>"$DEP_N_LOG"
    echo "Status: Enrollment Complete" >>"$DEP_N_LOG"
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Status: Enrollment Complete" >>"$DEP_N_DEBUG"

    ACTIVE_USER=$( ls -l /dev/console | awk '{print $3}' )
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for ${ACTIVE_USER} user to logout... " >>"$DEP_N_DEBUG"
    FINDER_PROCESS=$(pgrep -l "Finder")
    while [ "$FINDER_PROCESS" != "" ]; do
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Finder process found. Waiting until session end" >>"$DEP_N_DEBUG"
        sleep 1
        FINDER_PROCESS=$(pgrep -l "Finder")
    done

    # add gate file here, user interaction complete
    kill $caffeinatePID
    touch $DEP_N_GATE_DONE
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # END Post login active session workflow                                       ~
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
fi

# final steps to check
# this will initially fail at the end of the script, if we remove the welcome user
# the LaunchDaemon will be running as user null. However on next run, the script
# will run as root and should have access to remove the launch daemon and remove
# this script. The LaunchDaemon process with status 127 will remain on the system
# until reboot, it will be not be called again after reboot.
if [[ -f $DEP_N_GATE_DONE ]]; then
    # Delete enrollment users
    if [[ $DELETE_ENROLLMENT_USERS == true ]]; then
        # wait until welcome user is logged out
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Testing if ${ENROLLMENT_USER} user is logged out" >>"$DEP_N_DEBUG"
        ACTIVE_USER=$( ls -l /dev/console | awk '{print $3}' )
        if [[ "${ACTIVE_USER}" == "${ENROLLMENT_USER}" ]]; then
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Logged in user is: ${ACTIVE_USER}, waiting until logout to continue" >>"$DEP_N_DEBUG"
            FINDER_PROCESS=$(pgrep -l "Finder")
            echo "$(date "+%Y-%m-%d %H:%M:%S"): $FINDER_PROCESS" >>"$DEP_N_DEBUG"
            while [ "$FINDER_PROCESS" != "" ]; do
                echo "$(date "+%Y-%m-%d %H:%M:%S"): Finder process found. Waiting until session end" >>"$DEP_N_DEBUG"
                sleep 1
                FINDER_PROCESS=$(pgrep -l "Finder")
            done
        fi
        # given the case that the enrollment user was logged in previously, recheck the active user
        ACTIVE_USER=$( ls -l /dev/console | awk '{print $3}' )
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Logged in user is: ${ACTIVE_USER}" >>"$DEP_N_DEBUG"
        if [[ "${ACTIVE_USER}" == "" || "${ACTIVE_USER}" != "${ENROLLMENT_USER}" ]]; then
            # delete the enrollment and decrypt user
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Deleting the first enrollment user: $ENROLLMENT_USER" >>"$DEP_N_DEBUG"
            sysadminctl -deleteUser $ENROLLMENT_USER >>"$DEP_N_DEBUG" 2>&1
            echo "$(date "+%Y-%m-%d %H:%M:%S"): Deleting the decrypt user: $DECRYPT_USER" >>"$DEP_N_DEBUG"
            sysadminctl -deleteUser $DECRYPT_USER >>"$DEP_N_DEBUG" 2>&1
        fi

    fi
    # Clean up steps
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Status: Removing LaunchDaemon" >>"$DEP_N_DEBUG"
    # Remove the LaunchDaemon file if it exists
    if [[ -f "/Library/LaunchDaemons/${DAEMON}" ]]; then
        rm -rf "/Library/LaunchDaemons/${DAEMON}"
        echo "$(date "+%Y-%m-%d %H:%M:%S"): Status: LaunchDaemon Removed" >>"$DEP_N_DEBUG"
    else
        echo "$(date "+%Y-%m-%dT%H:%M:%S"): Warning: Could not find/ remove LaunchDaemon" >>"$DEP_N_DEBUG"
    fi
    # Clean up receipts
    rm /var/tmp/com.jumpcloud*
    # Make script delete itself
    rm -- "$0"
fi
