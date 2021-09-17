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

# https://www.tecmint.com/set-permanent-dns-nameservers-in-ubuntu-debian/
# https://phoenixnap.com/kb/crontab-reboot
# https://linuxconfig.org/how-to-disable-ipv6-address-on-ubuntu-20-04-lts-focal-fossa
# https://stackoverflow.com/questions/4880290/how-do-i-create-a-crontab-through-a-script

##########################################################################
# File created and modified by this script
##########################################################################

# /etc/openvpn/login.txt # Contains your PIA login details
# /etc/openvpn/openvpn.zip # A file containing all of PIA's .ovpn file as well as their .pem and .crt
# "sweden.ovpn" "crl.rsa.2048.pem" "ca.rsa.2048.crt"
# openvpn.conf
# /etc/systemd/system/openvpn@openvpn.service
# iptables.sh
# /var/spool/cron/crontabs/root

##########################################################################
# Variables
##########################################################################

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
pink=$(tput setaf 5)
cyan=$(tput setaf 6)
devoid=$(tput sgr0)

echo "${yellow}Enter your REGULAR username and password:"
read -p 'Username: ' username
read -p 'Password: ' password

echo "Please enter your PIA username and Password"
read -p 'Username: ' pia_user
read -p 'Password: ' pia_pass

log="/opt/split_tunnel.log"
vpn_user="vpn"
##########################################################################
# Main
##########################################################################

# "Checking if you are root user, otherwise the script will not work."
[[ $(id -u) -eq 0 ]] || { echo >&2 "${red}Must be root to run this script. Run 'sudo su -' prior to running this script."; exit 1; }

echo "${cyan}Step 1.${green} Install necessary Packages: OpenVPN, iptables and unzip${devoid}"
sudo apt-get update >> "$log" 2>&1
sudo apt-get install openvpn iptables unzip -y >> "$log" 2>&1

echo "${cyan}Step 2.${green} Create regular and vpn User, and add to one anothers groups${devoid}"
# TODO: Make this user sudo capable
useradd "$username" -m -G www-data -s /bin/bash
chpasswd <<< "$username:$password"
useradd "$vpn_user" -m -G www-data -s /bin/bash
chpasswd <<< "$vpn_user:$password"
usermod -aG "$vpn_user" "$username"
usermod -aG "$username" "$vpn_user"

echo "${cyan}Step 3.${green} Make OpenVPN Auto Login on Service Start${devoid}"
touch /etc/openvpn/login.txt
{
  echo "$pia_user"
  echo "$pia_pass"
  } >> /etc/openvpn/login.txt
chmod 600 /etc/openvpn/login.txt  # Set perms to rw-------
echo "${cyan}Your PIA login details are now saved in /etc/openvpn/login.txt${devoid}"

echo "${cyan}Step 4.${green} Collect PIA Configuration Files: sweden.ovpn crl.rsa.2048.pem ca.rsa.2048.crt${devoid}"
wget https://www.privateinternetaccess.com/openvpn/openvpn.zip -P /etc/openvpn >> "$log" 2>&1
unzip /etc/openvpn/openvpn.zip "sweden.ovpn" "crl.rsa.2048.pem" "ca.rsa.2048.crt" -d /etc/openvpn >> "$log" 2>&1

echo "${cyan}Step 5.${green} Create Modified PIA Configuration File for Split Tunneling${devoid}"
wget https://raw.githubusercontent.com/Aethaeran/pia/master/openvpn.conf -P /etc/openvpn >> "$log" 2>&1

echo "${cyan}Step 6.${green} Create systemd Service for OpenVPN${devoid}"
wget https://raw.githubusercontent.com/Aethaeran/pia/master/openvpn%40openvpn.service -P /etc/systemd/system/ >> "$log" 2>&1

echo "${cyan}Step 7.${green} iptables Script for vpn User${devoid}"
wget https://raw.githubusercontent.com/Aethaeran/pia/master/iptables.sh -P /etc/openvpn/ >> "$log" 2>&1
localipaddr=$(curl api.ipify.org -s)
sed -e "s/export LOCALIP=\"192.168.1.110\"/export LOCALIP=\"${localipaddr}\"/g" -i.backup /etc/openvpn/iptables.sh
interface=$(ip route list | grep default | cut -f5 -d" ")
sed -e "s/export NETIF=\"eth0\"/export NETIF=\"${interface}\"/g" -i /etc/openvpn/iptables.sh
sudo chmod +x /etc/openvpn/iptables.sh # Make the iptables script executable

