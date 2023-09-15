#!/bin/bash

gitFolderResetAndBackup()
{
    update_done=false
    # Folder setup
    # Check if the directory specified in $script_dir exists
    if [ ! -d "$backup_install_dir/$backupFolder" ]; then
        result=$(mkdirFolders "$backup_install_dir/$backupFolder")
        checkSuccess "Create the backup folder"
    fi
    result=$(cd $backup_install_dir)
    checkSuccess "Going into the backup install folder"
    
    # Copy folders
    result=$(copyFolder "$configs_dir" "$backup_install_dir/$backupFolder")
    checkSuccess "Copy the configs to the backup folder"
    result=$(copyFolder "$logs_dir" "$backup_install_dir/$backupFolder")
    checkSuccess "Copy the logs to the backup folder"
    
    # Reset git
    result=$(sudo -u $easydockeruser rm -rf $script_dir)
    checkSuccess "Deleting all Git files"
    result=$(mkdirFolders "$script_dir")
    checkSuccess "Create the directory if it doesn't exist"
    cd "$script_dir"
    checkSuccess "Going into the install folder"
    result=$(sudo -u $easydockeruser git clone "$repo_url" "$script_dir" > /dev/null 2>&1)
    checkSuccess "Clone the Git repository"
    
    # Copy files back into the install folder
    result=$(copyFolders "$backup_install_dir/$backupFolder/" "$script_dir")
    checkSuccess "Copy the backed up folders back into the installation directory"
    
    # Zip up folder for safe keeping and remove folder
    result=$(sudo -u $easydockeruser zip -r "$backup_install_dir/$backupFolder.zip" "$backup_install_dir/$backupFolder")
    checkSuccess "Zipping up the the backup folder for safe keeping"
    result=$(sudo rm -rf "$backup_install_dir/$backupFolder")
    checkSuccess "Removing the backup folder"
    
    # Fixing the issue where the git does not use the .gitignore
    result=$(cd $script_dir)
    checkSuccess "Going into the install folder"
    sudo -u $easydockeruser git rm --cached $configs_dir/$config_file_backup > /dev/null 2>&1
    sudo -u $easydockeruser git rm --cached $configs_dir/$config_file_general > /dev/null 2>&1
    sudo -u $easydockeruser git rm --cached $configs_dir/$config_file_requirements > /dev/null 2>&1
    sudo -u $easydockeruser git rm --cached $configs_dir/$ip_file > /dev/null 2>&1
    sudo -u $easydockeruser find "$containers_dir" -type f -name '*.config' -exec git rm --cached {} \; > /dev/null 2>&1
    sudo -u $easydockeruser git rm --cached $logs_dir/$docker_log_file > /dev/null 2>&1
    sudo -u $easydockeruser git rm --cached $logs_dir/$backup_log_file > /dev/null 2>&1
    isSuccessful "Removing configs and logs from git for git changes"
    result=$(sudo -u $easydockeruser git commit -m "Stop tracking ignored files")
    checkSuccess "Removing tracking ignored files"
    
    isSuccessful "Custom changes have been discarded successfully"
    update_done=true
}

sourceScripts() 
{
    local current_dir="$1"
    for script_file in "$current_dir"/*.sh; do
        if [ -f "$script_file" ]; then
            # Source the script
            . "$script_file"
            echo "SCRIPT FILE : $script_file"
        fi
    done

    # Traverse subdirectories
    for sub_dir in "$current_dir"/*/; do
        if [ -d "$sub_dir" ]; then
            sourceScripts "$sub_dir"
        fi
    done
}

function userExists() {
    if id "$1" &>/dev/null; then
        return 0 # User exists
    else
        return 1 # User does not exist
    fi
}

function checkSuccess()
{
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS:${NC} $1"
        if [ -f "$logs_dir/$docker_log_file" ]; then
            echo "SUCCESS: $1" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" >/dev/null
        fi
    else
        echo -e "${RED}ERROR:${NC} $1"
        # Ask to continue
        while true; do
            isQuestion "An error has occurred. Do you want to continue, exit or go to back to the Menu? (c/x/m) "
            read -rp "" error_occurred
            if [[ -n "$error_occurred" ]]; then
                break
            fi
            isNotice "Please provide a valid input."
        done
        
        if [[ "$error_occurred" == [cC] ]]; then
            isNotice "Continuing after error has occured."
        fi
        
        if [[ "$error_occurred" == [xX] ]]; then
            # Log the error output to the log file
            echo "ERROR: $1" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file"
            echo "===================================" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file"
            exit 1  # Exit the script with a non-zero status to stop the current action
        fi
        
        if [[ "$error_occurred" == [mM] ]]; then
            # Log the error output to the log file
            echo "ERROR: $1" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file"
            echo "===================================" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file"
            resetToMenu
        fi
    fi
}

