manageCA
========

Brief
-----

CLI tool to Manage Certificate Authority

Usage
-----

manageCA.sh [OPTIONS]

Options:
-u       print usage
-h, -?   print help
-c       config file
-p       PKI path ( where the CA will be created )
-n       Name of th CA
-r       Regenerate CRL only. -n option is mandatory.

Menu
----

- Create a client / server / OCSP certificate
- Create a web certificate (PKCS#12) from an existing certificate
- Renew a certificate
- Revoke a certificate
- List all certificates

- Initialize the Root Certificate Authority
- Regenerate CRL
- Delete entirely the Root Certificate Authority
- Show/Modify/Save CA Options

CA Options are saved on a config file:
- Country Name
- State Name
- City Name
- Company Name
- OCSP URL

=====================================================================
             Home-Didier Certificate Management System
=====================================================================

   1) Create a Client/Server/OCSP certificate

   2) Create a Client Certificate for Web (PKCS#12)

   3) Renew a Certificate

   4) Revoke a Certificate

   5) List Certificates


   i) Initialize Root Certificate Authority (CA)

   r) Regenerate CRL

   d) Delete CA

   o) Show/Modify/Save CA Options

   q) Quit


   Options available before init

   p) Change PKI default path [/etc/pki]

   n) Change CA name [httpd]


 ==> Make your choice [none]:
