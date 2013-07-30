#!/bin/bash
################################################################################
# Author: Didier Fabert
# Rev 0.5
################################################################################
COUNTRYNAME="FR"
STATE="Languedoc-Roussillon"
CITY="Beaucaire"
COMPANY="Didier Home"
OCSP_URL="http://didier.domicile.org/"

PKI_PATH="/etc/pki"
NAME=""
CFG_FILE="/etc/manageCA.conf"
REGEN_ONLY=0

function printUsage() {
	echo "Usage: $(basename $0)"
}

function printHelp() {
	echo
	echo "Options:"
	echo -e "  -c <NAME>     Config File [${CFG_FILE}]"
	echo -e "  -p <PATH>     Path for PKI [/etc/pki]"
	echo -e "  -n <NAME>     CA Name [None]"
	echo -e "  -r            Regenerate CRL only. -n option is mandatory."
}

function printMenu() {
	clear
	echo "====================================================================="
	echo "             ${COMPANY} Certificate Management System"
	echo "====================================================================="
	echo
	echo "   1) Create a Client/Server/OCSP certificate"
	echo "   2) Create a Client Certificate for Web (PKCS#12)"
	echo "   3) Renew a Certificate"
	echo "   4) Revoke a Certificate"
	echo "   5) List Certificates"
	echo
	echo "   i) Initialize Root Certificate Authority (CA)"
	echo "   r) Regenerate CRL"
	echo "   d) Delete CA"
	echo "   o) Show/Modify/Save CA Options"
	echo "   q) Quit"
	echo
	echo "   Options available before init"
	echo "   p) Change PKI default path [${PKI_PATH}]"
	echo "   n) Change CA name [${NAME}]"
	echo
}

function printSubMenu {
        clear
        echo "-----------------------------------------------------------------"
        echo ${1}
        echo "-----------------------------------------------------------------"
        echo
}

function manageOptions() {
	local buffer
	while true;
	do
		printSubMenu "CA Global Options"
		echo "   1) Country Name [${COUNTRYNAME}]"
		echo "   2) State Name [${STATE}]"
		echo "   3) City Name [${CITY}]"
		echo "   4) Company Name [${COMPANY}]"
		echo "   5) OCSP URL [${OCSP_URL}]"
		echo
		echo "   s) Save Options"
		echo "   p) Previous menu"
		echo
		read -p " ==> Make your choice [none]: " -n 1 CHOICE
		echo
		echo
		case ${CHOICE} in
			1)
				read -p " ==> New Country Name [${COUNTRYNAME}]: " buffer
				[ ! -z "${buffer}" ] && COUNTRYNAME=${buffer}
				;;
			2)
				read -p " ==> New State Name [${STATE}]: " buffer
				[ ! -z "${buffer}" ] && STATE=${buffer}
				;;
			3)
				read -p " ==> New City Name [${CITY}]: " buffer
				[ ! -z "${buffer}" ] && CITY=${buffer}
				;;
			4)
				read -p " ==> New Company Name [${COMPANY}]: " buffer
				echo "buffer=\"${buffer}\""
				[ ! -z "${buffer}" ] && COMPANY=${buffer}
				;;
			5)
				read -p " ==> New OCSP URL [${OCSP_URL}]: " buffer
				[ ! -z "${buffer}" ] && OCSP_URL=${buffer}
				;;
			s)
				saveCfg
				;;
			p)
				return
				;;
		esac
	done
}

