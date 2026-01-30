# GitLab URL
external_url 'https://gitlab.example.com'

gitlab_rails['gitlab_shell_ssh_port'] = 22

# ssl
letsencrypt['enable'] = false
nginx['redirect_http_to_https'] = true
nginx['ssl_certificate'] = "/etc/gitlab/ssl/cert.pem"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/key.pem"
nginx['ssl_client_certificate'] = "/etc/gitlab/ssl/ca.pem"

# SMTP Integration
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "maildev.example.com"
gitlab_rails['smtp_openssl_verify_mode'] = 'peer'
gitlab_rails['smtp_port'] = 1025
gitlab_rails['smtp_ssl'] = true
gitlab_rails['smtp_enable_starttls_auto'] = false

# Container Registry settings
registry_external_url 'https://registry.example.com'
### Settings used by GitLab application
gitlab_rails['registry_path'] = "/var/opt/gitlab/gitlab-rails/shared/registry"

### Settings used by Registry application
registry['enable'] = true
## Registry NGINX
# Below you can find settings that are exclusive to "Registry NGINX"
registry_nginx['enable'] = true
registry_nginx['ssl_certificate'] = "/etc/gitlab/ssl/cert.pem"
registry_nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/key.pem"

### Git LFS
gitlab_rails['lfs_enabled'] = true

# Ldap Integration
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = {
    'main' => {
        'label' => 'TechNova Corp LDAP',
        'host' => 'openldap',
        'port' => 1636,
        'uid' => 'uid',
        'bind_dn' => 'uid=gitlab,ou=services,dc=ldap,dc=example,dc=com',
        'base' => 'ou=users,dc=ldap,dc=example,dc=com',
        'group_base' => 'ou=groups,dc=ldap,dc=example,dc=com',
        'admin_group' => 'admins',
        'password' => 'gitlab',
        'encryption' => 'simple_tls',
        'verify_certificates' => true,
        'tls_options' => {
            'ca_file' => '/etc/gitlab/ssl/ca.pem'
        },
        'timeout' => 10,
        'active_directory' => false,
        'user_filter' => '',
        'lowercase_usernames' => false,
        'allow_username_or_email_login' => true,
        'block_auto_created_users' => false,
        'attributes' => {
            'username' => ['uid'],
            'email' => ['mail'],
            'name' => 'displayName',
            'first_name' => 'givenName',
            'last_name' => 'sn'
        }
    }
}
gitlab_rails['ldap_sync_worker_cron'] = "0 */12 * * *"
gitlab_rails['ldap_group_sync_worker_cron'] = "0 */2 * * *"
