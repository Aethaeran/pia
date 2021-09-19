#!/bin/bash

# Based off of the following guide.
# https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/
# Originally By Georgiy Sitnikov.
# Modified by Aethaeran.
#
# Will setup a Split Tunnel user name 'vpn' using Private Internet Access, openvpn, and resolvconf.
#
# AS-IS without any warranty

##########################################################################
# References
##########################################################################

# https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/
# https://www.tecmint.com/set-permanent-dns-nameservers-in-ubuntu-debian/
# https://phoenixnap.com/kb/crontab-reboot
# https://linuxconfig.org/how-to-disable-ipv6-address-on-ubuntu-20-04-lts-focal-fossa
# https://stackoverflow.com/questions/4880290/how-do-i-create-a-crontab-through-a-script
# https://pimylifeup.com/ubuntu-disable-ipv6/

##########################################################################
# File created and modified by this script
##########################################################################

# /etc/openvpn/login.txt # Contains your PIA login details
# /etc/openvpn/openvpn.zip # A file containing all of PIA's .ovpn file as well as their .pem and .crt
# /etc/openvpn/sweden.ovpn
# /etc/openvpn/crl.rsa.2048.pem
# /etc/openvpn/ca.rsa.2048.crt
# /etc/openvpn/openvpn.conf
# /etc/openvpn/iptables.sh
# /etc/openvpn/routing.sh
# /etc/openvpn/update-resolv-conf
# /etc/systemd/system/openvpn@openvpn.service
# /etc/iproute2/rt_tables
# /etc/sysctl.d/9999-vpn.conf
# /etc/resolvconf/resolv.conf.d/head
# /var/spool/cron/crontabs/root
# /etc/rc.local
# /etc/sysctl.conf

##########################################################################
# Introduction
##########################################################################

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
pink=$(tput setaf 5)
cyan=$(tput setaf 6)
devoid=$(tput sgr0)

cat <<EOF
${green}
   //           //              //           //
 //// //////////////          //// //////////////
   //           //             //            //
 //// //////////////        ////  //////////////
   //           //          ///            //
 //// //////////////     ////  ///////////////
   //           //      ///             //
 //// //////////////////   ////////////////
   //           /////              ///
 //// ////////////   //////////////////
   //        /////            ///
 //// //////////// ///////////////
   //    //     //       ///
 ////  /////////// /////////
   /////        //   //
 /////////////////////
   ///          ////
 ///////////////////
   //           ///
 //// //////////////
${blue}

█▀ █▀█ █░░ █ ▀█▀   ▀█▀ █░█ █▄░█ █▄░█ █▀▀ █░░
▄█ █▀▀ █▄▄ █ ░█░   ░█░ █▄█ █░▀█ █░▀█ ██▄ █▄▄

    █░█ █▀█ █▄░█   █░█ █ ▄▀█   █▀█ █ ▄▀█
    ▀▄▀ █▀▀ █░▀█   ▀▄▀ █ █▀█   █▀▀ █ █▀█

${devoid}
EOF

##########################################################################
# Variables
##########################################################################

# TODO: Possibly use ENV_VARs to bypass reads
# TODO: Add logic to ensure these are actually filled in.

echo "${yellow}Enter your PRIMARY username and password:"
read -rp 'Username: ' username
read -rp 'Password: ' password

# TODO: Add reads for vpn_user and vpn_password as well.
vpn_user="vpn"

echo "Please enter your PIA username and password:"
read -rp 'Username: ' pia_user
read -rp 'Password: ' pia_pass

# TODO: Allow the choice of which PIA network they prefer, but default to Sweden.

echo "Please enter which file to save the log file to. Will use /opt/split_tunnel.log if nothing is entered."
read -rp 'Log File: ' log
if [[ -z $log ]];then
  log="/opt/split_tunnel.log"
  echo "Nothing entered. So setting default log location: $log"
fi
echo "Log file being saved to: $log"

##########################################################################
# Main
##########################################################################

# "Checking if you are root user, otherwise the script will not work."
[[ $(id -u) -eq 0 ]] || {
  echo >&2 "${red}Must be root to run this script. Run 'sudo su -' prior to running this script."
  exit 1
}

echo "${cyan}Step 01.${green} Install necessary apt packages: ${pink}openvpn, iptables and unzip${devoid}"
apt update >>"$log" 2>&1
apt install openvpn iptables unzip -y >>"$log" 2>&1

echo "${cyan}Step 02.${green} Create users, and add to one another's groups: ${pink}$username $vpn_user${devoid}"
useradd "$username" -m -G sudo -s /bin/bash
chpasswd <<<"$username:$password"
useradd "$vpn_user" -m -G www-data -s /bin/bash
chpasswd <<<"$vpn_user:$password"
usermod -aG "$vpn_user" "$username"
usermod -aG "$username" "$vpn_user"

echo "${cyan}Step 03.${green} Save PIA Credentials for OpenVPN at ${pink}/etc/openvpn/login.txt${devoid}"
cat >"/etc/openvpn/login.txt" <<EOF
$pia_user
$pia_pass
EOF
chmod 600 "/etc/openvpn/login.txt" # Set perms to rw-------

