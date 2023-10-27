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
    local silent_flag=""
    if [ "$1" == "--silent" ]; then
        silent_flag="$1"
        shift
    fi

    local app_name="$1"
    local flags="$2"
    local target_path="$containers_dir$app_name"
    local source_file="$install_containers_dir$app_name/$app_name.config"
    local config_file="$app_name.config"

    if [ "$app_name" == "" ]; then
        isError "The app_name is empty."
        return 1
    fi

    if [ -d "$target_path" ]; then
        if [ -z "$silent_flag" ]; then
            isNotice "The directory '$target_path' already exists."
        fi
    else
        if [ -z "$silent_flag" ]; then
            mkdirFolders "$target_path"
        else
            mkdirFolders "$silent_flag" "$target_path"
        fi
    fi

    if [ ! -f "$source_file" ]; then
        isError "The config file '$source_file' does not exist."
        return 1
    fi

    if [ ! -f "$target_path/$config_file" ]; then
        if [ -z "$silent_flag" ]; then
            isNotice "Copying config file to '$target_path/$config_file'..."
            copyFile "$source_file" "$target_path/$config_file" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
        else
            copyFile "$silent_flag" "$source_file" "$target_path/$config_file" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
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
                            copyFile "$source_file" "$target_path/$config_file" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
                            source $target_path/$config_file
                            setupConfigToContainer $app_name;
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
            copyFile "$source_file" "$target_path/$config_file" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
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

    loadFiles "app_configs";
}

checkAllowedInstall()
{
    local app_name="$1"

    if [ "$app_name" == "mailcow" ]; then
        if checkAppInstalled "virtualmin" "linux"; then
            isError "Virtualmin is installed, this will conflict with $app_name."
            isError "Installation is now aborting..."
            uninstallApp "$app_name";
            return 1
        fi
    fi

    if [ "$app_name" == "virtualmin" ] && ! checkAppInstalled "virtualmin" "linux" "check_active"; then
        isError "Virtualmin is not installed or running, it is required."
        uninstallApp "$app_name"
        return 1
    else
        if ! checkAppInstalled "traefik" "docker"; then
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
        fi
    fi

    isSuccessful "Application is allowed to be installed."
}

checkAppInstalled() 
{
    local app_name="$1"
    local flag="$2"
    local check_active="$3"

    if [ "$flag" = "linux" ]; then
        # Check if the package is installed
        if dpkg -l | grep -q "^ii $app_name"; then
            # Package is installed, now check if it should also check if the service is running
            if [ "$check_active" = "check_active" ]; then
                if systemctl is-active --quiet "$app_name"; then
                    return 0  # Installed and running
                else
                    return 1  # Installed but not running
                fi
            else
                return 0  # Installed
            fi
        else
            return 2  # Not installed
        fi
    elif [ "$flag" = "docker" ]; then
        # Query the database to check if the app is installed in Docker
        results=$(sudo sqlite3 "$docker_dir/$db_file" "SELECT name FROM apps WHERE status = 1 AND name = '$app_name';")
        if [ -n "$results" ]; then
            return 0  # Installed in Docker
        else
            return 2  # Not installed in Docker
        fi
    else
        return 3  # Invalid flag
    fi
}

installApp()
{
    local $app_name="$1"
    local app_name_ucfirst="$(tr '[:lower:]' '[:upper:]' <<< ${app_name:0:1})${app_name:1}"
    local installFuncName="install${app_name_ucfirst}"

    # Create a variable with the name of $app_name and set its value to "i"
    declare "$app_name=i"

    # Call the installation function
    ${installFuncName}
}

setupComposeFileNoApp()
{
    local app_name="$1"
    local target_path="$containers_dir$app_name"
    local source_file="$install_containers_dir$app_name/docker-compose.yml"
    
    if [ "$app_name" == "" ]; then
        isError "The app_name is empty."
        return 1
    fi
    
    if [ ! -f "$source_file" ]; then
        isError "The source file '$source_file' does not exist."
        return 1
    fi
    
    copyFile "$source_file" "$target_path/docker-compose.yml" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
    
    if [ $? -ne 0 ]; then
        isError "Failed to copy the source file to '$target_path'. Check '$docker_log_file' for more details."
        return 1
    fi
}

setupComposeFileApp()
{
    local app_name="$1"
    local target_path="$containers_dir$app_name"
    local source_file="$install_containers_dir$app_name/docker-compose.yml"
    
    if [ "$app_name" == "" ]; then
        isError "The app_name is empty."
        return 1
    fi
    
    if [ ! -f "$source_file" ]; then
        isError ""Error: "The source file '$source_file' does not exist."
        return 1
    fi
    
    copyFile "$source_file" "$target_path/docker-compose.$app_name.yml" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
    
    if [ $? -ne 0 ]; then
        isError "Failed to copy the source file to '$target_path'. Check '$docker_log_file' for more details."
        return 1
    fi
}

