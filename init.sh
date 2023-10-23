#!/bin/bash

param1="$1"

sudo_user_name=easydocker
hostname="virtualmin"
repo_url="https://github.com/OpenSourceWebstar/EasyDocker"
sshd_config="/etc/ssh/sshd_config"
sudo_bashrc="/home/$sudo_user_name/.bashrc"

# Directories
docker_dir="/docker"
containers_dir="$docker_dir/containers/"
ssl_dir="$docker_dir/ssl/"
ssh_dir="$docker_dir/ssh/"
logs_dir="$docker_dir/logs/"
configs_dir="$docker_dir/configs/"
backup_dir="$docker_dir/backups"
backup_full_dir="$backup_dir/full"
backup_single_dir="$backup_dir/single"
backup_install_dir="$backup_dir/install"
restore_dir="$docker_dir/restore"
restore_full_dir="$restore_dir/full"
restore_single_dir="$restore_dir/single"
migrate_dir="$docker_dir/migrate"
migrate_full_dir="$migrate_dir/full"
migrate_single_dir="$migrate_dir/single"
# Install Scripts
script_dir="$docker_dir/install"
install_configs_dir="$script_dir/configs/"
install_containers_dir="$script_dir/containers/"
install_scripts_dir="$script_dir/scripts/"

initializeScript()
{
	# Check if script is run as root
	if [[ $EUID -ne 0 ]]; then
		echo "This script must be run as root."
		exit 1
	fi
	echo ""
	echo "####################################################"
	echo "###              Initial Questions               ###"
	echo "####################################################"
	echo ""
	read -p "Do you want to install Virtualmin? (Y/n): " install_virtualmin
	if [[ "$install_virtualmin" == [yY] ]]; then
		while true; do
			# Prompt the user for the domain they want to use with Virtualmin
			read -p "What domain would you like to use with Virtualmin (e.g test.com) " domain_virtualmin

			# Check if the input contains "@" and is not empty
			if [[ "$domain_virtualmin" =~ .+@.+\..+ ]]; then
				break  # Valid format, exit the loop
			else
				echo "Invalid domain format. Please enter a valid domain in the format 'user@domain.com'."
			fi
		done
	fi

	echo ""
	echo "####################################################"
	echo "###          Updating Operating System           ###"
	echo "####################################################"
	echo ""
	sudo apt-get update
	sudo apt-get dist-upgrade -y

    if [ -n "$hostname" ] && [ -n "$domain_virtualmin" ]; then
        if ! grep -q "127.0.1.1\s$hostname.$domain_virtualmin $hostname" /etc/hosts; then
            sudo sed -i "1i 127.0.1.1\t$domain_virtualmin $hostname" /etc/hosts
            echo "Hostname and FQDN added to the top of /etc/hosts."
        else
            echo "The entries for '$domain_virtualmin' and '$hostname' already exist in /etc/hosts. No changes made."
        fi
    fi

	if [[ "$install_virtualmin" == [yY] ]]; then
		local current_hostname=$(cat /etc/hostname)
		if [ "$current_hostname" != "$hostname" ]; then
			echo "$hostname" | sudo tee /etc/hostname > /dev/null
			echo "Hostname updated to '$hostname'."
			echo ""
			echo "The system will reboot to apply the changes."
			echo "Please rerun this script after reboot..."
			sleep 5
			reboot
		else
			echo "Hostname is already set to '$hostname'. No update needed."
		fi
	fi
	echo "SUCCESS: OS Updated"

	echo ""
	echo "####################################################"
	echo "###         Installing Prerequired Apps          ###"
	echo "####################################################"
	echo ""
	sudo apt-get install sudo git zip curl sshpass dos2unix apt-transport-https ca-certificates software-properties-common uidmap -y
	echo "SUCCESS: Prerequisite apps installed."

	echo ""
	echo "####################################################"
	echo "###           Creating User Accounts             ###"
	echo "####################################################"
	echo ""
	if id "$sudo_user_name" &>/dev/null; then
		echo "SUCCESS: User $sudo_user_name already exists."
	else
		# If the user doesn't exist, create the user
		useradd -s /bin/bash -d "/home/$sudo_user_name" -m -G sudo "$sudo_user_name"
		echo "Setting password for $sudo_user_name user."
		passwd $sudo_user_name
		echo "SUCCESS: User $sudo_user_name created successfully."
	fi

	echo ""
	echo "####################################################"
	echo "###        EasyDocker Folder Creation            ###"
	echo "####################################################"
	echo ""
	# Setup folder structure
	folders=("$docker_dir" "$containers_dir" "$ssl_dir" "$ssh_dir" "$logs_dir" "$configs_dir" "$backup_dir" "$backup_full_dir" "$backup_single_dir" "$backup_install_dir" "$restore_dir" "$restore_full_dir" "$restore_single_dir" "$migrate_dir" "$migrate_full_dir" "$migrate_single_dir"  "$script_dir")
	for folder in "${folders[@]}"; do
		if [ ! -d "$folder" ]; then
			sudo mkdir "$folder"
			sudo chown $sudo_user_name:$sudo_user_name "$folder"
			sudo chmod 750 "$folder"
			echo "SUCCESS: Folder '$folder' created."
		#else
			#echo "Folder '$folder' already exists."
		fi
	done
	echo "SUCCESS: All folders have been created."

	echo ""
	echo "####################################################"
	echo "###      	       Git Clone / Update              ###"
	echo "####################################################"
	echo ""
	# Git Clone and Update
	# Check if it's a Git repository by checking if it's inside a Git working tree
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		echo "A Git repository is already cloned in '$script_dir'."
		echo "NOTICE: Please run the easydocker command to update the repository."
	else
		echo "NOTICE: No Git repository found. Cloning Git Repository."
		# Clone the Git repository into the specified directory
		runuser -l  $sudo_user_name -c "git clone -q "$repo_url" "$script_dir""
		echo "SUCCESS: Git repository cloned into '$script_dir'."
	fi

	echo ""
	echo "####################################################"
	echo "###      	     Custom Command Setup              ###"
	echo "####################################################"
	echo ""
	# Custom command check
	if ! grep -q "easydocker" $sudo_bashrc; then
		echo "NOTICE: Custom command 'easydocker' is not installed. Installing..."
		echo 'easydocker() {' >> $sudo_bashrc
		echo '  if [ -f "/docker/install/start.sh" ]; then' >> $sudo_bashrc
		echo '    local path="$PWD"' >> $sudo_bashrc
		echo '    cd /docker/install/ && chmod 0755 /docker/install/* && ./start.sh  "" "" "$path"' >> $sudo_bashrc
		echo '  else' >> $sudo_bashrc
		echo '    sudo sh -c "rm -rf /docker/install && cd ~ && rm -rf init.sh && apt-get install wget -y && wget -O init.sh https://raw.githubusercontent.com/OpenSourceWebstar/EasyDocker/main/init.sh && chmod 0755 init.sh && ./init.sh run"' >> $sudo_bashrc
		echo '  fi' >> $sudo_bashrc
		echo '}' >> $sudo_bashrc
		source $sudo_bashrc
	else
		echo "SUCCESS: easydocker command already installed."
	fi

	if [[ "$install_virtualmin" == [yY] ]]; then
		echo ""
		echo "####################################################"
		echo "###      	      Virtualmin Install               ###"
		echo "####################################################"
		echo ""

		# Download the Virtualmin auto-install script
		cd / && wget https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh

		# Make the script executable
		chmod +x virtualmin-install.sh

		# Run the Virtualmin auto-install script with sudo
		sudo ./virtualmin-install.sh

		while true; do
			# Prompt the user for the new password
			read -s -p "Enter the new password for the 'root' Webmin user: " webmin_password
			echo

			# Check if the password is not empty and meets the minimum length requirement (e.g., 8 characters)
			if [ -n "$webmin_password" ] && [ ${#webmin_password} -ge 8 ]; then
				# Change the Webmin 'root' user password
				sudo /usr/share/webmin/changepass.pl /etc/webmin root "$webmin_password"
				sudo systemctl stop webmin
				echo "Password changed and Webmin restarted successfully."
				break
			else
				echo "Password is too short or empty. Please provide a password with at least 8 characters."
			fi
		done
	else
		echo "Virtualmin installation not required."
	fi

	echo ""
	echo "####################################################"
	echo "###      EasyDocker Initilization Complete       ###"
	echo "####################################################"
	echo ""
	echo "You can now use the 'easydocker' command under the $sudo_user_name."
	echo ""
	echo "If you have installed Virtualmin, please run EasyDocker to finalize the setup."
	echo "Otherwise run 'sudo systemctl start'"
	echo ""
	echo "Thank you & Enjoy! <3"
	echo ""
	exit
}

if [ "$param1" == "run" ]; then
	initializeScript;
fi