function isSuccessful()
{
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

function isError()
{
    echo -e "${RED}ERROR:${NC} $1"
}

function isFatalError()
{
    echo -e "${RED}ERROR:${NC} $1"
}

function isFatalErrorExit()
{
    echo -e "${RED}ERROR:${NC} $1"
    echo ""
    exit 1
}

function isNotice()
{
    echo -e "${YELLOW}NOTICE:${NC} $1"
}

function isQuestion()
{
    echo -e -n "${BLUE}QUESTION:${NC} $1 "
}

function isOptionMenu()
{
    echo -e -n "${PINK}OPTION:${NC} $1"
}

function isOption()
{
    echo -e "${PINK}OPTION:${NC} $1"
}

detectOS()
{
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "$NAME" in
            "Debian GNU/Linux")
                detected_os="Debian 10 / 11 / 12"
            OS=1 ;;
            "Ubuntu")
                case "$VERSION_ID" in
                    "18.04")
                        detected_os="Ubuntu 18.04"
                    OS=2 ;;
                    "20.04" | "21.04" | "22.04")
                        detected_os="Ubuntu 20.04 / 21.04 / 22.04"
                    OS=3 ;;
                esac
            ;;
            "Arch Linux")
                detected_os="Arch Linux"
            OS=4 ;;
            *)  # Default selection (End this Installer)
                echo "Unable to detect OS."
            exit 1 ;;
        esac
        
        echo ""
        checkSuccess "Detected OS: $detected_os"
        
        if [ "$OS" -gt 1 ]; then
            isError "This OS ($detected_os) is untested and may not be fully supported."
            while true; do
                isQuestion "Do you wish to continue anyway? (y/n): "
                read -rp "" oswarningaccept
                if [[ -n "$oswarningaccept" ]]; then
                    break
                fi
                isNotice "Please provide a valid input."
            done
        fi
        
        installDockerUser;
        scanConfigsForRandomPassword;
        checkRequirements;
    else
        checkSuccess "Unable to detect OS."
        exit 1
    fi
}

runCommandForDockerInstallUser()
{
    local remote_command="$1"
    
    # Run the SSH command using the existing SSH variables
    result=$(sshpass -p "$CFG_DOCKER_INSTALL_PASS" ssh -o StrictHostKeyChecking=no "$CFG_DOCKER_INSTALL_USER@localhost" "$remote_command")
}

# Function to check missing config variables in local config files against remote config files
checkConfigFilesMissingVariables()
{
    local local_configs=("$configs_dir"config_*)
    remote_config_dir="https://raw.githubusercontent.com/OpenSourceWebstar/EasyDocker/main/configs/"
    
    for local_config_file in "${local_configs[@]}"; do
        local_config_filename=$(basename "$local_config_file")
        #echo "Checking local config file: $local_config_filename"  # Debug line output
        
        # Extract config variables from the local file
        local_variables=($(grep -o 'CFG_[A-Za-z0-9_]*=' "$local_config_file" | sed 's/=$//'))
        
        # Generate the remote URL based on the local config file name
        remote_url="$remote_config_dir$local_config_filename"
        
        #echo "Checking remote config file: $local_config_filename"  # Debug line output
        
        # Download the remote config file
        tmp_file=$(mktemp)
        curl -s "$remote_url" -o "$tmp_file"
        
        # Extract config variables from the remote file
        remote_variables=($(grep -o 'CFG_[A-Za-z0-9_]*=' "$tmp_file" | sed 's/=$//'))
        
        # Filter out empty variable names from the remote variables
        remote_variables=("${remote_variables[@]//[[:space:]]/}")  # Remove whitespace
        remote_variables=($(echo "${remote_variables[@]}" | tr ' ' '\n' | grep -v '^$' | tr '\n' ' '))
        
        # Compare local and remote variables
        for remote_var in "${remote_variables[@]}"; do
            if ! [[ " ${local_variables[@]} " =~ " $remote_var " ]]; then
                var_line=$(grep "${remote_var}=" "$tmp_file")
                
                echo ""
                echo "########################################"
                echo "###   Missing Config Variable Found  ###"
                echo "########################################"
                echo ""
                isNotice "Variable '$remote_var' is missing in the local config file '$local_config_filename'."
                echo ""
                isOption "1. Add the '$var_line' to the '$local_config_filename'"
                isOption "2. Add the '$remote_var' with my own value"
                isOption "x. Skip"
                echo ""
                
                isQuestion "Enter your choice (1 or 2) or 'x' to skip : "
                read -rp "" choice
                
                case "$choice" in
                    1)
                        echo ""
                        echo "$var_line" | sudo tee -a "$local_config_file" > /dev/null 2>&1
                        checkSuccess "Adding the $var_line to '$local_config_filename':"
                    ;;
                    2)
                        echo ""
                        isQuestion "Enter your value for $remote_var: "
                        read -p " " custom_value
                        echo ""
                        echo "CFG_${remote_var}=$custom_value" | sudo tee -a "$local_config_file" > /dev/null 2>&1
                        checkSuccess "Adding the CFG_${remote_var}=$custom_value to '$local_config_filename':"
                    ;;
                    [xX])
                        # User chose to skip
                    ;;
                    *)
                        echo "Invalid choice. Skipping."
                    ;;
                esac
            fi
        done
        
        # Clean up the temporary file
        rm "$tmp_file"
    done
    
    echo ""
    isSuccessful "Config variable check completed."  # Indicate completion
}