echo "${cyan}Step 8.${green} Routing Rules Script for the Marked Packets${devoid}"
wget https://raw.githubusercontent.com/Aethaeran/pia/master/routing.sh -P /etc/openvpn/ >> "$log" 2>&1
sudo chmod +x /etc/openvpn/routing.sh # Finally, make the script executable

echo "${cyan}Step 9.${green} Configure Split Tunnel VPN Routing${devoid}"
echo "200     vpn" >> /etc/iproute2/rt_tables

echo "${cyan}Step 10.${green} Change Reverse Path Filtering${devoid}"
echo "net.ipv4.conf.all.rp_filter = 2" > /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.default.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.eth0.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
sysctl --system >> "$log" 2>&1 # Apply new sysctl rules

echo "${cyan}Step 11.${green} Configure VPN DNS Servers to Stop DNS Leaks${devoid}"
sed -e "s/#     foreign_option_1='dhcp-option DNS 193.43.27.132'/foreign_option_1=\'dhcp-option DNS 209.222.18.222\'/g" -i.backup /etc/openvpn/update-resolv-conf
sed -e "s/#     foreign_option_2='dhcp-option DNS 193.43.27.133'/foreign_option_2=\'dhcp-option DNS 209.222.18.218\'/g" -i /etc/openvpn/update-resolv-conf
sed -e "s/#     foreign_option_3='dhcp-option DOMAIN be.bnc.ch'/foreign_option_3=\'dhcp-option DNS 8.8.8.8\'/g" -i /etc/openvpn/update-resolv-conf

echo "${cyan}Step 12.${green} Set persistent iptable rules by installing iptables-persistent${devoid}"
iptables --flush # Flush current iptables rules - Delete all rules in  chain or all chains
iptables --delete-chain # Delete a user-defined chain
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections # Bypass ipv4 confirmation when installing iptables-persistent
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections # Bypass ipv6 confirmation when installing iptables-persistent
iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP # Add rule, which will block vpn user’s access to Internet (except the loopback device).
apt install iptables-persistent -y >> "$log" 2>&1 # Install iptables-persistent to save this single rule that will be always applied on each system start.

echo "${cyan}Step 13.${green} Set Permanent DNS Nameservers ${devoid}"
apt install resolvconf >> "$log" 2>&1
{
echo "nameserver 209.222.18.222"
echo "nameserver 209.222.18.218"
echo "nameserver 8.8.8.8"
} >> /etc/resolvconf/resolv.conf.d/head
systemctl restart resolvconf.service >> "$log" 2>&1
resolvconf -u >> "$log" 2>&1
(crontab -l 2>/dev/null; echo "# Set DNS Nameservers ") | crontab - # Add cronjob to root
(crontab -l 2>/dev/null; echo "@reboot sudo resolvconf -u") | crontab - # Add cronjob to root
#wget https://raw.githubusercontent.com/Aethaeran/pia/master/root -P /var/spool/cron/crontabs/
#echo "@reboot sudo resolvconf -u" >> /var/spool/cron/crontabs/root

echo "${cyan}Step 14.${green} Disable IPv6 to prevent leaks.${devoid}"
# This sets it immediately
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >> "$log" 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >> "$log" 2>&1
# This sets it on reboot
# TODO: There was an instance where adding this disabled someone's internet entirely.
# TODO: Change this to insert after other set variables if they exist.
sed -e 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/GRUB_CMDLINE_LINUX_DEFAULT=\"ipv6.disable=1\"/g' -i /etc/default/grub
update-grub >> "$log" 2>&1

echo "${cyan}Step 15.${green} Start the service.${devoid}"
systemctl enable openvpn@openvpn.service >> "$log" 2>&1 # Now enable the openvpn@openvpn.service
systemctl start openvpn@openvpn >> "$log" 2>&1 # Starting openvpn service