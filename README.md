# Hidden Service Setup Script

This script helps you set up a Tor hidden service with Nginx and generates an Onion address. It also allows for configuring a manual URL or automatically generating one. The script handles the installation of necessary packages, such as Tor, Nginx, and Go, and facilitates downloading the `oniongen` tool for generating Onion addresses.

## Features

- Installs Tor and Nginx (if not already installed)
- Configures Tor for hidden services by uncommenting necessary lines in `torrc`
- Allows users to configure a manual URL for the hidden service or generates a random one
- Downloads and sets up the `oniongen` tool to generate a custom Onion address
- Provides an option to keep the generated Onion address or regenerate it if necessary
- Prompts users to copy the generated keys to the Tor hidden service directory

## Prerequisites

Before running this script, ensure you have the following:

- A Linux-based system (Ubuntu or Debian-based preferred)
- A basic understanding of using the terminal
- Internet connection to download required packages and tools

## Installation

1. Clone the repository or download the script:

   ```bash
   git clone https://github.com/yourusername/hidden-service-setup.git
   cd hidden-service-setup
   ```

2. Make the script executable:

   ```bash
   chmod +x hidden_service_setup.sh
   ```

3. Run the script:

   ```bash
   ./hidden_service_setup.sh
   ```

## Usage

1. The script will first check if Tor and Nginx are installed on your system. If they are not, it will install them.
2. The script will automatically modify the `torrc` file to enable hidden services by uncommenting the necessary lines (`HiddenServiceDir` and `HiddenServicePort`).
3. It will then attempt to restart Tor. If Tor fails to restart, it will prompt you to try again.
4. After that, it will display the generated Onion address and ask whether you want to configure a manual URL.
5. If you choose to configure a manual URL, the script will prompt you for the URL and proceed with generating the Onion address using the `oniongen` tool.
6. Finally, it will guide you to copy the generated keys to the `/var/lib/tor/hidden_service/` directory and restart the Tor service.

## Script Workflow

1. **Install Tor**: If not already installed, Tor will be installed using the default package manager.
2. **Install Nginx**: If not already installed, Nginx will be installed using `torify` to ensure the installation goes through the Tor network.
3. **Configure `torrc` file**: The script will uncomment the necessary lines to enable the hidden service functionality in Tor.
4. **Restart Tor**: Tor will be restarted to apply the changes.
5. **Generate or Configure Onion Address**: The script will generate an Onion address using `oniongen`. You can either accept the generated URL or provide a manual URL.
6. **Copy Keys to Tor Directory**: You will be instructed to copy the generated keys to the appropriate Tor hidden service directory.
7. **Restart Tor Service**: The script will restart Tor to apply all configurations.

## Troubleshooting

- If the script fails to restart Tor, you can manually restart the Tor service using the following command:

   ```bash
   sudo systemctl restart tor
   ```

- Ensure that your system's package manager is set up correctly to avoid installation issues with Tor and Nginx.

## Contributing

Feel free to fork the repository, submit issues, and create pull requests to improve the script.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