checkConfigFilesExist()
{
    if [[ $CFG_REQUIREMENT_CONFIG == "true" ]]; then
        local file_found_count=0
        
        for file in "${config_files_all[@]}"; do
            if [ -f "$configs_dir/$file" ]; then
                ((file_found_count++))
            else
                isFatalError "Config File $file does not exist in $configs_dir."
                isFatalErrorExit "Please make sure all configs are present"
            fi
        done
        
        if [ "$file_found_count" -eq "${#config_files_all[@]}" ]; then
            isSuccessful "All config files are found in the configs folder."
        else
            isFatalError "Not all config files were found in $configs_dir."
        fi
    fi
}

checkConfigFilesEdited()
{
    # Flag to control the loop
    config_check_done=false
    
    while ! "$config_check_done"; do
        # Check if configs have not been changed
        if grep -q "Change-Me" "$configs_dir/$config_file_general"; then
            echo ""
            isNotice "Default config values have been found, have you edited the config files?"
            echo ""
            while true; do
                isQuestion "Would you like to continue with the default config values or edit them? (c/e): "
                read -rp "" configsnotchanged
                echo ""
                case $configsnotchanged in
                    [cC])
                        isNotice "Config files have been accepted with the default values, continuing... "
                        config_check_done=true  # Set the flag to exit the loop
                        break  # Exit the loop
                    ;;
                    [eE])
                        viewConfigs
                        # No need to set config_check_done here; it will continue to the next iteration of the loop
                        break  # Exit the loop
                    ;;
                    *)
                        isNotice "Please provide a valid input (c or e)."
                    ;;
                esac
            done
        else
            isSuccessful "Config file has been updated, continuing..."
            config_check_done=true  # Set the flag to exit the loop
        fi
    done
}

viewLogsAppMenu()
{
    local app_name="$1"
    echo ""
    isNotice "Viewing logs for $app_name:"
    echo ""
    isOption "1. Show last 20 lines"
    isOption "2. Show last 50 lines"
    isOption "3. Show last 100 lines"
    isOption "4. Show last 200 lines"
    isOption "5. Show full log"
    isOption "x. Back to main menu"
    echo ""
    isQuestion "Enter your choice (1-5, x): "
    read -p "" app_log_choice
    case "$app_log_choice" in
        1)
            runCommandForDockerInstallUser "docker logs $app_name --tail 20"
            isQuestion "Press Enter to continue..."
            read -p "" continueafterlogs
            viewLogsAppMenu "$app_name"
        ;;
        2)
            runCommandForDockerInstallUser "docker logs $app_name --tail 50"
            isQuestion "Press Enter to continue..."
            read -p "" continueafterlogs
            viewLogsAppMenu "$app_name"
        ;;
        3)
            runCommandForDockerInstallUser "docker logs $app_name --tail 100"
            isQuestion "Press Enter to continue..."
            read -p "" continueafterlogs
            viewLogsAppMenu "$app_name"
        ;;
        4)
            runCommandForDockerInstallUser "docker logs $app_name --tail 200"
            isQuestion "Press Enter to continue..."
            read -p "" continueafterlogs
            viewLogsAppMenu "$app_name"
        ;;
        5)
            runCommandForDockerInstallUser "docker logs $app_name"
            isQuestion "Press Enter to continue..."
            read -p "" continueafterlogs
            viewLogsAppMenu "$app_name"
        ;;
        x)
            viewLogs;  # Return to the viewLogs submenu
        ;;
        *)
            isNotice "Invalid choice. Please select a valid option (1-5, x)."
            viewLogsAppMenu "$app_name"
        ;;
    esac
}

