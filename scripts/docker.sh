#!/bin/bash

runCommandForDockerInstallUser()
{
    local silent_flag=""
    if [ "$1" == "--silent" ]; then
        silent_flag="$1"
        shift
    fi
    local remote_command="$1"
    
    # Run the SSH command using the existing SSH variables
    local output
    if [ -z "$silent_flag" ]; then
        sshpass -p "$CFG_DOCKER_INSTALL_PASS" ssh -o StrictHostKeyChecking=no "$CFG_DOCKER_INSTALL_USER@localhost" "$remote_command"
        local exit_code=$?
    else
        sshpass -p "$CFG_DOCKER_INSTALL_PASS" ssh -o StrictHostKeyChecking=no "$CFG_DOCKER_INSTALL_USER@localhost" "$remote_command" > /dev/null 2>&1
        local exit_code=$?
    fi

    if [ $exit_code -eq 0 ]; then
        return 0  # Success, command completed without errors
    else
        return 1  # Error, command encountered issues
    fi
}

setupConfigToContainer()
{
    local silent_flag="$1"
    local app_name="$2"
    local flags="$3"

    local target_path="$containers_dir$app_name"
    local source_file="$install_containers_dir$app_name/$app_name.config"
    local config_file="$app_name.config"

    if [ "$app_name" == "" ]; then
        isError "The app_name is empty."
        return 1
    fi

    if [ -d "$target_path" ]; then
        if [ "$silent_flag" == "loud" ]; then
            isNotice "The directory '$target_path' already exists."
        fi
    else
        if [ "$silent_flag" == "loud" ]; then
            mkdirFolders "$silent_flag" "$CFG_DOCKER_INSTALL_USER" "$target_path"
        elif [ "$silent_flag" == "silent" ]; then
            mkdirFolders "$silent_flag" "$CFG_DOCKER_INSTALL_USER" "$target_path"
        fi
    fi

    if [ ! -f "$source_file" ]; then
        isError "The config file '$source_file' does not exist."
        return 1
    fi

    if [ ! -f "$target_path/$config_file" ]; then
        if [ "$silent_flag" == "loud" ]; then
            isNotice "Copying config file to '$target_path/$config_file'..."
            copyFile "$silent_flag" "$source_file" "$target_path/$config_file" $CFG_DOCKER_INSTALL_USER | sudo -u $sudo_user_name tee -a "$logs_dir/$docker_log_file" 2>&1
        elif [ "$silent_flag" == "silent" ]; then
            copyFile "$silent_flag" "$source_file" "$target_path/$config_file" $CFG_DOCKER_INSTALL_USER | sudo -u $sudo_user_name tee -a "$logs_dir/$docker_log_file" 2>&1
        fi
    fi

    if [[ "$flags" == "install" ]]; then
        if [ -f "$target_path/$config_file" ]; then
            # Same content check
            if cmp -s "$source_file" "$target_path/$config_file"; then
                echo ""
                isNotice "Config file for $app_name contains no edits."
                echo ""
                while true; do
                    isQuestion "Would you like to make edits to the config file? (y/n): "
                    read -rp "" editconfigaccept
                    echo ""
                    case $editconfigaccept in
                        [yY])
                            # Calculate the checksum of the original file
                            local original_checksum=$(md5sum "$target_path/$config_file")

                            # Open the file with nano for editing
                            sudo nano "$target_path/$config_file"

                            # Calculate the checksum of the edited file
                            local edited_checksum=$(md5sum "$target_path/$config_file")

                            # Compare the checksums to check if changes were made
                            if [[ "$original_checksum" != "$edited_checksum" ]]; then
                                source $target_path/$config_file
                                setupInstallVariables $app_name;
                                isSuccessful "Changes have been made to the $config_file."
                            fi
                            break
                            ;;
                        [nN])
                            break  # Exit the loop without updating
                            ;;
                        *)
                            isNotice "Please provide a valid input (y or n)."
                            ;;
                    esac
                done
            else
                echo ""
                isNotice "Config file for $app_name has been updated..."
                echo ""
                while true; do
                    isQuestion "Would you like to reset the config file? (y/n): "
                    read -rp "" resetconfigaccept
                    echo ""
                    case $resetconfigaccept in
                        [yY])
                            isNotice "Resetting $app_name config file."
                            copyFile "loud" "$source_file" "$target_path/$config_file" $CFG_DOCKER_INSTALL_USER | sudo -u $sudo_user_name tee -a "$logs_dir/$docker_log_file" 2>&1
                            source $target_path/$config_file
                            setupConfigToContainer "loud" $app_name;
                            break
                            ;;
                        [nN])
                            break  # Exit the loop without updating
                            ;;
                        *)
                            isNotice "Please provide a valid input (y or n)."
                            ;;
                    esac
                done
            fi
        else
            isNotice "Config file for $app_name does not exist. Creating it..."
            copyFile "loud" "$source_file" "$target_path/$config_file" $CFG_DOCKER_INSTALL_USER | sudo -u $sudo_user_name tee -a "$logs_dir/$docker_log_file" 2>&1
            echo ""
            isNotice "Config file for $app_name contains no edits."
            echo ""
            while true; do
                isQuestion "Would you like to make edits to the config file? (y/n): "
                read -rp "" editconfigaccept
                echo ""
                case $editconfigaccept in
                    [yY])
                        # Calculate the checksum of the original file
                        local original_checksum=$(md5sum "$target_path/$config_file")

                        # Open the file with nano for editing
                        sudo nano "$target_path/$config_file"

                        # Calculate the checksum of the edited file
                        local edited_checksum=$(md5sum "$target_path/$config_file")

                        # Compare the checksums to check if changes were made
                        if [[ "$original_checksum" != "$edited_checksum" ]]; then
                            source $target_path/$config_file
                            setupInstallVariables $app_name;
                            isSuccessful "Changes have been made to the $config_file."
                        fi
                        break
                        ;;
                    [nN])
                        break  # Exit the loop without updating
                        ;;
                    *)
                        isNotice "Please provide a valid input (y or n)."
                        ;;
                esac
            done
        fi
    fi

    scanFileForRandomPassword "$target_path/$config_file";
    loadFiles "app_configs";
}

