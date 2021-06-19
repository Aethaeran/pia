
echo "${green}Step 6. Configure VPN DNS Servers to Stop DNS Leaks${devoid}"
sudo sed -i -e "s/#     foreign_option_1='dhcp-option DNS 193.43.27.132'/foreign_option_1=\'dhcp-option DNS 209.222.18.222\'/g" /etc/openvpn/update-resolv-conf
sudo sed -i -e "s/#     foreign_option_2='dhcp-option DNS 193.43.27.133'/foreign_option_2=\'dhcp-option DNS 209.222.18.218\'/g" /etc/openvpn/update-resolv-conf
sudo sed -i -e "s/#     foreign_option_3='dhcp-option DOMAIN be.bnc.ch'/foreign_option_3=\'dhcp-option DNS 8.8.8.8\'/g" /etc/openvpn/update-resolv-conf
echo



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