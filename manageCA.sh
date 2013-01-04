#!/bin/bash
################################################################################
# Author: Didier Fabert
# Rev 0.1
################################################################################
COUNTRYNAME="FR"
STATE="Languedoc-Roussillon"
CITY="Beaucaire"
COMPANY="Home"

PKI_PATH="/etc/pki"
NAME=""

function printUsage() {
	echo "$(basename $0)"
}

function printHelp() {
	echo
	echo "Options:"
	echo -e "\t-p <PATH>     Path for PKI [/etc/pki]"
	echo -e "\t-n <NAME>     CA Name [None]"
}

function printMenu() {
	clear
	echo "====================================================================="
	echo "             ${COMPANY} Certificate Management System"
	echo "====================================================================="
	echo ""
	echo "   1) Create a client certificate (PKCS#10)"
	echo "   2) Create a Client Certificate for Web (PKCS#12)"
	echo "   2) Renew a Server Certificate (PEM SelfSigned)"
	echo "   4) Revoke a Client Certificate"
	echo "   5) List Client Certificates"
	echo ""
	echo "   i) Initialize Root Certificate Authority (CA)"
	echo "   p) Change default path [${PKI_PATH}]"
	echo "   p) Change CA name [${NAME}]"
	echo "   d) Delete CA"
	echo "   o) Show, modify CA Options"
	echo "   q) Quit"
	echo ""
}

function printSubMenu {
        clear
        echo "-----------------------------------------------------------------"
        echo ${1}
        echo "-----------------------------------------------------------------"
        echo ""
}

function manageOptions() {
	local BUFFER
	while true;
	do
		printSubMenu "CA Options"
		echo "   1) Country Name [${COUNTRYNAME}]"
		echo "   2) State Name [${STATE}]"
		echo "   3) City Name [${CITY}]"
		echo "   4) Company Name [${COMPANY}]"
		echo ""
		echo "   p) Previous menu"
		echo ""
		read -p " ==> Make your choice [none]: " -n 1 CHOICE
		echo
		case ${CHOICE} in
			1)
				read -p "New Country Name [${COUNTRYNAME}]:" BUFFER
				if [ ! -z ${BUFFER} ]; then COUNTRYNAME=${BUFFER} ; fi
				;;
			2)
				read -p "New State Name [${STATE}]:" BUFFER
				if [ ! -z ${BUFFER} ]; then STATE=${BUFFER} ; fi
				;;
			3)
				read -p "New City Name [${CITY}]:" BUFFER
				if [ ! -z ${BUFFER} ]; then CITY=${BUFFER} ; fi
				;;
			4)
				read -p "New Company Name [${COMPANY}]:" BUFFER
				if [ ! -z ${BUFFER} ]; then COMPANY=${BUFFER} ; fi
				;;
			p)
				return
				;;
		esac
	done
}

function addUser() {
	local user
	local email
	printSubMenu "Create a client certificate"
	read -p "User name: " user
	if [[ "$user" == "" ]]
	then
		echo "Error: Name cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	read -p "User email: " email
	if [[ "$email" == "" ]]
	then
		echo "Error: email cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi 
	openssl genrsa -out ${PKI_PATH}/${NAME}/certs/${user}.key 2048 \
		1>/dev/null 2>&1
	local userdata="organizationalUnitName_default  = User\n"
	userdata="${userdata}commonName_default              = ${user}\n"
	userdata="${userdata}emailAddress_default            = ${email}"
	cat ${PKI_PATH}/${NAME}/ssl.cnf | tr -d '#' | \
		sed -e "s/@USERDATA@/${userdata}/" \
		> ${PKI_PATH}/${NAME}/ssl2.cnf
	openssl req -config ${PKI_PATH}/${NAME}/ssl2.cnf -new -nodes -batch \
		-out ${PKI_PATH}/${NAME}/certs/${user}.csr \
		-key ${PKI_PATH}/${NAME}/certs/${user}.key
	openssl ca -config ${PKI_PATH}/${NAME}/ssl2.cnf \
		-out ${PKI_PATH}/${NAME}/certs/${user}.crt \
		-outdir ${PKI_PATH}/${NAME}/certs \
		-infiles ${PKI_PATH}/${NAME}/certs/${user}.csr
	cat ${PKI_PATH}/${NAME}/certs/${user}.crt \
		${PKI_PATH}/${NAME}/certs/${user}.key \
			> ${PKI_PATH}/${NAME}/pem/${user}.pem
	mv ${PKI_PATH}/${NAME}/ssl2.cnf ${PKI_PATH}/${NAME}/confs/${user}-ssl.cnf
	read -p "Press [enter] to continue" DUMMY
}

