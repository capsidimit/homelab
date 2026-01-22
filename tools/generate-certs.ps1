#requires -Version 5.0

#region Logging functions
$script:GlobalLogLevel = if ($env:GLOBAL_LOG_LEVEL) { $env:GLOBAL_LOG_LEVEL } else { "INFO" }

$script:LogLevelValues = @{
    "ERROR" = 3
    "WARNING" = 4
    "INFO" = 6
    "SUCCESS" = 7
    "DEBUG" = 7
}

# Use PowerShell's built-in colors for better compatibility
# You can customize these colors by changing the values below or setting environment variables
# Available colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, 
# Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White
$script:LogDefaultColor = if ($env:LOG_DEFAULT_COLOR) { $env:LOG_DEFAULT_COLOR } else { "White" }
$script:LogErrorColor = if ($env:LOG_ERROR_COLOR) { $env:LOG_ERROR_COLOR } else { "Red" }
$script:LogInfoColor = if ($env:LOG_INFO_COLOR) { $env:LOG_INFO_COLOR } else { "Cyan" }
$script:LogSuccessColor = if ($env:LOG_SUCCESS_COLOR) { $env:LOG_SUCCESS_COLOR } else { "Green" }
$script:LogWarnColor = if ($env:LOG_WARN_COLOR) { $env:LOG_WARN_COLOR } else { "Yellow" }
$script:LogDebugColor = if ($env:LOG_DEBUG_COLOR) { $env:LOG_DEBUG_COLOR } else { "Blue" }

function Write-Log {
    param(
        [string]$LogText,
        [string]$LogLevel = "INFO",
        [string]$LogColor = $script:LogInfoColor
    )
    
    if (-not $LogLevel) { $LogLevel = "INFO" }
    if (-not $LogColor) { $LogColor = $script:LogInfoColor }
    
    if ($script:LogLevelValues[$script:GlobalLogLevel] -ge $script:LogLevelValues[$LogLevel]) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$LogLevel] $LogText" -ForegroundColor $LogColor
    }
}

function Write-LogInfo { Write-Log -LogText $args[0] }
function Write-LogSuccess { Write-Log -LogText $args[0] -LogLevel "SUCCESS" -LogColor $script:LogSuccessColor }
function Write-LogError { Write-Log -LogText $args[0] -LogLevel "ERROR" -LogColor $script:LogErrorColor }
function Write-LogWarning { Write-Log -LogText $args[0] -LogLevel "WARNING" -LogColor $script:LogWarnColor }
function Write-LogDebug { Write-Log -LogText $args[0] -LogLevel "DEBUG" -LogColor $script:LogDebugColor }
#endregion

#region Definitions of variables
$script:CAKey = if ($env:CA_KEY) { $env:CA_KEY } else { "ca-key.pem" }
$script:CACert = if ($env:CA_CERT) { $env:CA_CERT } else { "ca.pem" }
$script:CAExpire = if ($env:CA_EXPIRE) { $env:CA_EXPIRE } else { "60" }
$script:CASubject = if ($env:CA_SUBJECT) { $env:CA_SUBJECT } else { "test-ca" }

$script:SSLConfig = if ($env:SSL_CONFIG) { $env:SSL_CONFIG } else { "openssl.cnf" }
$script:SSLKey = if ($env:SSL_KEY) { $env:SSL_KEY } else { "key.pem" }
$script:SSLCsr = if ($env:SSL_CSR) { $env:SSL_CSR } else { "key.csr" }
$script:SSLCert = if ($env:SSL_CERT) { $env:SSL_CERT } else { "cert.pem" }
$script:SSLSize = if ($env:SSL_SIZE) { $env:SSL_SIZE } else { "2048" }
$script:SSLExpire = if ($env:SSL_EXPIRE) { $env:SSL_EXPIRE } else { "60" }
$script:SSLCertsDir = if ($env:SSL_CERTS_DIR) { $env:SSL_CERTS_DIR } else { "certs_$(Get-Date -Format 'yyyyMMdd')" }