function saveCfg() {
	local buffer=$1
	if [ -z "${buffer}" ]
	then
		echo
		read -p " ==> File to save [${CFG_FILE}]: " buffer
		[ ! -z "${buffer}" ] && CFG_FILE=${buffer}
	fi
	touch ${CFG_FILE}
	
	if [ -w ${CFG_FILE} ]
	then
		echo "## Configuration file for manageCA.sh script" > ${CFG_FILE}
		echo >> ${CFG_FILE}
		echo "# Country Code for certificate" >> ${CFG_FILE}
		echo "COUNTRYNAME=\"${COUNTRYNAME}\"" >> ${CFG_FILE}
		echo >> ${CFG_FILE}
		echo "# State Name for certificate" >> ${CFG_FILE}
		echo "STATE=\"${STATE}\"" >> ${CFG_FILE}
		echo >> ${CFG_FILE}
		echo "# City Name for certificate" >> ${CFG_FILE}
		echo "CITY=\"${CITY}\"" >> ${CFG_FILE}
		echo >> ${CFG_FILE}
		echo "# Company Name for certificate" >> ${CFG_FILE}
		echo "COMPANY=\"${COMPANY}\"" >> ${CFG_FILE}
		echo >> ${CFG_FILE}
		echo "# OCSP URL for certificate" >> ${CFG_FILE}
		echo "OCSP_URL=\"${OCSP_URL}\"" >> ${CFG_FILE}
		echo >> ${CFG_FILE}
		echo "# PKI Default Path" >> ${CFG_FILE}
		echo "PKI_PATH=\"${PKI_PATH}\"" >> ${CFG_FILE}
		echo >> ${CFG_FILE}
	else
		echo
		echo "Error: ${CFG_FILE} is not writable for you"
		read -p "Press [enter] to continue" DUMMY
	fi
}

function testCA() {
	if [ ! -f ${PKI_PATH}/${NAME}/ssl.cnf ]
	then
		echo
		echo
		echo -e "\033[31m !!! CA not found, initialize CA first !!! \033[0m"
		echo
		read -p "Press any key to switch back to the previous menu: "
		return 1
	fi
	return 0
}

function addUser() {
	testCA
	local retval=$?
	if [ ${retval} -eq 1 ]
	then
		return
	fi
	local user
	local email
	local usage="client"
	local buffer
	local userdata
	printSubMenu "Create a client certificate"
	read -p " ==> User name [NONE]: " user
	if [[ "${user}" == "" ]]
	then
		return
	fi
	echo
	read -p " ==> User email [NONE]: " email
	if [[ "${email}" == "" ]]
	then
		return
	fi
	echo
	
	read -p " ==> Select Usage Key (server, client or ocsp) [client]: " buffer
	[ -z "${buffer}" ] || usage=${buffer}
	echo
	if [[ "${usage}" == "client" ]]
	then
		read -p " ==> Custom Organization Unit Name [User]: " oun
		[ -z "${oun}" ] && oun="User"
		echo
	fi
	if [[ "${usage}" == "ocsp" ]]
	then
		extension="-extensions OCSP"
		altname=""
	else
		read -p "Add OCSP Extension to Certificate ? [Y/n]: " buffer
		[ -z "${buffer}" ] && buffer="y"
		if [[ "${buffer}" == "y" ]]
		then
			if [[ "${usage}" == "server" ]]
			then
				extension="-extensions OCSP_SERVER"
				altname=$(getAlternativeName)
			else
				extension="-extensions OCSP_CLIENT"
				altname=""
			fi
		else
			extension=""
			altname=""
		fi
	fi
	
	openssl genrsa -out ${PKI_PATH}/${NAME}/private/${user}-${email}.key 2048 \
		1>/dev/null 2>&1
	if [[ "${usage}" != "server" ]]
	then
		userdata="organizationalUnitName_default  = ${oun}\n"
	else
		userdata="organizationalUnitName_default  = Admin\n"
	fi
	userdata="${userdata}commonName_default              = ${user}\n"
	userdata="${userdata}emailAddress_default            = ${email}"
	cat ${PKI_PATH}/${NAME}/ssl.cnf | tr -d '#' | \
		sed -e "s/@USERDATA@/${userdata}/" \
		-e "s/@ALTNAME@/${altname}/" \
		> ${PKI_PATH}/${NAME}/ssl2.cnf
	openssl req -config ${PKI_PATH}/${NAME}/ssl2.cnf -new -nodes -batch \
		-out ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr \
		-key ${PKI_PATH}/${NAME}/private/${user}-${email}.key
	openssl ca -config ${PKI_PATH}/${NAME}/ssl2.cnf \
		-cert ${PKI_PATH}/${NAME}/${NAME}ca.crt ${extension} \
		-out ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		-outdir ${PKI_PATH}/${NAME}/certs \
		-infiles ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr
	cat ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		${PKI_PATH}/${NAME}/private/${user}-${email}.key \
			> ${PKI_PATH}/${NAME}/pem/${user}-${email}.pem
	mv ${PKI_PATH}/${NAME}/ssl2.cnf ${PKI_PATH}/${NAME}/confs/${user}-${email}-ssl.cnf
	read -p "Press [enter] to continue" DUMMY
}

