#!/bin/bash
# Script to enable memberOf overlay in OpenLDAP
set -e
# Note: cn=module{1},cn=config assumes that the module will be loaded as the second module. cn=module{0} being the first.
# Additionally, olcDatabase={2}mdb assumes that the database is the second one configured in OpenLDAP. Adjust as necessary.
# Create a temporary LDIF file
# ensure cn=module{N},cn=config and cn: module{N} match eachother and do not conflict with existing modules. Run `slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep 'cn=module'` to check existing modules.
cat > /tmp/memberof-overlay.ldif << 'EOF'
dn: cn=module{1},cn=config
changetype: add
objectClass: olcModuleList
cn: module{1}
olcModuleLoad: memberof
olcModulePath: /opt/bitnami/openldap/lib/openldap

dn: olcOverlay=memberof,olcDatabase={2}mdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcMemberOf
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf

dn: cn=module{2},cn=config
changetype: add
objectClass: olcModuleList
cn: module{2}
olcmoduleload: refint
olcModulePath: /opt/bitnami/openldap/lib/openldap

dn: olcOverlay={1}refint,olcDatabase={2}mdb,cn=config
changetype: add
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: {1}refint
olcRefintAttribute: memberof member manager owner
EOF

# Apply the LDIF to enable memberOf overlay
echo "Enabling memberOf overlay in OpenLDAP configuration..."
echo "Loading memberOf overlay with slapadd..."

if slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config | grep -q memberof
then
    echo "MemberOf overlay is already configured."
    exit 0
else
    slapmodify -F /opt/bitnami/openldap/etc/slapd.d -b cn=config -l /tmp/memberof-overlay.ldif || {
        echo "NOTICE: slapadd failed to load memberOf overlay. Check the cn=module{N} with \"slapcat -F /opt/bitnami/openldap/etc/slapd.d -b cn=config |grep 'cn=module'\""
        exit 1
    }
fi

echo "MemberOf overlay has been configured."
