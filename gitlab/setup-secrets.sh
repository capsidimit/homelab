#!/bin/bash

# GitLab Secrets Setup Script
# This script helps create the required secret files for GitLab Docker setup

echo "GitLab Docker Secrets Setup"
echo "============================"

SECRETS_DIR="secrets"
REQUIRED_SECRETS=(
    "ldap_admin_password.txt"
)

# Create secrets directory if it doesn't exist
mkdir -p "$SECRETS_DIR"

# Create each secret file
for secret in "${REQUIRED_SECRETS[@]}"; do
    secret_path="$SECRETS_DIR/$secret"
    
    if [ -f "$secret_path" ]; then
        echo "Secret file already exists: $secret"
        read -p "Overwrite? (y/N) " overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            continue
        fi
    fi
    
    case "$secret" in
        "ldap_admin_password.txt")
            description="LDAP admin password"
            ;;
        *)
            description="Secret for $secret"
            ;;
    esac
    
    echo
    echo "Enter password for: $description"
    read -s -p "Password: " password
    echo
    
    echo "$password" > "$secret_path"
    chmod 640 "$secret_path"
    echo "Created: $secret"
done

echo
echo "Setup complete!"
echo "Secret files are located in: $SECRETS_DIR"
echo "Make sure to add these files to your backup and secure them properly."
