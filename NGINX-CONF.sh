#!/bin/bash
REPO_URL="https://github.com/davidnet-net/NGINX-CONF"
LOG_FILE="/var/log/nginx-update.log"

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "I need sudo."
    exit 1
fi

echo "Starting NGINX configuration update process..." >> $LOG_FILE

# Stop NGINX service
sudo systemctl stop nginx
echo "Stopped NGINX service." >> $LOG_FILE
cd /etc/nginx/

# Backup and remove old configurations if they exist
if [ -d "NGINX_CONF_OLD" ]; then
    rm -rf "NGINX_CONF_OLD"
    echo "Removed old NGINX_CONF_OLD directory." >> $LOG_FILE
fi
if [ -d "NGINX_CONF" ]; then
    rm -rf "NGINX_CONF"
    echo "Backed up and removed old NGINX_CONF directory." >> $LOG_FILE
fi
if [ -d "sites-enabled" ]; then
    rm -rf "sites-enabled"
    echo "Removed old sites-enabled directory." >> $LOG_FILE
fi

# Clone the new NGINX configuration from GitHub
mkdir NGINX_CONF
cd NGINX_CONF
git clone $REPO_URL .
echo "Cloned new NGINX configuration from GitHub." >> $LOG_FILE

# Restore the 'sites-enabled' directory
cp -r sites-enabled ../sites-enabled
echo "Restored sites-enabled directory." >> $LOG_FILE

cd /var/
if [ -d "www" ]; then
    rm -rf "www"
    echo "Removed old www directory." >> $LOG_FILE
fi
cp -r /etc/nginx/NGINX_CONF/www/ www/
echo "Copied new www directory from configuration." >> $LOG_FILE

cd /etc/nginx/NGINX_CONF/

# Test the NGINX configuration
if sudo nginx -t; then
    echo "NGINX configuration is valid." >> $LOG_FILE

    # Check and renew certificates using certbot
    echo "Checking SSL certificates..." >> $LOG_FILE
    
    # Extract domain names from the NGINX configuration files that need SSL (listen 443 ssl)
    domains=$(grep -l 'listen 443 ssl' /etc/nginx/NGINX_CONF/sites-enabled/* | \
              xargs -I {} grep -oP 'server_name\s+\K([a-zA-Z0-9.-]+)' {} | sort -u)

    if [ -z "$domains" ]; then
        echo "No domains with SSL (listen 443 ssl) found in the configuration files." >> $LOG_FILE
    else
        for domain in $domains; do
            echo "Checking SSL certificates for $domain..." >> $LOG_FILE

            # Check if SSL certificates are already issued for the domain
            if sudo certbot certificates | grep -q "$domain"; then
                echo "SSL certificates for $domain found. Checking if renewal is needed..." >> $LOG_FILE

                # Renew certificates if they are expiring soon (within 30 days)
                if sudo certbot certificates | grep -qE "$domain.*Expiry Date:.*(30 days|less)"; then
                    echo "Certs for $domain are about to expire. Renewing..." >> $LOG_FILE
                    sudo certbot renew
                else
                    echo "Certs for $domain are up-to-date." >> $LOG_FILE
                fi
            else
                echo "No SSL certificates found for $domain. Obtaining new certificates..." >> $LOG_FILE
                sudo certbot --nginx -d "$domain" # You can pass multiple domains here if needed
            fi
        done
    fi

    # Restart NGINX service
    echo "Restarting NGINX..." >> $LOG_FILE
    sudo systemctl start nginx
    echo "NGINX restarted successfully." >> $LOG_FILE
else
    if [ -d "NGINX_CONF_OLD" ]; then
        echo "NGINX configuration test failed. Restoring old configuration..." >> $LOG_FILE
        rm -rf /etc/nginx/NGINX_CONF
        mv /etc/nginx/NGINX_CONF_OLD /etc/nginx/NGINX_CONF
        cp -r /etc/nginx/NGINX_CONF/sites-enabled /etc/nginx/sites-enabled
        echo "Restored old NGINX configuration." >> $LOG_FILE
        sudo systemctl start nginx
        echo "NGINX restarted with the old configuration." >> $LOG_FILE
    else
        echo "Nginx exploded!"
        exit 1
    fi
fi

cd /etc/nginx/

# Cleanup
cp -r NGINX_CONF NGINX_CONF_OLD
if [ -d "NGINX_CONF" ]; then
    rm -rf "NGINX_CONF"
    echo "Cleaned up new! " >> $LOG_FILE
fi
