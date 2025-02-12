#!/bin/bash

### **Step 1: Install Tor if not installed**
if ! command -v tor &> /dev/null
then
    echo "Tor not found, installing..."
    sudo apt update
    sudo apt install -y tor
else
    echo "Tor is already installed."
fi

### **Step 2: Install nginx if not installed using torify**
if ! command -v nginx &> /dev/null
then
    echo "nginx not found, installing using torify..."
    sudo torify apt install -y nginx
else
    echo "nginx is already installed."
fi

### **Step 3: Uncomment `HiddenServiceDir` and `HiddenServicePort` in the torrc file**
TORRC_PATH="/etc/tor/torrc"
if grep -q "#HiddenServiceDir" "$TORRC_PATH" && grep -q "#HiddenServicePort" "$TORRC_PATH"; then
    echo "Uncommenting HiddenServiceDir and HiddenServicePort in $TORRC_PATH..."
    sudo sed -i '/#HiddenServiceDir/s/^#//g' $TORRC_PATH
    sudo sed -i '/#HiddenServicePort/s/^#//g' $TORRC_PATH
else
    echo "HiddenServiceDir and HiddenServicePort are already uncommented."
fi

### **Step 4: Restart Tor**
echo "Restarting Tor..."
sudo systemctl restart tor
sleep 3  # Give it a moment to restart

while ! systemctl is-active --quiet tor; do
    echo "Tor failed to restart. Do you want to try again? (yes/no)"
    read -r response
    if [[ "$response" =~ ^[Yy](es)?$ ]]; then
        echo "Restarting Tor..."
        sudo systemctl restart tor
        sleep 3
    else
        echo "Exiting. Tor is not running."
        exit 1
    fi
done
echo "Tor restarted successfully."

### **Step 5: Check if user has permanent keys**
read -p "Do you already have a permanent onion service key? (y/n): " has_keys

if [[ "$has_keys" == "y" || "$has_keys" == "Y" ]]; then
    read -p "Enter the path to your onion service keys folder: " key_path
    if [ -d "$key_path" ]; then
        echo "Backing up existing keys..."
        sudo mv /var/lib/tor/hidden_service/hostname /var/lib/tor/hidden_service/hostname.bak
        sudo mv /var/lib/tor/hidden_service/hs_ed25519_public_key /var/lib/tor/hidden_service/hs_ed25519_public_key.bak
        sudo mv /var/lib/tor/hidden_service/hs_ed25519_secret_key /var/lib/tor/hidden_service/hs_ed25519_secret_key.bak

        echo "Copying new keys..."
        sudo cp -r "$key_path/." "/var/lib/tor/hidden_service/"
        sudo chown -R debian-tor:debian-tor /var/lib/tor/hidden_service/
        sudo chmod 700 /var/lib/tor/hidden_service/

        echo "Restarting Tor with the new keys..."
        sudo systemctl restart tor
        sleep 3

        custom_onion_address=$(sudo cat /var/lib/tor/hidden_service/hostname)
        echo "Your onion address is: $custom_onion_address"
        echo "Copy your website content to /var/www/html and it will serve on this onion address"
        exit 0
    else
        echo "Invalid path. Please make sure the folder exists and try again."
        exit 1
    fi
fi

### **Step 6: Generate a new onion address if user doesn't have permanent keys**
onion_address=$(sudo cat /var/lib/tor/hidden_service/hostname)
echo "Generated Onion Address: $onion_address"
echo "Copy your website content to /var/www/html and it will serve on this onion address"
# Ask if user wants to back up the automatically generated keys
read -p "Do you want to save a backup of auto generated onion service keys? (y/n): " backup_choice

if [[ "$backup_choice" == "y" || "$backup_choice" == "Y" ]]; then
    read -p "Enter the backup directory path: " backup_path
    mkdir -p "$backup_path"
    sudo cp /var/lib/tor/hidden_service/hostname "$backup_path/"
    sudo cp /var/lib/tor/hidden_service/hs_ed25519_public_key "$backup_path/"
    sudo cp /var/lib/tor/hidden_service/hs_ed25519_secret_key "$backup_path/"
    echo "Keys backed up to: $backup_path"
fi

# Ask if user wants to configure a manual URL
read -p "Do you want to configure a manual URL? (y/n): " choice

if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    read -p "Please enter the manual URL: " manual_url
    echo "You have configured the manual URL as: $manual_url"

    # Function to setup oniongen and generate a custom onion address
    setup_oniongen() {
        ONION_DATA_PATH="$HOME/Desktop/onion_data"
        if [ ! -d "$ONION_DATA_PATH" ]; then
            mkdir -p "$ONION_DATA_PATH"
        fi

        if ! command -v go &> /dev/null; then
            sudo apt update
            sudo torify apt install -y golang
        fi

        ONIONGEN_PATH="$HOME/Desktop/onion_data/oniongen"
        if [ ! -d "$ONIONGEN_PATH" ]; then
            sudo torify git clone https://github.com/rdkr/oniongen.git "$ONIONGEN_PATH"
            sudo chmod -R 777 "$ONIONGEN_PATH"
        fi

        cd "$ONIONGEN_PATH"
        generate_onion_address() {
            onion_address=$(go run main.go "^$manual_url" 1)
            echo "Generated onion address: $onion_address"
            echo "Copy your website content to /var/www/html and it will serve on this onion address"
            read -p "Do you want to keep this onion address? (y/n): " keep_choice
            if [[ "$keep_choice" == "y" || "$keep_choice" == "Y" ]]; then
                echo "Copying keys to Tor hidden service directory..."
                sudo mv /var/lib/tor/hidden_service/hostname /var/lib/tor/hidden_service/hostname.bak
                sudo mv /var/lib/tor/hidden_service/hs_ed25519_public_key /var/lib/tor/hidden_service/hs_ed25519_public_key.bak
                sudo mv /var/lib/tor/hidden_service/hs_ed25519_secret_key /var/lib/tor/hidden_service/hs_ed25519_secret_key.bak

                sudo cp -r "$ONIONGEN_PATH/$onion_address/." "/var/lib/tor/hidden_service/"
                sudo chown -R debian-tor:debian-tor /var/lib/tor/hidden_service/
                sudo chmod 700 /var/lib/tor/hidden_service/
                sudo systemctl restart tor
                custom_onion_address=$(sudo cat /var/lib/tor/hidden_service/hostname)
                echo "Custom Onion Address: $custom_onion_address"

                read -p "Do you want to save a backup of the onion service keys? (y/n): " backup_choice
                if [[ "$backup_choice" == "y" ]]; then
                    read -p "Enter the backup directory path: " backup_path
                    mkdir -p "$backup_path"
                    cp -r "$ONIONGEN_PATH/$onion_address/." "$backup_path/"
                    echo "Keys backed up to: $backup_path"
                fi
                echo "Setup complete!"
                echo "Copy your website content to /var/www/html and it will serve on this onion address"
            else
                rm -rf "$ONIONGEN_PATH/$onion_address"
                generate_onion_address
            fi
        }
        generate_onion_address
    }
    setup_oniongen
else
    echo "Using automatically generated onion address: $onion_address"
    echo "Copy your website content to /var/www/html and it will serve on this onion address"
fi