function webUser() {
	printSubMenu "Create a Client Certificate for Web"
	printUserList
	read -p "User name: " user
	if [[ "$user" == "" ]]
	then
		echo "Error encoured: Name cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	if [ -f ${PKI_PATH}/${NAME}/certs/${user}.crt ]
	then
		openssl pkcs12 -export -inkey ${PKI_PATH}/${NAME}/certs/${user}.key \
			-in ${PKI_PATH}/${NAME}/certs/${user}.crt \
			-CAfile ${PKI_PATH}/${NAME}/${caname}_ca.crt \
			-out ${PKI_PATH}/${NAME}/certs/${user}_browser_cert.p12
	fi
	[ -f ${PKI_PATH}/${NAME}/certs/${user}_browser_cert.p12 ] \
		&& echo "Web certificate: ${PKI_PATH}/${NAME}/certs/${user}_browser_cert.p12" \
		|| echo "Error encoured"
	read -p "Press [enter] to continue" DUMMY
}

function renewUser() {
	printSubMenu "Renew a Server Certificate"
	printUserList
	read -p "User name: " user
	if [[ "$user" == "" ]]
	then
		echo "Error: Name cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	openssl ca -config ${PKI_PATH}/${NAME}/confs/${user}-ssl.cnf \
        -out ${PKI_PATH}/${NAME}/certs/${user}.crt \
        -outdir ${PKI_PATH}/${NAME}/certs \
        -infiles ${PKI_PATH}/${NAME}/certs/${user}.csr
	read -p "Press [enter] to continue" DUMMY
}

function revokeUser() {
	printSubMenu "Revoke a Client Certificate"
	printUserList
	read -p "User name: " user
	if [[ "$user" == "" ]]
	then
		echo "Error: Name cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	openssl ca -revoke ${PKI_PATH}/${NAME}/certs/${user}.crt \
		-config ${PKI_PATH}/${NAME}/ssl.cnf 
	openssl ca -gencrl -config ${PKI_PATH}/${NAME}/ssl.cnf \
		-out ${PKI_PATH}/${NAME}/crl.pem
	read -p "Press [enter] to continue" DUMMY
}

function listUser() {
	printSubMenu "List Client Certificates"
	while [ 1 ]
	do
	   read LINE || break
	   LISTNUM=`echo ${LINE} | grep -v "^R" | awk '{ print $3 }'`
	   LISTCN=`echo ${LINE} | grep -v "^R" | awk -F CN= '{ print $2 }' | cut -d '/' -f1`
	   [ -z ${LISTNUM} ] || echo " ${LISTNUM} ${LISTCN}"
	done < ${PKI_PATH}/${NAME}/index.txt
	read -p "Press [enter] to continue" DUMMY
}

function printUserList() {
	while [ 1 ]
	do
	   read LINE || break
	   LISTCN=`echo ${LINE} | grep -v "^R" | awk -F CN= '{ print $2 }' | cut -d '/' -f1`
	   [ -z ${LISTCN} ] || echo "- ${LISTCN}"
	done < ${PKI_PATH}/${NAME}/index.txt
}

function changeDefaultPath() {
	read -p "Select New path for CA [${PKI_PATH}]: " PKI_PATH
}

function changeName() {
	read -p "Select New CA name [NONE]: " NAME
}

function initCA() {
	printSubMenu "CA Initialisation"
	if [ -f ${PKI_PATH}/${NAME}/ssl.cnf ]
	then
		read -p "Already initalized"
		return
	fi
	initConfig
	read -p "Fully qualified Hostname: " hostname
	if [[ "$hostname" == "" ]]
	then
		echo "Error: Fully qualified Hostname cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	read -p "Admin email: " email
	if [[ "$email" == "" ]]
	then
		echo "Error: email cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi 
	mkdir -p ${PKI_PATH}/${NAME}/{certs,newcerts,private,confs,crl,pem}
	touch ${PKI_PATH}/${NAME}/index.txt
	[ -f ${PKI_PATH}/${NAME}/serial ] || echo 01 > ${PKI_PATH}/${NAME}/serial
	[ -f ${PKI_PATH}/${NAME}/crlnumber ] || echo 01 > ${PKI_PATH}/${NAME}/crlnumber
	[ -f ${PKI_PATH}/${NAME}/private/${NAME}_ca.key ] || \
		openssl genrsa -out ${PKI_PATH}/${NAME}/private/${NAME}_ca.key 2048 \
		1>/dev/null 2>&1
	local userdata="organizationalUnitName_default  = Admin\n"
	userdata="${userdata}commonName_default              = ${hostname}\n"
	userdata="${userdata}emailAddress_default            = ${email}"
	cat ${PKI_PATH}/${NAME}/ssl.cnf | tr -d '#' | \
		sed -e "s/@USERDATA@/${userdata}/" \
		> ${PKI_PATH}/${NAME}/ssl2.cnf
	openssl req -config ${PKI_PATH}/${NAME}/ssl2.cnf -new -x509 -days 3650 -batch \
		-key ${PKI_PATH}/${NAME}/private/${NAME}_ca.key \
		-out ${PKI_PATH}/${NAME}/${NAME}_ca.crt -extensions v3_ca
	mv ${PKI_PATH}/${NAME}/ssl2.cnf ${PKI_PATH}/${NAME}/confs/ca.cnf
	[ -f ${PKI_PATH}/${NAME}/crl.pem ] || openssl ca -gencrl \
		-config ${PKI_PATH}/${NAME}/ssl.cnf -out ${PKI_PATH}/${NAME}/crl.pem
	ln ${PKI_PATH}/${NAME}/crl.pem ${PKI_PATH}/${NAME}/crl/
	local hash=`openssl crl -hash -noout -in ${PKI_PATH}/${NAME}/crl/crl.pem`
	ln -s ${PKI_PATH}/${NAME}/crl/crl.pem ${PKI_PATH}/${NAME}/crl/$hash.r0
	echo "CA initialized"
	read -p "Press [enter] to continue" DUMMY
}

