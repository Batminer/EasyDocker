#!/bin/bash

mainMenu()
{
	# Enable input
	stty echo
	
	while true; do
		echo ""
		echo "#####################################"
		echo "###         Install Menu          ###"
		echo "#####################################"
		echo ""
		isOption "s. System Apps"
		isOption "p. Privacy Apps"
		isOption "u. User Apps"
		isOption "o. Old/Unfinished"
		echo ""
		echo "#####################################"
		echo "###    Backup/Restore/Migrate     ###"
		echo "#####################################"
		echo ""
		isOption "b. Backup"
		isOption "r. Restore"
		isOption "m. Migrate"
		echo ""
		echo "#####################################"
		echo "###          Tools/Other          ###"
		echo "#####################################"
		echo ""
		isOption "d. Database"
		isOption "c. Configs"
		isOption "l. Logs"
		isOption "t. Tools"
		echo ""
		isOption "i. Initialize"
		isOption "x. Exit"
		echo ""
		isQuestion "What is your choice: "
		read -rp "" choice

		case $choice in
			s)
				showInstallInstructions;

				echo ""				
				echo "#####################################"
				echo "###          System Apps          ###"
				echo "#####################################"
				echo ""
				isOptionMenu "Fail2Ban - Connection Security (u/s/r/i): "
				read -rp "" fail2ban
				isOptionMenu "Traefik - Reverse Proxy (u/s/r/i): "
				read -rp "" traefik
				isOptionMenu "Wireguard Easy - VPN Server (u/s/r/i): "
				read -rp "" wireguard
				isOptionMenu "Adguard & Unbound - DNS Server (u/s/r/i): "
				read -rp "" adguard
				isOptionMenu "Portainer - Docker Management (u/s/r/i): "
				read -rp "" portainer
				isOptionMenu "Watchtower - Docker Updater (u/s/r/i): "
				read -rp "" watchtower
				isOptionMenu "Dashy - Docker Dashboard (u/s/r/i): "
				read -rp "" dashy
				
   				startInstall;
				
				;;
			p)
				showInstallInstructions;

				echo ""
				echo "#####################################"
				echo "###          Privacy Apps         ###"
				echo "#####################################"
				echo ""
				isOptionMenu "Searxng - Search Engine (u/s/r/i): "
				read -rp "" searxng
				isOptionMenu "Speedtest - Internet Testing (u/s/r/i): "
				read -rp "" speedtest
				isOptionMenu "IPInfo - Show IP Address  (u/s/r/i): "
				read -rp "" ipinfo
				isOptionMenu "Trilium - Note Manager (u/s/r/i): "
				read -rp "" trilium
				isOptionMenu "Vaultwarden - Password Manager (u/s/r/i): "
				read -rp "" vaultwarden
				isOptionMenu "Actual - Money Budgetting (u/s/r/i): "
				read -rp "" actual

    			startInstall;
				
				;;
			u)
				showInstallInstructions;

				echo ""
				echo "#####################################"
				echo "###           User Apps           ###"
				echo "#####################################"
				echo ""
				isOptionMenu "Jitsi Meet - Video Conferencing (u/s/r/i): "
				read -rp "" jitsimeet
				isOptionMenu "OwnCloud - File & Document Cloud (u/s/r/i): "
				read -rp "" owncloud
				isOptionMenu "Killbill - Payment Processing (u/s/r/i): "
				read -rp "" killbill
				isOptionMenu "Mattermost - Collaboration Platform (u/s/r/i): "
				read -rp "" mattermost
				isOptionMenu "Kimai - Online-Timetracker (u/s/r/i): "
				read -rp "" kimai
				
    			startInstall;

				;;
			o)
				showInstallInstructions;

				echo ""
				echo "#####################################"
				echo "###         Old/Unfinished        ###"
				echo "#####################################"
				echo ""
				isOptionMenu "PRIVACY - Mailcow - Mail Server (u/s/r/i): "
				read -rp "" mailcow
				isOptionMenu "USER - Tiledesk - Live Chat Platform (u/s/r/i): "
				read -rp "" tiledesk
				isOptionMenu "USER - GitLab - DevOps Platform (u/s/r/i): "
				read -rp "" gitlab
				isOptionMenu "USER - Akaunting - Invoicing Solution (u/s/r/i): "
				read -rp "" akaunting
				isOptionMenu "USER - Cozy - Cloud Platfrom (u/s/r/i): "
				read -rp "" cozy
				isOptionMenu "SYSTEM - Pi-Hole - DNS Server (u/s/r/i): "
				read -rp "" pihole
				isOptionMenu "SYSTEM - Duplicati - Backups (u/s/r/i): "
				read -rp "" duplicati
				isOptionMenu "SYSTEM - Caddy - Reverse Proxy (u/s/r/i): "
				read -rp "" caddy

				startInstall

				;;
			b)

				echo ""
				echo "#####################################"
				echo "###             Backup            ###"
				echo "#####################################"
				echo ""
				isOptionMenu "Single App Backup - Docker Container Folder (y/n): "
				read -rp "" backupsingle
				isOptionMenu "Full Backup - Docker Folder (y/n): "
				read -rp "" backupfull

				startOther

				;;
			r)
				echo ""
				echo "#####################################"
				echo "###            Restore            ###"
				echo "#####################################"
				echo ""
   				echo "Please select 'l' for local restore."
    			echo "Please select 'r' for remote restore."
				echo ""
				echo ""
				isOptionMenu "Single Restore - App (l/r): "
				read -rp "" restoresingle
				isOptionMenu "Full Restore - Docker Folder (l/r): "
				read -rp "" restorefull

				startOther;

				;;
			m)
				echo ""
				echo "#####################################"
				echo "###            Migrate            ###"
				echo "#####################################"
				echo ""
   				echo "Please make sure your migration connection settings are setup"
				echo ""
				isOptionMenu "Migrate Single Docker App (y/n): "
				read -rp "" migratesingle
				isOptionMenu "Migrate Full Docker Folder (y/n): "
				read -rp "" migratefull

				startOther;

				;;
			d)
				echo ""
				echo "#####################################"
				echo "###            Database           ###"
				echo "#####################################"
				echo ""
				isOptionMenu "View Database Tables & Data? (y/n): "
				read -rp "" toollistalltables
				isOptionMenu "List all apps database? (y/n): "
				read -rp "" toollistallapps
				isOptionMenu "List all installed apps? (y/n): "
				read -rp "" toollistinstalledapps
				isOptionMenu "Update database with installed apps? (y/n): "
				read -rp "" toolupdatedb
				isOptionMenu "Empty a Database Tables? (y/n): "
				read -rp "" toolemptytable
				isOptionMenu "Delete database file? (y/n): "
				read -rp "" tooldeletedb

				

				startOther;

				;;

			t)
				echo ""
				echo "#####################################"
				echo "###             Tools             ###"
				echo "#####################################"
				echo ""
				isOptionMenu "Reset EasyDocker Git Folder (y/n): "
				read -rp "" toolsresetgit
				isOptionMenu "Start Pre-Installation (y/n): "
				read -rp "" toolstartpreinstallation
				isOptionMenu "Start Crontab Installation? (y/n): "
				read -rp "" toolsstartcrontabsetup
				isOptionMenu "Start/Restart all docker containers? (y/n): "
				read -rp "" toolrestartcontainers
				isOptionMenu "Stop all docker containers? (y/n): "
				read -rp "" toolstopcontainers
				isOptionMenu "Remove Docker Manager User from this PC? (y/n): "
				read -rp "" toolsremovedockermanageruser
				isOptionMenu "Install Docker Manager User on this PC? (y/n): "
				read -rp "" toolsinstalldockermanageruser
				isOptionMenu "Install Remote SSH Keys? (y/n): "
				read -rp "" toolinstallremotesshlist
				isOptionMenu "Install Crontab? (y/n): "
				read -rp "" toolinstallcrontab
				isOptionMenu "Install SSH Scanning into Crontab? (y/n): "
				read -rp "" toolinstallcrontabssh

				startOther;

				;;
			c)

				viewConfigs;

				;;
			l)
				viewLogs;

				;;
			i)
				endStart;

				;;
			x)
				exitScript;

				;;
			*)
				echo "Invalid choice. Please select a valid option."
				;;
		esac
	done
}