# myrha
Summarize supportdump files from Mirantis MCC/MOS clusters<br>
<br>
# Installation:
Download the .sh scripts which corresponds to your distro (myrha-mac.sh or myrha-linux.sh). After that, create a link to /usr/local/bin folder:<br>

```
$ sudo ln -s ~/Downloads/myrha-mac.sh /usr/local/bin/myrha
```

You should run "myrha" command inside the supportdump extracted folder, where either MCC or MOS logs are located. Example:<br>

```
$ ~/Downloads/test/kaas-bootstrap/logs/ ls
kaas-mgmt/  mos/
$ ~/Downloads/test/kaas-bootstrap/logs/ myrha
```

Myrha will check for nececessary packages and will prompt you to install them if needed (using apt,dnf or brew).<br>
Once the script is complete, a new folder called "myrha" will be created, where yaml files will be created, containing the summary of different cluster aspects (MCC and/or MOS)<br><br>
By default, the script is set to automatically open Sublime text with all files generated. You can also open them up on vim by commenting the following lines:<br>

```
# Run sublime text to load all files:
/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl --new-window --command $LOGPATH/*.yaml 2> /dev/null
```

and uncommenting the following ones:<br>

```
# Run nvim to load all files:
#nvim -R -c 'silent argdo set syntax=yaml' -p $LOGPATH/*_*
#nvim -R -p $LOGPATH/*.yaml
```

