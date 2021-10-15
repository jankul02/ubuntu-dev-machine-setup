#!/bin/bash

set -e 

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    # shellcheck source=./setupLibrary.sh
    source "${current_dir}/setupLibrary.sh"
}

function cleanup() {
    # cleanup if needed
    echo cleanup
    exit
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="output.log"


function main() {
    # Run setup functions
    trap cleanup EXIT SIGHUP SIGINT SIGTERM

    SSHPORT=4242
    remote=${remote:-'hit.nata4d.de'}
    username=$(id -u -n)




    while [ $# -gt 0 ]; do

    if [[ $1 == *"--"* ]]; then
            param="${1/--/}"
            declare $param="$2"
            echo $1 $2 
    fi

    shift
    done

    echo "remote is:" $remote 
    echo "username is:" $username 
    echo "openvpnkeysfolder:" $openvpnkeysfolder
    echo "SSHPORT:" $SSHPORT

    while true; do
        read -p 'Do you wish to continue ? [YyNn]' yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    PASSWORDS_MATCH=0
    while [ "${PASSWORDS_MATCH}" -eq "0" ]; do
        read -s -rp "Enter password for the new remote $username user:" password
        printf "\n"
        read -s -rp "Retype password:" password_confirmation
        printf "\n"

        if [[ "${password}" != "${password_confirmation}" ]]; then
            echo "Passwords do not match! Please try again."
        else
            PASSWORDS_MATCH=1
        fi
    done 

    unset sshkeyfiles idx
    while IFS= read -r -d $'\0' f; do
        sshkeyfiles[idx++]="$f"
    done < <(find ~/.ssh/ -maxdepth 1 -type f ! -name "*.*" -print0 )


    select keyfilename in "${sshkeyfiles[@]}" "Stop"; do
        case $keyfilename.pub in
            Stop.pub)
            echo "You chose to stop"
            exit
            ;;
            *.pub)
            echo "public key $keyfilename selected"
            echo '******************************'
            cat $keyfilename.pub
            echo '******************************'
            break
            # processing
            ;;
            *)
            echo "This is not a number"
            ;;
        esac
    done
publickey=$(cat $keyfilename.pub)



printf "\n"


ssh  -i $keyfilename root@${remote} <<-ENDROOT

        # setup the regular user and its ssh pub key
        adduser --disabled-password --gecos '' "$username"
        echo "${username}:${password}" | chpasswd
        usermod -aG sudo "${username}"
        remotehome=\$(echo ~${username})
        remoteusergroup=\$(id -gn ${username})
        mkdir -p \${remotehome}/.ssh
        chmod 700 \${remotehome}/.ssh
        touch \${remotehome}/.ssh/authorized_keys
        chown -Rv ${username}:\${remoteusergroup}  \${remotehome}/.ssh
        ls -Ral \${remotehome}
tee -a \${remotehome}/.ssh/authorized_keys <<PUBKEYFILETAG 
${publickey}
PUBKEYFILETAG

        chmod 600 \${remotehome}/.ssh/authorized_keys

        echo user ${username} and his ssh keys has been set
        
        
        # setup ufw 
        ufw allow 443
        ufw allow 8443
        ufw allow $SSHPORT
        ufw allow 10194
        ufw allow 22
        echo "y" | ufw enable


    # setup ssh, disable root 
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config && service ssh restart
    sed -re 's/^(\#?)(PasswordAuthentication)([[:space:]]+)yes/\2\3no/' -i."\$(echo 'old')" /etc/ssh/sshd_config
    sed -re 's/^(\#?)(PermitRootLogin)([[:space:]]+)(.*)/PermitRootLogin no/' -i /etc/ssh/sshd_config
    echo Port $SSHPORT >>/etc/ssh/sshd_config
    service ssh restart


ENDROOT

echo "hello from ${username} on local"

ssh  ${username}@${remote} -p $SSHPORT <<-USERSSH
    echo "hello from ${username} on ${remote}"
    remotehome=\$(echo ~${username}) 
    cat \${remotehome}/.ssh/authorized_keys
    ls -Ral \${remotehome}
    mkdir -p \${remotehome}/.ubuntusetup
    touch \${remotehome}/.ubuntusetup/0100secureaccess
    ssh-keygen -t ed25519
 
USERSSH


ssh  ${username}@${remote} -p $SSHPORT <<-SUDOSSH
    echo  again as ${username}@${remote}
    
    printf ${password} | sudo -S ufw deny 22
    printf ${password} | sudo -S ufw status

    printf ${password} | sudo -S apt-get update 
    printf ${password} | sudo -S apt-get -y install git




SUDOSSH

 
}




function logTimestamp() {
    local filename=${1}
    {
        echo "===================" 
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}


# Keep prompting for the password and password confirmation
function promptForPassword() {
   PASSWORDS_MATCH=0
   while [ "${PASSWORDS_MATCH}" -eq "0" ]; do
       read -s -rp "Enter new UNIX password:" password
       printf "\n"
       read -s -rp "Retype new UNIX password:" password_confirmation
       printf "\n"

       if [[ "${password}" != "${password_confirmation}" ]]; then
           echo "Passwords do not match! Please try again."
       else
           PASSWORDS_MATCH=1
       fi
   done 
}



main