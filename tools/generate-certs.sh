#!/bin/bash

#region Logging functions based on log4bash
GLOBAL_LOG_LEVEL=${GLOBAL_LOG_LEVEL:-"INFO"}
declare -r -A LOG_LEVEL_VAL=(
    ["ERROR"]=3
    ["WARNING"]=4
    ["INFO"]=6
    ["SUCCESS"]=7
    ["DEBUG"]=7
)
declare -r LOG_DEFAULT_COLOR="\033[0m"
declare -r LOG_ERROR_COLOR="\033[1;31m"
declare -r LOG_INFO_COLOR="\033[1m"
declare -r LOG_SUCCESS_COLOR="\033[1;32m"
declare -r LOG_WARN_COLOR="\033[1;33m"
declare -r LOG_DEBUG_COLOR="\033[1;34m"

log() {
    local log_text="$1"
    local log_level="$2"
    local log_color="$3"

    # Default level to "info"
    [[ -z ${log_level} ]] && log_level="INFO";
    [[ -z ${log_color} ]] && log_color="${LOG_INFO_COLOR}";

    if [[ ${LOG_LEVEL_VAL["$GLOBAL_LOG_LEVEL"]} -ge ${LOG_LEVEL_VAL["$log_level"]} ]]; then
        echo -e "${log_color}[$(date +"%Y-%m-%d %H:%M:%S %Z")] [${log_level}] ${log_text} ${LOG_DEFAULT_COLOR}";
    fi

    return 0;
}

log_info()      { log "$@"; }
log_success()   { log "$1" "SUCCESS" "${LOG_SUCCESS_COLOR}"; }
log_error()     { log "$1" "ERROR" "${LOG_ERROR_COLOR}"; }
log_warning()   { log "$1" "WARNING" "${LOG_WARN_COLOR}"; }
log_debug()     { log "$1" "DEBUG" "${LOG_DEBUG_COLOR}"; }
#endregion

#region Definitions of variables
CWD=$(pwd -P)
CA_KEY=${CA_KEY:-"ca-key.pem"}
CA_CERT=${CA_CERT:-"ca.pem"}
CA_EXPIRE=${CA_EXPIRE:-"60"}
CA_SUBJECT=${CA_SUBJECT:-"test-ca"}

SSL_CONFIG=${SSL_CONFIG:-"openssl.cnf"}
SSL_KEY=${SSL_KEY:-"key.pem"}
SSL_CSR=${SSL_CSR:-"key.csr"}
SSL_CERT=${SSL_CERT:-"cert.pem"}
SSL_SIZE=${SSL_SIZE:-"2048"}
SSL_EXPIRE=${SSL_EXPIRE:-"60"}
SSL_CERTS_DIR=${SSL_CERTS_DIR:-"${CWD}/certs_$(date '+%Y%m%d')"}

DRY_RUN=${DRY_RUN:-0}
SERVICES=()
SERVICE_DOMAINS=()
SERVICE_IPS=()
#endregion

#region Help function
function usage() {
    echo -e "Generates certificates for specified services"
    echo -e ""
    echo -e "Usage: $0 [OPTIONS] service1@domain1,domain2:ip1,ip2 service2@domain1:ip1"
    echo -e ""
    echo -e "Options:"
    echo -e "  Certificate Authority:"
    echo -e "    -d|--certs-dir <path_to_certs_dir> - directory where all certificates will be stored. Default: $SSL_CERTS_DIR"
    echo -e "    -k|--ca-key <path_to_ca_key_file> - file with .key extension of the Certificate Authority. Default: $CA_KEY"
    echo -e "    -c|--ca-cert <path_to_ca_cert_file> - file with .crt extension of the Certificate Authority. Default: $CA_CERT"
    echo -e "    --ca-expire <days> - days for the Certificate Authority to expire. Default: $CA_EXPIRE"
    echo -e "    --ca-subject <subject> - subject of the Certificate Authority. Default: $CA_SUBJECT" 
    echo -e ""
    echo -e "  Other Options:"
    echo -e "    --log-level LOGLEVEL    Log level (default: $GLOBAL_LOG_LEVEL)"
    echo -e "    -h, --help              Display help information"
    echo -e "    --dry-run               Dry run without generating certificates"
    echo -e ""
    echo -e "Service Format:"
    echo -e "    service@domain1,domain2:ip1,ip2"
    echo -e "    - service: service name (used as CN)"
    echo -e "    - domain1,domain2: comma-separated domain names (optional)"
    echo -e "    - ip1,ip2: comma-separated IP addresses (optional)"
    echo -e ""
    echo -e "Example:"
    echo -e "\t$0 --ca-key ~/certs/global/server.key --ca-cert ~/certs/global/server.crt \"web@web.example.com,api.example.com:192.168.1.10,10.0.0.1\" \"db@db.example.com\""

    exit 0
}
#endregion

