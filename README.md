# myrha
Summarize supportdump files from Mirantis MCC/MOS clusters

# Installation:
Download the .sh scripts which corresponds to your distro (myrha-mac.sh or myrha-linux.sh). After that, create a link to /usr/local/bin folder:

$ sudo ln -s ~/Downloads/myrha-mac.sh /usr/local/bin/myrha

You should run "myrha" command inside the supportdump extracted folder, where either MCC or MOS logs are located. Example:

$ ~/Downloads/test/kaas-bootstrap/logs/ ls
kaas-mgmt/  mos/
$ ~/Downloads/test/kaas-bootstrap/logs/ myrha

Myrha will check for nececessary packages and will prompt you to install them if needed (using apt,dnf or brew).
Once the script is complete, a new folder called "myrha" will be created, where yaml files will be created, containing the summary of different cluster aspects (MCC and/or MOS)
