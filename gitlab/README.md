# GitLab Homelab

## Map of Content
- [[#Prerequisites|Prerequisites]]
- [[#Setup Instruction|Setup Instruction]]

## Prerequisites
- Docker
- Docker Compose
- Git

## Setup Instruction
1. Create secrets by running `setup-secrets.sh`
2. Edit /etc/hosts file to add the following lines:
```
127.0.0.1   gitlab.example.com
127.0.0.1   registry.example.com
127.0.0.1   maildev.example.com
127.0.0.1   ldap.example.com
```
3. Run `docker compose up -d`
4. Create in /etc/docker/certs.d/ fodlers for:
- `gitlab.example.com`
- r`egistry.example.com`
5. Copy generated certificates to `/etc/docker/certs.d/` folders:
- `gitlab.example.com`
```bash
mkdir -p /etc/docker/certs.d/gitlab.example.com
cd /etc/docker/certs.d/gitlab.example.com
docker cp gitlab:/etc/gitlab/ssl/ca.crt ca.crt
docker cp gitlab:/etc/gitlab/ssl/cert.pem client.cert
docker cp gitlab:/etc/gitlab/ssl/key.pem client.key
```
- `registry.example.com`
```bash
mkdir -p /etc/docker/certs.d/registry.example.com
cd /etc/docker/certs.d/registry.example.com
docker cp gitlab:/etc/gitlab/ssl/ca.crt ca.crt
docker cp gitlab:/etc/gitlab/ssl/cert.pem client.cert
docker cp gitlab:/etc/gitlab/ssl/key.pem client.key
```
6. Reload docker daemon:
```bash
sudo systemctl reload docker
```
7. Edit `/etc/gitlab-runner/config.toml` of `gitlab-runner`
```
concurrent = 6
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner"
  url = "https://gitlab.example.com"
  id = 1
  token = "your-token"
  tls-ca-file = "/etc/gitlab-runner/certs/ca.pem"
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "docker:24.0.5-cli"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
    network_mtu = 0
    network_mode = "gitlab_net"
```

## Validation
### Maildev
1. Open `gitlab-rails console`
```bash
docker exec -it gitlab gitlab-rails console
```
2. Send test email
```ruby
Notify.test_email('root@example.com', 'Test Subject', 'Test Body').deliver_now
```
3. Check maildev web interface, there should be a new email for `root@example.com`

