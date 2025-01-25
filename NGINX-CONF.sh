#!/bin/bash
REPO_URL="https://github.com/davidnet-net/NGINX-CONF"

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "I need sudo."
    exit 1
fi
echo "Renewing certs"sudo certbot renew

echo "Starting NGINX configuration update process..."
# Stop NGINX service
sudo systemctl stop nginx
echo "Stopped NGINX service."cd /etc/nginx/

# Backup and remove old configurations if they exist
if [ -d "NGINX_CONF_OLD" ]; then
    rm -rf "NGINX_CONF_OLD"
    echo "Removed old NGINX_CONF_OLD directory."fi
if [ -d "NGINX_CONF" ]; then
    rm -rf "NGINX_CONF"
    echo "Backed up and removed old NGINX_CONF directory."fi
if [ -d "sites-enabled" ]; then
    rm -rf "sites-enabled"
    echo "Removed old sites-enabled directory."fi

# Clone the new NGINX configuration from GitHub
mkdir NGINX_CONF
cd NGINX_CONF
git clone $REPO_URL .
echo "Cloned new NGINX configuration from GitHub."
# Restore the 'sites-enabled' directory
cp -r sites-enabled ../sites-enabled
echo "Restored sites-enabled directory."
cd /var/
if [ -d "www" ]; then
    rm -rf "www"
    echo "Removed old www directory."fi
cp -r /etc/nginx/NGINX_CONF/www/ www/
echo "Copied new www directory from configuration."
cd /etc/nginx/NGINX_CONF/

# Test the NGINX configuration
if sudo nginx -t; then
    echo "NGINX configuration is valid."
    # Restart NGINX service
    echo "Restarting NGINX..."    sudo systemctl start nginx
    echo "NGINX restarted successfully."else
    if [ -d "NGINX_CONF_OLD" ]; then
        echo "NGINX configuration test failed. Restoring old configuration..."        rm -rf /etc/nginx/NGINX_CONF
        mv /etc/nginx/NGINX_CONF_OLD /etc/nginx/NGINX_CONF
        cp -r /etc/nginx/NGINX_CONF/sites-enabled /etc/nginx/sites-enabled
        echo "Restored old NGINX configuration."        sudo systemctl start nginx
        echo "NGINX restarted with the old configuration."    else
        echo "Nginx exploded!"
        exit 1
    fi
fi

cd /etc/nginx/

# Cleanup
cp -r NGINX_CONF NGINX_CONF_OLD
if [ -d "NGINX_CONF" ]; then
    rm -rf "NGINX_CONF"
    echo "Cleaned up new! "fi
fi