dockerDownUpDefault()
{
    local app_name="$1"
    if [[ "$OS" == [1234567] ]]; then
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose down")
            checkSuccess "Shutting down container for $app_name"

            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose up -d")
            checkSuccess "Started container for $app_name"

        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then

            local result=$(sudo -u $easydockeruser docker-compose down)
            checkSuccess "Shutting down container for $app_name"

            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(sudo -u $easydockeruser docker-compose up -d)
            checkSuccess "Started container for $app_name"
        fi
    else
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then

            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose down")
            checkSuccess "Shutting down container for $app_name"
            
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose up -d")
            checkSuccess "Started container for $app_name"

        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then

            local result=$(sudo -u $easydockeruser docker-compose down)
            checkSuccess "Shutting down container for $app_name"
            
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(sudo -u $easydockeruser docker-compose up -d)
            checkSuccess "Started container for $app_name"

        fi
    fi
}

dockerDownUpAdditionalYML()
{
    local app_name="$1"
    if [[ "$OS" == [1234567] ]]; then
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down")
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"

            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml -q up -d")
            checkSuccess "Started container for $app_name (Using additional yml file)"
            elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            local result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down)
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"
            
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml -q up -d)
            checkSuccess "Started container for $app_name (Using additional yml file)"
        fi
    else
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down")
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"
            
            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(runCommandForDockerInstallUser "cd $containers_dir$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml -q -q up -d")
            checkSuccess "Started container for $app_name (Using additional yml file)"
            elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            local result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down)
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"

            isNotice "Starting container for $app_name, this may take a while..."
            local result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml up -d)
            checkSuccess "Started container for $app_name (Using additional yml file)"
        fi
    fi
}

editComposeFileDefault()
{
    local app_name="$1"
    local compose_file="$containers_dir$app_name/docker-compose.yml"
    
    local result=$(sudo sed -i \
        -e "s|DOMAINNAMEHERE|$domain_full|g" \
        -e "s|DOMAINSUBNAMEHERE|$host_setup|g" \
        -e "s|DOMAINPREFIXHERE|$domain_prefix|g" \
        -e "s|PUBLICIPHERE|$public_ip|g" \
        -e "s|IPADDRESSHERE|$ip_setup|g" \
        -e "s|PORT1|$usedport1|g" \
        -e "s|PORT2|$usedport2|g" \
        -e "s|TIMEZONEHERE|$CFG_TIMEZONE|g" \
    "$compose_file")
    checkSuccess "Updating Compose file for $app_name"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        local result=$(sudo sed -i \
            -e "s|- /var/run/docker.sock|- /run/user/${docker_install_user_id}/docker.sock|g" \
            -e "s|DOCKERINSTALLUSERID|$docker_install_user_id|g" \
        "$compose_file")
        checkSuccess "Updating Compose file docker socket for $app_name"
    fi

    if [[ "$public" == "true" ]]; then    
        setupTraefikLabels $app_name $compose_file;
    fi
    
    if [[ "$public" == "false" ]]; then
        if ! grep -q "#labels:" "$compose_file"; then
            local result=$(sudo sed -i 's/labels:/#labels:/g' "$compose_file")
            checkSuccess "Disable Traefik options for private setup"
        fi
    fi

    scanFileForRandomPassword $compose_file;
    
    isSuccessful "Updated the $app_name docker-compose.yml"
}

editComposeFileApp()
{
    local app_name="$1"
    local compose_file="$containers_dir$app_name/docker-compose.$app_name.yml"

    local result=$(sudo sed -i \
        -e "s|DOMAINNAMEHERE|$domain_full|g" \
        -e "s|DOMAINSUBNAMEHERE|$host_setup|g" \
        -e "s|DOMAINPREFIXHERE|$domain_prefix|g" \
        -e "s|PUBLICIPHERE|$public_ip|g" \
        -e "s|IPADDRESSHERE|$ip_setup|g" \
        -e "s|PORT1|$usedport1|g" \
        -e "s|PORT2|$usedport2|g" \
        -e "s|TIMEZONEHERE|$CFG_TIMEZONE|g" \
    "$compose_file")
    checkSuccess "Updating Compose file for $app_name (Using additional yml file)"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        local result=$(sudo sed -i \
            -e "s|- /var/run/docker.sock|- /run/user/${docker_install_user_id}/docker.sock|g" \
            -e "s|DOCKERINSTALLUSERID|$docker_install_user_id|g" \
        "$compose_file")
        checkSuccess "Updating Compose file docker socket for $app_name"
    fi

    if [[ "$public" == "true" ]]; then    
        setupTraefikLabels $app_name $compose_file;
    fi

    if [[ "$public" == "false" ]]; then
        if ! grep -q "#labels:" "$compose_file"; then
            local result=$(sudo sed -i 's/labels:/#labels:/g' "$compose_file")
            checkSuccess "Disable Traefik options for private setup"
        fi
    fi
    
    scanFileForRandomPassword $compose_file;

    isSuccessful "Updated the docker-compose.$app_name.yml"
}

