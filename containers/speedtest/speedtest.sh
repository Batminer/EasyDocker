#!/bin/bash

# Category : privacy
# Description : LibreSpeed - Internet Speed Test (c/u/s/r/i):

installSpeedtest()
{
    local passedValue="$1"

    if [[ "$passedValue" == "install" ]]; then
        speedtest=i
    fi

    if [[ "$speedtest" == *[cCtTuUsSrRiI]* ]]; then
        setupConfigToContainer --silent speedtest;
        local app_name=$CFG_SPEEDTEST_APP_NAME
		setupInstallVariables $app_name;
    fi

    if [[ "$speedtest" == *[cC]* ]]; then
        editAppConfig $app_name;
    fi

	if [[ "$speedtest" == *[uU]* ]]; then
		uninstallApp $app_name;
	fi

	if [[ "$speedtest" == *[sS]* ]]; then
		shutdownApp $app_name;
	fi

	if [[ "$speedtest" == *[rR]* ]]; then
        if [[ $compose_setup == "default" ]]; then
		    dockerDownUpDefault $app_name;
        elif [[ $compose_setup == "app" ]]; then
            dockerDownUpAdditionalYML $app_name;
        fi
	fi

    if [[ "$speedtest" == *[iI]* ]]; then
        echo ""
        echo "##########################################"
        echo "###           Install $app_name"
        echo "##########################################"
        echo ""

        ((menu_number++))
        echo ""
        echo "---- $menu_number. Checking & Opening ports if required"
        echo ""

        checkAppPorts $app_name $port $port_2;
        
		((menu_number++))
        echo ""
        echo "---- $menu_number. Setting up install folder and config file for $app_name."
        echo ""

        setupConfigToContainer $app_name install;
        isSuccessful "Install folders and Config files have been setup for $app_name."

		((menu_number++))
        echo ""
        echo "---- $menu_number. Pulling a default $app_name docker-compose.yml file."
        echo ""

        if [[ $compose_setup == "default" ]]; then
		    setupComposeFileNoApp $app_name;
        elif [[ $compose_setup == "app" ]]; then
            setupComposeFileApp $app_name;
        fi

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
        echo "---- $menu_number. Adding $app_name to the Apps Database table."
        echo ""

		databaseInstallApp $app_name;

		((menu_number++))
        echo ""
        echo "---- $menu_number. You can find $app_name files at $containers_dir$app_name"
        echo ""
        echo "    You can now navigate to your $app_name service using any of the options below : "
        echo ""
        echo "    Public : https://$host_setup/"
        echo "    External : http://$public_ip:$port/"
        echo "    Local : http://$ip_setup:$port/"
        echo ""
		     
		menu_number=0
        sleep 3s
        cd
	fi
	speedtest=n
}
