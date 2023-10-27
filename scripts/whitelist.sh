#!/bin/bash

# Function to update IP whitelist in YAML files
whitelistAndStartApp()
{
    local app_name="$1"
    local flags="$2"
    local norestart="$3"

    # Starting variable for app
    clearAllPortData;
    setupInstallVariables $app_name;

    # Always keep YML updated
    whitelistUpdateYML $app_name $flags $norestart;
}

# Function to update IP whitelist in YAML files
whitelistScan()
{
    echo ""
    echo "#####################################"
    echo "###     Whitelist/Port Updater    ###"
    echo "#####################################"
    echo ""
    for app_name_dir in "$containers_dir"/*/; do
        if [ -d "$app_name_dir" ]; then
            local app_name=$(basename "$app_name_dir")

            # Starting variable for app
            clearAllPortData;
            setupInstallVariables $app_name;
    
            # Always keep YML updated
            whitelistUpdateYML $app_name scan;

            # Update ports for the app
            checkAppPorts $app_name scan;
        fi
    done
    
    handleAllConflicts;
    isSuccessful "All application whitelists are up to date."
}

whitelistUpdateYML()
{
    local app_name="$1"
    local flags="$2"
    local norestart="$3"

    local whitelistupdates=false
    local timezoneupdates=false

    if [[ $compose_setup == "default" ]]; then
        local compose_file="docker-compose.yml"
    elif [[ $compose_setup == "app" ]]; then
        local compose_file="docker-compose.$app_name.yml"
    fi

    # Whitelist update for yml files
    for yaml_file in "$containers_dir/$app_name"/$compose_file; do
        if [ -f "$yaml_file" ]; then
            # Check if the YAML file contains ipwhitelist.sourcerange
            if grep -q "ipwhitelist.sourcerange:" "$yaml_file"; then
                # Whitelist not setup yet
                if grep -q "ipwhitelist.sourcerange: IPWHITELIST" "$yaml_file"; then
                    local result=$(sudo sed -i "s/ipwhitelist.sourcerange: IPWHITELIST/ipwhitelist.sourcerange: $CFG_IPS_WHITELIST/" "$yaml_file")
                    checkSuccess "Update the IP whitelist for $app_name"
                    local whitelistupdates=true
                    break  # Exit the loop after updating
                fi
                # If the IPs are setup already but need an update
                local current_ip_range=""
                local current_ip_range=$(grep "traefik.http.middlewares.my-whitelist-in-docker.ipwhitelist.sourcerange:" "$yaml_file" | cut -d ':' -f 2 | xargs)
                if [ "$current_ip_range" != "$CFG_IPS_WHITELIST" ] && [ "$current_ip_range" != "IPWHITELIST" ]; then
                    local result=$(sudo sed -i "s/ipwhitelist.sourcerange: $current_ip_range/ipwhitelist.sourcerange: $CFG_IPS_WHITELIST/" "$yaml_file")
                    checkSuccess "Update the IP whitelist for $app_name"
                    local whitelistupdates=true
                fi
            fi

            # This is for updating Timzeones
            if grep -q " TZ=" "$yaml_file"; then
                if grep -q " TZ=TIMZEONEHERE" "$yaml_file"; then
                    local result=$(sudo sed -i "s| TZ=TIMZEONEHERE| TZ=$CFG_TIMEZONE|" "$yaml_file")
                    checkSuccess "Update the IP whitelist for $app_name"
                    local timezoneupdates=true
                    break  # Exit the loop after updating
                fi
                # If the timzones are setup already but need an update
                local current_timezone=""
                local current_timezone=$(grep " TZ=" "$yaml_file" | cut -d '=' -f 2 | xargs)
                if [ "$current_timezone" != "$CFG_TIMEZONE" ] && [ "$current_timezone" != "TIMZEONEHERE" ]; then
                    local result=$(sudo sed -i "s| TZ=$current_timezone| TZ=$CFG_TIMEZONE|" "$yaml_file")
                    checkSuccess "Update the Timezone for $app_name"
                    local timezoneupdates=true
                fi
            fi
        fi
    done

    # Fail2ban specifics
    if [[ "$app_name" == "fail2ban" ]]; then
        local jail_local_file="$containers_dir/$app_name/config/$app_name/jail.local"
        
        if [ -f "$jail_local_file" ]; then
            if grep -q "ignoreip = ips_whitelist" "$jail_local_file"; then

                # Whitelist not set up yet
                if grep -q "ignoreip = ips_whitelist" "$yaml_file"; then
                    local result=$(sudo sed -i "s/ips_whitelist/$CFG_IPS_WHITELIST/" "$jail_local_file")
                    checkSuccess "Update the IP whitelist for $app_name"
                    local whitelistupdates=true
                fi

                # If the IPs are set up already but need an update
                local current_ip_range=$(grep "ignoreip = " "$jail_local_file" | cut -d ' ' -f 2)
                if [ "$current_ip_range" != "$CFG_IPS_WHITELIST" ]; then
                    local result=$(sudo sed -i "s/ignoreip = ips_whitelist/ignoreip = $CFG_IPS_WHITELIST/" "$jail_local_file")
                    checkSuccess "Update the IP whitelist for $app_name"
                    local whitelistupdates=true
                fi
            fi
        fi
    fi

    if [ "$flags" == "install" ]; then
        whitelistUpdateCompose $app_name;
        if [[ $norestart != "norestart"]]
            whitelistUpdateRestart $app_name $flags;
        fi
        if [ "$whitelistupdates" == "true" ] && [ "$timezoneupdates" == "true" ]; then
            if [ "$did_not_restart" == "true" ]; then
                isSuccessful "The whitelist and timezone for $app_name are now up to date."
                isNotice "Please restart $app_name to apply any updates."
            else
                isSuccessful "The whitelist and timezone for $app_name are now up to date and restarted."
            fi
        elif [ "$whitelistupdates" == "true" ]; then
            if [ "$did_not_restart" == "true" ]; then
                isSuccessful "The whitelist for $app_name is now up to date."
                isNotice "Please restart $app_name to apply any updates."
            else
                isSuccessful "The whitelist for $app_name is now up to date and restarted."
            fi
        elif [ "$timezoneupdates" == "true" ]; then
            if [ "$did_not_restart" == "true" ]; then
                isSuccessful "The timezone for $app_name is now up to date."
                isNotice "Please restart $app_name to apply any updates."
            else
                isSuccessful "The timezone for $app_name is now up to date and restarted."
            fi
        fi
        local whitelistupdates=false
        local timezoneupdates=false
        did_not_restart=false
    fi

    if [ "$whitelistupdates" == "true" ] || [ "$timezoneupdates" == "true" ]; then
        if [ "$flags" == "scan" ]; then
            if [ "$whitelistupdates" == "true" ] && [ "$timezoneupdates" == "true" ]; then
                if [ "$did_not_restart" == "true" ]; then
                    isSuccessful "The whitelist and timezone for $app_name are now up to date."
                    isNotice "Please restart $app_name to apply any updates."
                else
                    isSuccessful "The whitelist and timezone for $app_name are now up to date and restarted."
                fi
            elif [ "$whitelistupdates" == "true" ]; then
                if [ "$did_not_restart" == "true" ]; then
                    isSuccessful "The whitelist for $app_name is now up to date."
                    isNotice "Please restart $app_name to apply any updates."
                else
                    isSuccessful "The whitelist for $app_name is now up to date and restarted."
                fi
            elif [ "$timezoneupdates" == "true" ]; then
                if [ "$did_not_restart" == "true" ]; then
                    isSuccessful "The timezone for $app_name is now up to date."
                    isNotice "Please restart $app_name to apply any updates."
                else
                    isSuccessful "The timezone for $app_name is now up to date and restarted."
                fi
            fi
            local whitelistupdates=false
            local timezoneupdates=false
            did_not_restart=false
        fi
    fi

    if [ "$flags" == "restart" ]; then
        whitelistUpdateCompose $app_name;
        if [[ $norestart != "norestart"]]
            whitelistUpdateRestart $app_name $flags;
        fi
    fi
}

whitelistUpdateCompose()
{
    local app_name="$1"

    if [[ $compose_setup == "default" ]]; then
        editComposeFileDefault $app_name;
    elif [[ $compose_setup == "app" ]]; then
        editComposeFileApp $app_name;
    fi
}

whitelistUpdateRestart()
{
    local app_name="$1"
    local flags="$2"

    if [[ $compose_setup == "default" ]]; then
        if [[ $flags == "install" ]] ; then
            dockerDownUpDefault $app_name;
            did_not_restart=false
        elif [[ $flags == "" ]] || [[ $flags == "restart" ]]; then
            while true; do
                echo ""
                isNotice "Changes have been made to the $app_name configuration."
                echo ""
                isQuestion "Would you like to restart $app_name? (y/n): "
                echo ""
                read -p "" restart_choice
                if [[ -n "$restart_choice" ]]; then
                    break
                fi
                isNotice "Please provide a valid input."
            done
            if [[ "$restart_choice" == [yY] ]]; then
                dockerDownUpDefault $app_name;
                did_not_restart=false
            fi
            if [[ "$restart_choice" == [nN] ]]; then
                did_not_restart=true
            fi
        fi
    elif [[ $compose_setup == "app" ]]; then
        if [[ $flags == "install" ]]; then
            dockerDownUpDefault $app_name;
        elif [[ $flags == "" ]] || [[ $flags == "restart" ]]; then
            while true; do
                echo ""
                isNotice "Changes have been made to the $app_name configuration."
                echo ""
                isQuestion "Would you like to restart $app_name? (y/n): "
                echo ""
                read -p "" restart_choice
                if [[ -n "$restart_choice" ]]; then
                    break
                fi
                isNotice "Please provide a valid input."
            done
            if [[ "$restart_choice" =~ [yY] ]]; then
                dockerDownUpAdditionalYML $app_name;
                did_not_restart=false
            fi
            if [[ "$restart_choice" == [nN] ]]; then
                did_not_restart=true
            fi
        fi
    fi

}