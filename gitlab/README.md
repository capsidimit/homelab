# GitLab Docker Setup with Secrets

This setup uses Docker secrets for secure password management instead of hardcoded values.

## Setup Instructions

### 1. Environment Variables
Copy `.env.example` to `.env` and update with your values:
```bash
cp .env.example .env
```

### 2. Create Secret Files
Create the following files in the `secrets/` directory with your actual passwords:

- `secrets/ldap_bind_password.txt` - LDAP bind password for GitLab authentication
- `secrets/ldap_admin_password.txt` - LDAP admin password
- `secrets/ldap_config_password.txt` - LDAP config password  
- `secrets/gitlab_root_password.txt` - GitLab initial root password

Each file should contain only the password (no extra whitespace or newlines).

### 3. File Permissions
Set appropriate permissions for secret files:
```bash
chmod 600 secrets/*.txt
```

### 4. Start Services
```bash
docker-compose up -d
```

## Security Notes

- The `secrets/` directory is included in `.gitignore` to prevent accidental commits
- Secret files are mounted as Docker secrets and only available to the specific containers
- Environment variables in `.env` should also be kept secure and not committed

## Migration from Hardcoded Passwords

If migrating from the previous setup with hardcoded passwords:
1. Create the secret files with your existing passwords
2. The containers will automatically use the new secret files on next restart
3. Remove any hardcoded passwords from your configuration

## ToDo

- [ ] Add ssl certs generation for services from specified CA and private files