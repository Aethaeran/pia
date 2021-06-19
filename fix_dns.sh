#!/bin/bash

# References:
# https://www.tecmint.com/set-permanent-dns-nameservers-in-ubuntu-debian/
# https://phoenixnap.com/kb/crontab-reboot

# Set Permanent DNS Nameservers in Ubuntu and Debian
sudo apt update
sudo apt install resolvconf
echo "nameserver 209.222.18.222" >> /etc/resolvconf/resolv.conf.d/head
echo "nameserver 209.222.18.218" >> /etc/resolvconf/resolv.conf.d/head
echo "nameserver 8.8.8.8" >> /etc/resolvconf/resolv.conf.d/head
sudo systemctl restart resolvconf.service
sudo resolvconf -u

# Set resolvconf -u to run on boot with crontab
# crontab -e to manually edit crontab
# press 1 for nano
cd /var/spool/cron/crontabs/
wget https://raw.githubusercontent.com/Aethaeran/pia/master/root
echo "@reboot sudo resolvconf -u" >> /var/spool/cron/crontabs/root