#region Process arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--ca-key)
            CA_KEY="$2"
            shift
            ;;
        -c|--ca-cert)
            CA_CERT="$2"
            shift
            ;;
        --ca-expire)
            CA_EXPIRE="$2"
            shift
            ;;
        --ca-subject)
            CA_SUBJECT="$2"
            shift
            ;;
        -d|--certs-dir)
            SSL_CERTS_DIR="$2"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        --log-level)
            if ! [[ " ${!LOG_LEVEL_VAL[@]} " =~ " $2 " ]] ; then
                log_error "Invalid value of log level expected one of [${!LOG_LEVEL_VAL[*]}], got: \"$2\""
                exit 1
            fi
            GLOBAL_LOG_LEVEL="$2"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ $1 =~ ^[[:alnum:]-]+@[[:alnum:].,-]+(:[[:alnum:].,-]+)?$ ]]; then
                # Parse service@domains:ips format
                service_part="${1%%@*}"
                domains_ips_part="${1#*@}"
                
                SERVICES+=("$service_part")
                
                # Extract domains and IPs if present
                if [[ "$domains_ips_part" != "$1" ]]; then
                    # Split domains and IPs by colon
                    if [[ "$domains_ips_part" == *":"* ]]; then
                        domains_part="${domains_ips_part%%:*}"
                        ips_part="${domains_ips_part#*:}"
                        
                        # Parse domains (comma-separated)
                        if [[ -n "$domains_part" ]]; then
                            IFS=',' read -r -a domains_array <<< "$domains_part"
                            SERVICE_DOMAINS+=("$(IFS=','; echo "${domains_array[*]}")")
                        else
                            SERVICE_DOMAINS+=("")
                        fi
                        
                        # Parse IPs (comma-separated)
                        if [[ -n "$ips_part" ]]; then
                            IFS=',' read -r -a ips_array <<< "$ips_part"
                            SERVICE_IPS+=("$(IFS=','; echo "${ips_array[*]}")")
                        else
                            SERVICE_IPS+=("")
                        fi
                    else
                        # Only domains, no IPs
                        if [[ -n "$domains_ips_part" ]]; then
                            IFS=',' read -r -a domains_array <<< "$domains_ips_part"
                            SERVICE_DOMAINS+=("$(IFS=','; echo "${domains_array[*]}")")
                        else
                            SERVICE_DOMAINS+=("")
                        fi
                        SERVICE_IPS+=("")
                    fi
                else
                    # No @ symbol, just service name
                    SERVICE_DOMAINS+=("")
                    SERVICE_IPS+=("")
                fi
            else
                echo -e "Error: Invalid format in argument '$1'. Expected 'service@domain1,domain2:ip1,ip2' or 'service@domain'."
                exit 1
            fi
            ;;
    esac
    shift
done
#endregion

echo -e "--> Working directory"


log_debug "Creating directory \"$SSL_CERTS_DIR\" for certificates"
if [[ $DRY_RUN -eq 0 ]]; then
    if [[-d "${SSL_CERTS_DIR}"]]; then 
        log_debug "Using existing directory \"$SSL_CERTS_DIR\" for certificates"
    else
        mkdir -pv "$SSL_CERTS_DIR" || exit 1
    fi
fi

log_debug "Changing directory to \"$SSL_CERTS_DIR\""
if [[ $DRY_RUN -eq 0 ]]; then
    cd "$SSL_CERTS_DIR" || exit 1
fi
echo -e ""

echo -e "--> Certificate Authority"