checkAllowedInstall() 
{
    local app_name="$1"

    #if [ "$status" == "installed" ]; then
    #elif [ "$status" == "running" ]; then
    #elif [ "$status" == "not_installed" ]; then
    #elif [ "$status" == "invalid_flag" ]; then

    case "$app_name" in
        "mailcow")
            status=$(checkAppInstalled "webmin" "linux" "check_active")
            if [ "$status" == "installed" ]; then
                isError "Virtualmin is installed, this will conflict with $app_name."
                isError "Installation is now aborting..."
                uninstallApp "$app_name"
                return 1
            elif [ "$status" == "running" ]; then
                isError "Virtualmin is installed, this will conflict with $app_name."
                isError "Installation is now aborting..."
                uninstallApp "$app_name"
                return 1
            fi
            ;;
        "virtualmin")
            status=$(checkAppInstalled "webmin" "linux" "check_active")
            if [ "$status" == "not_installed" ]; then
              isError "Virtualmin is not installed or running, it is required."
              uninstallApp "$app_name"
              return 1
            elif [ "$status" == "invalid_flag" ]; then
              isError "Invalid flag provided..cancelling install..."
              uninstallApp "$app_name"
              return 1
            fi
            status=$(checkAppInstalled "traefik" "docker")
            if [ "$status" == "not_installed" ]; then
                while true; do
                    echo ""
                    isNotice "Traefik is not installed, it is required."
                    echo ""
                    isQuestion "Would you like to install Traefik? (y/n): "
                    read -p "" virtualmin_traefik_choice
                    if [[ -n "$virtualmin_traefik_choice" ]]; then
                        break
                    fi
                    isNotice "Please provide a valid input."
                done
                if [[ "$virtualmin_traefik_choice" == [yY] ]]; then
                    installApp traefik;
                fi
                if [[ "$virtualmin_traefik_choice" == [nN] ]]; then
                    isError "Installation is now aborting..."
                    uninstallApp "$app_name"
                    return 1
                fi
            elif [ "$status" == "invalid_flag" ]; then
              isError "Invalid flag provided..cancelling install..."
              uninstallApp "$app_name"
              return 1
            fi
            ;;
    esac

    isSuccessful "Application is allowed to be installed."
}

checkAppInstalled() 
{
    local app_name="$1"
    local flag="$2"
    local check_active="$3"
    local package_status=""

    if [ "$flag" = "linux" ]; then
        if dpkg -l | grep -q "$app_name"; then
            package_status="installed"
            if [ "$check_active" = "check_active" ]; then
                if systemctl is-active --quiet "$app_name"; then
                    package_status="running"
                fi
            fi
        else
            package_status="not_installed"
        fi
    elif [ "$flag" = "docker" ]; then
        results=$(sudo sqlite3 "$docker_dir/$db_file" "SELECT name FROM apps WHERE status = 1 AND name = '$app_name';")
        if [ -n "$results" ]; then
            package_status="installed"
        else
            package_status="not_installed"
        fi
    else
        package_status="invalid_flag"
    fi

    echo "$package_status"
}

