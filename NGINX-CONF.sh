#!/bin/bash
REPO_URL="https://github.com/davidnet-net/NGINX-CONF"

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "I need sudo."
    exit 1
fi

echo "Renewing certs"
sudo certbot renew

echo "Starting NGINX configuration update process..."

# Stop NGINX service
systemctl stop nginx
echo "Stopped NGINX service."

# Backup current configuration
cd /etc/nginx/ || { echo "Failed to navigate to /etc/nginx/"; exit 1; }
if [ -d "NGINX_CONF" ]; then
    mv NGINX_CONF NGINX_CONF_OLD
    echo "Backed up current NGINX_CONF to NGINX_CONF_OLD."
fi

if [ -d "sites-enabled" ]; then
    mv sites-enabled sites-enabled.bak
    echo "Backed up sites-enabled to sites-enabled.bak."
fi

# Clone the new NGINX configuration from GitHub
mkdir -p NGINX_CONF
cd NGINX_CONF || { echo "Failed to navigate to NGINX_CONF"; exit 1; }
git clone "$REPO_URL" .
if [ $? -ne 0 ]; then
    echo "Failed to clone repository. Exiting."
    exit 1
fi
echo "Cloned new NGINX configuration from GitHub."

# Restore 'sites-enabled' directory
cp -r sites-enabled ../sites-enabled
echo "Restored sites-enabled directory."

# Update web directory
cd /var/ || { echo "Failed to navigate to /var/"; exit 1; }
if [ -d "www" ]; then
    rm -rf "www"
    echo "Removed old www directory."
fi
cp -r /etc/nginx/NGINX_CONF/www/ www/
echo "Copied new www directory from configuration."

# Test the NGINX configuration
if sudo nginx -t; then
    echo "NGINX configuration is valid."
    # Restart NGINX service
    echo "Restarting NGINX..."
    systemctl start nginx
    echo "NGINX restarted successfully."
else
    echo "NGINX configuration test failed. Restoring old configuration..."
    rm -rf /etc/nginx/NGINX_CONF
    mv /etc/nginx/NGINX_CONF_OLD /etc/nginx/NGINX_CONF
    mv /etc/nginx/sites-enabled.bak /etc/nginx/sites-enabled
    systemctl start nginx
    echo "NGINX restarted with the old configuration."
    exit 1
fi

# Cleanup
cd /etc/nginx/ || exit
rm -rf NGINX_CONF
echo "Cleaned up temporary files."
