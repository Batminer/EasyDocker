#!/bin/bash

# Category : old
# Description : Duplicati - Backups (c/u/s/r/i):

installDuplicati()
{
    passedValue="$1"

    if [[ "$passedValue" == "install" ]]; then
        duplicati=i
    fi

    if [[ "$duplicati" == *[cCtTuUsSrRiI]* ]]; then
        setupConfigToContainer duplicati;
        app_name=$CFG_DUPLICATI_APP_NAME
		setupInstallVariables $app_name;
    fi

    if [[ "$duplicati" == *[cC]* ]]; then
        editAppConfig $app_name;
    fi

    if [[ "$duplicati" == *[uU]* ]]; then
        uninstallApp $app_name;
    fi

    if [[ "$duplicati" == *[sS]* ]]; then
        shutdownApp $app_name;
    fi

    if [[ "$duplicati" == *[rR]* ]]; then
        if [[ $compose_setup == "default" ]]; then
		    dockerDownUpDefault $app_name;
        elif [[ $compose_setup == "app" ]]; then
            dockerDownUpAdditionalYML $app_name;
        fi
    fi

    if [[ "$duplicati" == *[iI]* ]]; then
        echo ""
        echo "##########################################"
        echo "###           Install $app_name"
        echo "##########################################"
        echo ""
		
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

		fixPermissionsBeforeStart;

		((menu_number++))
        echo ""
        echo "---- $menu_number. Running the docker-compose.yml to install and start $$app_name"
        echo ""

		whitelistAndStartApp $app_name;

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