function webUser() {
	testCA
	local retval=$?
	if [ ${retval} -eq 1 ]
	then
		return
	fi
	local user
	printSubMenu "Create a Client Certificate for Web"
	printUserList
	echo
	read -p " ==> User name [NONE]: " user
	if [[ "${user}" == "" ]]
	then
		return
	fi
	echo
	read -p " ==> User email [NONE]: " email
	if [[ "${email}" == "" ]]
	then
		return
	fi
	echo
	if [ -f ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt ]
	then
		openssl pkcs12 -export -inkey ${PKI_PATH}/${NAME}/private/${user}-${email}.key \
			-in ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
			-CAfile ${PKI_PATH}/${NAME}/${NAME}ca.crt \
			-out ${PKI_PATH}/${NAME}/certs/${user}-${email}_browser_cert.p12
	fi
	echo
	[ -f ${PKI_PATH}/${NAME}/certs/${user}-${email}_browser_cert.p12 ] \
		&& echo "Web certificate: ${PKI_PATH}/${NAME}/certs/${user}-${email}_browser_cert.p12" \
		|| echo "Error encoured"
	echo
	read -p "Press [enter] to continue" DUMMY
}

function renewUser() {
	testCA
	local retval=$?
	if [ ${retval} -eq 1 ]
	then
		return
	fi
	local user
	printSubMenu "Renew a Server Certificate"
	printUserList
	echo
	read -p " ==> User name [NONE]: " user
	if [[ "${user}" == "" ]]
	then
		echo "Error: Name cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	echo
	read -p " ==> User email [NONE]: " email
	if [[ "${email}" == "" ]]
	then
		return
	fi
	echo
	revokeUser ${user} ${email}
	openssl ca -config ${PKI_PATH}/${NAME}/confs/${user}-${email}-ssl.cnf \
        -out ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
        -outdir ${PKI_PATH}/${NAME}/certs \
        -infiles ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr
	cat ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		${PKI_PATH}/${NAME}/private/${user}-${email}.key \
			> ${PKI_PATH}/${NAME}/pem/${user}-${email}.pem
	echo
	read -p "Press [enter] to continue" DUMMY
}

function revokeUser() {
	testCA
	local retval=$?
	if [ ${retval} -eq 1 ]
	then
		return
	fi
	local user=$1
	local email=$2
	printSubMenu "Revoke a Client Certificate"
	printUserList
	echo
	[ -z "${user}" ] && read -p " ==> User name [NONE]: " user
	if [[ "${user}" == "" ]]
	then
		return
	fi
	echo
	[ -z "${email}" ] && read -p " ==> User email [NONE]: " email
	if [[ "${email}" == "" ]]
	then
		return
	fi
	echo
	openssl ca -revoke ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		-config ${PKI_PATH}/${NAME}/ssl.cnf
	# Save old certificate
	x=1
	while [ -f "${PKI_PATH}/${NAME}/certs/${user}-${email}.revoked.$x.crt" ]
	do
		x=$(( $x + 1 ))
	done
		cp ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt ${PKI_PATH}/${NAME}/certs/${user}-${email}.revoked.$x.crt
	
	x=1
	while [ -f "${PKI_PATH}/${NAME}/pem/${user}-${email}.revoked.$x.pem" ]
	do
		x=$(( $x + 1 ))
	done
	cp ${PKI_PATH}/${NAME}/pem/${user}-${email}.pem ${PKI_PATH}/${NAME}/pem/${user}-${email}.revoked.$x.pem
	echo
	regenCRL
	read -p "Press [enter] to continue" DUMMY
}

