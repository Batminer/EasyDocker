#!/bin/bash

installUFW()
{
   if [[ "$CFG_REQUIREMENT_UFW" == "true" ]]; then
    	ISUFW=$( (ufw status ) 2>&1 )
		if [[ "$ISUFW" == *"command not found"* ]]; then
            echo ""
            echo "##########################################"
            echo "###     Install UFW Firewall           ###"
            echo "##########################################"
            echo ""
            echo "---- $menu_number. Installing using linux package installer"
            echo ""

            result=$(yes | sudo -u $easydockeruser apt-get install ufw )
            checkSuccess "Installing UFW package"

            result=$(sudo -u $easydockeruser ufw allow 22)
            checkSuccess "Enabling Port 22 through the firewall"
            result=$(sudo -u $easydockeruser ufw allow ssh)
            checkSuccess "Enabling SSH through the firewall"

            while true; do
                isQuestion "Do you want to keep port 22 (SSH) open? (y/n): "
                read -rp "" UFWSSH
                if [[ "$UFWSSH" =~ ^[yYnN]$ ]]; then
                    break
                fi
                isNotice "Please provide a valid input (y/n)."
            done

            if [[ "$UFWSSH" == [nN] ]]; then
                result=$(sudo -u $easydockeruser ufw deny 22)
                checkSuccess "Enabling Port 22 through the firewall"
                result=$(sudo -u $easydockeruser ufw deny ssh)
                checkSuccess "Enabling SSH through the firewall"
            fi

            result=$(sudo -u $easydockeruser ufw --force enable)
            checkSuccess "Enabling UFW Firewall"

            result=$(yes | sudo -u $easydockeruser ufw logging off)
            checkSuccess "Disabling UFW Firewall Logging"
            
            # UFW Logging rules : https://linuxhandbook.com/ufw-logs/
            while true; do
                isQuestion "Do you want to enable logging (Potential privacy issue)? (y/n): "
                read -rp "" UFWP
                if [[ "$UFWP" =~ ^[yYnN]$ ]]; then
                    break
                fi
                isNotice "Please provide a valid input (y/n)."
            done            
            
            if [[ "$UFWP" == [yY] ]]; then
                result=$(yes | sudo -u $easydockeruser ufw logging medium)
                checkSuccess "Enabling UFW Firewall Logging"	
            fi

            echo ""
            echo "---- $menu_number. UFW has been installed, you can use ufw status to see the status"
            echo "    NOTE - The UFW-Docker package is NEEDED as docker ignores the UFW Firewall"
            echo ""       
            cd
        fi
    fi
}

installUFWDocker()
{
    if [[ "$CFG_REQUIREMENT_UFWD" == "true" ]]; then
		if [[ "$ISUFWD" == *"command not found"* ]]; then
            echo ""
            echo "##########################################"
            echo "###     Install UFW-Docker             ###"
            echo "##########################################"
            echo ""
            echo "---- $menu_number. Installing using linux package installer"
            echo ""

            result=$(sudo -u $easydockeruser wget -O /usr/local/bin/ufw-docker https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker)
            checkSuccess "Downloading UFW Docker installation files"

            result=$(sudo -u $easydockeruser chmod +x /usr/local/bin/ufw-docker)
            checkSuccess "Setting permissions for install files"

            result=$(sudo -u $easydockeruser ufw-docker install)
            checkSuccess "Installing UFW Docker"

            result=$(sudo -u $easydockeruser systemctl restart ufw)
            checkSuccess "Restarting UFW Firewall service"

            echo "---- $menu_number. UFW-Docker has been installed, you can use ufw-docker to see the available commands"
            echo ""
            echo ""       
            cd
        fi
    fi
}