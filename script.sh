#!/bin/bash

set -e  # Exit immediately if a command fails
set -o pipefail  # Catch errors in piped commands

set -e
set -o pipefail

install_tor() {
    if ! command -v tor &> /dev/null; then
        echo "Installing Tor..."
        sudo apt update && sudo apt install -y tor
    else
        echo "Tor is already installed."
    fi
}
install_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo "Installing Nginx via Tor..."
        torify sudo apt install -y nginx || { echo "Nginx installation failed!"; exit 1; }
    else
        echo "Nginx is already installed."
    fi
}
install_go() {
    if ! command -v go &> /dev/null; then
        echo "Installing Go via Tor..."
        torify sudo apt install -y golang || { echo "Go installation failed!"; exit 1; }
    else
        echo "Go is already installed."
    fi
}
install_tor &
install_nginx &
install_go &
wait

# Step 4: Configure Tor Hidden Service
configure_torrc() {
    TORRC_PATH="/etc/tor/torrc"
    if grep -q "#HiddenServiceDir" "$TORRC_PATH" && grep -q "#HiddenServicePort" "$TORRC_PATH"; then
        echo "Configuring Hidden Service in torrc..."
        sudo sed -i 's/#HiddenServiceDir/HiddenServiceDir/' $TORRC_PATH
        sudo sed -i 's/#HiddenServicePort/HiddenServicePort/' $TORRC_PATH
    else
        echo "Hidden Service settings are already configured."
    fi
}
configure_torrc

# Step 5: Restart Tor Service with Validation
restart_tor() {
    echo "Restarting Tor..."
    sudo systemctl restart tor
    sleep 3
    
    if ! systemctl is-active --quiet tor; then
        echo "Tor failed to restart. Please check logs."
        exit 1
    fi
    echo "Tor restarted successfully."
}
restart_tor

# Step 6: Retrieve Hidden Service URL
onion_address=$(sudo cat /var/lib/tor/hidden_service/hostname 2>/dev/null || echo "Hidden service not available yet")
echo "Generated Hidden Service URL: $onion_address"

# Step 7: Setup OnionGen
setup_oniongen() {
    ONION_DATA_PATH="$HOME/Desktop/onion_data"
    mkdir -p "$ONION_DATA_PATH"
    echo "onion_data folder is set up at: $ONION_DATA_PATH"
    
    ONIONGEN_PATH="$ONION_DATA_PATH/oniongen"
    if [ ! -d "$ONIONGEN_PATH" ]; then
        echo "Downloading oniongen..."
        torify git clone https://github.com/rdkr/oniongen.git "$ONIONGEN_PATH" || { echo "Failed to download oniongen."; exit 1; }
    else
        echo "oniongen already exists."
    fi
    
    cd "$ONIONGEN_PATH"
}

# Step 8: Generate Custom Onion Address
generate_onion_address() {
    echo "Generating custom onion address for: $manual_url"
    onion_address=$(go run main.go "^$manual_url" 1 2>/dev/null || echo "")
    
    if [[ -z "$onion_address" ]]; then
        echo "Failed to generate onion address. Try again."
        exit 1
    fi
    
    echo "Generated onion address: $onion_address"
    read -p "Do you want to keep this onion address? (y/n): " keep_choice
    if [[ "$keep_choice" =~ ^[Yy]$ ]]; then
        echo "Copy the keys from $ONIONGEN_PATH/$onion_address to /var/lib/tor/hidden_service/."
    else
        echo "Generating a new onion address..."
        rm -rf "$ONIONGEN_PATH/$onion_address"
        generate_onion_address
    fi
}

# Step 9: Ask User for Manual URL Configuration
read -p "Do you want to configure a manual URL? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    read -p "Enter the manual URL: " manual_url
    echo "Configured manual URL: $manual_url"
    setup_oniongen
    generate_onion_address
else
    echo "Using automatically generated hidden service URL: $onion_address"
fi

# Final Step: Restart Tor After Key Update
restart_tor
