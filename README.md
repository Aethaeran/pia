# OpenVPN Split Tunnel User via PIA

## PIA Split Tunnel User Script
This script is based off of **GAS85**'s script made to achieve the same result. His script in turn is based on an **HTPC Guides** tutorial, which uses some scripts found in a post on **Niftiest Software**. I've provided links to all three here:
-  [GAS85's readme for his rendition of the script.](https://gist.github.com/GAS85/4e40ece16ffa748e7138b9aa4c37ca52)
-  [HTPC Guides - Force Torrent Traffic through VPN Split Tunnel Debian 8 + Ubuntu 16.04](https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/)
-  [Niftiest Software - Making all network traffic for a Linux user use a specific network interface](http://www.niftiestsoftware.com/2011/08/28/making-all-network-traffic-for-a-linux-user-use-a-specific-network-interface/)

## Differences in my Method
- I set DNS servers permanently across the entire system. Rather than only have them kick in when the systemd service is running via update-resolv-conf.
- I disable IPv6 entirely to stop IPv6 from leaking as this script only handles IPv4. This is because currently [PIA themselves only support](https://ipv6leak.com/) IPv4.

The following code block should run the split tunnel script without the need to download it. It will prompt you to manually enter your primary username and password, as well as your PIA credentials.
```
bash <(curl -sL git.io/JzsuC) && . ~/.bashrc
```
## PIA Split Tunnel User Test Script
This should run a script for verifying the split tunnel is working correctly. If you only get green text **(no red text)**. You're probably good to go.
```
bash <(curl -sL git.io/Jzsuu) && . ~/.bashrc
```