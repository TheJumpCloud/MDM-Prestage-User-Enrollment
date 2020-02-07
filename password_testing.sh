#!/bin/bash
pass_path=update_required
ACTIVE_USER=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
uid=$(id -u "$ACTIVE_USER")
minlength=8
case $pass_path in
    update_required)
        echo "doing password stuff"
        # DEPNotify reset

        Sleep 2

        VALID_PASSWORD='False'
        passCheck=0

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
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password meets length requirements"
            else
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password does not meet length requirements"
                LENGTH='\n* LENGTH'
                VALID_PASSWORD='False'
            fi

            # Upper case check
            upperCheck='[[:upper:]]+'
            if [[ $password =~ $upperCheck ]]; then
                UPPER=''
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password contains a upper case letter"
            else
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password does not contain a upper case letter"
                UPPER='\n* UPPER CASE'
                VALID_PASSWORD='False'

            fi

            # Lower chase check
            lowerCheck='[[:lower:]]+'
            if [[ $password =~ $lowerCheck ]]; then
                LOWER=''
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password contains a lower case letter"
            else
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password does not contain a lower case letter"
                LOWER='\n* LOWER CASE'
                VALID_PASSWORD='False'

            fi

            # Special character check
            specialCharCheck='[!@#$%^&*(),.?":{}|<>]'
            if [[ $password =~ $specialCharCheck ]]; then
                SPECIAL=''
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password contains a special character"
            else
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password does not contains a special character"
                SPECIAL='\n* SPECIAL CHARACTER'
                VALID_PASSWORD='False'

            fi

            # Number check
            numberCheck='[0-9]'
            if [[ $password =~ $numberCheck ]]; then
                NUMBER=''
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password contains a number"
            else
                echo "$(date "+%Y-%m-%dT%H:%M:%S") Password does not contain a number"
                NUMBER='\n* NUMBER'
                VALID_PASSWORD='False'
            fi
            
            echo $passCheck
            if [[ $passCheck == 0 ]]; then
                COMPLEXITY='\n\nCOMPLEXITY NOT SATISFIED:\n --------------------------------------------------------------'$LENGTH''$UPPER''$LOWER''$SPECIAL''$NUMBER' \n\n TRY AGAIN'
            else
                COMPLEXITY='\n\nCOMPLEXITY NOT SATISFIED:\n --------------------------------------------------------------'$LENGTH''$UPPER''$LOWER''$SPECIAL''$NUMBER''$passMatch' \n\n TRY AGAIN'
            fi

            if [[ $VALID_PASSWORD == 'True' ]]; then
                passCheck=$((passCheck + 1))
                password2=$(launchctl asuser "$uid" /usr/bin/osascript -e '
                Tell application "System Events" 
                    with timeout of 1800 seconds 
                        display dialog "CONFIRM PASSWORD:\n--------------------------------------------------------------\n" with title "CONFIRM A SECURE PASSWORD"  buttons {"Continue"} default button "Continue" with hidden answer default answer ""' -e 'text returned of result 
                    end timeout
                end tell' 2>/dev/null)

                # match Check
                passMatch="Passwords do not match"
                if [[ $password == "$password2" ]]; then
                    echo "$(date "+%Y-%m-%dT%H:%M:%S") Passwords Match"
                    passMatch="Passwords match"
                else
                    echo "$(date "+%Y-%m-%dT%H:%M:%S") Password does not contain a match"
                    VALID_PASSWORD='False'
                fi 

                COMPLEXITY='\n\nCOMPLEXITY NOT SATISFIED:\n --------------------------------------------------------------'$LENGTH''$UPPER''$LOWER''$SPECIAL''$NUMBER''$passMatch' \n\n TRY AGAIN'

                # COMPLEXITY='\n\nCOMPLEXITY NOT SATISFIED:\n --------------------------------------------------------------'$passMatch' \n\n TRY AGAIN'
            fi

        done

        ;;
    not_required)
        echo "not required"
        ;;
    esac