#!/bin/bash

## curl -X GET -H "X-DC-DEVKEY: <chiave utente> " -H "Content-Type: application/json" "https://www.digicert.com/services/v2/organization"

if [ -z "$1" ]
  then
          echo "No certificate FQDN argument supplied"
          echo "usage:  please provide 3 input parameters:  FQDN of server, Token of user, ORG-ID" 
          exit
fi

if [ -z "$2" ]
  then
          echo "No user digicert key (token) provided"
          echo "usage:  please provide 3 input parameters:  FQDN of server, Token of user, ORG-ID" 
          exit
fi

if [ -z "$3" ]
  then
          echo "No ORG-ID provided or other required input parameters"
          echo "usage:  provide 3 input parameters:  FQDN of server, Token of user, ORG-ID" 
          exit
fi

if [ -e myfile ]; then
  rm myfile
fi
if [ -e data-corrected1.json ]; then
  rm data-corrected1.json
fi
if [ -e data1.json ]; then
  rm data1.json
fi
if [ -e data1-template.json ]; then
  rm data1-template.json
fi
if [ -e data-final.json ]; then
  rm data-final.json
fi
if [ -e interfile ]; then
        rm interfile
fi
if [ -e fqdnfile ]; then
  rm fqdnfile
fi
if [ -e request-id-output ]; then
  rm request-id-output
fi
if [ -e ssl-approve.json ]; then
  rm ssl-approve.json
fi
if [ -e orderidfile ]; then
  rm orderidfile
fi
if [ -e certidfile ]; then
  rm certidfile
fi
if [ -e reqidfile ]; then
  rm reqidfile
fi
if [ -e certid-output ]; then
  rm certid-output
fi


touch  myfile
touch data-corrected1.json
touch  data1-template.json


echo $1 > fqdnfile

echo "========================="
export FQDN=$1
echo  "FQDN = " $FQDN

export USERTOK=$2
echo  "USER KEY - TOKEN = " $USERTOK

export ORGID=$3
echo "ORG ID = " $ORGID

echo "========================="


cat >  data1-template.json <<EOF
{
  "certificate": {
    "common_name": "FQDN",
    "csr": "request",
    "server_platform": {
      "id": 2
    },
    "signature_hash": "sha512"
  },
  "organization": {
    "id": #ORGID#
  },
  "validity_years": 2
}
EOF

cat data1-template.json | sed "s/#ORGID#/$ORGID/g" > data1.json

cat >  ssl-approve.json <<EOF
{
  "status": "approved"
}
EOF


openssl genrsa -out ${FQDN}.key 4096

openssl req -new -sha512 -key ${FQDN}.key -out ${FQDN}.csr -subj "/CN=${FQDN}"   

sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' ${FQDN}.csr

sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' ${FQDN}.csr  > myfile

echo "============================ " 

perl -pe 's/request/`head -c -1 -q myfile`/e' data1.json > interfile
perl -pe 's/FQDN/`head -c -1 -q fqdnfile`/e' interfile  > data-final.json

echo "sending certificate request to Digicert..."

curl -X POST -H "X-DC-DEVKEY: $USERTOK" -H "Content-Type: application/json" https://www.digicert.com/services/v2/order/certificate/ssl_multi_domain --data-binary @data-final.json > request-id-output

cat request-id-output | awk 'BEGIN { FS = ":" } $0 ~ // {print $4}' | awk 'BEGIN { FS = "," } // {print $1}' > reqidfile

cat request-id-output | awk 'BEGIN { FS = ":" } $0 ~ // {print $2}' |  awk 'BEGIN { FS = "," } // {print $1}' > orderidfile

reqid=`cat reqidfile`
orderid=`cat orderidfile`


echo "Submitted request ID = " $reqid
echo
echo "ORDER ID = " $orderid
echo 
echo "==================================================================" 

curl -X PUT -H "X-DC-DEVKEY: $USERTOK"  -H "Content-Type: application/json" https://www.digicert.com/services/v2/request/$reqid/status --data-binary @ssl-approve.json

sleep 2

a=`curl -X GET -H "X-DC-DEVKEY: $USERTOK" -H "Content-Type: application/json" https://www.digicert.com/services/v2/order/certificate/$orderid | awk 'BEGIN { FS = ":" } $0 ~ // {print $4}' |  awk 'BEGIN { FS = "," } // {print $1}'`

echo "CERTIFICATE ID = " $a

sleep 5

echo "Downloading certificate locally ......."

curl -X GET -H "X-DC-DEVKEY: $USERTOK" -H "Content-Type: application/json" https://www.digicert.com/services/v2/certificate/$a/download/format/pem_nointermediate

curl -X GET -H "X-DC-DEVKEY: $USERTOK" -H "Content-Type: application/json" https://www.digicert.com/services/v2/certificate/$a/download/format/pem_nointermediate >  certificato_pem_$FQDN.pem