editEnvFileDefault()
{
    local env_file="$containers_dir$app_name/.env"
    
    local result=$(sudo sed -i \
        -e "s|DOMAINNAMEHERE|$domain_full|g" \
        -e "s|DOMAINSUBNAMEHERE|$host_setup|g" \
        -e "s|DOMAINPREFIXHERE|$domain_prefix|g" \
        -e "s|PUBLICIPHERE|$public_ip|g" \
        -e "s|IPADDRESSHERE|$ip_setup|g" \
        -e "s|IPWHITELIST|$CFG_IPS_WHITELIST|g" \
        -e "s|PORT1|$usedport1|g" \
        -e "s|PORT2|$usedport2|g" \
        -e "s|TIMEZONEHERE|$CFG_TIMEZONE|g" \
    "$env_file")
    checkSuccess "Updating .env file for $app_name"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        local result=$(sudo sed -i \
            -e "s|DOCKERINSTALLUSERID|$docker_install_user_id|g" \
        "$env_file")
        checkSuccess "Updating Compose file docker socket for $app_name"
    fi

    scanFileForRandomPassword $env_file;

    isSuccessful "Updated the .env file"
}

editCustomFile()
{
    local customfile="$1"
    local custompath="$2"
    local custompathandfile="$custompath/$customfile"
    
    local result=$(sudo sed -i \
        -e "s|DOMAINNAMEHERE|$domain_full|g" \
        -e "s|DOMAINSUBNAMEHERE|$host_setup|g" \
        -e "s|DOMAINPREFIXHERE|$domain_prefix|g" \
        -e "s|PUBLICIPHERE|$public_ip|g" \
        -e "s|IPADDRESSHERE|$ip_setup|g" \
        -e "s|IPWHITELIST|$CFG_IPS_WHITELIST|g" \
        -e "s|PORT1|$usedport1|g" \
        -e "s|PORT2|$usedport2|g" \
        -e "s|TIMEZONEHERE|$CFG_TIMEZONE|g" \
    "$custompathandfile")
    checkSuccess "Updating $customfile file for $app_name"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        local result=$(sudo sed -i \
            -e "s|- /var/run/docker.sock|- /run/user/${docker_install_user_id}/docker.sock|g" \
            -e "s|DOCKERINSTALLUSERID|$docker_install_user_id|g" \
        "$custompathandfile")
        checkSuccess "Updating Compose file docker socket for $app_name"
    fi
    
    scanFileForRandomPassword $custompathandfile;

    isSuccessful "Updated the $customfile file"
}

setupTraefikLabelsSetupMiddlewares() 
{
    local app_name="$1"
    local temp_file="$2"

    local middlewares_line=$(grep -m 1 ".middlewares:" "$temp_file")

    local middleware_entries=()

    if [[ "$authelia_setup" == "true" && $(checkAppInstalled "authelia" "docker") -eq 0 && "$whitelist" == "true" ]]; then
        middleware_entries+=("my-whitelist-in-docker")
        middleware_entries+=("authelia@docker")
    elif [[ "$authelia_setup" == "true" && $(checkAppInstalled "authelia" "docker") -eq 0 && "$whitelist" == "false" ]]; then
        middleware_entries+=("authelia@docker")
    elif [[ "$authelia_setup" == "false" && "$whitelist" == "true" ]]; then
        middleware_entries+=("my-whitelist-in-docker")
    fi

    # Join the middleware entries with commas
    local middlewares_string="$(IFS=,; echo "${middleware_entries[*]}")"

    # Replace the .middlewares line with the updated line
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

    copyFile --silent "$temp_file" "$compose_file" overwrite
    sudo rm "$temp_file"

    local indentation="      "
    awk -v indentation="$indentation" '/\.middlewares:/ { if ($0 !~ "^" indentation) { $0 = indentation $0 } } 1' "$compose_file" > "$compose_file.tmp" && sudo mv "$compose_file.tmp" "$compose_file"
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
    local result=$(copyFile $containers_dir$app_name/env.example $containers_dir$app_name/.env)
    checkSuccess "Setting up .env file to path"
}

dockerStopAllApps()
{
    isNotice "Please wait for docker containers to stop"
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local result=$(runCommandForDockerInstallUser 'docker stop $(docker ps -a -q)')
        checkSuccess "Stopping all docker containers"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        local result=$(sudo -u $easydockeruser docker stop $(docker ps -a -q))
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
        local result=$(sudo -u $easydockeruser docker restart $(docker ps -a -q))
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