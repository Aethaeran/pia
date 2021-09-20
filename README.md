# PIA

## PIA Split Tunnel Script
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
Make it executable by command:~~

    chmod +x pia_ecryptfs.sh

~~and run as root:~~

    sudo ./pia_ecryptfs.sh
