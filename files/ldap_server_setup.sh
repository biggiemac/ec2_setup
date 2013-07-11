#!/bin/bash

####################
# Install OpenLDAP Server
####################

yum -y install openldap-servers openldap-clients 
sleep 30
echo "pidfile     /var/run/openldap/slapd.pid
argsfile    /var/run/openldap/slapd.args" > /etc/openldap/slapd.conf
rm -rf /etc/openldap/slapd.d/* 
slaptest -f /etc/openldap/slapd.conf -F /etc/openldap/slapd.d 
sed -i  '/^olcAcces/d' /etc/openldap/slapd.d/cn=config/olcDatabase\={0}config.ldif 
echo "olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break " >> /etc/openldap/slapd.d/cn=config/olcDatabase\={0}config.ldif 
echo "dn: olcDatabase={1}monitor
objectClass: olcDatabaseConfig
olcDatabase: {1}monitor
olcAccess: {1}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
olcAddContentAcl: FALSE
olcLastMod: TRUE
olcMaxDerefDepth: 15
olcReadOnly: FALSE
olcMonitoring: FALSE
structuralObjectClass: olcDatabaseConfig
creatorsName: cn=config
modifiersName: cn=config " > /etc/openldap/slapd.d/cn=config/olcDatabase\={1}monitor.ldif 
chown -R ldap. /etc/openldap/slapd.d 
chmod -R 700 /etc/openldap/slapd.d 
/etc/rc.d/init.d/slapd start 
chkconfig slapd on 

####################
# Initial OpenLDAP Configuration
####################

ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/core.ldif 
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif 
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif 
cd /tmp
SLAPPASSWD=`slappasswd -s adaptive`

echo -e "dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulepath: /usr/lib64/openldap
olcModuleload: back_hdb

dn: olcDatabase=hdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcHdbConfig
olcDatabase: {2}hdb
olcSuffix: dc=adaptive,dc=com
olcDbDirectory: /var/lib/ldap
olcRootDN: cn=Manager,dc=adaptive,dc=com
olcRootPW: `echo $SLAPPASSWD`
olcDbConfig: set_cachesize 0 2097152 0
olcDbConfig: set_lk_max_objects 1500
olcDbConfig: set_lk_max_locks 1500
olcDbConfig: set_lk_max_lockers 1500
olcDbIndex: objectClass eq
olcLastMod: TRUE
olcMonitoring: TRUE
olcDbCheckpoint: 512 30
olcAccess: to attrs=userPassword by dn=\"cn=Manager,dc=adaptive,dc=com\" write by anonymous auth by self write by * none
olcAccess: to attrs=shadowLastChange by self write by * read
olcAccess: to dn.base=\"\" by * read
olcAccess: to * by dn=\"cn=Manager,dc=adaptive,dc=com\" write by * read" >/tmp/backend.ldif

ldapadd -Y EXTERNAL -H ldapi:/// -f backend.ldif

echo -e "dn: dc=adaptive,dc=com
objectClass: top
objectClass: dcObject
objectclass: organization
o: Adaptive Computing
dc: adaptive

dn: cn=Manager,dc=adaptive,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: Manager
userPassword: `echo $SLAPPASSWD`

dn: ou=people,dc=adaptive,dc=com
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=adaptive,dc=com
objectClass: organizationalUnit
ou: groups" >/tmp/frontend.ldif

ldapadd -x -D cn=Manager,dc=adaptive,dc=com -w adaptive -f /tmp/frontend.ldif

####################
# Add Local Users to OpenLDAP
####################

SUFFIX='dc=adaptive,dc=com'
LDIF='/tmp/ldapuser.ldif'

echo -n > $LDIF
for line in `grep "x:[5-9][0-9][0-9]:" /etc/passwd | sed -e "s/ /%/g"`
do
   UID1=`echo $line | cut -d: -f1`
   NAME=`echo $line | cut -d: -f5 | cut -d, -f1`
   if [ ! "$NAME" ]
   then
      NAME=$UID1
   else
      NAME=`echo $NAME | sed -e "s/%/ /g"`
   fi
   SN=`echo $NAME | awk '{print $2}'`
   if [ ! "$SN" ]
   then
      SN=$NAME
   fi
   GIVEN=`echo $NAME | awk '{print $1}'`
   UID2=`echo $line | cut -d: -f3`
   GID=`echo $line | cut -d: -f4`
   PASS=`grep $UID1: /etc/shadow | cut -d: -f2`
   SHELL=`echo $line | cut -d: -f7`
   HOME=`echo $line | cut -d: -f6`
   EXPIRE=`passwd -S $UID1 | awk '{print $7}'`
   FLAG=`grep $UID1: /etc/shadow | cut -d: -f9`
   if [ ! "$FLAG" ]
   then
      FLAG="0"
   fi
   WARN=`passwd -S $UID1 | awk '{print $6}'`
   MIN=`passwd -S $UID1 | awk '{print $4}'`
   MAX=`passwd -S $UID1 | awk '{print $5}'`
   LAST=`grep $UID1: /etc/shadow | cut -d: -f3`

   echo "dn: uid=$UID1,ou=people,$SUFFIX" >> $LDIF
   echo "objectClass: inetOrgPerson" >> $LDIF
   echo "objectClass: posixAccount" >> $LDIF
   echo "objectClass: shadowAccount" >> $LDIF
   echo "uid: $UID1" >> $LDIF
   echo "sn: $SN" >> $LDIF
   echo "givenName: $GIVEN" >> $LDIF
   echo "cn: $NAME" >> $LDIF
   echo "displayName: $NAME" >> $LDIF
   echo "uidNumber: $UID2" >> $LDIF
   echo "gidNumber: $GID" >> $LDIF
   echo "userPassword: {crypt}$PASS" >> $LDIF
   echo "gecos: $NAME" >> $LDIF
   echo "loginShell: $SHELL" >> $LDIF
   echo "homeDirectory: $HOME" >> $LDIF
   echo "shadowExpire: $EXPIRE" >> $LDIF
   echo "shadowFlag: $FLAG" >> $LDIF
   echo "shadowWarning: $WARN" >> $LDIF
   echo "shadowMin: $MIN" >> $LDIF
   echo "shadowMax: $MAX" >> $LDIF
   echo "shadowLastChange: $LAST" >> $LDIF
   echo >> $LDIF
done

ldapadd -x -D cn=Manager,dc=adaptive,dc=com -w adaptive -f /tmp/ldapuser.ldif

####################
# Add Local Groups to OpenLDAP
####################

SUFFIX='dc=adaptive,dc=com'
LDIF='/tmp/ldapgroup.ldif'

echo -n > $LDIF
for line in `grep "x:[5-9][0-9][0-9]:" /etc/group`
do
   CN=`echo $line | cut -d: -f1`
   GID=`echo $line | cut -d: -f3`
   echo "dn: cn=$CN,ou=groups,$SUFFIX" >> $LDIF
   echo "objectClass: posixGroup" >> $LDIF
   echo "cn: $CN" >> $LDIF
   echo "gidNumber: $GID" >> $LDIF
   users=`echo $line | cut -d: -f4 | sed "s/,/ /g"`
   for user in ${users} ; do
      echo "memberUid: ${user}" >> $LDIF
   done
   echo >> $LDIF
done
ldapadd -x -D cn=Manager,dc=adaptive,dc=com -w adaptive -f /tmp/ldapgroup.ldif

###################
# Cat out a file for ensuring this ran.
###################

touch /tmp/configured_ldap_server.txt