$script:DryRun = if ($env:DRY_RUN) { [int]$env:DRY_RUN } else { 0 }
$script:Services = @()
$script:ServiceDomains = @()
$script:ServiceIPs = @()
#endregion

#region Help function
function Show-Usage {
    Write-Host "Generates certificates for specified services"
    Write-Host ""
    Write-Host "Usage: $($MyInvocation.ScriptName) [OPTIONS] service1@domain1,domain2:ip1,ip2 service2@domain1:ip1"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  Certificate Authority:"
    Write-Host "    -d|--certs-dir <path_to_certs_dir> - directory where all certificates will be stored. Default: $script:SSLCertsDir"
    Write-Host "    -k|--ca-key <path_to_ca_key_file> - file with .key extension of the Certificate Authority. Default: $script:CAKey"
    Write-Host "    -c|--ca-cert <path_to_ca_cert_file> - file with .crt extension of the Certificate Authority. Default: $script:CACert"
    Write-Host "    --ca-expire <days> - days for the Certificate Authority to expire. Default: $script:CAExpire"
    Write-Host "    --ca-subject <subject> - subject of the Certificate Authority. Default: $script:CASubject"
    Write-Host ""
    Write-Host "  Other Options:"
    Write-Host "    --log-level LOGLEVEL    Log level (default: $script:GlobalLogLevel)"
    Write-Host "    -h, --help              Display help information"
    Write-Host "    --dry-run               Dry run without generating certificates"
    Write-Host ""
    Write-Host "Service Format:"
    Write-Host "    service@domain1,domain2:ip1,ip2"
    Write-Host "    - service: service name (used as CN)"
    Write-Host "    - domain1,domain2: comma-separated domain names (optional)"
    Write-Host "    - ip1,ip2: comma-separated IP addresses (optional)"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "`t$($MyInvocation.ScriptName) --ca-key ~/certs/global/server.key --ca-cert ~/certs/global/server.crt `"web@web.example.com,api.example.com:192.168.1.10,10.0.0.1`" `"db@db.example.com`""
    
    exit 0
}
#endregion

#region Process arguments
function Parse-ServiceArgument {
    param([string]$Argument)
    
    if ($Argument -match '^[a-zA-Z0-9-]+@[a-zA-Z0-9.,-]+(:[a-zA-Z0-9.,-]+)?$') {
        # Parse service@domains:ips format
        $servicePart = $Argument.Split('@')[0]
        $domainsIpsPart = $Argument.Substring($Argument.IndexOf('@') + 1)
        
        $script:Services += $servicePart
        
        # Extract domains and IPs if present
        if ($domainsIpsPart -and $domainsIpsPart -ne $Argument) {
            # Split domains and IPs by colon
            if ($domainsIpsPart -match ':') {
                $domainsPart = $domainsIpsPart.Split(':')[0]
                $ipsPart = $domainsIpsPart.Substring($domainsIpsPart.IndexOf(':') + 1)
                
                # Parse domains (comma-separated)
                if ($domainsPart) {
                    $domainsArray = $domainsPart -split ','
                    $script:ServiceDomains += ($domainsArray -join ',')
                } else {
                    $script:ServiceDomains += ""
                }
                
                # Parse IPs (comma-separated)
                if ($ipsPart) {
                    $ipsArray = $ipsPart -split ','
                    $script:ServiceIPs += ($ipsArray -join ',')
                } else {
                    $script:ServiceIPs += ""
                }
            } else {
                # Only domains, no IPs
                if ($domainsIpsPart) {
                    $domainsArray = $domainsIpsPart -split ','
                    $script:ServiceDomains += ($domainsArray -join ',')
                } else {
                    $script:ServiceDomains += ""
                }
                $script:ServiceIPs += ""
            }
        } else {
            # No @ symbol, just service name
            $script:ServiceDomains += ""
            $script:ServiceIPs += ""
        }
        return $true
    } else {
        return $false
    }
}