installApp() {
    local app_name="$1"
    local app_name_ucfirst="$(tr '[:lower:]' '[:upper:]' <<< ${app_name:0:1})${app_name:1}"
    local installFuncName="install${app_name_ucfirst}"

    # Create an associative array with the name of $app_name and set its value to "i"
    declare -A app_data
    app_data["$app_name"]="i"

    # Call the installation function
    ${installFuncName}
}

setupComposeFile()
{
    local app_name="$1"
    local custom_file="$2"
    local custom_path="$3"

    # Source Filenames
    if [[ $custom_file == "" ]]; then
        local source_compose_file="docker-compose.yml";
    elif [[ $custom_file != "" ]]; then
        local source_compose_file="$custom_file";
    fi

    if [[ $custom_path == "" ]]; then
        local source_path="$install_containers_dir$app_name"
    elif [[ $custom_path != "" ]]; then
        local source_path="$install_containers_dir$app_name/$custom_path/"
    fi

    local source_file="$source_path/$source_compose_file"

    # Target Filenames
    if [[ $compose_setup == "default" ]]; then
        local target_compose_file="docker-compose.yml";
    elif [[ $compose_setup == "app" ]]; then
        local target_compose_file="docker-compose.$app_name.yml";
    fi

    local target_path="$containers_dir$app_name"
    local target_file="$target_path/$target_compose_file"


    if [ "$app_name" == "" ]; then
        isError "The app_name is empty."
        return 1
    fi
    
    if [ ! -f "$source_file" ]; then
        isError "The source file '$source_file' does not exist."
        return 1
    fi
    
    copyFile "loud" "$source_file" "$target_file" $CFG_DOCKER_INSTALL_USER | sudo -u $sudo_user_name tee -a "$logs_dir/$docker_log_file" 2>&1
    
    if [ $? -ne 0 ]; then
        isError "Failed to copy the source file to '$target_path'. Check '$docker_log_file' for more details."
        return 1
    fi
}

dockerDownUp()
{
    local app_name="$1"

    dockerDown $app_name;
    dockerUp $app_name;
}

dockerDown()
{
    local app_name="$1"
    local custom_compose="$2"
    # Compose file public variable for restarting etc
    if [[ $compose_setup == "default" ]]; then
        local setup_compose="-f docker-compose.yml"
    elif [[ $compose_setup == "app" ]]; then
        local setup_compose="-f docker-compose.yml -f docker-compose.$app_name.yml"
    fi
    if [[ $custom_compose != "" ]]; then
        local setup_compose="-f docker-compose.yml -f $custom_compose"
    fi

    if [[ "$OS" == [1234567] ]]; then
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose $setup_compose down")
            checkSuccess "Shutting down container for $app_name"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            local result=$(sudo -u $sudo_user_name docker-compose $setup_compose down)
            checkSuccess "Shutting down container for $app_name"
        fi
    else
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose $setup_compose down")
            checkSuccess "Shutting down container for $app_name"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            local result=$(sudo -u $sudo_user_name docker-compose $setup_compose down)
            checkSuccess "Shutting down container for $app_name"
        fi
    fi
}

dockerUp()
{
    local app_name="$1"
    local custom_compose="$2"
    # Compose file public variable for restarting etc
    if [[ $compose_setup == "default" ]]; then
        local setup_compose="-f docker-compose.yml"
    elif [[ $compose_setup == "app" ]]; then
        local setup_compose="-f docker-compose.yml -f docker-compose.$app_name.yml"
    fi
    if [[ $custom_compose != "" ]]; then
        local setup_compose="-f docker-compose.yml -f $custom_compose"
    fi

    if [[ "$OS" == [1234567] ]]; then
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose $setup_compose up -d")
            checkSuccess "Started container for $app_name"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(sudo -u $sudo_user_name docker-compose up -d)
            checkSuccess "Started container for $app_name"
        fi
    else
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose $setup_compose up -d")
            checkSuccess "Started container for $app_name"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(sudo -u $sudo_user_name docker-compose $setup_compose up -d)
            checkSuccess "Started container for $app_name"
        fi
    fi
}