function regenCRL() {
	testCA
	local retval=$?
	if [ ${retval} -eq 1 ]
	then
		return
	fi
	openssl ca -gencrl -config ${PKI_PATH}/${NAME}/ssl.cnf \
		-out ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl
	retval=$?
	echo
	if [ ${retval} -eq 0 ]
	then
		echo "CRL regenerated."
	else
		echo "Error encoured during CRL regeneration process !!!"
	fi
}

function regenerateCRL() {
	printSubMenu "Regen CRL"
	regenCRL
	echo
	read -p "Press [enter] to continue" DUMMY
}

function listUser() {
	testCA
	local retval=$?
	if [ ${retval} -eq 1 ]
	then
		return
	fi
	printSubMenu "List Client Certificates"
	while [ 1 ]
	do
	   read LINE || break
	   LISTNUM=`echo ${LINE} | grep -v "^R" | awk '{ print $3 }'`
	   LISTCN=`echo ${LINE} | grep -v "^R" | awk -F 'CN=' '{ print $2 }' | cut -d '/' -f1`
	   LISTEMAIL=`echo ${LINE} | grep -v "^R" | awk -F 'emailAddress=' '{ print $2 }' | cut -d '/' -f1`
	   [ -z "${LISTNUM}" ] || echo " ${LISTNUM} ${LISTCN} (${LISTEMAIL})"
	done < ${PKI_PATH}/${NAME}/index.txt
	echo
	read -p "Press [enter] to continue" DUMMY
}

function printUserList() {
	testCA
	local retval=$?
	if [ ${retval} -eq 1 ]
	then
		return
	fi
	while [ 1 ]
	do
	   read LINE || break
	   LISTNUM=`echo ${LINE} | grep -v "^R" | awk '{ print $3 }'`
	   LISTCN=`echo ${LINE} | grep -v "^R" | awk -F CN= '{ print $2 }' | cut -d '/' -f1`
	   LISTEMAIL=`echo ${LINE} | grep -v "^R" | awk -F 'emailAddress=' '{ print $2 }' | cut -d '/' -f1`
	   [ -z "${LISTCN}" ] || echo "- ${LISTNUM} ${LISTCN} (${LISTEMAIL})"
	done < ${PKI_PATH}/${NAME}/index.txt
}

function changeDefaultPath() {
	local buffer
	read -p " ==> Select New path for CA [${PKI_PATH}]: " buffer
	if [ ! -z "${buffer}" ]; then PKI_PATH=${buffer} ; fi
}

function changeName() {
	read -p " ==> Select New CA name [NONE]: " NAME
}

function getAlternativeName() {
	local buffer
	local altname
	
	read -p " ==> Add Alternative Name [N/y]: " buffer
	[ -z "${buffer}" ] && buffer="n"
	if [[ "${buffer}" == "y" ]]
	then
		if [ -z "${altname}" ]
		then
			altname="subjectAltName                  = @alt_names"
			altname="${altname}\n\n[alt_names]"
		fi
		local i=1
		while [ ! -z "${buffer}" ]
		do
			read -p "  => Alternative Name [NONE]: " buffer
			if [ ! -z "${buffer}" ]
			then
				altname="${altname}\nDNS.${i}                           = ${buffer}"
			fi
			i=$(($i+1))
		done
	fi
	
	read -p " ==> Add Alternative IP Address [N/y]: " buffer
	[ -z "${buffer}" ] && buffer="n"
	if [[ "${buffer}" == "y" ]]
	then
		if [ -z "${altname}" ]
		then
			altname="subjectAltName                  = @alt_names"
			altname="${altname}\n\n[alt_names]"
		fi
		local i=1
		while [ ! -z "${buffer}" ]
		do
			read -p "  => Alternative IP Address [NONE]: " buffer
			if [ ! -z "${buffer}" ]
			then
				altname="${altname}\nIP.${i}                            = ${buffer}"
			fi
			i=$(($i+1))
		done
	fi
	
	echo ${altname}
}

