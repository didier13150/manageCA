#!/bin/bash
################################################################################
# Author: Didier Fabert
# Rev 0.7.3
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
KEY_SIZE="2048"
MESSAGE_DIGEST="sha256"

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
	echo -e "  -k <INT>      Default key size [2048]"
	echo -e "  -d <DIGEST>   Message Digest [sha256]"
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
        [ -z "${2}" ] && clear
        echo "-----------------------------------------------------------------"
        echo -e "${1}"
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
		echo -e "\033[31m !!! Error: ${CFG_FILE} is not writable for you !!! \033[0m"
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
	printSubMenu "Create certificate"
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
	else
		read -p "Add OCSP Extension to Certificate ? [Y/n]: " buffer
		[ -z "${buffer}" ] && buffer="y"
		if [[ "${buffer}" == "y" ]]
		then
			if [[ "${usage}" == "server" ]]
			then
				extension="-extensions OCSP_SERVER"
			else
				extension="-extensions OCSP_CLIENT"
			fi
		else
			extension=""
		fi
	fi
	
	if [ -f "${PKI_PATH}/${NAME}/private/${user}-${email}.key" ]
	then
		echo -e "\033[31m !!! A User with same common name and same email already exists !!! \033[0m"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	
	comfirmExec "${usage} certificate" "${user}" "${email}" "${altname}"
	retval=$?
	[ ${retval} -ne 0 ] && return
	echo
	
	echo -n "Generate ${KEY_SIZE} bits key:"
	openssl genrsa -out ${PKI_PATH}/${NAME}/private/${user}-${email}.key ${KEY_SIZE} \
		1>/dev/null 2>&1
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -f ${PKI_PATH}/${NAME}/private/${user}-${email}.key
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	if [[ "${usage}" != "server" ]]
	then
		userdata="organizationalUnitName_default  = ${oun}\n"
	else
		userdata="organizationalUnitName_default  = Admin\n"
	fi
	userdata="${userdata}commonName_default              = ${user}\n"
	userdata="${userdata}emailAddress_default            = ${email}"
	
	echo -n "Prepare config file: "
	cat ${PKI_PATH}/${NAME}/ssl.cnf | tr -d '#' | \
		sed -e "s/@USERDATA@/${userdata}/" \
		> ${PKI_PATH}/${NAME}/ssl2.cnf
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -f ${PKI_PATH}/${NAME}/private/${user}-${email}.key
		rm -f ${PKI_PATH}/${NAME}/ssl2.cnf
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	echo -n "Create certificate request: "
	openssl req -config ${PKI_PATH}/${NAME}/ssl2.cnf -new -nodes -batch \
		-out ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr \
		-key ${PKI_PATH}/${NAME}/private/${user}-${email}.key
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -f ${PKI_PATH}/${NAME}/private/${user}-${email}.key
		rm -f ${PKI_PATH}/${NAME}/ssl2.cnf
		rm -f ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	echo "Start Signing certificate request"
	openssl ca -config ${PKI_PATH}/${NAME}/ssl2.cnf \
		-cert ${PKI_PATH}/${NAME}/${NAME}ca.crt ${extension} \
		-out ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		-outdir ${PKI_PATH}/${NAME}/certs \
		-infiles ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr
	echo -n "Sign certificate request: "
	if [ -s ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -f ${PKI_PATH}/${NAME}/private/${user}-${email}.key
		rm -f ${PKI_PATH}/${NAME}/ssl2.cnf
		rm -f ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr
		rm -f ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	echo -n "Create pem file which contains both key and certificate: "
	cat ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		${PKI_PATH}/${NAME}/private/${user}-${email}.key \
			> ${PKI_PATH}/${NAME}/pem/${user}-${email}.pem
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		return
	fi
	echo -n "Save config file for ${user} (${email}) on confs directory: "
	mv ${PKI_PATH}/${NAME}/ssl2.cnf ${PKI_PATH}/${NAME}/confs/${user}-${email}-ssl.cnf
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		read -p "Press [enter] to continue" DUMMY
		return
	fi
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
	else
		echo -e "\033[31m !!! Error: Certificate not found !!! \033[0m"
	fi
	echo -n "Create web certificate"
	if [ -f ${PKI_PATH}/${NAME}/certs/${user}-${email}_browser_cert.p12 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
		echo "Web certificate: ${PKI_PATH}/${NAME}/certs/${user}-${email}_browser_cert.p12"
	else
		echo -e "\033[31m FAILURE \033[0m"
	fi
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
	echo -n "Renew certificate: "
	openssl ca -config ${PKI_PATH}/${NAME}/confs/${user}-${email}-ssl.cnf \
        -out ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
        -outdir ${PKI_PATH}/${NAME}/certs \
        -infiles ${PKI_PATH}/${NAME}/certs/${user}-${email}.csr
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		return
	fi
        
	echo -n "Regenerate pem: "
	cat ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		${PKI_PATH}/${NAME}/private/${user}-${email}.key \
			> ${PKI_PATH}/${NAME}/pem/${user}-${email}.pem
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		return
	fi
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
	
	echo -n "Revoke certificate: "
	openssl ca -revoke ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt \
		-config ${PKI_PATH}/${NAME}/ssl.cnf
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		return
	fi
	
	# Save old certificate
	echo -n "Save old certificate: "
	x=1
	while [ -f "${PKI_PATH}/${NAME}/certs/${user}-${email}.revoked.$x.crt" ]
	do
		x=$(( $x + 1 ))
	done
	cp ${PKI_PATH}/${NAME}/certs/${user}-${email}.crt ${PKI_PATH}/${NAME}/certs/${user}-${email}.revoked.$x.crt
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		return
	fi
	
	echo -n "Save old pem: "
	x=1
	while [ -f "${PKI_PATH}/${NAME}/pem/${user}-${email}.revoked.$x.pem" ]
	do
		x=$(( $x + 1 ))
	done
	cp ${PKI_PATH}/${NAME}/pem/${user}-${email}.pem ${PKI_PATH}/${NAME}/pem/${user}-${email}.revoked.$x.pem
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		return
	fi
	
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
		return 1
	fi
	return 0
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

function comfirmExec() {
	local type=${1}
	local hostname=${2}
	local email=${3}
	local altname=${4}
	local summary
	local buffer
	
	summary="CN:     ${hostname}"
	summary="${summary}\nAdmin email:  ${email}"
	if [ ! -z "${altname}" ]
	then
		summary="${summary}\nAlter name:"
		summary="${summary}\n$(echo -e ${altname} | grep '^DNS' | awk -F '=' '{print $2}')"
		summary="${summary}\n$(echo -e ${altname} | grep '^IP' | awk -F '=' '{print $2}')"
	fi
	printSubMenu "$summary" "noclear"
	echo
	read -p " ==> Create ${type} with this parameters ? [Y/n]: " buffer
	[ -z "${buffer}" ] && buffer="y"
	if [[ "${buffer}" != "y" ]]
	then
		return 1
	fi
	return 0
}

function initCA() {
	local altname
	local buffer
	printSubMenu "${NAME} CA Initialisation"
	if [ -f ${PKI_PATH}/${NAME}/ssl.cnf ]
	then
		echo -e "\033[31m !!! Already initalized, delete CA first !!! \033[0m"
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
	
	read -p " ==> Add Alternative Name [N/y]: " buffer
	[ -z "${buffer}" ] && buffer="n"
	if [[ "${buffer}" == "y" ]]
	then
		echo
		echo "Just press [ENTER] to stop asking alternative"
		echo
		local i=1
		if [ -z "${altname}" ]
		then
			altname="subjectAltName                  = @alt_names"
			altname="${altname}\n\n[alt_names]"
			altname="${altname}\nDNS.${i}                           = ${hostname}"
			i=$(($i+1))
		fi
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
	echo
	
	read -p " ==> Add Alternative IP Address [N/y]: " buffer
	[ -z "${buffer}" ] && buffer="n"
	if [[ "${buffer}" == "y" ]]
	then
		echo
		echo "Just press [ENTER] to stop asking alternative"
		echo
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
	echo
	
	comfirmExec "certificate authority" "${hostname}" "${email}" "${altname}"
	local retval=$?
	[ ${retval} -ne 0 ] && return
	
	
	echo -n "Create CA Tree:"
	mkdir -p ${PKI_PATH}/${NAME}/{certs,newcerts,private,confs,crl,pem}
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -rf ${PKI_PATH}/${NAME}
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	initConfig "${altname}"
	echo
	
	echo -n "Init CA index:"
	touch ${PKI_PATH}/${NAME}/index.txt
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -rf ${PKI_PATH}/${NAME}
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	if [ ! -f ${PKI_PATH}/${NAME}/serial ]
	then
		echo -n "Init CA serial:"
		echo 01 > ${PKI_PATH}/${NAME}/serial
		retval=$?
		if [ ${retval} -eq 0 ]
		then
			echo -e "\033[32m SUCCESS \033[0m"
		else
			echo -e "\033[31m FAILURE \033[0m"
			rm -rf ${PKI_PATH}/${NAME}
			read -p "Press [enter] to continue" DUMMY
			return
		fi
	fi
	if [ ! -f ${PKI_PATH}/${NAME}/crlnumber ]
	then
		echo -n "Init CA CRL:"
		echo 01 > ${PKI_PATH}/${NAME}/crlnumber
		retval=$?
		if [ ${retval} -eq 0 ]
		then
			echo -e "\033[32m SUCCESS \033[0m"
		else
			echo -e "\033[31m FAILURE \033[0m"
			rm -rf ${PKI_PATH}/${NAME}
			read -p "Press [enter] to continue" DUMMY
			return
		fi
	fi
	
	if [ ! -f ${PKI_PATH}/${NAME}/private/${NAME}ca.key ]
	then
		echo -n "Generate ${KEY_SIZE} bits key:"
		openssl genrsa -out ${PKI_PATH}/${NAME}/private/${NAME}ca.key ${KEY_SIZE} \
		1>/dev/null 2>&1
		retval=$?
		if [ ${retval} -eq 0 ]
		then
			echo -e "\033[32m SUCCESS \033[0m"
		else
			echo -e "\033[31m FAILURE \033[0m"
			rm -rf ${PKI_PATH}/${NAME}
			read -p "Press [enter] to continue" DUMMY
			return
		fi
	fi
	local userdata="organizationalUnitName_default  = Certificate Authority\n"
	userdata="${userdata}commonName_default              = ${hostname}\n"
	userdata="${userdata}emailAddress_default            = ${email}"
	
	echo -n "Prepare CA config file: "
	cat ${PKI_PATH}/${NAME}/ssl.cnf | tr -d '#' | \
		sed -e "s/@USERDATA@/${userdata}/" \
		> ${PKI_PATH}/${NAME}/ssl2.cnf
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -rf ${PKI_PATH}/${NAME}
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	
	echo -n "Create CA:"
	openssl req -config ${PKI_PATH}/${NAME}/ssl2.cnf -new -x509 -days 3650 -batch \
		-key ${PKI_PATH}/${NAME}/private/${NAME}ca.key \
		-out ${PKI_PATH}/${NAME}/${NAME}ca.crt -extensions v3_ca
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -rf ${PKI_PATH}/${NAME}
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	
	echo -n "Save CA config file: "
	mv ${PKI_PATH}/${NAME}/ssl2.cnf ${PKI_PATH}/${NAME}/confs/ca.cnf
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -rf ${PKI_PATH}/${NAME}
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	
	if [ ! -f ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl ]
	then
		echo -n "Generate CRL: "
		regenCRL \
		-config ${PKI_PATH}/${NAME}/ssl.cnf -out ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl 1>/dev/null 2>&1
		retval=$?
		if [ ${retval} -eq 0 ]
		then
			echo -e "\033[32m SUCCESS \033[0m"
		else
			echo -e "\033[31m FAILURE \033[0m"
			rm -rf ${PKI_PATH}/${NAME}
			read -p "Press [enter] to continue" DUMMY
			return
		fi
	fi
	echo -n "Link CRL to Hash: "
	local hash=`openssl crl -hash -noout -in ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl`
	ln -s ${PKI_PATH}/${NAME}/crl/${NAME}ca.crl ${PKI_PATH}/${NAME}/crl/$hash.r0
	retval=$?
	if [ ${retval} -eq 0 ]
	then
		echo -e "\033[32m SUCCESS \033[0m"
	else
		echo -e "\033[31m FAILURE \033[0m"
		rm -rf ${PKI_PATH}/${NAME}
		read -p "Press [enter] to continue" DUMMY
		return
	fi
	
	echo
	echo "CA initialized"
	echo
	#openssl x509 -in ${PKI_PATH}/${NAME}/${NAME}ca.crt -noout -text
	#echo
	read -p "Press [enter] to continue" DUMMY
}

function deleteCA() {
	printSubMenu "Deleting CA"
	if [ -d ${PKI_PATH}/${NAME} ]
	then
		read -p " ==> Are you sure ? Type uppercase YES to confirm: " CONFIRM
		if [[ "${CONFIRM}" == "YES" ]]
		then
			rm -rf ${PKI_PATH}/${NAME}
			echo
			echo "CA completely deleted"
			echo
			read -p "Press [enter] to continue" DUMMY
		fi
	else
		echo -e "\033[31m !!! CA not exists !!! \033[0m"
		echo
		read -p "Press [enter] to continue" DUMMY
	fi
}

function initConfig() {
	local altname=${1}
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
default_md                      = @MESSAGEDIGEST@
preserve                        = no
policy                          = policy_match
copy_extensions                 = copy
default_bits                    = @KEYSIZE@

[policy_match] 
countryName                     = match
stateOrProvinceName             = match
organizationName                = match
organizationalUnitName          = optional
commonName                      = supplied
emailAddress                    = optional

[req] 
default_bits                    = @KEYSIZE@
default_md                      = @MESSAGEDIGEST@
default_keyfile                 = privkey.pem
distinguished_name              = req_distinguished_name
attributes                      = req_attributes
x509_extensions                 = v3_req
req_extensions                  = v3_req
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

[v3_req] 
subjectKeyIdentifier            = hash
basicConstraints                = CA:FALSE

[v3_ca] 
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid:always,issuer:always
basicConstraints                = CA:TRUE
@ALTNAME@

[crl_ext]
authorityKeyIdentifier          = keyid:always,issuer:always

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
keyUsage                        = digitalSignature, nonRepudiation, keyEncipherment, keyCertSign, cRLSign
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
		-e "s#@KEYSIZE@#${KEY_SIZE}#g" \
		-e "s#@ALTNAME@#${altname}#g" \
		-e "s#@MESSAGEDIGEST@#${MESSAGE_DIGEST}#g" \
		${PKI_PATH}/${NAME}/ssl.cnf
}
#Main program


# process command line arguments
while getopts "?hurp:n:c:k:d:" opt
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
			NAME=${OPTARG}
			;;
		r)
			REGEN_ONLY=1
			;;
		k)
			if [ ${OPTARG} -gt ${KEY_SIZE} ]
			then
				KEY_SIZE=${OPTARG}
			else
				echo "Error: Key size must be greater than ${KEY_SIZE}."
				exit 1
			fi
			;;
		d)
			MESSAGE_DIGEST=${OPTARG}
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