setupFileWithConfigData()
{
    local app_name="$1"
    local custom_file="$2"
    local custom_path="$3"

    if [[ $compose_setup == "default" ]]; then
        local file_name="docker-compose.yml";
    elif [[ $compose_setup == "app" ]]; then
        local file_name="docker-compose.$app_name.yml";
    fi

    if [[ $custom_file != "" ]]; then
        local file_name="$custom_file"
    fi

    if [[ $custom_path == "" ]]; then
        local file_path="$containers_dir$app_name"
    elif [[ $custom_path != "" ]]; then
        local file_path="$containers_dir$app_name/$custom_path/"
    fi

    local full_file_path="$file_path/$file_name"

    local result=$(sudo sed -i \
        -e "s|DOMAINNAMEHERE|$domain_full|g" \
        -e "s|DOMAINSUBNAMEHERE|$host_setup|g" \
        -e "s|DOMAINPREFIXHERE|$domain_prefix|g" \
        -e "s|PUBLICIPHERE|$public_ip|g" \
        -e "s|IPADDRESSHERE|$ip_setup|g" \
        -e "s|PORT1|$usedport1|g" \
        -e "s|PORT2|$usedport2|g" \
        -e "s|PORT3|$usedport3|g" \
        -e "s|PORT4|$usedport4|g" \
        -e "s|TIMEZONEHERE|$CFG_TIMEZONE|g" \
        -e "s|EMAILHERE|$CFG_EMAIL|g" \
        -e "s|DOCKERNETWORK|$CFG_NETWORK_NAME|g" \
    "$full_file_path")
    checkSuccess "Updating $file_name for $app_name"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        local result=$(sudo sed -i \
            -e "s|- /var/run/docker.sock|- /run/user/${docker_install_user_id}/docker.sock|g" \
            -e "s|DOCKERINSTALLUSERID|$docker_install_user_id|g" \
        "$full_file_path")
        checkSuccess "Updating docker socket for $app_name"
    fi

    if [[ $file_name == *".yml"* ]]; then
        if [[ "$public" == "true" ]]; then    
            setupTraefikLabels $app_name $full_file_path;
        fi
        
        if [[ "$public" == "false" ]]; then
            if ! grep -q "#labels:" "$full_file_path"; then
                local result=$(sudo sed -i 's/labels:/#labels:/g' "$full_file_path")
                checkSuccess "Disable Traefik options for private setup"
            fi
            local result=$(sudo sed -i \
                -e "s|0.0.0.0:|127.0.0.1:|g" \
            "$full_file_path")
            checkSuccess "Updating $file_name for $app_name"
        fi
    fi

    scanFileForRandomPassword $full_file_path;
    
    isSuccessful "Updated the $app_name docker-compose.yml"
}

setupTraefikLabelsSetupMiddlewares() 
{
    local app_name="$1"
    local temp_file="$2"

    local middlewares_line=$(grep -m 1 ".middlewares:" "$temp_file")

    local middleware_entries=()

    if [[ "$authelia_setup" == "true" && "$whitelist" == "true" ]]; then
        middleware_entries+=("default@file")
        middleware_entries+=("my-whitelist-in-docker")
        if [[ $(checkAppInstalled "authelia" "docker") == "installed" ]]; then
            middleware_entries+=("authelia@docker")
        fi
    elif [[ "$authelia_setup" == "true" && "$whitelist" == "false" ]]; then
        if [[ $(checkAppInstalled "authelia" "docker") == "installed" ]]; then
            middleware_entries+=("authelia@docker")
        fi
    elif [[ "$authelia_setup" == "false" && "$whitelist" == "true" ]]; then
        middleware_entries+=("my-whitelist-in-docker")
    fi

    local middlewares_string="$(IFS=,; echo "${middleware_entries[*]}")"

    sed -i "s/.middlewares:.*/.middlewares: $middlewares_string/" "$temp_file"
}

