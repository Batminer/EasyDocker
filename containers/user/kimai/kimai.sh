#!/bin/bash

# Description : Kimai - Online-Timetracker (c/u/s/r/i):

installKimai()
{
    setupInstallVariables $app_name;
	port=$CFG_KIMAI_PORT

    if [[ "$kimai" == *[cC]* ]]; then
        editAppConfig $app_name;
    fi

	if [[ "$kimai" == *[uU]* ]]; then
		uninstallApp $app_name;
	fi

	if [[ "$kimai" == *[sS]* ]]; then
		shutdownApp;
	fi

    if [[ "$kimai" == *[rR]* ]]; then
        dockerDownUpDefault $app_name;
    fi

    if [[ "$kimai" == *[iI]* ]]; then
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
        echo "---- $menu_number. Pulling a default Kimai docker-compose.yml file."
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
        echo "---- $menu_number. Running the docker-compose.yml to install and start Kimai"
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
	kimai=n
}