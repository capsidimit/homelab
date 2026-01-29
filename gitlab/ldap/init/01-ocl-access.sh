#!/bin/bash
# Script to enable memberOf overlay in OpenLDAP
set -e
# Note: cn=module{1},cn=config assumes that the module will be loaded as the second module. cn=module{0} being the first.
# Additionally, olcDatabase={2}mdb assumes that the database is the second one configured in OpenLDAP. Adjust as necessary.
# Create a temporary LDIF file
# ensure cn=module{N},cn=config and cn: module{N} match eachother and do not conflict with existing modules. Run `slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep 'cn=module'` to check existing modules.
cat > /tmp/ocl-access.ldif << 'EOF'
dn: olcDatabase={2}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword
  by self write
  by anonymous auth
  by * none
olcAccess: {1}to attrs=shadowLastChange
  by self write
  by * read
olcAccess: {2}to dn.subtree="ou=users,dc=ldap,dc=example,dc=com"
  by dn.exact="uid=gitlab,ou=services,dc=ldap,dc=example,dc=com" read
  by dn.exact="cn=admin,dc=ldap,dc=example,dc=com" write
  by self read
  by * none
olcAccess: {3}to dn.subtree="ou=groups,dc=ldap,dc=example,dc=com"
  by dn.exact="uid=gitlab,ou=services,dc=ldap,dc=example,dc=com" read
  by dn.exact="cn=admin,dc=ldap,dc=example,dc=com" write
  by users read
  by * none
olcAccess: {4}to *
  by dn.exact="cn=admin,dc=ldap,dc=example,dc=com" write
  by users read
  by * none
EOF

# Apply the LDIF
if slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep mdb -A 30 | grep -q olcAccess
then
    echo "olcAccess is already configured."
    exit 0
else
    slapmodify -F /opt/bitnami/openldap/etc/slapd.d -b cn=config -l /tmp/ocl-access.ldif || {
        echo "NOTICE: slapadd failed to load olcAccess. Check the cn=module{N} with \"slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep mdb -A 30\""
        exit 1
    }
fi

echo "olcAccess has been configured."

