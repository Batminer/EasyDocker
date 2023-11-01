#!/bin/bash

# Category : system
# Description : Adguard & Unbound - DNS Server (c/u/s/r/i):

installAdguard()
{
    if [[ "$adguard" == *[cCtTuUsSrRiI]* ]]; then
        setupConfigToContainer silent adguard;
        local app_name=$CFG_ADGUARD_APP_NAME
    	setupInstallVariables $app_name;
    fi

    if [[ "$adguard" == *[cC]* ]]; then
        editAppConfig $app_name;
    fi

    if [[ "$adguard" == *[uU]* ]]; then
        uninstallApp $app_name;
    fi

    if [[ "$adguard" == *[sS]* ]]; then
        shutdownApp $app_name;
    fi

    if [[ "$adguard" == *[rR]* ]]; then
        dockerDownUp $app_name;
    fi

    if [[ "$adguard" == *[iI]* ]]; then
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

		local result=$(copyResource "$app_name" "unbound.conf" "unbound.conf" | sudo -u $sudo_user_name tee -a "$logs_dir/$docker_log_file" 2>&1)
		checkSuccess "Copying unbound.conf to containers folder."

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
        echo "---- $menu_number. Initial install started for $app_name"
        echo ""
        echo ""
		echo "    NOTICE : Setup is needed in order to get Adguard online"
        echo "    NOTICE : Below are the urls for the setup ONLY."
        echo "    NOTICE : You can press next x5 until the installation is complete."
        echo ""
        echo "    External : http://$public_ip:$usedport1/"
        echo "    Local : http://$ip_setup:$usedport1/"
        echo ""
        echo ""

        while true; do
            echo ""
            isNotice "Setup is now available, please follow the instructions above."
            echo ""
            isQuestion "Have you followed the instructions above? (y/n): "
            read -p "" adguard_instructions
            if [[ "$adguard_instructions" == 'y' || "$adguard_instructions" == 'Y' ]]; then
                break
            else
                isNotice "Please confirm the setup or provide a valid input."
            fi
        done

        result=$(sudo sed -i "s/address: 0.0.0.0:80/address: 0.0.0.0:${usedport2}/g" "$containers_dir$app_name/conf/AdGuardHome.yaml")
        checkSuccess "Changing port 80 to $usedport2 for Admin Panel"
        DockerDownUp "$app_name";


		((menu_number++))
        echo ""
        echo "---- $menu_number. Editing local variables for DNS server to $app_name"
        echo ""
        
        updateDNS;

		((menu_number++))
		echo ""
        echo "---- $menu_number. Adding $app_name to the Apps Database table."
        echo ""

		databaseInstallApp $app_name;

		((menu_number++))
        echo ""
        echo "---- $menu_number. You can find $app_name files at $containers_dir$app_name"
        echo ""
        echo "    You can now navigate to your $app_name service using any of the options below : "
        echo ""
        echo "    NOTICE : Below are the URLs for the admin panel to use after you have setup Adguard"
        echo ""
        echo "    Public : https://$host_setup/"
        echo "    External : http://$public_ip:$usedport2/"
        echo "    Local : http://$ip_setup:$usedport2/"
        echo ""

		menu_number=0
        sleep 3s
        cd
    fi
    adguard=n
}