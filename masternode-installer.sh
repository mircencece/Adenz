#!/bin/bash
clear

# Set these to change the version of Adenz to install
TARBALLURL="https://github.com/AdenzProject/Adenz/releases/download/v1.3/binaries.tgz"
TARBALLNAME="binaries.tgz"
FGCVERSION="1.3"

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 900 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
clear

echo "
    ___T_
   | o o |
   |__-__|
   /| []|\\
 ()/|___|\()
    |_|_|
    /_|_\  ------- MASTERNODE INSTALLER v2.1 -------+
 |                                                |
 |You can choose between two installation options:|::
 |             default and advanced.              |::
 |                                                |::
 | The advanced installation will install and run |::
 |  the masternode under a non-root user. If you  |::
 |  don't know what that means, use the default   |::
 |              installation method.              |::
 |                                                |::
 | Otherwise, your masternode will not work, and  |::
 |the FGC Team CANNOT assist you in repairing |::
 |        it. You will have to start over.        |::
 |                                                |::
 |Don't use the advanced option unless you are an |::
 |            experienced Linux user.             |::
 |                                                |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::
"

sleep 5

read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then

USER=dnz

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

echo "" && echo 'Added user "dnz"' && echo ""
sleep 1

else

USER=root

fi

USERHOME=`eval echo "~$USER"`

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
  aptitude -y -q install fail2ban
  service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 15288/tcp
  yes | ufw enable
fi

# Install Adenz daemon
wget $TARBALLURL
tar -xzvf $TARBALLNAME #&& mv bin dnz-$FGCVERSION
rm $TARBALLNAME
cp ./dnzd /usr/local/bin
cp ./dnz-cli /usr/local/bin
cp ./dnz-tx /usr/local/bin
rm -rf dnz-$FGCVERSION

# Create .dnz directory
mkdir $USERHOME/.dnz

# Install bootstrap file
#if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
#  echo "Installing bootstrap file..."
#  wget $BOOTSTRAPURL && unzip $BOOTSTRAPARCHIVE -d $USERHOME/.dnz/ && rm $BOOTSTRAPARCHIVE
#fi

# Create dnz.conf
touch $USERHOME/.dnz/dnz.conf
cat > $USERHOME/.dnz/dnz.conf << EOL
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:4361
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1
EOL
chmod 0600 $USERHOME/.dnz/dnz.conf
chown -R $USER:$USER $USERHOME/.dnz

sleep 1

cat > /etc/systemd/system/dnzd.service << EOL
[Unit]
Description=dnzd
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/dnzd -conf=${USERHOME}/.dnz/dnz.conf -datadir=${USERHOME}/.dnz
ExecStop=/usr/local/bin/dnz-cli -conf=${USERHOME}/.dnz/dnz.conf -datadir=${USERHOME}/.dnz stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl enable dnzd
sudo systemctl start dnzd
sudo systemctl start dnzd.service

#clear

clear
echo "Your masternode is syncing. Please wait for this process to finish."

sleep 1
clear
su -c "/usr/local/bin/dnz-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode setup completed." && echo ""
