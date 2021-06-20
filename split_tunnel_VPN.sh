#!/bin/bash

# By Georgiy Sitnikov. Modified by Aethaeran
#
# Will setup a Split Tunnel user.
#
# AS-IS without any warranty

echo "Checking if you are root user, otherwise the script will not work."
[[ $(id -u) -eq 0 ]] || { echo >&2 "Must be root to run this script."; exit 1; }

# TODO (Might be needed for 16.04)
#wget https://swupdate.openvpn.net/repos/repo-public.gpg -O - | apt-key add -
#echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" | tee -a /etc/apt/sources.list.d/openvpn.list

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
pink=`tput setaf 5`
cyan=`tput setaf 6`
devoid=`tput sgr0`

echo "${green}Step 1. Install needed Packages${devoid}"
echo "${green}Install OpenVPN, iptables and unzip${devoid}"

sudo apt-get update
sudo apt-get install openvpn iptables unzip  -y
echo

echo "${green}Step 2. Create regular and vpn User${devoid}"
echo "${green}Enter your REGULAR username, will also be used as group name of your regular user that you would like to add the vpn user to${yellow}"
read -p 'Username: ' username
echo "Enter the details for the REGULAR user."
sudo adduser $username
echo "Enter the details for the VPN user."
sudo adduser vpn
echo
usermod -aG vpn $username
echo "${green}$username added to vpn group.${devoid}"
echo
usermod -aG $username vpn
echo "${green}vpn user added to $username group.${devoid}"
echo

echo "${green}Step 3. Make OpenVPN Auto Login on Service Start${devoid}"
# Ask the PIA user for login details
echo
echo "${yellow}Please enter your PIA username and Password"
read -p 'Username: ' uservar
read -p 'Password: ' passvar
echo
echo $uservar > /etc/openvpn/login.txt
echo $passvar >> /etc/openvpn/login.txt
sudo chmod 700 /etc/openvpn/login.txt
sudo chmod -x /etc/openvpn/login.txt
echo "${green}Thank you. You now have your PIA login details saved in /etc/openvpn/login.txt${devoid}"
echo

echo "${green}Step 4. Create PIA Configuration File for Split Tunneling${devoid}"
cd /etc/openvpn
sudo wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
sudo unzip openvpn.zip
echo

echo "${green}Step 4. Create Modified PIA Configuration File for Split Tunneling${devoid}"
echo "${green}Create the OpenVPN configuration file${devoid}"
echo "${green}under /etc/openvpn/openvpn.conf${devoid}"

cd /etc/openvpn/
wget https://raw.githubusercontent.com/Aethaeran/pia/master/openvpn.conf
echo

echo "${green}Step 5. Create systemd Service for OpenVPN${devoid}"
cd /etc/systemd/system/
wget https://raw.githubusercontent.com/Aethaeran/pia/master/openvpn%40openvpn.service

echo "${green}Now enable the openvpn@openvpn.service we just created${devoid}"
sudo systemctl enable openvpn@openvpn.service
echo

echo "${green}Step 8. iptables Script for vpn User${devoid}"
echo "${green}Get Routing Information for the iptables Script${devoid}"
echo
echo "${green}We need the local IP and the name of the network interface.${devoid}"
echo "${green}Again, make sure you are using a static IP on your machine or reserved DHCP also known as static DHCP, but configured on your router!${devoid}"
interface=$(ip route list | grep default | cut -f5 -d" ")
localipaddr=$(curl api.ipify.org -s)
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
cd /etc/openvpn/
wget https://raw.githubusercontent.com/Aethaeran/pia/master/iptables.sh

sudo sed -i.backup -e "s/export LOCALIP=\"192.168.1.110\"/export LOCALIP=\"${localipaddr}\"/g" iptables.sh
sudo sed -i -e "s/export NETIF=\"eth0\"/export NETIF=\"${interface}\"/g" iptables.sh

#Make the iptables script executable
sudo chmod +x /etc/openvpn/iptables.sh

echo
echo "${green}Step 9. Routing Rules Script for the Marked Packets${devoid}"

cd /etc/openvpn/
wget https://raw.githubusercontent.com/Aethaeran/pia/master/routing.sh

# Finally, make the script executable
sudo chmod +x /etc/openvpn/routing.sh

echo "${green}Step 10. Configure Split Tunnel VPN Routing${devoid}"
echo "200     vpn" >> /etc/iproute2/rt_tables
echo

echo "Step 11. Change Reverse Path Filtering"
echo "net.ipv4.conf.all.rp_filter = 2" > /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.default.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
echo "net.ipv4.conf.eth0.rp_filter = 2" >> /etc/sysctl.d/9999-vpn.conf
echo Apply new sysctl rules
sysctl --system

echo "${green}Step 6. Configure VPN DNS Servers to Stop DNS Leaks${devoid}"
sudo sed -i.backup -e "s/#     foreign_option_1='dhcp-option DNS 193.43.27.132'/foreign_option_1=\'dhcp-option DNS 209.222.18.222\'/g" /etc/openvpn/update-resolv-conf
sudo sed -i -e "s/#     foreign_option_2='dhcp-option DNS 193.43.27.133'/foreign_option_2=\'dhcp-option DNS 209.222.18.218\'/g" /etc/openvpn/update-resolv-conf
sudo sed -i -e "s/#     foreign_option_3='dhcp-option DOMAIN be.bnc.ch'/foreign_option_3=\'dhcp-option DNS 8.8.8.8\'/g" /etc/openvpn/update-resolv-conf
echo

echo "${green}Flush current iptables rules${devoid}"
sudo iptables -F
sudo iptables -X
echo "${green}Add rule, which will block vpn user’s access to Internet (except the loopback device).${devoid}"
sudo iptables -A OUTPUT ! -o lo -m owner --uid-owner vpn -j DROP
echo "${green}Install iptables-persistent to save this single rule that will be always applied on each system start.${devoid}"
echo
echo "${yellow}During the install, iptables-persistent will ask you to save current iptables rules to /etc/iptables/rules.v4, accept this with YES.${devoid}"
echo
sudo apt-get install iptables-persistent -y

echo "${green}Starting openvpn service.${devoid}"
sudo systemctl start openvpn@openvpn

exit 0