setupTraefikLabels() 
{
    local app_name="$1"
    local compose_file="$2"
    local temp_file="/tmp/temp_compose_file.yml"

    > "$temp_file"
    sudo cp "$compose_file" "$temp_file"

    setupTraefikLabelsSetupMiddlewares "$app_name" "$temp_file"

    # No Whitelist Data
    if [[ "$CFG_IPS_WHITELIST" == "" ]]; then
        sudo sed -i "s/#labels:/labels:/g" "$temp_file"
        sudo sed -i -e '/#traefik/ s/#//g' -e '/#whitelist/ s/#//g' "$temp_file"
    else
        if [[ "$whitelist" == "true" && "$authelia_setup" == "false" ]]; then
            sudo sed -i "s/#labels:/labels:/g" "$temp_file"
            sudo sed -i '/#traefik/ s/#//g' "$temp_file"
        fi
        if [[ "$whitelist" == "false" && "$authelia_setup" == "false" ]]; then
            sudo sed -i "s/#labels:/labels:/g" "$temp_file"
            sudo sed -i -e '/#traefik/ s/#//g' -e '/#whitelist/ s/#//g' "$temp_file"
        fi
        if [[ "$whitelist" == "false" && "$authelia_setup" == "true" ]]; then
            sudo sed -i "s/#labels:/labels:/g" "$temp_file"
            sudo sed -i -e '/#traefik/ s/#//g' -e '/#whitelist/ s/#//g' "$temp_file"
        fi
        if [[ "$whitelist" == "true" && "$authelia_setup" == "true" ]]; then
            sudo sed -i "s/#labels:/labels:/g" "$temp_file"
            sudo sed -i '/#traefik/ s/#//g' "$temp_file"
        fi
    fi

    copyFile "silent" "$temp_file" "$compose_file" $CFG_DOCKER_INSTALL_USER overwrite
    sudo rm "$temp_file"

    local indentation="      "
    if sudo grep -q '\.middlewares:' "$compose_file"; then
        sudo awk -v indentation="$indentation" '/\.middlewares:/ { if ($0 !~ "^" indentation) { $0 = indentation $0 } } 1' "$compose_file" | sudo tee "$compose_file.tmp" > /dev/null
        sudo mv "$compose_file.tmp" "$compose_file"
    fi
}

scanFileForRandomPassword()
{
    local file="$1"
    
    if [ -f "$file" ]; then
        # Check if the file contains the placeholder string "RANDOMIZEDPASSWORD"
        while sudo grep  -q "RANDOMIZEDPASSWORD" "$file"; do
            # Generate a unique random password
            local random_password=$(openssl rand -base64 12 | tr -d '+/=')
            
            # Capture the content before "RANDOMIZEDPASSWORD"
            local config_content=$(sudo sed -n "s/.*RANDOMIZEDPASSWORD \(.*\)/\1/p" "$file")

            # Update the first occurrence of "RANDOMIZEDPASSWORD" with the new password
            sudo sed -i "0,/\(RANDOMIZEDPASSWORD\)/s//${random_password}/" "$file"
            
            # Display the update message with the captured content and file name
            isSuccessful "Updated $config_content in $(basename "$file") with a new password."
        done
    fi
}

setupEnvFile()
{
    local result=$(copyFile "loud" $containers_dir$app_name/env.example $containers_dir$app_name/.env $CFG_DOCKER_INSTALL_USER)
    checkSuccess "Setting up .env file to path"
}

dockerStopAllApps()
{
    isNotice "Please wait for docker containers to stop"
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local result=$(runCommandForDockerInstallUser 'docker stop $(docker ps -a -q)')
        checkSuccess "Stopping all docker containers"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        local result=$(sudo -u $sudo_user_name docker stop $(docker ps -a -q))
        checkSuccess "Stopping all docker containers"
    fi
}

dockerStartAllApps()
{
    isNotice "Please wait for docker containers to start"
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local result=$(runCommandForDockerInstallUser 'docker restart $(docker ps -a -q)')
        checkSuccess "Starting up all docker containers"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        local result=$(sudo -u $sudo_user_name docker restart $(docker ps -a -q))
        checkSuccess "Starting up all docker containers"
    fi
}

dockerAppDown() 
{
    local app_name="$1"

    isNotice "Please wait for $app_name container to stop"

    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        if [ -d "$containers_dir$app_name" ]; then
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose down")
            checkSuccess "Shutting down $app_name container"
        else
            isNotice "Directory $containers_dir$app_name does not exist. Container not found."
        fi
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        if [ -d "$containers_dir$app_name" ]; then
            local result=$(cd "$containers_dir$app_name" && docker-compose down)
            checkSuccess "Shutting down $app_name container"
        else
            isNotice "Directory $containers_dir$app_name does not exist. Container not found."
        fi
    fi
}

dockerAppUp()
{
    local app_name="$1"

    isNotice "Please wait for $app_name container to start"

    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose up -d")
        checkSuccess "Starting up $app_name container"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        local result=$(cd $containers_dir$app_name && docker-compose up -d)
        checkSuccess "Starting up $app_name container"
    fi
}