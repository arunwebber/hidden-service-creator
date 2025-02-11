### **Step 1: Install tor if not installed**
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
### **Step 4: restart tor if not restarted tell user tor failed to restart and ask user want to try again to restart**
echo "Restarting Tor..."
sudo systemctl restart tor
sleep 3  # Give it a moment to restart

# Check if Tor is running
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
### **Step 5: Print the hidden service url and ask if user if he wants to configure a manual url
onion_address=$(sudo cat /var/lib/tor/hidden_service/hostname)
echo $onion_address
# Function to check and create onion_data folder and download oniongen if not present
setup_oniongen() {
    # Step 6: Check if the onion_data folder exists on the Desktop, if not, create it
    ONION_DATA_PATH="$HOME/Desktop/onion_data"
    if [ ! -d "$ONION_DATA_PATH" ]; then
        echo "onion_data folder not found, creating..."
        mkdir -p "$ONION_DATA_PATH"
    else
        echo "onion_data folder already exists."
    fi
    # Install Go if not installed
    if ! command -v go &> /dev/null; then
        echo "Go not found, installing..."
        sudo apt update
        sudo torify apt install -y golang
    else
        echo "Go is already installed."
    fi
    # Step 7: Download oniongen to the folder onion_data if not downloaded
    ONIONGEN_PATH="$HOME/Desktop/onion_data/oniongen"
    if [ ! -d "$ONIONGEN_PATH" ]; then
        echo "oniongen not found, downloading..."
        sudo torify git clone https://github.com/rdkr/oniongen.git "$ONIONGEN_PATH"
        
        # Set permissions to 777
        echo "Setting permissions to 777 for $ONIONGEN_PATH..."
        sudo chmod -R 777 "$ONIONGEN_PATH"
    else
        echo "oniongen already exists in $ONIONGEN_PATH"
    fi

        # Go to the oniongen folder
    cd "$ONIONGEN_PATH"

    # Function to generate the onion address
    generate_onion_address() {
        echo "Running Go with manual_url: $manual_url"
        onion_address=$(go run main.go "^$manual_url" 1)

        # Print the generated onion address
        echo "Generated onion address: $onion_address"

        # Ask the user if they want to keep this onion address
        read -p "Do you want to keep this onion address? (y/n): " keep_choice
        if [[ "$keep_choice" == "y" || "$keep_choice" == "Y" ]]; then
            echo "You have chosen to keep the onion address: $onion_address"
            # Instruct the user to copy the keys found in the folder to the onion folder
            echo "Please copy the keys found in the $ONIONGEN_PATH/$onion_address folder to the onion folder WHich is /var/lib/tor/hidden_service/."
            #sudo diff -qr "$ONIONGEN_PATH/$onion_address" "/var/lib/tor/hidden_service/"
            sudo mv /var/lib/tor/hidden_service/hostname /var/lib/tor/hidden_service/hostname.bak
            sudo mv /var/lib/tor/hidden_service/hs_ed25519_public_key /var/lib/tor/hidden_service/hs_ed25519_public_key.bak
            sudo mv /var/lib/tor/hidden_service/hs_ed25519_secret_key /var/lib/tor/hidden_service/hs_ed25519_secret_key.bak
            sudo cp -r "$ONIONGEN_PATH/$onion_address/." "/var/lib/tor/hidden_service/"
            sudo chown -R debian-tor:debian-tor /var/lib/tor/hidden_service/
            sudo chmod 700 /var/lib/tor/hidden_service/
            sudo systemctl restart tor
            custom_onion_address=$(sudo cat /var/lib/tor/hidden_service/hostname)
            echo "Custom Onion Address:$custom_onion_address"
            # Ask user if they want to save a backup of the keys
            read -p "Do you want to save a backup of the onion service keys in another location? (y/n): " backup_choice
            if [[ "$backup_choice" == "y" ]]; then
                read -p "Enter the backup directory path: " backup_path                
                # Ensure the directory exists
                mkdir -p "$backup_path"        
                # Copy keys to the backup location
                cp -r "$ONIONGEN_PATH/$onion_address/." "$backup_path/"                
                echo "Keys have been backed up to: $backup_path"
            fi
            echo "Setup complete!"
        else
            echo "You have chosen to generate a new onion address."
            echo "Removing the old folder: $ONIONGEN_PATH/$onion_address"
            rm -rf "$ONIONGEN_PATH/$onion_address"
            # Re-run the onion generation process
            generate_onion_address
        fi
    }
    generate_onion_address

}

# Ask the user if they want to configure a manual URL
read -p "Do you want to configure a manual URL? (y/n): " choice

# Check user's response
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    # Ask the user for the manual URL input
    read -p "Please enter the manual URL: " manual_url
    echo "You have configured the manual URL as: $manual_url"
    # Proceed with the setup
    setup_oniongen
else
    echo "Using the automatically generated hidden service URL: $onion_address"
fi
### **Step 8: Copy the Generated Keys to Hidden Service Directory**
### **Step 9: Restart the Tor Service**
