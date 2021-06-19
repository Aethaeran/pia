# Check if you are root user, otherwise will not work
[[ $(id -u) -eq 0 ]] || { echo >&2 "Must be root to run this script."; exit 1; }

echo "Please enter your PIA username and Password"
read -p 'PIA Username: ' piauservar
read -p 'PIA Password: ' piapassvar
echo "Please enter your regular username"
read -p 'Username: ' uservar

echo Install OpenVPN
sudo apt-get update
sudo apt-get install openvpn -y
echo Create systemd Service for OpenVPN
cat > /etc/systemd/system/openvpn@openvpn.service << EOF
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
sudo systemctl enable openvpn@openvpn.service

echo Create PIA Configuration File for Split Tunneling
echo Get the Required Certificates for PIA
sudo apt-get install unzip -y
cd /etc/openvpn
sudo wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
sudo unzip openvpn.zip

echo Create Modified PIA Configuration File for Split Tunneling
cat > /etc/openvpn/openvpn.conf << EOF
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

echo Make OpenVPN Auto Login on Service Start
echo $piauservar > /etc/openvpn/login.txt
echo $piapassvar >> /etc/openvpn/login.txt

echo Configure VPN DNS Servers to Stop DNS Leaks
sed -i.bak -e "s/#     foreign_option_1='dhcp-option DNS 193.43.27.132'/foreign_option_1=\'dhcp-option DNS 209.222.18.222\'/g" /etc/openvpn/update-resolv-conf
sed -i -e "s/#     foreign_option_2='dhcp-option DNS 193.43.27.133'/foreign_option_2=\'dhcp-option DNS 209.222.18.218\'/g" /etc/openvpn/update-resolv-conf
sed -i -e "s/#     foreign_option_3='dhcp-option DOMAIN be.bnc.ch'/foreign_option_3=\'dhcp-option DNS 8.8.8.8\'/g" /etc/openvpn/update-resolv-conf

echo Split Tunneling with iptables and Routing Tables
sudo adduser $username
sudo adduser vpn
sudo usermod -aG vpn $username
sudo usermod -aG $username vpn

echo Get Routing Information for the iptables Script
interface=$(ip route list | grep default | cut -f5 -d" ")
localipaddr=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
echo
echo Local Default interface is $interface
echo Local IP Address is $localipaddr
while true; do
    read -p "Are listed IP Addr and Interface correct?" yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) corrections=1;break;;
        * ) echo "Please answer yes or no.";;
    esac
done
if [ "$corrections" == 1 ]; then
	echo Your current route list:
	ip route list
	echo
	read -p 'Please enter correct defailt interface: ' interface
	read -p 'Please enter correct IP Address: ' localipaddr
fi
sudo iptables -F
sudo iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP
sudo apt-get install iptables-persistent -y

echo iptables Script for vpn User
cat > /etc/openvpn/iptables.sh << EOF
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
chmod +x /etc/openvpn/iptables.sh

echo Routing Rules Script for the Marked Packets
cat > /etc/openvpn/routing.sh << EOF
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
chmod +x /etc/openvpn/routing.sh

echo Configure Split Tunnel VPN Routing
echo "200     vpn" >> /etc/iproute2/rt_tables


echo "Step 11. Change Reverse Path Filtering"
echo "net.ipv4.conf.all.rp_filter = 2" > /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.default.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.eth0.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
echo Apply new sysctl rules
sysctl --system


echo
echo "Testing the VPN Split Tunnel"
echo
systemctl start openvpn@openvpn.service
echo
systemctl status openvpn@openvpn.service
echo
echo "Check IP address"
echo "Regular User"
curl ipinfo.io
echo
echo "VPN User"
sudo -u vpn -i -- curl ipinfo.io
echo
echo "If Location and IPs are different - everything is fine"
echo
echo Check DNS Server
echo
sudo -u vpn -i -- cat /etc/resolv.conf
echo
echo "If outupt is following, everything is ok:
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
# DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 209.222.18.222
nameserver 209.222.18.218
nameserver 8.8.8.8"

exit 0