# Parse command line arguments
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    
    switch -Regex ($arg) {
        '^(-k|--ca-key)$' {
            if ($i + 1 -lt $args.Count) {
                $script:CAKey = $args[$i + 1]
                $i++
            } else {
                Write-LogError "Missing value for $arg"
                exit 1
            }
        }
        '^(-c|--ca-cert)$' {
            if ($i + 1 -lt $args.Count) {
                $script:CACert = $args[$i + 1]
                $i++
            } else {
                Write-LogError "Missing value for $arg"
                exit 1
            }
        }
        '^--ca-expire$' {
            if ($i + 1 -lt $args.Count) {
                $script:CAExpire = $args[$i + 1]
                $i++
            } else {
                Write-LogError "Missing value for $arg"
                exit 1
            }
        }
        '^--ca-subject$' {
            if ($i + 1 -lt $args.Count) {
                $script:CASubject = $args[$i + 1]
                $i++
            } else {
                Write-LogError "Missing value for $arg"
                exit 1
            }
        }
        '^(-d|--certs-dir)$' {
            if ($i + 1 -lt $args.Count) {
                $script:SSLCertsDir = $args[$i + 1]
                $i++
            } else {
                Write-LogError "Missing value for $arg"
                exit 1
            }
        }
        '^--dry-run$' {
            $script:DryRun = 1
        }
        '^--log-level$' {
            if ($i + 1 -lt $args.Count) {
                $logLevel = $args[$i + 1]
                if (-not $script:LogLevelValues.ContainsKey($logLevel)) {
                    Write-LogError "Invalid value of log level expected one of [$($script:LogLevelValues.Keys -join ', ')], got: `"$logLevel`""
                    exit 1
                }
                $script:GlobalLogLevel = $logLevel
                $i++
            } else {
                Write-LogError "Missing value for $arg"
                exit 1
            }
        }
        '^(-h|--help)$' {
            Show-Usage
        }
        default {
            if (-not (Parse-ServiceArgument -Argument $arg)) {
                Write-LogError "Error: Invalid format in argument '$arg'. Expected 'service@domain1,domain2:ip1,ip2' or 'service@domain'."
                exit 1
            }
        }
    }
}
#endregion

Write-Host "--> Working directory"

$CWD = (Get-Location).Path
$BaseDir = Join-Path $CWD $script:SSLCertsDir

Write-LogDebug "Creating directory `"$BaseDir`" for certificates"
if ($script:DryRun -eq 0) {
    try {
        New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
    } catch {
        Write-LogError "Failed to create directory: $($_.Exception.Message)"
        exit 1
    }
}

Write-LogDebug "Changing directory to `"$BaseDir`""
if ($script:DryRun -eq 0) {
    try {
        Set-Location $BaseDir
    } catch {
        Write-LogError "Failed to change directory: $($_.Exception.Message)"
        exit 1
    }
}
Write-Host ""

Write-Host "--> Certificate Authority"

if (Test-Path $script:CAKey) {
    Write-LogInfo "Using existing CA Key $script:CAKey"
} else {
    Write-LogInfo "Generating new CA key $script:CAKey"
    if ($script:DryRun -eq 0) {
        try {
            & openssl genrsa -out $script:CAKey 2048
            if ($LASTEXITCODE -ne 0) { throw "OpenSSL command failed" }
        } catch {
            Write-LogError "Failed to generate CA key: $($_.Exception.Message)"
            exit 1
        }
    }
}

if (Test-Path $script:CACert) {
    Write-LogInfo "Using existing CA Certificate $script:CACert"
} else {
    Write-LogInfo "Generating new CA Certificate $script:CACert"
    if ($script:DryRun -eq 0) {
        try {
            & openssl req -x509 -new -nodes `
                -key $script:CAKey `
                -days $script:CAExpire `
                -out $script:CACert `
                -subj "/CN=$script:CASubject"
            if ($LASTEXITCODE -ne 0) { throw "OpenSSL command failed" }
        } catch {
            Write-LogError "Failed to generate CA certificate: $($_.Exception.Message)"
            exit 1
        }
    }
}
Write-Host ""

Write-Host "--> Processing services and generating certificates"
for ($i = 0; $i -lt $script:Services.Count; $i++) {
    $service = $script:Services[$i]
    $domains = $script:ServiceDomains[$i]
    $ips = $script:ServiceIPs[$i]
    
    $serviceDir = Join-Path $BaseDir $service
    Write-LogDebug "Creating directory `"$serviceDir`" for service `"$service`" certificates"
    if ($script:DryRun -eq 0) {
        try {
            New-Item -ItemType Directory -Path $serviceDir -Force | Out-Null
        } catch {
            Write-LogError "Failed to create service directory: $($_.Exception.Message)"
            exit 1
        }
    }
    Write-LogDebug "Changing directory to `"$serviceDir`""
    if ($script:DryRun -eq 0) {
        try {
            Set-Location $serviceDir
        } catch {
            Write-LogError "Failed to change to service directory: $($_.Exception.Message)"
            exit 1
        }
    }

    # Generate SSL config with SAN entries for this service
    Write-LogInfo "Generating new config file $script:SSLConfig for service `"$service`""
    if ($script:DryRun -eq 0) {
        $configContent = @"
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
"@
        
        if ($domains -or $ips) {
            $configContent += @"

subjectAltName = @alt_names
[alt_names]
"@
            
            # Add DNS entries
            $dnsEntries = @()
            if ($domains) {
                $dnsEntries += $domains -split ','
            }
            $dnsEntries += $service
            
            for ($j = 0; $j -lt $dnsEntries.Count; $j++) {
                $configContent += "DNS.$($j + 1) = $($dnsEntries[$j])`r`n"
            }
            
            # Add IP entries
            if ($ips) {
                $ipEntries = $ips -split ','
                for ($j = 0; $j -lt $ipEntries.Count; $j++) {
                    $configContent += "IP.$($j + 1) = $($ipEntries[$j])`r`n"
                }
            }
        }
        
        try {
            Set-Content -Path $script:SSLConfig -Value $configContent -NoNewline
        } catch {
            Write-LogError "Failed to create SSL config: $($_.Exception.Message)"
            exit 1
        }
    }

    Write-LogInfo "Generating new SSL KEY $script:SSLKey"
    if ($script:DryRun -eq 0) {
        try {
            & openssl genrsa -out $script:SSLKey $script:SSLSize
            if ($LASTEXITCODE -ne 0) { throw "OpenSSL command failed" }
        } catch {
            Write-LogError "Failed to generate SSL key: $($_.Exception.Message)"
            exit 1
        }
    }

    Write-LogInfo "Generating new SSL CSR $script:SSLCsr"
    if ($script:DryRun -eq 0) {
        try {
            & openssl req -new `
                -key $script:SSLKey `
                -out $script:SSLCsr `
                -subj "/CN=$service" `
                -config $script:SSLConfig
            if ($LASTEXITCODE -ne 0) { throw "OpenSSL command failed" }
        } catch {
            Write-LogError "Failed to generate SSL CSR: $($_.Exception.Message)"
            exit 1
        }
    }

    Write-LogInfo "Generating new SSL CERT $script:SSLCert"
    if ($script:DryRun -eq 0) {
        try {
            $caCertPath = Join-Path $BaseDir $script:CACert
            $caKeyPath = Join-Path $BaseDir $script:CAKey
            
            & openssl x509 -req -in $script:SSLCsr -CA $caCertPath -CAkey $caKeyPath -CAcreateserial -out $script:SSLCert `
                -days $script:SSLExpire -extensions v3_req -extfile $script:SSLConfig
            if ($LASTEXITCODE -ne 0) { throw "OpenSSL command failed" }
        } catch {
            Write-LogError "Failed to generate SSL certificate: $($_.Exception.Message)"
            exit 1
        }
    }
    
    Write-LogDebug "Changing directory to `"$BaseDir`"`n"
    if ($script:DryRun -eq 0) {
        try {
            Set-Location $BaseDir
        } catch {
            Write-LogError "Failed to return to base directory: $($_.Exception.Message)"
            exit 1
        }
    }
}

Write-LogDebug "Changing directory to `"$CWD`"`n"
if ($script:DryRun -eq 0) {
    try {
        Set-Location $CWD
    } catch {
        Write-LogError "Failed to return to original directory: $($_.Exception.Message)"
        exit 1
    }
}
