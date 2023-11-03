#!/bin/bash

# Category : privacy
# Description : Trilium - Note Manager (c/u/s/r/i):

installTrilium()
{
    if [[ "$trilium" == *[cCtTuUsSrRiI]* ]]; then
        setupConfigToContainer silent trilium;
        local app_name=$CFG_TRILIUM_APP_NAME
		setupInstallVariables $app_name;
    fi

    if [[ "$trilium" == *[cC]* ]]; then
        editAppConfig $app_name;
    fi

    if [[ "$trilium" == *[uU]* ]]; then
        uninstallApp $app_name;
    fi

    if [[ "$trilium" == *[sS]* ]]; then
        shutdownApp $app_name;
    fi

    if [[ "$trilium" == *[rR]* ]]; then
        dockerDownUp $app_name;
    fi

    if [[ "$trilium" == *[iI]* ]]; then
        echo ""
        echo "##########################################"
        echo "###          Install $app_name"
        echo "##########################################"
        echo ""

		((menu_number++))
        echo ""
        echo "---- $menu_number. Setting up install folder and config file for $app_name."
        echo ""

        setupConfigToContainer "loud" "$app_name" "install";
        isSuccessful "Install folders and Config files have been setup for $app_name."

        ((menu_number++))
        echo ""
        echo "---- $menu_number. Checking & Opening ports if required"
        echo ""

        checkAppPorts $app_name install;
        if [[ $disallow_used_port == "true" ]]; then
            isError "A used port conflict has occured, setup is cancelling..."
            disallow_used_port=""
            return
        else
            isSuccessful "No used port conflicts found, setup is continuing..."
        fi
        if [[ $disallow_open_port == "true" ]]; then
            isError "An open port conflict has occured, setup is cancelling..."
            disallow_open_port=""
            return
        else
            isSuccessful "No open port conflicts found, setup is continuing..."
        fi
        
		((menu_number++))
        echo ""
        echo "---- $menu_number. Setting up the $app_name docker-compose.yml file."
        echo ""

        setupComposeFile $app_name;

		((menu_number++))
        echo ""
        echo "---- $menu_number. Updating file permissions before starting."
        echo ""

		fixPermissionsBeforeStart $app_name;

		((menu_number++))
        echo ""
        echo "---- $menu_number. Running the docker-compose.yml to install and start $app_name"
        echo ""

		whitelistAndStartApp $app_name install;

		((menu_number++))
		echo ""
        echo "---- $menu_number. Updating defaul port and restarting $app_name"
        echo ""

        local timeout=30
        local start_time=$(date +%s)
        while true; do
            if [ -f "$config_file" ]; then
                # File exists, perform the configuration change
                result=$(sudo sed -i "s|port=8080|port=$usedport1|g" "$containers_dir$app_name/trilium-data/config.ini")
                checkSuccess "Configured $app_name from default 8080 to $desired_port"
                break  # Exit the loop once the configuration is done
            fi

            local current_time=$(date +%s)
            # Check if the timeout has been reached
            if [ $((current_time - start_time)) -ge $timeout ]; then
                echo "Timeout reached. File not found after $timeout seconds."
                break  # Exit the loop due to the timeout
            fi
            
            isNotice "Checking for config.ini every 1 second"
            sleep 1  # Wait for 1 second before checking again
        done

        dockerDownUp $app_name;

		((menu_number++))
		echo ""
        echo "---- $menu_number. Adding $app_name to the Apps Database table."
        echo ""

		databaseInstallApp $app_name;

		((menu_number++))
        echo ""
        echo "---- $menu_number. Running Headscale setup (if required)"
        echo ""

		setupHeadscale $app_name;

		((menu_number++))
        echo ""
        echo "---- $menu_number. You can find $app_name files at $containers_dir$app_name"
        echo ""
        echo "    You can now navigate to your $app_name service using any of the options below : "
        echo ""
        echo "    Public : https://$host_setup/"
        echo "    External : http://$public_ip:$usedport1/"
        echo "    Local : http://$ip_setup:$usedport1/"
        echo ""
		     
		menu_number=0
        sleep 3s
        cd
    fi
    trilium=n
}