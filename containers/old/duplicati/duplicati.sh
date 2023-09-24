#!/bin/bash

# Description : Duplicati - Backups (c/u/s/r/i):

installDuplicati()
{
    setupInstallVariables $app_name;

    if [[ "$duplicati" == *[cC]* ]]; then
        editAppConfig $app_name;
    fi

    if [[ "$duplicati" == *[uU]* ]]; then
        uninstallApp $app_name;
    fi

    if [[ "$duplicati" == *[sS]* ]]; then
        shutdownApp;
    fi

    if [[ "$duplicati" == *[rR]* ]]; then
        dockerDownUpDefault $app_name;
    fi

    if [[ "$duplicati" == *[iI]* ]]; then
        echo ""
        echo "##########################################"
        echo "###           Install $app_name"
        echo "##########################################"
        echo ""
    
		((menu_number++))
        echo ""
        echo "---- $menu_number. Checking custom DNS entry and IP for setup"
        echo ""

		setupIPsAndHostnames $app_name;
		
		((menu_number++))
        echo ""
        echo "---- $menu_number. Pulling a default $app_name docker-compose.yml file."
        echo ""

		setupComposeFileNoApp;
		whitelistApp $app_name false;

		((menu_number++))
        echo ""
        echo "---- $menu_number. Updating file permissions before starting."
        echo ""

		fixPermissionsBeforeStart;

		((menu_number++))
        echo ""
        echo "---- $menu_number. Running the docker-compose.yml to install and start $$app_name"
        echo ""

		dockerDownUpDefault $app_name;

        ((menu_number++))
        echo ""
        echo "---- $menu_number. Opening ports if required"
        echo ""

        openAppPorts $app_name;

		((menu_number++))
		echo ""
        echo "---- $menu_number. Adding $app_name to the Apps Database table."
        echo ""

		databaseInstallApp;

		((menu_number++))
        echo ""
        echo "---- $menu_number. You can find $app_name files at $install_dir$app_name"
        echo ""
        echo "    You can now navigate to your new service using one of the options below : "
        echo ""
        echo "    Public : https://$host_setup/"
        echo "    External : http://$public_ip:$port/"
        echo "    Local : http://$ip_setup:$port/"
        echo ""

		menu_number=0
        sleep 3s
        cd
    fi
    duplicati=n
}