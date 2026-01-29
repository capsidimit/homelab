#!/usr/bin/env pwsh

# GitLab Secrets Setup Script
# This script helps create the required secret files for GitLab Docker setup

Write-Host "GitLab Docker Secrets Setup" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

$secretsDir = "secrets"
$requiredSecrets = @(
    "ldap_admin_password.txt", 
    "ldap_gitlab_password.txt",
    "ldap_users_password.txt",
    "gitlab_root_password.txt"
)

# Create secrets directory if it doesn't exist
if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Path $secretsDir | Out-Null
    Write-Host "Created secrets directory" -ForegroundColor Yellow
}

# Create each secret file
foreach ($secret in $requiredSecrets) {
    $secretPath = Join-Path $secretsDir $secret
    
    if (Test-Path $secretPath) {
        Write-Host "Secret file already exists: $secret" -ForegroundColor Cyan
        $overwrite = Read-Host "Overwrite? (y/N)"
        if ($overwrite -ne "y" -and $overwrite -ne "Y") {
            continue
        }
    }
    
    $description = switch ($secret) {
        "ldap_admin_password.txt" { "LDAP admin password" }
        "ldap_gitlab_password.txt" { "LDAP gitlab password" }
        "ldap_users_password.txt" { "LDAP users password" }
        "gitlab_root_password.txt" { "GitLab initial root password" }
        default { "Secret for $secret" }
    }
    
    Write-Host "`nEnter password for: $description" -ForegroundColor Yellow
    $password = Read-Host -AsSecureString "Password"
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    
    $plainPassword | Out-File -FilePath $secretPath -NoNewline
    Write-Host "Created: $secret" -ForegroundColor Green
}

Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "Secret files are located in: $secretsDir" -ForegroundColor Yellow
Write-Host "Make sure to add these files to your backup and secure them properly." -ForegroundColor Red
