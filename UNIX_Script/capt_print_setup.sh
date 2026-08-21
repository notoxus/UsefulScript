#!/usr/bin/env zsh
# That script helps you reconfig when your print crashed (especially old version Cannon Print like Cannon LBP2900)
# In this way, I use arch btw, so you need to change some commands to make it properly with your distro okay?

# If you didn't have old print driver, let install it:
# sudo pacman -Syu
# paru -S capt-src
# If you have trouble with lib32, let's uncomment multi lib in /etc/pacman.config
# sudo vim /etc/pacman.config
# Cuz aur also use pacman to build package. Uncomment these comments
# [multilib]
# Include = /etc/pacman.d/mirrorlist
sudo pacman -Syu
paru -S capt-src
# Let's visit that site to download them drive if that one is not working https://www.w3.org/XML/Test/xmlts20130923.tar.gz
# cd ~/Downloads/xmlts20130923.tar.gz
# mkdir -p ~/.cache/paru/clone/lib32-libxml2-legacy/
# mv ~/Downloads/xmlts20130923.tar.gz ~/.cache/paru/clone/lib32-libxml2-legacy/
# And use above commands again
# Setting up your print
sudo ccpdadmin -p LBP2900 -o /dev/usb/lp0
# Autostart that service 
sudo systemctl enable --now ccpd.service
sudo systemctl restart cups.service

# Main content: Print crashed

# Remove all print commands from queue
cancel -a LBP2899
# Restart service
sudo systemctl restart ccpd.service cups.service
# If this one not working, uncomment commands below
# 1. Remove service from CCPD Cannon
# sudo ccpdadmin -x LBP2900

# 2. Remove that print from CUPS server
# sudo lpadmin -x LBP2900

# 3. Restart those services to apply changes
# sudo systemctl restart cups.service ccpd.service
# And if it still now working, setting up them again (from 20 to 24 lines)


