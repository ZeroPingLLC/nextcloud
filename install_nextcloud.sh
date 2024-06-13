#!/bin/bash

############################################################
#                                                          #
#                  Nextcloud Installation                  #
#                                                          #
#                      Author: Kristian Gasic              #
#              Bereitgestellt von ZeroPing.sh              #
#                 Lizenz zur freien Verwendung             #
#                Bei Fragen: support@zeroping.sh           #
#                                                          #
############################################################

# Funktion zur Erfassung der Benutzereingaben
get_user_input() {
    read -p "Enter Nextcloud Username: " NEXTCLOUD_USER
    read -sp "Enter Nextcloud Password: " NEXTCLOUD_PASSWORD
    echo
    read -p "Enter MariaDB Username: " MARIADB_USER
    read -sp "Enter MariaDB Password: " MARIADB_PASSWORD
    echo
    read -p "Enter Subdomain (e.g., nextcloud.example.com): " SUBDOMAIN
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo "Detected IP Address: $IP_ADDRESS"
    DB_NAME="nextcloud"
}

# Funktion zur Erstellung des Installationsprotokolls
create_install_log() {
    cat << EOF > install.log
Nextcloud Installation Log
===========================
Nextcloud Username: ${NEXTCLOUD_USER}
Nextcloud Password: [REDACTED]
MariaDB Username: ${MARIADB_USER}
MariaDB Password: [REDACTED]
Database Name: ${DB_NAME}
IP Address: ${IP_ADDRESS}
Subdomain: ${SUBDOMAIN}
===========================
EOF
}

# Funktion zur Installation von Nextcloud
install_nextcloud() {
    echo "Updating system packages..."
    sudo apt update && sudo apt upgrade -y || { echo "Failed to update packages"; exit 1; }

    echo "Installing necessary packages..."
    sudo apt install apache2 mariadb-server software-properties-common unzip -y || { echo "Failed to install necessary packages"; exit 1; }
    sudo add-apt-repository ppa:ondrej/php -y || { echo "Failed to add PHP repository"; exit 1; }
    sudo apt update || { echo "Failed to update package list"; exit 1; }
    sudo apt install php8.1 libapache2-mod-php8.1 php8.1-gd php8.1-mysql php8.1-curl php8.1-mbstring php8.1-intl php8.1-imagick php8.1-xml php8.1-zip php8.1-opcache php8.1-redis redis-server -y || { echo "Failed to install PHP packages"; exit 1; }

    echo "Starting and securing MariaDB..."
    sudo systemctl start mariadb || { echo "Failed to start MariaDB"; exit 1; }
    sudo mysql -u root -p <<EOF
UPDATE mysql.user SET authentication_string=null WHERE User='root';
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MARIADB_PASSWORD}';
CREATE DATABASE ${DB_NAME};
CREATE USER '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${MARIADB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    echo "Configuring PHP Opcache and upload settings..."
    sudo mkdir -p /etc/php/8.1/apache2/conf.d
    sudo bash -c 'cat > /etc/php/8.1/apache2/conf.d/10-opcache.ini <<EOF
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=1
opcache.save_comments=1
EOF'
    sudo bash -c 'cat > /etc/php/8.1/apache2/conf.d/20-upload.ini <<EOF
upload_max_filesize=5G
post_max_size=5G
memory_limit=512M
max_execution_time=3600
max_input_time=3600
EOF'

    echo "Configuring Redis..."
    if [ -f /etc/redis/redis.conf ]; then
        sudo sed -i "s/^# *port .*/port 6379/" /etc/redis/redis.conf
        sudo sed -i "s/^# *bind 127.0.0.1 ::1/bind 127.0.0.1 ::1/" /etc/redis/redis.conf
        sudo sed -i "s/^# *maxmemory <bytes>/maxmemory 256mb/" /etc/redis/redis.conf
        sudo sed -i "s/^# *maxmemory-policy noeviction/maxmemory-policy allkeys-lru/" /etc/redis/redis.conf
        sudo systemctl restart redis-server || { echo "Failed to restart Redis server"; exit 1; }
    else
        echo "Redis configuration file not found. Skipping Redis configuration."
    fi

    echo "Downloading and setting up Nextcloud..."
    wget https://download.nextcloud.com/server/releases/latest.zip || { echo "Failed to download Nextcloud"; exit 1; }
    unzip latest.zip || { echo "Failed to unzip Nextcloud"; exit 1; }
    sudo mv nextcloud /var/www/ || { echo "Failed to move Nextcloud to /var/www"; exit 1; }
    sudo chown -R www-data:www-data /var/www/nextcloud || { echo "Failed to change ownership of /var/www/nextcloud"; exit 1; }
    sudo chmod -R 755 /var/www/nextcloud || { echo "Failed to change permissions of /var/www/nextcloud"; exit 1; }

    echo "Configuring Apache..."
    sudo bash -c "cat > /etc/apache2/sites-available/nextcloud.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@${SUBDOMAIN}
    DocumentRoot /var/www/nextcloud/
    ServerName ${SUBDOMAIN}

    <Directory /var/www/nextcloud/>
        Options +FollowSymlinks
        AllowOverride All

        <IfModule mod_dav.c>
            Dav off
        </IfModule>

        SetEnv HOME /var/www/nextcloud
        SetEnv HTTP_HOME /var/www/nextcloud
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF"
    sudo a2ensite nextcloud.conf || { echo "Failed to enable nextcloud site"; exit 1; }
    sudo a2dissite 000-default.conf || { echo "Failed to disable default site"; exit 1; }
    sudo a2enmod rewrite headers env dir mime || { echo "Failed to enable Apache modules"; exit 1; }
    sudo systemctl reload apache2 || { echo "Failed to reload Apache"; exit 1; }

    echo "Installing and configuring firewall..."
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 3306/tcp  # MariaDB
    sudo ufw allow 6379/tcp  # Redis
    sudo ufw --force enable || { echo "Failed to enable UFW"; exit 1; }

    echo "Nextcloud installation complete. Please finish the setup through the web interface."
    create_install_log
    echo "Installation log created: install.log"
}

# Funktion zur Installation von SSL
install_ssl() {
    read -p "Enter Subdomain (e.g., nextcloud.example.com): " SUBDOMAIN
    sudo apt install certbot python3-certbot-apache -y || { echo "Failed to install Certbot"; exit 1; }
    sudo certbot --apache -d ${SUBDOMAIN} || { echo "Failed to obtain SSL certificate"; exit 1; }
    sudo systemctl reload apache2 || { echo "Failed to reload Apache after SSL installation"; exit 1; }
    echo "SSL installation complete."
}

# Hauptlogik des Skripts
clear
echo "Nextcloud Installation Script"

if [ -d "/var/www/nextcloud" ]; then
    echo "Nextcloud is already installed."
    read -p "Do you want to install SSL with certbot? (y/n): " install_ssl_option
    if [[ "$install_ssl_option" =~ ^[Yy]$ ]]; then
        install_ssl
    else
        echo "SSL installation skipped."
    fi
else
    echo "Please provide the following information:"
    get_user_input
    install_nextcloud
    read -p "Do you want to install SSL with certbot? (y/n): " install_ssl_option
    if [[ "$install_ssl_option" =~ ^[Yy]$ ]]; then
        install_ssl
    else
        echo "SSL installation skipped."
    fi
fi
