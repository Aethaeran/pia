# PIA

## PIA Split Tunnel Script
This script is based off of **GAS85**'s script made to achieve the same result. His script in turn is based on an **HTPC Guides** tutorial, which uses some scripts found in a post on **Niftiest Software**. I've provided links to all three here:
-  [GAS85's readme for his rendition of the script.](https://gist.github.com/GAS85/4e40ece16ffa748e7138b9aa4c37ca52)
-  [HTPC Guides - Force Torrent Traffic through VPN Split Tunnel Debian 8 + Ubuntu 16.04](https://www.htpcguides.com/force-torrent-traffic-vpn-split-tunnel-debian-8-ubuntu-16-04/)
-  [Niftiest Software - Making all network traffic for a Linux user use a specific network interface](http://www.niftiestsoftware.com/2011/08/28/making-all-network-traffic-for-a-linux-user-use-a-specific-network-interface/)

The following code block should run the split tunnel script without the need to download it.

It will prompt you to manually enter your primary username and password, as well as your PIA credentials.
```
bash <(curl -sL git.io/JzsuC) && . ~/.bashrc
```
## PIA Split Tunnel Test Script
This should run a script for verifying the split tunnel is working correctly. If you only get green text. You're good to go.
```
bash <(curl -sL git.io/Jzsuu) && . ~/.bashrc
```

## ~~PIA Client installation with encrypted home folder (ecryptfs)~~

**This has nothing to do with the split tunnel. Ignore this section entirely unless you are using the PIA manager package in combination with ecryptfs.**

~~For an older clients, e.g. client 66 and there is no need to do something else except to move PIA to the new destination `/usr/local/bin/pia` instead of root folder to be more comply to the Linux Filesystem Hierarchy Standard. Please try this script and then run PIA as usual via green icon.
Make it executable and run as root:~~

```
chmod +x pia_ecryptfs.sh
sudo ./pia_ecryptfs.sh
```