function initCA() {
	local altname
	printSubMenu "${NAME} CA Initialisation"
	if [ -f ${PKI_PATH}/${NAME}/ssl.cnf ]
	then
		read -p "!!! Already initalized, delete CA first !!!"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	read -p " ==> Fully qualified Hostname [NONE]: " hostname
	if [ -z "$hostname" ]
	then
		echo "Error: Fully qualified Hostname cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	echo
	read -p " ==> Admin email [NONE]: " email
	if [ -z "$email" ]
	then
		echo "Error: email cannot be empty"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	echo
	
	altname=$(getAlternativeName)
	
	mkdir -p ${PKI_PATH}/${NAME}/{certs,newcerts,private,confs,crl,pem}
	initConfig
	touch ${PKI_PATH}/${NAME}/index.txt
	[ -f ${PKI_PATH}/${NAME}/serial ] || echo 01 > ${PKI_PATH}/${NAME}/serial
	[ -f ${PKI_PATH}/${NAME}/crlnumber ] || echo 01 > ${PKI_PATH}/${NAME}/crlnumber
	[ -f ${PKI_PATH}/${NAME}/private/${NAME}ca.key ] || \
		openssl genrsa -out ${PKI_PATH}/${NAME}/private/${NAME}ca.key 2048 \
		1>/dev/null 2>&1
	local userdata="organizationalUnitName_default  = Admin\n"
	userdata="${userdata}commonName_default              = ${hostname}\n"
	userdata="${userdata}emailAddress_default            = ${email}"
	cat ${PKI_PATH}/${NAME}/ssl.cnf | tr -d '#' | \
		sed -e "s/@USERDATA@/${userdata}/" \
		-e "s/@ALTNAME@/${altname}/" \
		> ${PKI_PATH}/${NAME}/ssl2.cnf
	openssl req -config ${PKI_PATH}/${NAME}/ssl2.cnf -new -x509 -days 3650 -batch \
		-key ${PKI_PATH}/${NAME}/private/${NAME}ca.key \
		-out ${PKI_PATH}/${NAME}/${NAME}ca.crt -extensions v3_ca
	mv ${PKI_PATH}/${NAME}/ssl2.cnf ${PKI_PATH}/${NAME}/confs/ca.cnf
	[ -f ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl ] || regenCRL \
		-config ${PKI_PATH}/${NAME}/ssl.cnf -out ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl
	local hash=`openssl crl -hash -noout -in ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl`
	ln -s ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl ${PKI_PATH}/${NAME}/crl/$hash.r0
	echo
	echo "CA initialized"
	echo
	openssl x509 -in ${PKI_PATH}/${NAME}/${NAME}ca.crt -noout -text
	echo
	read -p "Press [enter] to continue" DUMMY
}

function deleteCA() {
	printSubMenu "Deleting CA"
	read -p " ==> Are you sure ? Type uppercase YES to confirm: " CONFIRM
	if [[ "${CONFIRM}" == "YES" ]]
	then
		rm -rf ${PKI_PATH}/${NAME}
		echo
		echo "CA completely deleted"
		echo
		read -p "Press [enter] to continue" DUMMY
	fi
}

