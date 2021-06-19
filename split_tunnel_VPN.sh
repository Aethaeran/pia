#!/bin/bash

# By Georgiy Sitnikov.
#
# Will do setup Split Tunnel. More under:
# https://gist.github.com/GAS85/4e40ece16ffa748e7138b9aa4c37ca52
#
# AS-IS without any warranty

# Check if you are root user, otherwise will not work
[[ $(id -u) -eq 0 ]] || { echo >&2 "Must be root to run this script."; exit 1; }

# Optinally
#wget https://swupdate.openvpn.net/repos/repo-public.gpg -O - | apt-key add -
#echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" | tee -a /etc/apt/sources.list.d/openvpn.list

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
pink=`tput setaf 5`
cyan=`tput setaf 6`
devoid=`tput sgr0`

rem This was just to test if the colours were working.
rem echo "${red}red text ${green}green text ${yellow}yellow text ${blue}blue text ${pink}pink text ${cyan}cyan text ${reset}"

echo "${green}Step 1. Install needed Packages${devoid}"
echo "${green}Install OpenVPN, iptables and unzip${devoid}"

sudo apt-get update
sudo apt-get install openvpn iptables unzip  -y
echo


echo "${green}Step 7. Create regular and vpn User${devoid}"
echo "${green}Enter your regular username, will also be used as group name of your regular user that you would like to add the vpn user to${yellow}"
read -p 'Username: ' username
echo "${yellow}Enter the details for the regular user."
sudo adduser $username
echo "${yellow}Enter the details for the vpn user."
sudo adduser --disabled-login vpn
echo
usermod -aG vpn $username
echo "${green}Thank you, $username added to vpn group.${devoid}"
echo
usermod -aG $username vpn
echo "${green}Thank you. vpn user added to $username group.${devoid}"
echo

echo
echo "${green}Step 3. Create PIA Configuration File for Split Tunneling${devoid}"
cd /etc/openvpn
sudo wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
sudo unzip openvpn.zip
echo

echo "${green}Step 4. Create Modified PIA Configuration File for Split Tunneling${devoid}"
echo "${green}Create the OpenVPN configuration file${devoid}"
echo "${green}under /etc/openvpn/openvpn.conf${devoid}"
sudo cat > /etc/openvpn/openvpn.conf << EOF
client
dev tun
proto udp
remote sweden.privacy.network 1198
resolv-retry infinite
nobind
persist-key
persist-tun
cipher aes-128-cbc
auth sha1
tls-client
remote-cert-tls server
auth-user-pass /etc/openvpn/login.txt
auth-nocache
comp-lzo
verb 1
reneg-sec 0
crl-verify /etc/openvpn/crl.rsa.2048.pem
ca /etc/openvpn/ca.rsa.2048.crt
disable-occ
script-security 2
route-noexec

#up and down scripts to be executed when VPN starts or stops
up /etc/openvpn/iptables.sh
down /etc/openvpn/update-resolv-conf
EOF

echo
echo "${green}Step 5. Make OpenVPN Auto Login on Service Start${devoid}"
# Ask the PIA user for login details
echo
echo "${yellow}Please enter your PIA username and Password"
read -p 'Username: ' uservar
read -p 'Password: ' passvar
echo
echo $uservar > /etc/openvpn/login.txt
echo $passvar >> /etc/openvpn/login.txt
echo "${green}Thank you. You now have your PIA login details saved in /etc/openvpn/login.txt${devoid}"
echo

echo "${green}Step 2. Create systemd Service for OpenVPN${devoid}"
sudo cat > /etc/systemd/system/openvpn@openvpn.service << EOF
[Unit]
# HTPC Guides - www.htpcguides.com
Description=OpenVPN connection to %i
Documentation=man:openvpn(8)
Documentation=https://community.openvpn.net/openvpn/wiki/Openvpn23ManPage
Documentation=https://community.openvpn.net/openvpn/wiki/HOWTO
After=network.target

[Service]
RuntimeDirectory=openvpn
PrivateTmp=true
KillMode=mixed
Type=forking
ExecStart=/usr/sbin/openvpn --daemon ovpn-%i --status /run/openvpn/%i.status 10 --cd /etc/openvpn --script-security 2 --config /etc/openvpn/%i.conf --writepid /run/openvpn/%i.pid
PIDFile=/run/openvpn/%i.pid
ExecReload=/bin/kill -HUP $MAINPID
WorkingDirectory=/etc/openvpn
Restart=on-failure
RestartSec=3
ProtectSystem=yes
LimitNPROC=10
DeviceAllow=/dev/null rw
DeviceAllow=/dev/net/tun rw