viewLogs()
{
    echo ""
    echo "##########################################"
    echo "###    View Logs for Installed Apps    ###"
    echo "##########################################"
    echo ""
    
    # List installed apps and add them as numbered options
    local app_list=($(sqlite3 "$base_dir/$db_file" "SELECT name FROM apps WHERE status = 1;"))
    for ((i = 0; i < ${#app_list[@]}; i++)); do
        isOption "$((i + 1)). View logs for ${app_list[i]}"
    done
    
    isOption "e. View easydocker.log"
    isOption "x. Exit"
    echo ""
    
    isQuestion "Enter your choice (1-${#app_list[@]}, e, x): "
    read -p "" log_choice
    
    case "$log_choice" in
        [1-9]|[1-9][0-9]|10)
            index=$((log_choice - 1))
            if [ "$index" -ge 0 ] && [ "$index" -lt "${#app_list[@]}" ]; then
                app_name="${app_list[index]}"
                viewLogsAppMenu "$app_name"  # Call the app-specific menu
            else
                echo ""
                isNotice "Invalid app selection. Please select a valid app."
                viewLogs;
            fi
        ;;
        e)
            isNotice "Viewing easydocker.log:"
            nano "$logs_dir/easydocker.log"
            viewLogs;
        ;;
        x)
            isNotice "Exiting"
            return
        ;;
        *)
            isNotice "Invalid choice. Please select a valid option (1-${#app_list[@]}, e, x)."
            viewLogs;
        ;;
    esac
}


editAppConfig() 
{
    local app_name="$1"
    local app_dir="$containers_dir/$app_name"

    if [ -d "$app_dir" ]; then
        config_file="$app_dir/config"

        if [ -f "$config_file" ]; then
            nano "$config_file"
        else
            echo "Config file not found for $app_name."
        fi
    else
        echo "App folder not found for $app_name."
    fi
}

