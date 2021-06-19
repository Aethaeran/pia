#!/bin/bash
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
pink=`tput setaf 5`
cyan=`tput setaf 6`
devoid=`tput sgr0`

echo "${green}Check if created and modified files are accurate${devoid}"
echo
echo "${green}/etc/systemd/system/openvpn@openvpn.service:${devoid}"
cat /etc/systemd/system/openvpn@openvpn.service 
echo
echo "${green}/etc/openvpn/openvpn.conf:${devoid}"
cat /etc/openvpn/openvpn.conf 
echo
echo "${green}/etc/openvpn/login.txt:${devoid}"
cat /etc/openvpn/login.txt 
echo
echo "${green}/etc/openvpn/update-resolv-conf:${devoid}"
cat /etc/openvpn/update-resolv-conf
echo
echo "${green}/etc/openvpn/iptables.sh:${devoid}"
cat /etc/openvpn/iptables.sh
echo
echo "${green}/etc/openvpn/routing.sh:${devoid}"
cat /etc/openvpn/routing.sh
echo
echo "${green}/etc/iproute2/rt_tables:${devoid}"
cat /etc/iproute2/rt_tables
echo 

echo "${green}Testing if created shell scripts are executable${devoid}"
file=/etc/openvpn/iptables.sh
if [[ -x "$file" ]]
then
    echo "File '$file' is executable"
else
    echo "File '$file' is not executable or found"
fi

file=/etc/openvpn/routing.sh
if [[ -x "$file" ]]
then
    echo "File '$file' is executable"
else
    echo "File '$file' is not executable or found"
fi


echo
echo "${green}Testing the VPN Split Tunnel${devoid}"
echo "${yellow}Press Q to escape service status${devoid}"
echo
sudo systemctl restart openvpn@openvpn.service
echo
sudo systemctl status openvpn@openvpn.service
echo
echo "${green}Check IP address${devoid}"
echo "${green}Regular User${devoid}"
curl ipinfo.io
echo
echo "${green}Regular User but poiting at VPN interface${devoid}"
curl --interface tun0 ipinfo.io
echo
echo "${green}VPN User${devoid}"
sudo -u vpn -i -- curl ipinfo.io
echo
echo "${yellow}If Location and IPs match for the last two, but not the first one - everything is fine.${devoid}"
echo "${cyan}TODO Should also check that the killswitch is working by disabling openvpn and testing curl with VPN user.${devoid}"
echo
echo "${green}Check DNS Server${devoid}"
echo
sudo -u vpn -i -- cat /etc/resolv.conf

echo
echo "${yellow}If outupt is following, everything is ok:
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
# DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 209.222.18.222
nameserver 209.222.18.218
nameserver 8.8.8.8"
