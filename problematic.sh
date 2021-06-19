



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