function initConfig() {
	cat << 'EOF' > ${PKI_PATH}/${NAME}/ssl.cnf
HOME                            = @HOME@
RANDFILE                        = @HOME@/.rand

[ca] 
default_ca                      = ca_default

[ca_default] 
dir                             = @HOME@
certs                           = $dir/certs
crl_dir                         = $dir/crl
database                        = $dir/index.txt
new_certs_dir                   = $dir/newcerts
certificate                     = $dir/@NAME@ca.crt
private_key                     = $dir/private/@NAME@ca.key
serial                          = $dir/serial
crl                             = $dir/crl/@NAME@ca.crl
crlnumber                       = $dir/crlnumber
crl_extensions                  = crl_ext
x509_extensions                 = usr_cert
name_opt                        = ca_default
cert_opt                        = ca_default
default_days                    = 365
default_crl_days                = 30
default_md                      = md5
preserve                        = no
policy                          = policy_match

[policy_match] 
countryName                     = match
stateOrProvinceName             = match
organizationName                = match
organizationalUnitName          = optional
commonName                      = supplied
emailAddress                    = optional

[req] 
default_bits                    = 1024
default_keyfile                 = privkey.pem
distinguished_name              = req_distinguished_name
attributes                      = req_attributes
x509_extensions                 = v3_ca
string_mask                     = MASK:0x2002

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
keyUsage                        = keyEncipherment, dataEncipherment
extendedKeyUsage                = serverAuth
##@ALTNAME@

[crl_ext]
authorityKeyIdentifier=keyid:always,issuer:always

[OCSP]
basicConstraints                = CA:FALSE
keyUsage                        = digitalSignature
extendedKeyUsage                = OCSPSigning
issuerAltName                   = issuer:copy
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid:always,issuer:always
authorityInfoAccess             = OCSP;URI:@OCSPURL@
 
[OCSP_SERVER]
nsComment                       = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid,issuer:always
issuerAltName                   = issuer:copy
basicConstraints                = critical,CA:FALSE
keyUsage                        = digitalSignature, nonRepudiation, keyEncipherment
nsCertType                      = server
extendedKeyUsage                = serverAuth
authorityInfoAccess             = OCSP;URI:@OCSPURL@
 
[OCSP_CLIENT]
nsComment                       = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid,issuer:always
issuerAltName                   = issuer:copy
basicConstraints                = critical,CA:FALSE
keyUsage                        = digitalSignature, nonRepudiation
nsCertType                      = client
extendedKeyUsage                = clientAuth
authorityInfoAccess             = OCSP;URI:@OCSPURL@

EOF
	sed -i \
		-e "s#@HOME@#${PKI_PATH}/${NAME}#g" \
		-e "s#@NAME@#${NAME}#g" \
		-e "s#@COUNTRYNAME@#${COUNTRYNAME}#g" \
		-e "s#@STATE@#${STATE}#g" \
		-e "s#@CITY@#${CITY}#g" \
		-e "s#@ORGANISATION@#${COMPANY}#g" \
		-e "s#@OCSPURL@#${OCSP_URL}#g" \
		${PKI_PATH}/${NAME}/ssl.cnf
}

#Main program


# process command line arguments
while getopts "?hurp:n:c:" opt
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
		c)
			CFG_FILE=${OPTARG}
			;;
		p)
			pkipath=${OPTARG}
			;;
		n)
			NAME=$OPTARG
			;;
		r)
			REGEN_ONLY=1
			;;
		*)
			"Unknow option: ${opt}"
	esac
done

if [ ${REGEN_ONLY} -ne 0 ]
then
	if [ -z "${NAME}" ]
	then
		echo "Error: No name provided."
		echo "You must specify name with the '-n' option"
		exit 1
	fi
	regenCRL
	exit 0
fi

# Load config
[ -f ${CFG_FILE} ] && source ${CFG_FILE} || manageOptions

clear
[ -z "${NAME}" ] && changeName
# Overwrite PKI path if option is provided.
[ ! -z "${pkipath}" ] && PKI_PATH="${pkipath}"
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
		R|r)
			regenerateCRL
			;;
		O|o)
			manageOptions
			;;
	esac
done
