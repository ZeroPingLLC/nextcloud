# Nextcloud Installation Script

This script automates the installation and configuration of Nextcloud on an Ubuntu 22.04 server. It includes the setup of Apache, MariaDB, PHP 8.1, Redis, and Opcache. Additionally, it offers the option to install SSL certificates using Certbot.

## Author

- **Kristian Gasic**
- Provided by **ZeroPing.sh**
- License: Free for use
- For support, contact: [support@zeroping.sh](mailto:support@zeroping.sh)

## Features

- Automated installation of Nextcloud and necessary dependencies.
- Configuration of MariaDB, PHP 8.1, Redis, and Opcache.
- Option to install SSL certificates using Certbot.
- Detection of existing Nextcloud installation and option to add SSL later.

## Prerequisites

- A fresh Ubuntu 22.04 server installation.
- Root or sudo access to the server.

## Usage

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ZeroPingLLC/nextcloud.git
   ```

2. **Navigate to the script directory:**
   ```bash
   cd nextcloud
   ```

3. **Make the script executable:**
   ```bash
   chmod +x install_nextcloud.sh
   ```

4. **Run the script:**
   ```bash
   sudo ./install_nextcloud.sh
   ```

5. **Follow the prompts:**
   - Enter the MariaDB username and password.
   - Enter the subdomain for your Nextcloud instance.

6. **Optional SSL Installation:**
   - If you choose not to install SSL during the initial setup, you can run the script again to add SSL later.

## Script Details

- **Function to gather user input:** Prompts the user for MariaDB credentials and the subdomain.
- **Function to create installation log:** Records the details of the installation, including the MariaDB password in plain text, for future reference.
- **Function to install Nextcloud:** Installs and configures Apache, MariaDB, PHP 8.1, Redis, and Opcache. Downloads and sets up Nextcloud.
- **Function to install SSL:** Optionally installs SSL certificates using Certbot.

## Notes

- Ensure your DNS settings point the subdomain to your server's IP address.
- The script checks for an existing Nextcloud installation and will only offer SSL installation if Nextcloud is already set up.

## Troubleshooting

- If you encounter issues, check the log files located at `/var/log/apache2/` for Apache errors.
- For MariaDB issues, ensure the database and user are created correctly.
- Verify firewall rules if you have connectivity issues.

For any questions or support, contact [support@zeroping.sh](mailto:support@zeroping.sh).