echo "${cyan}Step 04.${green} Collect required PIA files: ${pink}sweden.ovpn crl.rsa.2048.pem ca.rsa.2048.crt${devoid}"
wget "https://www.privateinternetaccess.com/openvpn/openvpn.zip" -P "/etc/openvpn" >>"$log" 2>&1
unzip "/etc/openvpn/openvpn.zip" "sweden.ovpn" "crl.rsa.2048.pem" "ca.rsa.2048.crt" -d "/etc/openvpn" >>"$log" 2>&1

echo "${cyan}Step 05.${green} Create OpenVPN Configuration File: ${pink}/etc/openvpn/openvpn.conf${devoid}"
cat >"/etc/openvpn/openvpn.conf" <<'EOF'
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

# up and down scripts to be executed when VPN starts or stops
up /etc/openvpn/iptables.sh
# down /etc/openvpn/update-resolv-conf
EOF

echo "${cyan}Step 06.${green} Create systemd service: ${pink}/etc/systemd/system/openvpn@openvpn.service${devoid}"
cat >"/etc/systemd/system/openvpn@openvpn.service" <<'EOF'
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

echo "${cyan}Step 07.${green} Create iptables script for vpn user: ${pink}/etc/openvpn/iptables.sh${devoid}"
cat >"/etc/openvpn/iptables.sh" <<'EOF'
#! /bin/bash
# Niftiest Software – www.niftiestsoftware.com
# Modified version by HTPC Guides – www.htpcguides.com

export INTERFACE="tun0"
export VPNUSER="vpn"
export LOCALIP="192.168.1.110"
export NETIF="eth0"

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
localipaddr=$(curl api.ipify.org -s)
sed -e "s/export LOCALIP=\"192.168.1.110\"/export LOCALIP=\"${localipaddr}\"/g" -i.backup "/etc/openvpn/iptables.sh"
interface=$(ip route list | grep default | cut -f5 -d" ")
sed -e "s/export NETIF=\"eth0\"/export NETIF=\"${interface}\"/g" -i "/etc/openvpn/iptables.sh"
chmod +x "/etc/openvpn/iptables.sh" # Make the iptables script executable

echo "${cyan}Step 08.${green} Create routing rules script: ${pink}/etc/openvpn/routing.sh${devoid}"
cat >"/etc/openvpn/routing.sh" <<'EOF'
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
# /etc/openvpn/update-resolv-conf

exit 0
EOF
chmod +x "/etc/openvpn/routing.sh" # Finally, make the script executable

echo "${cyan}Step 09.${green} Configure Split Tunnel VPN Routing by editing: ${pink}/etc/iproute2/rt_tables${devoid}"
echo "200     vpn" >>"/etc/iproute2/rt_tables"

echo "${cyan}Step 10.${green} Change Reverse Path Filtering by editing: ${pink}/etc/sysctl.d/9999-vpn.conf${devoid}"
echo "net.ipv4.conf.all.rp_filter = 2" >"/etc/sysctl.d/9999-vpn.conf"
echo "net.ipv4.conf.default.rp_filter = 2" >>"/etc/sysctl.d/9999-vpn.conf"
echo "net.ipv4.conf.eth0.rp_filter = 2" >>"/etc/sysctl.d/9999-vpn.conf"
sysctl --system >>"$log" 2>&1 # Apply new sysctl rules

echo "${cyan}Step 11.${green} Set persistent iptable rules by installing: ${pink}iptables-persistent${devoid}"
iptables --flush                                                                               # Flush current iptables rules - Delete all rules in chain or all chains
iptables --delete-chain                                                                        # Delete a user-defined chain
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections # Bypass ipv4 confirmation when installing iptables-persistent
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections # Bypass ipv6 confirmation when installing iptables-persistent
iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP                                    # Add rule, which will block vpn user’s access to Internet (except the loopback device).
apt install iptables-persistent -y >>"$log" 2>&1                                               # Install iptables-persistent to save this single rule that will be always applied on each system start.

echo "${cyan}Step 12.${green} Set Permanent DNS Nameservers to eliminate DNS Leaks with: ${pink}resolvconf${green} ${devoid}"
apt install resolvconf >>"$log" 2>&1 # TODO: For some reason if resolvconf is installed earlier than this it can cause issues. Should look into this.
{
  echo "nameserver 209.222.18.222"
  echo "nameserver 209.222.18.218"
  echo "nameserver 8.8.8.8"
} >>"/etc/resolvconf/resolv.conf.d/head"
systemctl restart resolvconf.service >>"$log" 2>&1
resolvconf -u >>"$log" 2>&1
(
  crontab -l 2>/dev/null
  echo "# Set DNS Nameservers "
) | crontab - # Add cronjob to root
(
  crontab -l 2>/dev/null
  echo "@reboot sudo resolvconf -u"
) | crontab - # Add cronjob to root

echo "${cyan}Step 13.${green} Disable IPv6 entirely to eliminate IPv6 leaks with: ${pink}systcl${devoid}"
# This disables IPv6 immediately
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >>"$log" 2>&1
#sysctl -w net.ipv6.conf.default.disable_ipv6=1 >>"$log" 2>&1

echo "/etc/init.d/procps restart" >>/etc/rc.local
echo "net.ipv6.conf.all.disable_ipv6=1" >>/etc/sysctl.conf

echo "${cyan}Step 14.${green} Start the systemd service: ${pink}openvpn@openvpn${devoid}"
systemctl enable openvpn@openvpn.service >>"$log" 2>&1 # Now enable the openvpn@openvpn.service
systemctl start openvpn@openvpn >>"$log" 2>&1          # Starting openvpn service