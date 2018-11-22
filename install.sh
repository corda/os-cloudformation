#!/bin/bash -e

# Script to download and install Corda Open Source Binaries from Testnet
# Example:
#   ./install.sh 93.184.216.3 10001 6d21186f-3f67-41ce-887e-eff6415126c0 GB "Milton Keynes"

set -euo pipefail

# Parameters
PUBLIC_IP="$1"
P2P_PORT="$2"
TESTNET_KEY="$3"
COUNTRY="$4"
LOCALITY="$5"

# Constants
INSTALL_DIR="/opt/corda"
NODE_CONFIG_FILE="/opt/corda/node.conf"
TESTNET_URL="https://testnet.corda.network"
CORDA_CONFIG="DEFAULT"
CORDA_DISTRIBUTION="OPENSOURCE"

# Exits the process with a status indicating error
error() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [ERROR] $@" >> /dev/stderr
    exit 1
}

# Install Java 8
test $(rpm -qa java-1.8.0\* | wc -l) -gt 0 || sudo yum -y install java-1.8.0
test $(rpm -qa java-1.7.0-openjdk\* | wc -l) -eq 0 || sudo yum -y remove java-1.7.0-openjdk

# Create User
getent group corda &> /dev/null || sudo groupadd corda
getent passwd corda &> /dev/null || sudo adduser --gid corda --system --no-create-home corda

# Create Directories
sudo mkdir -p ${INSTALL_DIR}
sudo chown corda:corda ${INSTALL_DIR}
sudo -H -u corda mkdir -p "$INSTALL_DIR/cordapps"
sudo -H -u corda mkdir -p "$INSTALL_DIR/certificates"
sudo -H -u corda mkdir -p "$INSTALL_DIR/drivers"
cd ${INSTALL_DIR}

# Obtain Binaries
test -f "$INSTALL_DIR/corda.zip" || sudo -H -u corda curl -vLs \
    -d "{\"x500Name\":{\"locality\":\"$LOCALITY\",\"country\":\"$COUNTRY\"},\"configType\":\"$CORDA_CONFIG\",\"distribution\":\"$CORDA_DISTRIBUTION\"}" \
    -H "Content-Type: application/json" \
    -A "curl/AWS CloudFormation" \
    -X POST "$TESTNET_URL/api/user/node/generate/one-time-key/redeem/$TESTNET_KEY" \
    -o "$INSTALL_DIR/corda.zip" || error "Unable to download config template and truststore"

# Inflate Binaries
test -f "${INSTALL_DIR}/corda.jar" || sudo -H -u corda unzip "${INSTALL_DIR}/corda.zip" # 2> /dev/null || (cat "$INSTALL_DIR/corda.zip"; rm -f "$INSTALL_DIR/corda.zip"; error "Unable to unzip generated node bundle; was the correct one time download key used?")

# Patch Configuration File by replacing the line containing the default P2P address
sudo sed -i "s/.*p2pAddress.*/\    \"p2pAddress\" : \"$PUBLIC_IP:$P2P_PORT\",/" ${NODE_CONFIG_FILE}

# Install upstart Service
sudo tee /etc/init/corda.conf > /dev/null << 'EOF'
description "Corda"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
chdir /opt/corda
# FIXME `setuid corda` will fail since the version of upstart deployed to Amazon Linux is too old.
# setuid corda
exec su -s /bin/sh -c 'exec "$0" "$@"' corda -- java -Xmx2048m -jar /opt/corda/corda.jar
EOF
sudo chmod 644 /etc/init/corda.conf

# Start the Service
if [ $(sudo initctl list | grep corda | grep running | wc -l) -eq 0 ]
then
    sudo initctl start corda
else
    sudo initctl restart corda
fi