[Install]
WantedBy=multi-user.target
EOF

echo "${green}Now enable the openvpn@openvpn.service we just created${devoid}"
sudo systemctl enable openvpn@openvpn.service

echo
echo "${green}Step 8. iptables Script for vpn User${devoid}"

echo "${green}Get Routing Information for the iptables Script${devoid}"
echo
echo "${green}We need the local IP and the name of the network interface.${devoid}"
echo "${green}Again, make sure you are using a static IP on your machine or reserved DHCP also known as static DHCP, but configured on your router!${devoid}"
interface=$(ip route list | grep default | cut -f5 -d" ")
localipaddr=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
echo
echo Local Default interface is $interface
echo Local IP Address is $localipaddr
while true; do
	echo "${yellow}"
    read -p "Are listed IP Addr and Interface correct?" yn
	echo "${devoid}"
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) corrections=1;break;;
        * ) echo "Please answer yes or no.";;
    esac
done
if [ "$corrections" == 1 ]; then
	echo Your current route list:
	echo "${pink}"
	ip route list
	echo "${yellow}"
	echo
	read -p 'Please enter correct defailt interface: ' interface
	read -p 'Please enter correct IP Address: ' localipaddr
	echo "${devoid}"
fi

sudo cat > /etc/openvpn/iptables.sh << EOF
#! /bin/bash
# Niftiest Software – www.niftiestsoftware.com
# Modified version by HTPC Guides – www.htpcguides.com

export INTERFACE="tun0"
export VPNUSER="vpn"
export LOCALIP="$localipaddr"
export NETIF="$interface"

# flushes all the iptables rules, if you have other rules to use then add them into the script
iptables -F -t nat
iptables -F -t mangle
iptables -F -t filter

# mark packets from $VPNUSER
iptables -t mangle -A OUTPUT -j CONNMARK --restore-mark
iptables -t mangle -A OUTPUT ! --dest $LOCALIP -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT --dest $LOCALIP -p udp --dport 53 -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT --dest $LOCALIP -p tcp --dport 53 -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT ! --src $LOCALIP -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT -j CONNMARK --save-mark

# allow responses
iptables -A INPUT -i $INTERFACE -m conntrack --ctstate ESTABLISHED -j ACCEPT

# block everything incoming on $INTERFACE to prevent accidental exposing of ports
iptables -A INPUT -i $INTERFACE -j REJECT

# let $VPNUSER access lo and $INTERFACE
iptables -A OUTPUT -o lo -m owner --uid-owner $VPNUSER -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -m owner --uid-owner $VPNUSER -j ACCEPT

# all packets on $INTERFACE needs to be masqueraded
iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE

# reject connections from predator IP going over $NETIF
iptables -A OUTPUT ! --src $LOCALIP -o $NETIF -j REJECT

# Start routing script
/etc/openvpn/routing.sh

exit 0
EOF

#Make the iptables script executable
sudo chmod +x /etc/openvpn/iptables.sh

echo
echo "${green}Step 9. Routing Rules Script for the Marked Packets${devoid}"

sudo cat > /etc/openvpn/routing.sh << EOF
#! /bin/bash
# Niftiest Software – www.niftiestsoftware.com
# Modified version by HTPC Guides – www.htpcguides.com

VPNIF="tun0"
VPNUSER="vpn"
GATEWAYIP=$(ifconfig $VPNIF | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | egrep -v '255|(127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' | tail -n1)
if [[ `ip rule list | grep -c 0x1` == 0 ]]; then
ip rule add from all fwmark 0x1 lookup $VPNUSER
fi
ip route replace default via $GATEWAYIP table $VPNUSER
ip route append default via 127.0.0.1 dev lo table $VPNUSER
ip route flush cache

# run update-resolv-conf script to set VPN DNS
/etc/openvpn/update-resolv-conf

exit 0
EOF

# Finally, make the script executable
sudo chmod +x /etc/openvpn/routing.sh

echo
echo "${green}Step 10. Configure Split Tunnel VPN Routing${devoid}"
echo "200     vpn" >> /etc/iproute2/rt_tables

echo
echo "Step 11. Change Reverse Path Filtering"
echo "net.ipv4.conf.all.rp_filter = 2" > /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.default.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.eth0.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
echo Apply new sysctl rules
sysctl --system

sudo systemctl start openvpn@openvpn

exit 0