viewEasyDockerConfigs()
{
    local config_files=("$configs_dir"*)  # List all files in the /configs/ folder
    
    echo ""
    echo "#################################"
    echo "###    Manage Config Files    ###"
    echo "#################################"
    echo ""
    
    if [ ${#config_files[@]} -eq 0 ]; then
        isNotice "No files found in /configs/ folder."
        return
    fi
    
    declare -A config_timestamps  # Associative array to store config names and their modified timestamps
    
    PS3="Select a config to edit (Type the first letter of the config, or x to exit): "
    while true; do
        for ((i = 0; i < ${#config_files[@]}; i++)); do
            file_name=$(basename "${config_files[i]}")  # Get the basename of the file
            file_name_without_prefix=${file_name#config_}  # Remove the "config_" prefix from all files
            config_name=${file_name_without_prefix,,}  # Convert the name to lowercase
            
            if [[ "$file_name" == config_apps_* ]]; then
                config_name=${config_name#apps_}  # Remove the "apps_" prefix from files with that prefix
            fi
            
            first_letter=${config_name:0:1}  # Get the first letter
            
            # Check if the config name is in the associative array and retrieve the last modified timestamp
            if [ "${config_timestamps[$config_name]}" ]; then
                last_modified="${config_timestamps[$config_name]}"
            else
                last_modified=$(stat -c "%y" "${config_files[i]}")  # Get last modified time if not already in the array
                config_timestamps["$config_name"]=$last_modified  # Store the last modified timestamp in the array
            fi
            
            formatted_last_modified=$(date -d "$last_modified" +"%m/%d %H:%M")  # Format the timestamp
            
            isOption "$first_letter. ${config_name,,} (Last modified: $formatted_last_modified)"
        done
        
        isOption "x. Exit"
        echo ""
        isQuestion "Enter the first letter of the config (or x to exit): "
        read -p "" selected_letter
        
        if [[ "$selected_letter" == "x" ]]; then
            isNotice "Exiting."
            return
            elif [[ "$selected_letter" =~ [A-Za-z] ]]; then
            selected_file=""
            for ((i = 0; i < ${#config_files[@]}; i++)); do
                file_name=$(basename "${config_files[i]}")
                file_name_without_prefix=${file_name#config_}
                config_name=${file_name_without_prefix,,}
                
                if [[ "$file_name" == config_apps_* ]]; then
                    config_name=${config_name#apps_}
                fi
                
                first_letter=${config_name:0:1}
                if [[ "$selected_letter" == "$first_letter" ]]; then
                    selected_file="${config_files[i]}"
                    break
                fi
            done
            
            if [ -z "$selected_file" ]; then
                isNotie "No config found with the selected letter. Please try again."
                read -p "Press Enter to continue."
            else
                nano "$selected_file"
                
                # Update the last modified timestamp of the edited file
                createTouch "$selected_file"
                
                # Store the updated last modified timestamp in the associative array
                config_name=$(basename "${selected_file}" | sed 's/config_//')
                config_timestamps["$config_name"]=$(stat -c "%y" "$selected_file")
                
                # Show a notification message indicating the config has been updated
                echo ""
                isNotice "Configuration file '$config_name' has been updated."
                echo ""
            fi
        else
            isNotice "Invalid input. Please enter a valid letter or 'x' to exit."
            echo ""
            read -p "Press Enter to continue."
        fi
    done
}

# Function to view App configs
viewAppConfigs() {
    echo ""
    echo "#################################"
    echo "###        App Configs        ###"
    echo "#################################"
    echo ""

    app_config_files=("$containers_dir"/*/config)

    if [ ${#app_config_files[@]} -eq 0 ]; then
        isNotice "No app config files found in $containers_dir."
        return
    fi

    app_names=()
    for app_config_file in "${app_config_files[@]}"; do
        app_name=$(dirname "$app_config_file")
        app_name=$(basename "$app_name")
        app_names+=("$app_name")
    done

    PS3="Select an app to edit the config (or x to exit): "
    select app_name in "${app_names[@]}" "x. Exit"; do
        if [[ "$REPLY" == "x" ]]; then
            isNotice "Exiting."
            return
        elif [[ "${app_names[@]}" =~ "$app_name" ]]; then
            editAppConfig "$app_name"
            break
        else
            isNotice "Invalid selection. Please choose a valid option or 'x' to exit."
        fi
    done
}

# Main function for viewing configs
viewConfigs() {
    while true; do
        echo ""
        echo "#################################"
        echo "###    Manage Config Files    ###"
        echo "#################################"
        echo ""
        
        PS3="Select an option (1. EasyDocker configs, 2. App configs, or x to exit): "
        select option in "EasyDocker configs" "App configs" "Exit"; do
            case "$option" in
                "EasyDocker configs")
                    viewEasyDockerConfigs
                    ;;
                "App configs")
                    viewAppConfigs
                    ;;
                "Exit")
                    isNotice "Exiting."
                    return
                    ;;
                *)
                    isNotice "Invalid option. Please choose a valid option or 'x' to exit."
                    ;;
            esac
        done
    done
}

editAppConfig()
{
    local app_name="$1"
    local app_dir
    app_dir=$(find "$containers_dir" -type d -name "$app_name" -print -quit)
    
    if [ -n "$app_dir" ]; then
        config_file="$app_dir/config"
        
        if [ -f "$config_file" ]; then
            nano "$config_file"
        else
            isError "Config file not found for $app_name."
        fi
    else
        isError "App folder not found for $app_name."
    fi
}

setupIPsAndHostnames()
{
    found_match=false
    while read -r line; do
        local hostname=$(echo "$line" | awk '{print $1}')
        local ip=$(echo "$line" | awk '{print $2}')
        
        if [ "$hostname" = "$host_name" ]; then
            found_match=true
            # Public variables
            domain_prefix=$hostname
            domain_var_name="CFG_DOMAIN_${domain_number}"
            domain_full=$(sudo grep  "^$domain_var_name=" $configs_dir/config_general | cut -d '=' -f 2-)
            host_setup=${domain_prefix}.${domain_full}
            ssl_key=${domain_full}.key
            ssl_crt=${domain_full}.crt
            ip_setup=$ip
            
            if [[ "$public" == "true" ]]; then
                isSuccessful "Using $host_setup for public domain."
                checkSuccess "Match found: $hostname with IP $ip."  # Moved this line inside the conditional block
                echo ""
            fi
        fi
    done < "$configs_dir$ip_file"
    
    if ! "$found_match"; then  # Changed the condition to check if no match is found
        checkSuccess "No matching hostnames found for $host_name, please fill in the ips_hostname file"
        echo ""
    fi
}

setupComposeFileNoApp()
{
    local target_path="$install_path$app_name"
    local source_file="$script_dir/containers/docker-compose.$app_name.yml"
    
    if [ -d "$target_path" ]; then
        isNotice "The directory '$target_path' already exists."
        return 1
    fi
    
    if [ ! -f "$source_file" ]; then
        isError "The source file '$source_file' does not exist."
        return 1
    fi
    
    mkdirFolders "$target_path"
    if [ $? -ne 0 ]; then
        isError "Failed to create the directory '$target_path'."
        return 1
    fi
    
    copyFile "$source_file" "$target_path/docker-compose.yml" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
    
    if [ $? -ne 0 ]; then
        isError "Failed to copy the source file to '$target_path'. Check '$docker_log_file' for more details."
        return 1
    fi
    
    cd "$target_path"
}

setupComposeFileApp()
{
    local target_path="$install_path$app_name"
    local source_file="$script_dir/containers/docker-compose.$app_name.yml"
    
    if [ -d "$target_path" ]; then
        isNotice "The directory '$target_path' already exists."
        return 1
    fi
    
    if [ ! -f "$source_file" ]; then
        isError ""Error: "The source file '$source_file' does not exist."
        return 1
    fi
    
    result=$(sudo -u $easydockeruser mkdir -p "$target_path")
    checkSuccess "Creating install path for $app_name"
    
    if [ $? -ne 0 ]; then
        isError "Failed to create the directory '$target_path'."
        return 1
    fi
    
    copyFile "$source_file" "$target_path/docker-compose.$app_name.yml" | sudo -u $easydockeruser tee -a "$logs_dir/$docker_log_file" 2>&1
    
    if [ $? -ne 0 ]; then
        isError "Failed to copy the source file to '$target_path'. Check '$docker_log_file' for more details."
        return 1
    fi
    
    cd "$target_path"
}

dockerDownUpDefault()
{
    if [[ "$OS" == [123] ]]; then
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose down")
            checkSuccess "Shutting down container for $app_name"
            
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose up -d")
            checkSuccess "Starting up container for $app_name"
            elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            result=$(sudo -u $easydockeruser docker-compose down)
            checkSuccess "Shutting down container for $app_name"
            
            result=$(sudo -u $easydockeruser docker-compose up -d)
            checkSuccess "Starting up container for $app_name"
        fi
    else
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose down")
            checkSuccess "Shutting down container for $app_name"
            
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose up -d")
            checkSuccess "Starting up container for $app_name"
            elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            result=$(sudo -u $easydockeruser docker-compose down)
            checkSuccess "Shutting down container for $app_name"
            
            result=$(sudo -u $easydockeruser docker-compose up -d)
            checkSuccess "Starting up container for $app_name"
        fi
    fi
}

dockerUpDownAdditionalYML()
{
    if [[ "$OS" == [123] ]]; then
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down")
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"
            
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml -q up -d")
            checkSuccess "Starting up container for $app_name (Using additional yml file)"
            elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down)
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"
            
            result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml -q up -d)
            checkSuccess "Starting up container for $app_name (Using additional yml file)"
        fi
    else
        if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down")
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"
            
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml -q -q up -d")
            checkSuccess "Starting up container for $app_name (Using additional yml file)"
            elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
            result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml down)
            checkSuccess "Shutting down container for $app_name (Using additional yml file)"
            
            result=$(sudo -u $easydockeruser docker-compose -f docker-compose.yml -f docker-compose.$app_name.yml up -d)
            checkSuccess "Starting up container for $app_name (Using additional yml file)"
        fi
    fi
}

editComposeFileDefault()
{
    local compose_file="$install_path$app_name/docker-compose.yml"
    
    result=$(sudo sed -i \
        -e "s/DOMAINNAMEHERE/$domain_full/g" \
        -e "s/DOMAINSUBNAMEHERE/$host_setup/g" \
        -e "s/DOMAINPREFIXHERE/$domain_prefix/g" \
        -e "s/PUBLICIPHERE/$public_ip/g" \
        -e "s/IPADDRESSHERE/$ip_setup/g" \
        -e "s/IPWHITELIST/$CFG_IPS_WHITELIST/g" \
        -e "s/PORTHERE/$port/g" \
        -e "s/SECONDPORT/$port_2/g" \
    "$compose_file")
    checkSuccess "Updating Compose file for $app_name"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        result=$(sudo sed -i \
            -e "s|- /var/run/docker.sock|- /run/user/${docker_install_user_id}/docker.sock|g" \
        "$compose_file")
        checkSuccess "Updating Compose file for $app_name"
    fi
    
    if [[ "$public" == "true" ]]; then
        if [[ "$app_name" != "traefik" ]]; then
            result=$(sudo sed -i "s/#traefik/traefik/g" $compose_file)
            checkSuccess "Enabling Traefik options for public setup"
            result=$(sudo sed -i "s/#labels:/labels:/g" $compose_file)
            checkSuccess "Enable labels for Traefik option options on private setup"
        fi
    fi
    
    if [[ "$public" == "false" ]]; then
        if [[ "$app_name" != "traefik" ]]; then
            result=$(sudo sed -i "s/labels:/#labels/g" $compose_file)
            checkSuccess "Disable Traefik options for private setup"
        fi
    fi
    
    isSuccessful "Updated the $app_name docker-compose.yml"
}

editComposeFileApp()
{
    local compose_file="$install_path$app_name/docker-compose.$app_name.yml"
    
    result=$(sudo sed -i \
        -e "s/DOMAINNAMEHERE/$domain_full/g" \
        -e "s/DOMAINSUBNAMEHERE/$host_setup/g" \
        -e "s/DOMAINPREFIXHERE/$domain_prefix/g" \
        -e "s/PUBLICIPHERE/$public_ip/g" \
        -e "s/IPADDRESSHERE/$ip_setup/g" \
        -e "s/IPWHITELIST/$CFG_IPS_WHITELIST/g" \
        -e "s/PORTHERE/$port/g" \
        -e "s/SECONDPORT/$port_2/g" \
    "$compose_file")
    checkSuccess "Updating Compose file for $app_name (Using additional yml file)"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        result=$(sudo sed -i \
            -e "s|- /var/run/docker.sock|- /run/user/${docker_install_user_id}/docker.sock|g" \
        "$compose_file")
        checkSuccess "Updating Compose file for $app_name"
    fi
    
    if [[ "$public" == "true" ]]; then
        if [[ "$app_name" != "traefik" ]]; then
            result=$(sudo sed -i "s/#traefik/traefik/g" $compose_file)
            checkSuccess "Enabling Traefik options for public setup)"
        fi
    fi
    
    if [[ "$public" == "false" ]]; then
        if [[ "$app_name" != "traefik" ]]; then
            result=$(sudo sed -i "s/labels:/#labels/g" $compose_file)
            checkSuccess "Disable Traefik options for private setup"
        fi
    fi
    
    isSuccessful "Updated the docker-compose.$app_name.yml"
}

editEnvFileDefault()
{
    local env_file="$install_path$app_name/.env"
    
    result=$(sudo sed -i \
        -e "s/DOMAINNAMEHERE/$domain_full/g" \
        -e "s/DOMAINSUBNAMEHERE/$host_setup/g" \
        -e "s/DOMAINPREFIXHERE/$domain_prefix/g" \
        -e "s/PUBLICIPHERE/$public_ip/g" \
        -e "s/IPADDRESSHERE/$ip_setup/g" \
        -e "s/IPWHITELIST/$CFG_IPS_WHITELIST/g" \
        -e "s/PORTHERE/$port/g" \
        -e "s/SECONDPORT/$port_2/g" \
    "$env_file")
    checkSuccess "Updating .env file for $app_name"
    
    isSuccessful "Updated the .env file"
}

editCustomFile()
{
    local customfile="$1"
    local custompath="$2"
    local custompathandfile="$custompath/$customfile"
    
    result=$(sudo sed -i \
        -e "s/DOMAINNAMEHERE/$domain_full/g" \
        -e "s/DOMAINSUBNAMEHERE/$host_setup/g" \
        -e "s/DOMAINPREFIXHERE/$domain_prefix/g" \
        -e "s/PUBLICIPHERE/$public_ip/g" \
        -e "s/IPADDRESSHERE/$ip_setup/g" \
        -e "s/IPWHITELIST/$CFG_IPS_WHITELIST/g" \
        -e "s/PORTHERE/$port/g" \
        -e "s/SECONDPORT/$port_2/g" \
    "$custompathandfile")
    checkSuccess "Updating $customfile file for $app_name"
    
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        local docker_install_user_id=$(id -u "$CFG_DOCKER_INSTALL_USER")
        result=$(sudo sed -i \
            -e "s|- /var/run/docker.sock|- /run/user/${docker_install_user_id}/docker.sock|g" \
        "$custompathandfile")
        checkSuccess "Updating Compose file for $app_name"
    fi
    
    isSuccessful "Updated the $customfile file"
}

passwordValidation()
{
    # Password Setup for DB with complexity checking
    # Initialize valid password flag
    valid_password=false
    # Loop until a valid password is entered
    while [ $valid_password = false ]
    do
        # Prompt the user for a password
        echo -n "Enter your password: "
        # Disable echoing of the password input, so that it is not displayed on the screen
        stty -echo
        # Read in the password input
        read password
        # Re-enable echoing of the input
        stty echo
        echo
        # Check the length of the password
        if [ ${#password} -lt 8 ]; then
            isError "Password is too short. Please enter a password with at least 8 characters."
            continue
        fi
        # Check the complexity of the password
        if ! [[ "$password" =~ [[:lower:]] ]] || ! [[ "$password" =~ [[:upper:]] ]] || ! [[ "$password" =~ [[:digit:]] ]]; then
            isError "Password is not complex enough. Please include at least one uppercase letter, one lowercase letter, and one numeric digit."
            continue
        fi
        # If we make it here, the password is valid
        valid_password=true
    done
}

emailValidation()
{
    # Initialize email variable to empty string
    email=""
    
    # Loop until a valid email is entered
    while [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
        
        # Prompt user to submit email
        isQuestion "Please enter your email address: "
        read -p "" email
        
        # Check email format using regex
        if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            isError "Invalid email format. Please try again."
        fi
        
    done
}

removeEmptyLineAtFileEnd()
{
    local file_path="$1"
    local last_line=$(tail -n 1 "$file_path")
    
    if [ -z "$last_line" ]; then
        result=$(sudo sed -i '$d' "$file_path")
        checkSuccess "Removed the empty line at the end of $file_path"
    fi
}

scanConfigsForRandomPassword()
{
    if [[ "$CFG_REQUIREMENT_PASSWORDS" == "true" ]]; then
        echo ""
        echo "##########################################"
        echo "###    Randomizing Config Passwords    ###"
        echo "##########################################"
        echo ""
        # Iterate through files in the folder
        for scanned_config_file in "$configs_dir"/*; do
            if [ -f "$scanned_config_file" ]; then
                # Check if the file contains the placeholder string "RANDOMIZEDPASSWORD"
                while sudo grep  -q "RANDOMIZEDPASSWORD" "$scanned_config_file"; do
                    # Generate a unique random password
                    local random_password=$(openssl rand -base64 12 | tr -d '+/=')
                    
                    # Capture the content before "RANDOMIZEDPASSWORD"
                    local config_content=$(sudo sed -n "s/RANDOMIZEDPASSWORD.*$/${random_password}/p" "$scanned_config_file")
                    
                    # Update the first occurrence of "RANDOMIZEDPASSWORD" with the new password
                    sudo sed -i "0,/\(RANDOMIZEDPASSWORD\)/s//${random_password}/" "$scanned_config_file"
                    
                    # Display the update message with the captured content and file name
                    #isSuccessful "Updated $config_content in $(basename "$scanned_config_file") with a new password: $random_password"
                done
            fi
        done
        isSuccessful "Random password generation and update completed successfully."
    fi
}

setupEnvFile()
{
    result=$(copyFile $install_path$app_name/env.example $install_path$app_name/.env)
    checkSuccess "Setting up .env file to path"
}

dockerStopAllApps()
{
    isNotice "Please wait for docker containers to stop"
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        result=$(runCommandForDockerInstallUser 'docker stop $(docker ps -a -q)')
        checkSuccess "Stopping all docker containers"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        result=$(sudo -u $easydockeruser docker stop $(docker ps -a -q))
        checkSuccess "Stopping all docker containers"
    fi
}

dockerStartAllApps()
{
    isNotice "Please wait for docker containers to start"
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        result=$(runCommandForDockerInstallUser 'docker restart $(docker ps -a -q)')
        checkSuccess "Starting up all docker containers"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        result=$(sudo -u $easydockeruser docker restart $(docker ps -a -q))
        checkSuccess "Starting up all docker containers"
    fi
}

dockerAppDown() {
    isNotice "Please wait for $app_name container to stop"
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        if [ -d "$install_path$app_name" ]; then
            result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose down")
            checkSuccess "Shutting down $app_name container"
        else
            isNotice "Directory $install_path$app_name does not exist. Container not found."
        fi
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        if [ -d "$install_path$app_name" ]; then
            result=$(cd "$install_path$app_name" && docker-compose down)
            checkSuccess "Shutting down $app_name container"
        else
            isNotice "Directory $install_path$app_name does not exist. Container not found."
        fi
    fi
}

dockerAppUp()
{
    local app_name="$1"
    isNotice "Please wait for $app_name container to start"
    if [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "true" ]]; then
        result=$(runCommandForDockerInstallUser "cd $install_path$app_name && docker-compose up -d")
        checkSuccess "Starting up $app_name container"
        elif [[ $CFG_REQUIREMENT_DOCKER_ROOTLESS == "false" ]]; then
        result=$(cd $install_path$app_name && docker-compose up -d)
        checkSuccess "Starting up $app_name container"
    fi
}

showInstallInstructions()
{
    echo ""
    echo "#####################################"
    echo "###       Usage Instructions      ###"
    echo "#####################################"
    echo ""
    isNotice "Please select 'c' for each item you would like to edit the config."
    isNotice "Please select 'i' for each item you would like to install."
    isNotice "Please select 'u' for each item you would like to uninstall."
    isNotice "Please select 's' for each item you would like to shutdown."
    isNotice "Please select 'r' for each item you would like to restart."
}

completeMessage()
{
    echo ""
    isSuccessful "You seem to have reached the end of the script! Restarting.... <3"
    echo ""
    sleep 1
}

resetToMenu()
{
    # Apps
    fail2ban=n
    traefik=n
    wireguard=n
    pihole=n
    portainer=n
    watchtower=n
    dashy=n
    searxng=n
    speedtest=n
    ipinfo=n
    trilium=n
    vaultwarden=n
    jitsimeet=n
    owncloud=n
    killbill=n
    mattermost=n
    kimai=n
    mailcow=n
    tiledesk=n
    gitlab=n
    actual=n
    akaunting=n
    cozy=n
    duplicati=n
    caddy=n
    
    # Backup
    backupsingle=n
    backupfull=n
    
    # Restore
    restoresingle=n
    restorefull=n
    
    # Mirate
    migratecheckforfiles=n
    migratemovefrommigrate=n
    migrategeneratetxt=n
    migratescanforupdates=n
    migratescanforconfigstomigrate=n
    migratescanformigratetoconfigs=n
    
    # Database
    toollistalltables=n
    toollistallapps=n
    toollistinstalledapps=n
    toolupdatedb=n
    toolemptytable=n
    tooldeletedb=n
    
    # Tools
    toolsresetgit=n
    toolstartpreinstallation=n
    toolsstartcrontabsetup=n
    toolrestartcontainers=n
    toolstopcontainers=n
    toolsremovedockermanageruser=n
    toolsinstalldockermanageruser=n
    toolinstallremotesshlist=n
    toolinstallcrontab=n
    toolinstallcrontabssh=n
    
    mainMenu
    return 1
}