#!/bin/bash
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
#blue=$(tput setaf 4)
#pink=$(tput setaf 5)
cyan=$(tput setaf 6)
devoid=$(tput sgr0)

function check_if_exists() {
  file=$1
  if [[ -e $file ]]; then
    echo "${green}$file exists. ${devoid}"
  else
    echo "${green}$file is missing.${devoid}"
  fi
}

function check_if_executable() {
  file=$1
  if [[ -x "$file" ]]; then
    echo "${green}File '$file' is executable.${devoid}"
  else
    echo "${red}File '$file' is not executable.${devoid}"
  fi
}

function check_dns_servers() {
  systemctl start systemd-resolved
  servers="$(systemd-resolve --status | sed -zE 's|.*DNS Servers:(.*?)DNSSEC NTA.*|\1|g' | sed -e 's| ||g')"
  systemctl stop systemd-resolved
}

echo "${cyan}Check if created and modified files exist and are accurate${devoid}"
check_if_exists /etc/systemd/system/openvpn@openvpn.service
check_if_exists /etc/openvpn/login.txt # TODO: Check our changes are in it
check_if_exists /etc/openvpn/openvpn.zip
check_if_exists /etc/openvpn/sweden.ovpn
check_if_exists /etc/openvpn/crl.rsa.2048.pem
check_if_exists /etc/openvpn/ca.rsa.2048.crt
check_if_exists /etc/openvpn/openvpn.conf
check_if_exists /etc/openvpn/iptables.sh && check_if_executable /etc/openvpn/iptables.sh
check_if_exists /etc/openvpn/routing.sh && check_if_executable /etc/openvpn/routing.sh
check_if_exists /etc/openvpn/update-resolv-conf && check_if_executable /etc/openvpn/update-resolv-conf # TODO: Check our changes are in it
check_if_exists /etc/iproute2/rt_tables                                                                # TODO: Check our changes are in it
check_if_exists /etc/sysctl.d/9999-vpn.conf                                                            # TODO: Check our changes are in it
check_if_exists /etc/resolvconf/resolv.conf.d/head                                                     # TODO: Check our changes are in it
# cat /etc/resolv.conf
check_if_exists /var/spool/cron/crontabs/root # TODO: Check our changes are in it
check_if_exists /etc/default/grub             # TODO: Check our changes are in it

echo "${cyan}Check DNS Servers${devoid}"
if check_dns_servers == "209.222.18.222\n209.222.18.218\n8.8.8.8"; then
  echo ${green}Success${devoid}
else
  echo ${red}Failure${devoid}
fi

echo "${cyan}openvpn@openvpn service checks:${devoid}"
service_enabled_check=$(systemctl is-enabled openvpn@openvpn.service)
service_active_check=$(systemctl is-active openvpn@openvpn.service)
if [[ $service_enabled_check == enabled ]]; then
  echo "${green}openvpn@openvpn service is enabled${devoid}"
else
  echo "${red}openvpn@openvpn service is not enabled${devoid}"

fi
if [[ $service_active_check == active ]]; then
  echo "${green}openvpn@openvpn service is active${devoid}"
else
  echo "${red}openvpn@openvpn service is not active${devoid}"
  # TODO: Add check to see if journalctl is hinting at invalid credentials.
fi

echo "${cyan}Check IP addresses${devoid}"
reg_user_default_ip=$(curl -s api.ipify.org)
reg_user_vpn_ip=$(curl --interface tun0 -s api.ipify.org)
vpn_user_ip=$(sudo -u vpn -i -- curl -s api.ipify.org)
if [[ "$reg_user_vpn_ip" == "$vpn_user_ip" ]] && [[ ! "$reg_user_default_ip" == "$reg_user_vpn_ip" ]] && [[ ! "$reg_user_default_ip" == "$vpn_user_ip" ]]; then
  echo "${green}Reported IP Addresses are correct.${devoid}"
else
  echo "${red}Something must have gone wrong.${devoid}"
  echo "${yellow}If IPs match for the 2nd and 3rd, but not the 1st - everything is fine.${devoid}"
  echo "$reg_user_default_ip"
  echo "$reg_user_vpn_ip"
  echo "$vpn_user_ip"
fi

echo "${cyan}Killswitch check:${devoid}"
killswitch_test=$(
  systemctl stop openvpn@openvpn
  timeout 3 sudo -u vpn -i -- curl -s api.ipify.org
  systemctl start openvpn@openvpn
)
if [[ -z $killswitch_test ]]; then
  echo "${green}VPN killswitch successful.${devoid}"
else
  echo "${red}VPN still had access through this IP: ${yellow}$killswitch_test ${devoid}"
fi

echo "${cyan}IPv6 disabled check:${devoid}"
if [[ ! -e /proc/sys/net/ipv6 ]]; then
  echo "${green}IPv6 is disabled via grub${devoid}"
else
  #shellcheck disable=SC2207
  interfaces=($(ls /proc/sys/net/ipv6/conf/))
  for interface in "${interfaces[@]}"; do
    if [[ $(cat "/proc/sys/net/ipv6/conf/$interface/disable_ipv6") == 0 ]]; then
      echo "${green}IPv6 $interface is disabled in sysctl${devoid}"
    else
      echo "${red}IPv6 $interface is enabled in sysctl${devoid}"
    fi
  done
fi
