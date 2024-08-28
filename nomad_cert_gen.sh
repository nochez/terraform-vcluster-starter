#!/bin/bash

DOMAIN="cluster.local"
ORG_UNIT="VCEF"
ORG_NAME="CSCS"
STREET_ADDRESS="Via Trevano"
POSTAL_CODE="6900"
LOCALITY="Lugano"
PROVINCE="TI"
COUNTRY="CH"
DAYS_VALID=1825
REGION="vm"
NAME_CONSTRAINT="false"
CERT_OUTPUT_DIR="./certificates"

# Create and cleanup output directory
mkdir -p "$CERT_OUTPUT_DIR"
rm -f "$CERT_OUTPUT_DIR"/*.pem

# Create Certificate Authority
echo "Creating Certificate Authority (CA)..."
nomad tls ca create \
 -common-name="Nomad Agent CA" \
 -domain="$DOMAIN" \
 -organizational-unit="$ORG_UNIT" \
 -organization="$ORG_NAME" \
 -street-address="$STREET_ADDRESS" \
 -postal-code="$POSTAL_CODE" \
 -locality="$LOCALITY" \
 -province="$PROVINCE" \
 -country="$COUNTRY" \
 -days="$DAYS_VALID" \
 -name-constraint="$NAME_CONSTRAINT" \
 -out="$CERT_OUTPUT_DIR/ca.pem"

# Function to check the exit status of the last command and exit if it failed
check_last_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

echo "Generating Wildcard Server Certificate..."
nomad tls cert create \
 -server \
 -domain="$DOMAIN" \
 -region="$REGION" \
 -additional-dnsname="*.$DOMAIN" \
 -out="$CERT_OUTPUT_DIR/server.pem"
check_last_command "Server certificate generation"

echo "Generating Wildcard Client Certificate..."
nomad tls cert create \
 -client \
 -domain="$DOMAIN" \
 -region="$REGION" \
 -additional-dnsname="*.$DOMAIN" \
 -out="$CERT_OUTPUT_DIR/client.pem"
check_last_command "Client certificate generation"

echo "Generating CLI Certificate..."
nomad tls cert create \
 -cli \
 -domain="$DOMAIN" \
 -region="$REGION" \
 -out="$CERT_OUTPUT_DIR/cli.pem"
check_last_command "CLI certificate generation"

echo "Certificates successfully generated into $CERT_OUTPUT_DIR"

