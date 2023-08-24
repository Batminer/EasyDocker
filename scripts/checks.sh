#!/bin/bash

 checkUpdates()
 {
	if [[ $CFG_REQUIREMENT_UPDATES == "true" ]]; then
		echo ""
		echo "#####################################"
		echo "###      Checking for Updates     ###"
		echo "#####################################"
		echo ""

		cd "$script_dir" || { echo "Error: Cannot navigate to the repository directory"; exit 1; }

		result=$(git config core.fileMode false)
		checkSuccess "Update Git to ignore changes in file permissions"

		# Check if there are uncommitted changes
		if [[ $(git status --porcelain) ]]; then
			isNotice "There are uncommitted changes in the repository."
			isQuestion "Do you want to discard these changes and update the repository? (y/n): "
			read -p "" customupdatesfound
			if [[ $customupdatesfound == [yY] ]]; then
				backupFolder="backup_$(date +"%Y%m%d%H%M%S")"

				gitFolderResetAndBackup;

				isSuccessful "Custom changes have been discarded successfully"
				isSuccessful "Restarting EasyDocker"
				exit 0 ; easydocker
			else
				isNotice "Custom changes will be kept, continuing..."
				checkRequirements;
			fi
		fi

		result=$(git remote update)
		checkSuccess "Checking for changes in the remote repository"

		# Check if the local branch is behind the remote branch
		if git status -uno | grep -q "Your branch is behind"; then
			isNotice "Updates found."
			result=$(git pull)
			checkSuccess "Pulling latest updates"
			isSuccessful "Files are now up to date."
		else
			isSuccessful "Files are all up to date."
		fi

		checkRequirements;
	else
		checkRequirements;
	fi
 }

 checkRequirements()
 {  
	echo ""
	echo "#####################################"
	echo "###      Checking Requirements    ###"
	echo "#####################################"
	echo ""
	isNotice "Requirements are about to be installed."
	isNotice "Edit the config_requirements if you want to disable anything before starting."
	echo ""

	if [[ $CFG_REQUIREMENT_ROOT == "true" ]]; then
		# Check if script is run as root
		if [[ $EUID -ne 0 ]]; then
			echo "This script must be run as root."
			exit 1
		else
			isSuccessful "Script ran under root user."
		fi
	fi

	if [[ $CFG_REQUIREMENT_COMMAND == "true" ]]; then
		# Custom command check
		if grep -q "easydocker" ~/.bashrc; then
			isSuccessful "Custom command 'easydocker' installed."
		else
			checkSuccess "No custom command installed, did you run the init.sh first?"
			echo ""
			isNotice "Please run the following command:"
			isNotice "cd ~ && chmod 0755 init.sh && ./init.sh run && source ~/.bashrc && easydocker"
			echo ""
			isNotice "Exiting...."
			exit
		fi
	fi

	ISACT=$( (sudo systemctl is-active docker ) 2>&1 )
	ISCOMP=$( (docker-compose -v ) 2>&1 )
	ISUFW=$( (ufw status ) 2>&1 )
	ISUFWD=$( (ufw-docker) 2>&1 )
	ISCRON=$( (crontab -l) 2>&1 )

	if [[ $CFG_REQUIREMENT_CONFIG == "true" ]]; then
		checkConfigFilesExist;
		checkConfigFilesEdited;
	fi

	if [[ $CFG_REQUIREMENT_DATABASE == "true" ]]; then
		### Database file
		if [ -f "$base_dir/$db_file" ] ; then
			isSuccessful "Installed Apps Database file found"
		else
			isNotice "Database file not found"
			((preinstallneeded++)) 
		fi
	fi

	if [[ $CFG_REQUIREMENT_DOCKER_CE == "true" ]]; then
		### Docker CE
		if [[ "$ISACT" == "active" ]]; then
			isSuccessful "Docker appears to be installed and running."
		else
			isNotice "Docker does not appear to be installed."
			((preinstallneeded++)) 
		fi
	fi

	if [[ $CFG_REQUIREMENT_DOCKER_COMPOSE == "true" ]]; then
		### Docker Compose
		if [[ "$ISCOMP" != *"command not found"* ]]; then
			isSuccessful "Docker-compose appears to be installed."
		else
			isNotice "Docker-compose does not appear to be installed."
			((preinstallneeded++)) 
		fi
	fi
	
	if [[ $CFG_REQUIREMENT_UFW == "true" ]]; then
		### UFW Firewall
		if [[ "$ISUFW" != *"command not found"* ]]; then
			isSuccessful "UFW Firewall appears to be installed."
		else
			isNotice "UFW Firewall does not appear to be installed."
			((preinstallneeded++)) 
		fi
	fi

	if [[ $CFG_REQUIREMENT_UFWD == "true" ]]; then
		### UFW Docker
		if [[ "$ISUFWD" != *"command not found"* ]]; then
			isSuccessful "UFW-Docker Fix appears to be installed."
		else
			isNotice "UFW-Docker Fix does not appear to be installed."
			((preinstallneeded++)) 
		fi
	fi
	

	if [[ $CFG_REQUIREMENT_MANAGER == "true" ]]; then
		### Docker Manager User Creation
		if userExists "$CFG_DOCKER_MANAGER_USER"; then
			isSuccessful "The Docker Manager User appears to be setup."
		else
			isNotice "The Docker Manager User is not setup."
			((preinstallneeded++)) 
		fi
	fi


	if [[ $CFG_REQUIREMENT_SSLCERTS == "true" ]]; then
		### SSL Certificates
		domains=()
		for domain_num in {1..9}; do
			domain="CFG_DOMAIN_$domain_num"
			domain_value=$(grep "^$domain=" $configs_dir$config_file_general | cut -d '=' -f 2 | tr -d '[:space:]')
			if [ -n "$domain_value" ]; then
				domains+=("$domain_value")
			fi
		done

		missing_ssl=()
		for domain_value in "${domains[@]}"; do
			key_file="$ssl_dir/${domain_value}.key"
			crt_file="$ssl_dir/${domain_value}.crt"

			if [ -f "$key_file" ] || [ -f "$crt_file" ]; then
				isSuccessful "Certificate for domain $domain_value installed."
			else
				missing_ssl+=("$domain_value")
				isNotice "Certificate for domain $domain_value not found."
			fi
		done

		if [ ${#missing_ssl[@]} -eq 0 ]; then
			isSuccessful "SSL certificates are setup for all domains."
			SkipSSLInstall=true
		else
			isNotice "An SSL certificate is missing for the following domain: ${missing_ssl[*]}"
			((preinstallneeded++)) 
		fi
	fi


	if [[ $CFG_REQUIREMENT_SWAPFILE == "true" ]]; then
		### Swap file
		if [ -f "$swap_file" ]; then
			isSuccessful "Swapfile appears to be installed."
		else
			isNotice "Swapfile does not appears to be installed."
			((preinstallneeded++)) 
		fi
	fi

	if [[ $CFG_REQUIREMENT_CRONTAB == "true" ]]; then
		### Crontab
		if [[ "$ISCRON" != *"command not found"* ]]; then
			isSuccessful "Crontab is successfully setup."
		elif ! crontab -l -u root | grep -q "cron is set up for root"; then
			isNotice "Crontab not installed."
			((preinstallneeded++)) 
		else
			isNotice "Crontab not installed."
			((preinstallneeded++)) 
		fi
	fi

	if [[ $CFG_REQUIREMENT_SSHREMOTE == "true" ]]; then
		### Custom SSH Remote Install
		# Check if the hosts line is empty or not found in the config file
		ssh_hosts_line=$(grep '^CFG_IPS_SSH_SETUP=' $configs_dir$config_file_general)
		if [ -n "$ssh_hosts_line" ]; then
			ssh_hosts=${ssh_hosts_line#*=}
			ip_found=0
			# Split the comma-separated IP addresses into an array
			IFS=',' read -ra ip_addresses <<< "$ssh_hosts"
			# Loop through the IP addresses
			for ip in "${ip_addresses[@]}"; do
				ip_found=1
			done

			if [ "$ip_found" -eq 0 ]; then
				isSuccessful "No for Remote SSH Install IP has been found to setup"
			else
				isSuccessful "Remote SSH Install IP(s) have been found to setup"
				setupSSHRemoteKeys=true
				((preinstallneeded++)) 
			fi
		else
			isSuccessful "No hosts found in the config file."
		fi
	fi
	
	if [[ $CFG_REQUIREMENT_PASSWORDS == "true" ]]; then
		### Password randomizer
		pass_found=0
		files_with_password=()

		for config_file in "$configs_dir"/*; do
			if [ -f "$config_file" ] && grep -q "RANDOMIZEDPASSWORD" "$config_file"; then
				files_with_password+=("$config_file")
				pass_found=1
			fi
		done

		if [ "$pass_found" -eq 0 ]; then
			checkSuccess "No passwords found to change."
		else
			echo ""
			checkSuccess "Passwords found to change in the following files:"
			printf '%s\n' "${files_with_password[@]}"
			((preinstallneeded++)) 
		fi
	fi

	if [[ "$preinstallneeded" -ne 0 ]]; then
		startPreInstall;
	fi

	startScan;
	mainMenu;
} 