function deleteCA() {
	printSubMenu "Deleting CA"
	read -p "Are you sure ? Type uppercase YES to confirm: " CONFIRM
	if [[ "${CONFIRM}" == "YES" ]]
	then
		rm -rf ${PKI_PATH}/${NAME}
		echo "CA completely deleted"
		read -p "Press [enter] to continue" DUMMY
	fi
}

function initConfig() {
	mkdir -p ${PKI_PATH}/${NAME}
	cat << 'EOF' > ${PKI_PATH}/${NAME}/ssl.cnf
HOME                    = @HOME@
RANDFILE                = @HOME@/.rand

[ca] 
default_ca              = ca_default

[ca_default] 
dir                     = @HOME@
certs                   = $dir/certs
crl_dir                 = $dir/crl
database                = $dir/index.txt
new_certs_dir           = $dir/newcerts
certificate             = $dir/@NAME@_ca.crt
private_key             = $dir/private/@NAME@_ca.key
serial                  = $dir/serial
crl                     = $dir/crl.pem
crlnumber               = $dir/crlnumber
crl_extensions          = crl_ext
x509_extensions         = usr_cert
name_opt                = ca_default
cert_opt                = ca_default
default_days            = 365
default_crl_days        = 30
default_md              = md5
preserve                = no
policy                  = policy_match

[policy_match] 
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[req] 
default_bits            = 1024
default_keyfile         = privkey.pem
distinguished_name      = req_distinguished_name
attributes              = req_attributes
x509_extensions         = v3_ca
string_mask             = MASK:0x2002

[req_distinguished_name] 
countryName                     = Country Name (2 letter code)
countryName_default             = @COUNTRYNAME@
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = @STATE@
localityName                    = Locality Name (eg, city)
localityName_default            = @CITY@
0.organizationName              = Organization Name (eg, company)
0.organizationName_default      = @ORGANISATION@
organizationalUnitName          = Organizational Unit Name (eg, section)
commonName                      = Common Name (eg, your name or your server\'s hostname)
commonName_max                  = 64
emailAddress                    = Email Address
emailAddress_max                = 64
##@USERDATA@

[req_attributes] 
challengePassword               = A challenge password
challengePassword_min           = 4
challengePassword_max           = 20
unstructuredName                = An optional company name

[usr_cert] 
basicConstraints                = CA:FALSE
nsComment                       = "OpenSSL Generated Certificate"
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid,issuer:always

[v3_ca] 
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid:always,issuer:always
basicConstraints                = CA:true

[crl_ext]
authorityKeyIdentifier=keyid:always,issuer:always
EOF

	sed -i \
		-e "s#@HOME@#${PKI_PATH}/${NAME}#g" \
		-e "s#@NAME@#${NAME}#g" \
		-e "s#@COUNTRYNAME@#${COUNTRYNAME}#g" \
		-e "s#@STATE@#${STATE}#g" \
		-e "s#@CITY@#${CITY}#g" \
		-e "s#@ORGANISATION@#${COMPANY}#g" \
		${PKI_PATH}/${NAME}/ssl.cnf
}

#Main program

# process command line arguments
while getopts "?hup:n:" opt
do
	case "${opt}" in
		u)
			printUsage
			exit 0
			;;
		h|\?)
			printUsage
			printHelp
			exit 0
			;;
		p)
			PKI_PATH=$OPTARG
			;;
		n)
			NAME=$OPTARG
			;;
	esac
done

clear
[ -z ${NAME} ] && changeName
while true;
do
	printMenu
#	CheckOpenSSLConfig
	read -p " ==> Make your choice [none]: " -n 1 CHOICE
	case ${CHOICE} in
		1)
			addUser
			;;
		2)
			webUser
			;;
		3)
			renewUser
			;;
		4)
			revokeUser
			;;
		5)
			listUser
			;;
		I|i)
			initCA
			;;
		Q|q)
			echo
			break
			;;
		P|p)
			echo
			changeDefaultPath
			;;
		N|n)
			echo
			changeName
			;;
		D|d)
			deleteCA
			;;
		O|o)
			manageOptions
			;;
	esac
done