if [[ -e ${CA_KEY} ]]; then
    log_info "Using existing CA Key ${CA_KEY}"
else
    log_info "Generating new CA key ${CA_KEY}"
    if [[ $DRY_RUN -eq 0 ]]; then
        openssl genrsa -out ${CA_KEY} 2048
    fi
fi

if [[ -e ${CA_CERT} ]]; then
    log_info "Using existing CA Certificate ${CA_CERT}"
else
    log_info "Generating new CA Certificate ${CA_CERT}"
    if [[ $DRY_RUN -eq 0 ]]; then
        openssl req -x509 -new -nodes \
            -key ${CA_KEY} \
            -days ${CA_EXPIRE} \
            -out ${CA_CERT} \
            -subj "/CN=${CA_SUBJECT}"  || exit 1
    fi
fi
echo -e ""


echo -e "--> Processing services and generating certificates"
for i in "${!SERVICES[@]}"; do
    service="${SERVICES[$i]}"
    domains="${SERVICE_DOMAINS[$i]}"
    ips="${SERVICE_IPS[$i]}"
    
    log_debug "Creating directory \"$SSL_CERTS_DIR/$service\" for service \"$service\" certificates"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -pv "$SSL_CERTS_DIR/$service" || exit 1
    fi
    log_debug "Changing directory to \"$SSL_CERTS_DIR/$service\""
    if [[ $DRY_RUN -eq 0 ]]; then
        cd "$SSL_CERTS_DIR/$service" || exit 1
    fi

    # Generate SSL config with SAN entries for this service
    log_info "Generating new config file ${SSL_CONFIG} for service \"$service\""
    if [[ $DRY_RUN -eq 0 ]]; then
        cat > ${SSL_CONFIG} <<EOM
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOM
        if [[ -n ${domains} || -n ${ips} ]]; then
            cat >> ${SSL_CONFIG} <<EOM
subjectAltName = @alt_names
[alt_names]
EOM

            IFS=","
            dns=("${domains[@]}")
            dns+=(${service})
            for i in "${!dns[@]}"; do
            echo DNS.$((i+1)) = ${dns[$i]} >> ${SSL_CONFIG}
            done

            if [[ -n ${ips} ]]; then
                ip=("${ips[@]}")
                for i in "${!ip[@]}"; do
                echo IP.$((i+1)) = ${ip[$i]} >> ${SSL_CONFIG}
                done
            fi
        fi
    fi

    log_info "Generating new SSL KEY ${SSL_KEY}"
    if [[ $DRY_RUN -eq 0 ]]; then
        openssl genrsa -out ${SSL_KEY} ${SSL_SIZE}  || exit 1
    fi

    log_info "Generating new SSL CSR ${SSL_CSR}"
    if [[ $DRY_RUN -eq 0 ]]; then
    openssl req -new \
    -key ${SSL_KEY} \
    -out ${SSL_CSR} \
    -subj "/CN=${service}" \
    -config ${SSL_CONFIG}  || exit 1
    fi

    log_info "Generating new SSL CERT ${SSL_CERT}"
    if [[ $DRY_RUN -eq 0 ]]; then
    openssl x509 -req -in ${SSL_CSR} -CA ${SSL_CERTS_DIR}/${CA_CERT} -CAkey ${SSL_CERTS_DIR}/${CA_KEY} -CAcreateserial -out ${SSL_CERT} \
        -days ${SSL_EXPIRE} -extensions v3_req -extfile ${SSL_CONFIG}  || exit 1
    fi
    
    log_info "Copying CA certificate to service directory"
    if [[ $DRY_RUN -eq 0 ]]; then
        cp ${SSL_CERTS_DIR}/${CA_CERT} ${SSL_CERTS_DIR}/${service}/${CA_CERT}
    fi
    
    log_debug "Changing directory to \"$SSL_CERTS_DIR\"\n"
    if [[ $DRY_RUN -eq 0 ]]; then
        cd "$SSL_CERTS_DIR" || exit 1
    fi
done

log_debug "Changing directory to \"$CWD\"\n"
if [[ $DRY_RUN -eq 0 ]]; then
    cd "$CWD" || exit 1
fi

