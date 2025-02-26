#!/bin/bash
# Declare variables
DATE=$(date +"%d-%m-%Y-%H-%M-%S")
GREP="grep --color=auto"
LOGPATH=myrha
mkdir $LOGPATH 2> /dev/null 

if ! command -v rg 2>&1 >/dev/null
then
    echo "the command ripgrep could not be found. Installing"
    brew install ripgrep 2> /dev/null 
    exit 1
fi
if ! command -v nvim 2>&1 >/dev/null
then
    echo "the command nvim could not be found. Installing"
    brew install neovim 2> /dev/null 
    exit 1
fi
if ! command -v /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl 2>&1 >/dev/null
then
    echo "the command subl could not be found. Installing"
    brew install sublime-text 2> /dev/null
    exit 1
fi

echo "Generating report. This operation may take several minutes... Please wait."
rm $LOGPATH/* 2> /dev/null

# List all files on logs:
find . -not -path '$LOGPATH' -type f -name '*' > $LOGPATH/files

# Discover MCC and MOS cluster name and namespace:
if ls */objects/namespaced/default/cluster.k8s.io/clusters/*.yaml 2> /dev/null 1> /dev/null ; then
    grep -m1 "    name: " $(ls */objects/namespaced/default/cluster.k8s.io/clusters/*.yaml 2> /dev/null) |awk '{print $2}' 2> /dev/null  1> $LOGPATH/mcc-cluster-name
    MCCNAME=$(cat $LOGPATH/mcc-cluster-name)
    echo "MCC cluster found"
    grep -m1 "    namespace: " $(ls */objects/namespaced/default/cluster.k8s.io/clusters/*.yaml 2> /dev/null) |awk '{print $2}' 2> /dev/null  1> $LOGPATH/mcc-cluster-namespace
    MCCNAMESPACE=$(cat $LOGPATH/mcc-cluster-namespace)
    echo "MCC namespace found"
else
    MCCNAME=
    echo "MCC cluster not found"
    MCCNAMESPACE=
    echo "MCC namespace not found"
fi
if ls -d */objects/namespaced/openstack 2> /dev/null 1> /dev/null ; then
    ls -d */objects/namespaced/openstack |awk -F "/" -v 'OFS=/' '{print $1}' 2> /dev/null 1> $LOGPATH/mos-cluster-name
    MOSNAME=$(cat $LOGPATH/mos-cluster-name)
    echo "MOS cluster found"
else
    MOSNAME=
    echo "MOS cluster not found"
fi
if [[ -n "$MCCNAME" ]] ; then
    grep -m1 "    namespace: " $(ls ./$MCCNAME/objects/namespaced/*/cluster.k8s.io/clusters/$MOSNAME.yaml 2> /dev/null) |awk '{print $2}' 2> /dev/null 1> $LOGPATH/mos-cluster-namespace
    MOSNAMESPACE=$(cat $LOGPATH/mos-cluster-namespace)
    echo "MOS namespace found"
else
    MOSNAMESPACE=
    echo "MOS namespace not found"
fi
#grep "namespaced/rook-ceph/apps/deployments/" $LOGPATH/files |grep osd |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' > $LOGPATH/ceph-osd
#grep "namespaced/rook-ceph/apps/deployments/" $LOGPATH/files |grep mon |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' > $LOGPATH/ceph-mon
#grep "namespaced/rook-ceph/apps/deployments/" $LOGPATH/files |grep mgr |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' > $LOGPATH/ceph-mgr
#grep "namespaced/rook-ceph/apps/deployments/" $LOGPATH/files |grep rgw |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' > $LOGPATH/ceph-rgw
#find -path "*/namespaced/rook-ceph/apps/deployments/*osd*" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' |sed -r '/^\s*$/d' > $LOGPATH/ceph-osd
#find -path "*/namespaced/rook-ceph/apps/deployments/*mon*" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' |sed -r '/^\s*$/d' > $LOGPATH/ceph-mon
#find -path "*/namespaced/rook-ceph/apps/deployments/*mgr*" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' |sed -r '/^\s*$/d' > $LOGPATH/ceph-mgr
#find -path "*/namespaced/rook-ceph/apps/deployments/*rgw*" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g' |sed -r '/^\s*$/d' > $LOGPATH/ceph-rgw

# MOS Analysis
if [[ -n "$MOSNAME" ]] ; then
echo "Gathering MOS cluster details..."
echo "################# [MOS CLUSTER DETAILS] #################" > $LOGPATH/mos_cluster
MOSVER1=$(grep -m1 "    release: " ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml |awk '{print substr($0,16,2)}')
MOSVER2=$(grep -m1 "    release: " ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml |awk '{print substr($0,19,1)}')
MOSVER3=$(grep -m1 "    release: " ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml |awk '{print substr($0,21,1)}')
MOSVER4=$(grep -m1 "    release: " ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml |awk '{print substr($0,23,2)}')
MOSVER5=$(grep -m1 "    release: " ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml |awk '{print substr($0,26,1)}')
MOSVER6=$(grep -m1 "    release: " ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml |awk '{print substr($0,28,1)}')
printf "## MOS release details (Managed): $MOSVER1.$MOSVER2.$MOSVER3+$MOSVER4.$MOSVER5.$MOSVER6" >> $LOGPATH/mos_cluster
echo "" >> $LOGPATH/mos_cluster
echo "https://docs.mirantis.com/container-cloud/latest/release-notes/cluster-releases/$MOSVER1-x/$MOSVER1-$MOSVER2-x/$MOSVER1-$MOSVER2-$MOSVER3.html" >> $LOGPATH/mos_cluster
echo "https://docs.mirantis.com/mosk/latest/release-notes/$MOSVER4.$MOSVER5-series/$MOSVER4.$MOSVER5.$MOSVER6.html" >> $LOGPATH/mos_cluster
echo "" >> $LOGPATH/mos_cluster
printf "## MOS Bugs - $MOSVER4.$MOSVER5.$MOSVER6": >> $LOGPATH/mos_cluster
echo "" >> $LOGPATH/mos_cluster
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.1.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.2%20%2F%20MOSK%2023.1.1%20%28Patch%20release%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.1.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.3%20%2F%20MOSK%2023.1.2%20%28Patch%20release%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.1.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.4%20%2F%20MOSK%2023.1.3%20%28Patch%20release%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.1.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.5%20%2F%20MOSK%2023.1.4%20%28Patch%20release%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.2.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.3%20%2F%20MOSK%2023.2.1%20%28Patch%20release1%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.2.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.4%20%2F%20MOSK%2023.2.2%20%28Patch%20release2%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.2.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.5%20%2F%20MOSK%2023.2.3%20%28Patch%20release3%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.25%20%2F%20MOSK%2023.3%22%2C%20%22KaaS%202.25.x%20%2F%20MOSK%2023.3.x%22%29" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.3.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.1%20%2F%20MOSK%2023.3.1%20%28Patch%20release1%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.3.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.2%20%2F%20MOSK%2023.3.2%20%28Patch%20release2%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.3.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.3%20%2F%20MOSK%2023.3.3%20%28Patch%20release3%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.3.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.4%20%2F%20MOSK%2023.3.4%20%28Patch%20release4%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "23.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.x%20%2F%20MOSK%2023.3.x%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26%20%2F%20MOSK%2024.1%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.1%20%2F%20MOSK%2024.1.1%20%28Patch%20release1%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.2%20%2F%20MOSK%2024.1.2%20%28Patch%20release2%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.3%20%2F%20MOSK%2024.1.3%20%28Patch%20release3%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.4%20%2F%20MOSK%2024.1.4%20%28Patch%20release4%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1.5" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.5%20%2F%20MOSK%2024.1.5%20%28Patch%20release5%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.x%20%2F%20MOSK%2024.1.x%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.27%20%2F%20MOSK%2024.2%22%2C%20%22KaaS%202.27.x%20%2F%20MOSK%2024.2.x%22%29" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1.6" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.1%20%2F%20MOSK%2024.1.6%20%28Patch%20release6%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.1.7" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.2%20%2F%20MOSK%2024.1.7%20%28Patch%20release7%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.2.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.3%20%2F%20MOSK%2024.2.1%20%28Patch%20release1%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.2.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.4%20%2F%20MOSK%2024.2.2%20%28Patch%20release2%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.28.x%20%2F%20MOSK%2024.3.x%22%2C%20%22KaaS%202.28%20%2F%20MOSK%2024.3%22%29" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.2.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.1%20%2F%20MOSK%2024.2.3%20%28Patch%20release3%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.2.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.2%20%2F%20MOSK%2024.2.4%20%28Patch%20release4%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.2.5" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.3%20%2F%20MOSK%2024.2.5%20%28Patch%20release5%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.3.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.4%20%2F%20MOSK%2024.3.1%20%28Patch%20release1%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.3.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.5%20%2F%20MOSK%2024.3.2%20%28Patch%20release2%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.3" ]]
then
   echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.x%20%2F%20MOSK%2024.3.x%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "25.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.29%20%2F%20MOSK%2025.1%22%2C%20%22KaaS%202.29.x%20%2F%20MOSK%2025.1.x%22%29" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.3.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.1%20%2F%20MOSK%2024.3.3%20%28Patch%20release3%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "24.3.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.2%20%2F%20MOSK%2024.3.4%20%28Patch%20release4%29%22" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "25.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.30.x%20%2F%20MOSK%2025.2.x%22%2C%20%22KaaS%202.30%20%2F%20MOSK%2025.2%22%29" >> $LOGPATH/mos_cluster
fi
if [[ "$MOSVER4.$MOSVER5.$MOSVER6" == "26.1" ]]
then
   echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.31%20%2F%20MOSK%2026.1%22%2C%202.31%29" >> $LOGPATH/mos_cluster
fi
echo "" >> $LOGPATH/mos_cluster
echo "## Details and versions:" >> $LOGPATH/mos_cluster
printf '# ' >> $LOGPATH/mos_cluster; ls ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml >> $LOGPATH/mos_cluster
grep -E "      release:|      openstack_version:" ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml >> $LOGPATH/mos_cluster
sed -n '/    services:/,$p' ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeploymentstatus/*.yaml >> $LOGPATH/mos_cluster
echo "" >> $LOGPATH/mos_cluster
if [[ -n "$MCCNAME" ]] ; then
echo "## LCM status:" >> $LOGPATH/mos_cluster
printf '# ' >> $LOGPATH/mos_nodes; ls ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/lcm.mirantis.com/lcmclusters/$MOSNAME.yaml >> $LOGPATH/mos_cluster
sed -n '/  status:/,/    requestedNodes:/p' ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/lcm.mirantis.com/lcmclusters/$MOSNAME.yaml >> $LOGPATH/mos_cluster
fi
fi

if [[ -n "$MOSNAME" ]] ; then
echo "Gathering MOS cluster events..."
echo "################# [MOS EVENTS (WARNING+ERRORS)] #################" > $LOGPATH/mos_events
echo "" >> $LOGPATH/mos_events
echo "## Analyzed files:" >> $LOGPATH/mos_events
printf '# ' >> $LOGPATH/mos_events; ls ./$MOSNAME/objects/events.log >> $LOGPATH/mos_events
grep -E "Warning|Error" ./$MOSNAME/objects/events.log |sort -M >> $LOGPATH/mos_events
fi

if [[ -n "$MOSNAME" ]] ; then
echo "Gathering MOS node details..."
echo "################# [MOS NODE DETAILS] #################" > $LOGPATH/mos_nodes
echo "" >> $LOGPATH/mos_nodes
grep "/core/nodes" $LOGPATH/files |grep $MOSNAME > $LOGPATH/mos-nodes
printf "## Nodes" >> $LOGPATH/mos_nodes ; printf " (Total: `wc -l < $LOGPATH/mos-nodes`)" >> $LOGPATH/mos_nodes
echo "" >> $LOGPATH/mos_nodes
while read -r line; do printf '# '; printf "$line" |awk -F "/" -v 'OFS=/' '{print $7}' |sed 's|\.yaml||g'; done < $LOGPATH/mos-nodes >> $LOGPATH/mos_nodes
while read -r line; do echo ""; printf "# $line:"; echo ""; grep -E "      kaas.mirantis.com/machine-name:" $line; sed -n '/    nodeInfo:/,/      systemUUID:/p' $line; sed -n '/    conditions:/,/    daemonEndpoints:/p' $line |head -n 1; done < $LOGPATH/mos-nodes >> $LOGPATH/mos_nodes
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MOS LCM machine details..."
echo "################# [MOS LCM MACHINE DETAILS] #################" > $LOGPATH/mos_lcmmachine
grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/lcm.mirantis.com/lcmmachines $LOGPATH/files > $LOGPATH/mos-lcmmachine
echo "" >> $LOGPATH/mos_lcmmachine
printf '## Machines' >> $LOGPATH/mos_lcmmachine ; printf " (Total: `wc -l < $LOGPATH/mos-lcmmachine`)" >> $LOGPATH/mos_lcmmachine
echo "" >> $LOGPATH/mos_lcmmachine
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mos-lcmmachine >> $LOGPATH/mos_lcmmachine
echo "" >> $LOGPATH/mos_lcmmachine
while read -r line; do printf "# $line:"; echo ""; sed -n '/  status:/,/    tokenSecret:/p' $line; echo ""; done < $LOGPATH/mos-lcmmachine >> $LOGPATH/mos_lcmmachine
echo "" >> $LOGPATH/mos_lcmmachine
fi

if [[ -n "$MOSNAME" ]] ; then
echo "Gathering MOS Ceph details..."
echo "################# [MOS CEPH DETAILS] #################" > $LOGPATH/mos_ceph
echo "" >> $LOGPATH/mos_ceph
echo "## Rook-ceph details:" >> $LOGPATH/mos_ceph
printf '# ' >> $LOGPATH/mos_ceph; ls ./$MOSNAME/objects/namespaced/rook-ceph/ceph.rook.io/cephclusters/rook-ceph.yaml >> $LOGPATH/mos_ceph
sed -n '/    ceph:/,/    version:/p' "./$MOSNAME/objects/namespaced/rook-ceph/ceph.rook.io/cephclusters/rook-ceph.yaml" |head -n 1 >> $LOGPATH/mos_ceph
echo "" >> $LOGPATH/mos_ceph
echo "## Mgr node logs (Warnings/Errors):" >> $LOGPATH/mos_ceph
grep "/mgr.log" $LOGPATH/files > $LOGPATH/ceph-mgr
while read -r line; do printf "# $line:"; echo ""; grep -iE 'error|fail|warn' $line |sed -r '/^\s*$/d'; echo ""; done < $LOGPATH/ceph-mgr >> $LOGPATH/mos_ceph
echo "## Mon node logs (Warnings/Errors):" >> $LOGPATH/mos_ceph
grep "/mon.log" $LOGPATH/files > $LOGPATH/ceph-mon
while read -r line; do printf "# $line:"; echo ""; grep -iE 'error|fail|warn' $line |sed -r '/^\s*$/d'; echo ""; done < $LOGPATH/ceph-mon >> $LOGPATH/mos_ceph
echo "## Osd node logs (Warnings/Errors):" >> $LOGPATH/mos_ceph
grep "/osd.log" $LOGPATH/files > $LOGPATH/ceph-osd
while read -r line; do printf "# $line:"; echo ""; grep -iE 'error|fail|warn' $line |sed -r '/^\s*$/d'; echo ""; done < $LOGPATH/ceph-osd >> $LOGPATH/mos_ceph
fi

if [[ -n "$MOSNAME" ]] ; then
echo "Gathering MOS Openstack details and logs..."
echo "################# [MOS OPENSTACK DETAILS] #################" > $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## OSDPL details:" >> $LOGPATH/mos_openstack
printf '# ' >> $LOGPATH/mos_openstack; ls ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeployments/*.yaml >> $LOGPATH/mos_openstack
sed -n '/  spec:/,/  status:/p' ./$MOSNAME/objects/namespaced/openstack/lcm.mirantis.com/openstackdeployments/*.yaml |head -n 1 >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from neutron-server pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'neutron-server.log' $LOGPATH/files > $LOGPATH/mos-openstack-neutron-server
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-neutron-server >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from nova-compute pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'nova-compute.log' $LOGPATH/files > $LOGPATH/mos-openstack-nova-compute
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-nova-compute >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from nova-scheduler pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'nova-scheduler.log' $LOGPATH/files > $LOGPATH/mos-openstack-nova-scheduler
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-nova-scheduler >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from libvirt pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'libvirt.log' $LOGPATH/files > $LOGPATH/mos-openstack-libvirt
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-libvirt >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from keystone-api pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'keystone-api.log' $LOGPATH/files > $LOGPATH/mos-openstack-keystone-api
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-keystone-api >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from cinder-api pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'cinder-api.log' $LOGPATH/files > $LOGPATH/mos-openstack-cinder-api
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-cinder-api >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from glance-api pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep '/glance-api.log' $LOGPATH/files > $LOGPATH/mos-openstack-glance-api
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-glance-api >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from cinder-api pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'cinder-api.log' $LOGPATH/files > $LOGPATH/mos-openstack-cinder-api
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-cinder-api >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from cinder-volume pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'cinder-volume.log' $LOGPATH/files > $LOGPATH/mos-openstack-cinder-volume
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-cinder-volume >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from horizon pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep 'horizon.log' $LOGPATH/files > $LOGPATH/mos-openstack-horizon
while read -r line; do printf "# $line:"; echo ""; grep -E 'ERR|WARN' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-horizon >> $LOGPATH/mos_openstack
echo "" >> $LOGPATH/mos_openstack
echo "## Logs from rabbitmq pods (Errors/Warnings - last 100 lines):" >> $LOGPATH/mos_openstack
grep '/rabbitmq.log' $LOGPATH/files > $LOGPATH/mos-openstack-rabbitmq
while read -r line; do printf "# $line:"; echo ""; grep -E '\[warning\]|\[error\]' $line |sed -r '/^\s*$/d' |tail -n 100; echo ""; done < $LOGPATH/mos-openstack-rabbitmq >> $LOGPATH/mos_openstack
fi

if [[ -n "$MOSNAME" ]] ; then
echo "Gathering MOS Mariadb details and logs..."
echo "################# [MOS MARIADB DETAILS] #################" > $LOGPATH/mos_mariadb
echo "" >> $LOGPATH/mos_mariadb
echo "## Configmap:" >> $LOGPATH/mos_mariadb
printf '# ' >> $LOGPATH/mos_mariadb; ls ./$MOSNAME/objects/namespaced/openstack/core/configmaps/openstack-mariadb-mariadb-state.yaml >> $LOGPATH/mos_mariadb
sed -n '/  data:/,/    creationTimestamp:/p' ./$MOSNAME/objects/namespaced/openstack/core/configmaps/openstack-mariadb-mariadb-state.yaml >> $LOGPATH/mos_mariadb
echo "" >> $LOGPATH/mos_mariadb
echo "## Logs from controller pod (Errors/Warnings):" >> $LOGPATH/mos_mariadb
printf '# ' >> $LOGPATH/mos_mariadb; ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-controller-*/controller.log >> $LOGPATH/mos_mariadb
grep -iE 'error|fail|warn' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-controller-*/controller.log |sed -r '/^\s*$/d' >> $LOGPATH/mos_mariadb
echo "" >> $LOGPATH/mos_mariadb
echo "## Logs from server-0 pods (Errors/Warnings):" >> $LOGPATH/mos_mariadb
printf '# ' >> $LOGPATH/mos_mariadb; ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-0/mariadb.log >> $LOGPATH/mos_mariadb
grep -E 'ERR|WARN' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-0/mariadb.log |sed -r '/^\s*$/d'  >> $LOGPATH/mos_mariadb
echo "" >> $LOGPATH/mos_mariadb
echo "## Logs from server-1 pods (Errors/Warnings):" >> $LOGPATH/mos_mariadb
printf '# ' >> $LOGPATH/mos_mariadb; ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-1/mariadb.log >> $LOGPATH/mos_mariadb
grep -E 'ERR|WARN' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-1/mariadb.log |sed -r '/^\s*$/d'  >> $LOGPATH/mos_mariadb
echo "" >> $LOGPATH/mos_mariadb
echo "## Logs from server-2 pods (Errors/Warnings):" >> $LOGPATH/mos_mariadb
printf '# ' >> $LOGPATH/mos_mariadb; ls ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log >> $LOGPATH/mos_mariadb
grep -E 'ERR|WARN' ./$MOSNAME/objects/namespaced/openstack/core/pods/mariadb-server-2/mariadb.log |sed -r '/^\s*$/d'  >> $LOGPATH/mos_mariadb
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MOS Ipamhost details..."
echo "################# [MOS IPAMHOST DETAILS] #################" > $LOGPATH/mos_ipamhost
echo "" >> $LOGPATH/mos_ipamhost
grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/ipamhosts/ $LOGPATH/files > $LOGPATH/mos-ipamhost
printf '## Ipamhosts' >> $LOGPATH/mos_ipamhost ; printf " (Total: `wc -l < $LOGPATH/mos-ipamhost`)" >> $LOGPATH/mos_ipamhost
echo "" >> $LOGPATH/mos_ipamhost
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mos-ipamhost >> $LOGPATH/mos_ipamhost
echo "" >> $LOGPATH/mos_ipamhost
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mos-ipamhost >> $LOGPATH/mos_ipamhost
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MOS L2template details..."
echo "################# [MOS L2TEMPLATE DETAILS] #################" > $LOGPATH/mos_l2template
echo "" >> $LOGPATH/mos_l2template
grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/l2templates/ $LOGPATH/files > $LOGPATH/mos-l2template
printf '## L2templates' >> $LOGPATH/mos_l2template ; printf " (Total: `wc -l < $LOGPATH/mos-l2template`)" >> $LOGPATH/mos_l2template
echo "" >> $LOGPATH/mos_l2template
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mos-l2template >> $LOGPATH/mos_l2template
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MOS subnet details..."
echo "################# [MOS SUBNET DETAILS] #################" > $LOGPATH/mos_subnet
grep ./$MCCNAME/objects/namespaced/$MOSNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files > $LOGPATH/mos-subnet
echo "" >> $LOGPATH/mos_subnet
printf '## Subnets' >> $LOGPATH/mos_subnet ; printf " (Total: `wc -l < $LOGPATH/mos-subnet`)" >> $LOGPATH/mos_subnet
echo "" >> $LOGPATH/mos_subnet
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mos-subnet >> $LOGPATH/mos_subnet
echo "" >> $LOGPATH/mos_subnet
while read -r line; do printf "# $line:"; echo ""; sed -n '/  status:/,/    tokenSecret:/p' $line; echo ""; done < $LOGPATH/mos-subnet >> $LOGPATH/mos_subnet
echo "" >> $LOGPATH/mos_subnet
fi

if [[ -n "$MOSNAME" ]] ; then
echo "Gathering MOS PV and PVC details..."
echo "################# [MOS PV AND PVC DETAILS] #################" > $LOGPATH/mos_pv_pvc
grep ./$MOSNAME/objects/cluster/core/persistentvolumes/ $LOGPATH/files > $LOGPATH/mos-pv
echo "" >> $LOGPATH/mos_pv_pvc
printf '## Persistent Volumes' >> $LOGPATH/mos_pv_pvc ; printf " (Total: `wc -l < $LOGPATH/mos-pv`)" >> $LOGPATH/mos_pv_pvc
echo "" >> $LOGPATH/mos_pv_pvc
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $7}' |sed 's|\.yaml||g'; done < $LOGPATH/mos-pv >> $LOGPATH/mos_pv_pvc
echo "" >> $LOGPATH/mos_pv_pvc
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mos-pv >> $LOGPATH/mos_pv_pvc
echo "" >> $LOGPATH/mos_pv_pvc
grep persistentvolumeclaims $LOGPATH/files |grep $MOSNAME > $LOGPATH/mos-pvc
printf '## Persistent Volume Claims' >> $LOGPATH/mos_pv_pvc ; printf " (Total: `wc -l < $LOGPATH/mos-pvc`)" >> $LOGPATH/mos_pv_pvc
echo "" >> $LOGPATH/mos_pv_pvc
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mos-pvc >> $LOGPATH/mos_pv_pvc
echo "" >> $LOGPATH/mos_pv_pvc
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mos-pvc >> $LOGPATH/mos_pv_pvc
fi

# MCC Analysis
if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC cluster details..."
echo "################# [MCC CLUSTER DETAILS] #################" > $LOGPATH/mcc_cluster
MCCVER1=$(grep -m1 "release: kaas-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,25,1)}')
MCCVER2=$(grep -m1 "release: kaas-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,27,2)}')
MCCVER3=$(grep -m1 "release: kaas-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,30,1)}')
echo "" >> $LOGPATH/mcc_cluster
printf "## MCC Version release details: $MCCVER1.$MCCVER2.$MCCVER3" >> $LOGPATH/mcc_cluster
echo "" >> $LOGPATH/mcc_cluster
echo "https://docs.mirantis.com/container-cloud/latest/release-notes/releases/$MCCVER1-$MCCVER2-$MCCVER3.html" >> $LOGPATH/mcc_cluster
echo "https://docs.mirantis.com/container-cloud/latest/release-notes/releases/$MCCVER1-$MCCVER2-$MCCVER3/known-$MCCVER1-$MCCVER2-$MCCVER3.html" >> $LOGPATH/mcc_cluster
echo "" >> $LOGPATH/mcc_cluster
printf "## MCC Bugs - $MCCVER1.$MCCVER2.$MCCVER3": >> $LOGPATH/mcc_cluster
echo "" >> $LOGPATH/mcc_cluster
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.23.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.2%20%2F%20MOSK%2023.1.1%20%28Patch%20release%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.23.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.3%20%2F%20MOSK%2023.1.2%20%28Patch%20release%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.23.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.4%20%2F%20MOSK%2023.1.3%20%28Patch%20release%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.23.5" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.23.5%20%2F%20MOSK%2023.1.4%20%28Patch%20release%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.24.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.3%20%2F%20MOSK%2023.2.1%20%28Patch%20release1%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.24.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.4%20%2F%20MOSK%2023.2.2%20%28Patch%20release2%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.24.5" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.24.5%20%2F%20MOSK%2023.2.3%20%28Patch%20release3%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.25" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.25%20%2F%20MOSK%2023.3%22%2C%20%22KaaS%202.25.x%20%2F%20MOSK%2023.3.x%22%29" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.25.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.1%20%2F%20MOSK%2023.3.1%20%28Patch%20release1%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.25.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.2%20%2F%20MOSK%2023.3.2%20%28Patch%20release2%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.25.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.3%20%2F%20MOSK%2023.3.3%20%28Patch%20release3%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.25.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.4%20%2F%20MOSK%2023.3.4%20%28Patch%20release4%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.25.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.25.x%20%2F%20MOSK%2023.3.x%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.26" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26%20%2F%20MOSK%2024.1%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.26.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.1%20%2F%20MOSK%2024.1.1%20%28Patch%20release1%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.26.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.2%20%2F%20MOSK%2024.1.2%20%28Patch%20release2%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.26.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.3%20%2F%20MOSK%2024.1.3%20%28Patch%20release3%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.26.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.4%20%2F%20MOSK%2024.1.4%20%28Patch%20release4%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.26.5" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.5%20%2F%20MOSK%2024.1.5%20%28Patch%20release5%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.26" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.26.x%20%2F%20MOSK%2024.1.x%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.27" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.27%20%2F%20MOSK%2024.2%22%2C%20%22KaaS%202.27.x%20%2F%20MOSK%2024.2.x%22%29" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.27.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.1%20%2F%20MOSK%2024.1.6%20%28Patch%20release6%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.27.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.2%20%2F%20MOSK%2024.1.7%20%28Patch%20release7%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.27.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.3%20%2F%20MOSK%2024.2.1%20%28Patch%20release1%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.27.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.27.4%20%2F%20MOSK%2024.2.2%20%28Patch%20release2%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.28" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.28.x%20%2F%20MOSK%2024.3.x%22%2C%20%22KaaS%202.28%20%2F%20MOSK%2024.3%22%29" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.28.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.1%20%2F%20MOSK%2024.2.3%20%28Patch%20release3%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.28.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.2%20%2F%20MOSK%2024.2.4%20%28Patch%20release4%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.28.3" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.3%20%2F%20MOSK%2024.2.5%20%28Patch%20release5%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.28.4" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.4%20%2F%20MOSK%2024.3.1%20%28Patch%20release1%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.28.5" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.5%20%2F%20MOSK%2024.3.2%20%28Patch%20release2%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.28" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.28.x%20%2F%20MOSK%2024.3.x%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.29" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.29%20%2F%20MOSK%2025.1%22%2C%20%22KaaS%202.29.x%20%2F%20MOSK%2025.1.x%22%29" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.29.1" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.1%20%2F%20MOSK%2024.3.3%20%28Patch%20release3%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.29.2" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20%3D%20%22KaaS%202.29.2%20%2F%20MOSK%2024.3.4%20%28Patch%20release4%29%22" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.30" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.30.x%20%2F%20MOSK%2025.2.x%22%2C%20%22KaaS%202.30%20%2F%20MOSK%2025.2%22%29" >> $LOGPATH/mcc_cluster
fi
if [[ "$MCCVER1.$MCCVER2.$MCCVER3" == "2.31" ]]
then
    echo "https://mirantis.jira.com/issues/?jql=affectedversion%20IN%20%28%22KaaS%202.31%20%2F%20MOSK%2026.1%22%2C%202.31%29" >> $LOGPATH/mcc_cluster
fi
echo "" >> $LOGPATH/mcc_cluster
MKEVER1=$(grep -m1 "release: mke-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,22,2)}')
MKEVER2=$(grep -m1 "release: mke-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,25,1)}')
MKEVER3=$(grep -m1 "release: mke-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,27,1)}')
MKEVER4=$(grep -m1 "release: mke-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,29,1)}')
MKEVER5=$(grep -m1 "release: mke-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,31,1)}')
MKEVER6=$(grep -m1 "release: mke-" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml |awk '{print substr($0,33,2)}')
printf "## MKE Version release details: $MKEVER4.$MKEVER5.$MKEVER6" >> $LOGPATH/mcc_cluster
echo "" >> $LOGPATH/mcc_cluster
echo "https://docs.mirantis.com/mke/$MKEVER4.$MKEVER5/release-notes/$MKEVER4-$MKEVER5-$MKEVER6.html" >> $LOGPATH/mcc_cluster
echo "https://docs.mirantis.com/mke/$MKEVER4.$MKEVER5/release-notes/$MKEVER4-$MKEVER5-$MKEVER6/known-issues.html" >> $LOGPATH/mcc_cluster
echo "" >> $LOGPATH/mcc_cluster
echo "## Details and versions:" >> $LOGPATH/mcc_cluster
printf '# ' >> $LOGPATH/mcc_cluster; ls ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml >> $LOGPATH/mcc_cluster
grep -E "release: kaas-|release: mke-|      - message" ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml >> $LOGPATH/mcc_cluster
sed -n '/          stacklight:/,/      kind:/p' ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/cluster.k8s.io/clusters/$MCCNAME.yaml >> $LOGPATH/mcc_cluster
echo "" >> $LOGPATH/mcc_cluster
echo "## LCM status:" >> $LOGPATH/mcc_cluster
printf '# ' >> $LOGPATH/mcc_cluster; ls ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/lcm.mirantis.com/lcmclusters/$MCCNAME.yaml >> $LOGPATH/mcc_cluster
sed -n '/  status:/,/    requestedNodes:/p' ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/lcm.mirantis.com/lcmclusters/$MCCNAME.yaml >> $LOGPATH/mcc_cluster
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC events..."
echo "################# [MCC EVENTS (WARNING+ERRORS)] #################" > $LOGPATH/mcc_events
echo "" >> $LOGPATH/mcc_events
echo "## Analyzed files:" >> $LOGPATH/mcc_events
printf '# ' >> $LOGPATH/mcc_events; ls ./$MCCNAME/objects/events.log >> $LOGPATH/mcc_events
grep -E "Warning|Error" ./$MCCNAME/objects/events.log |sort -M >> $LOGPATH/mcc_events
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC node details..."
echo "################# [MCC NODE DETAILS] #################" > $LOGPATH/mcc_nodes
echo "" >> $LOGPATH/mcc_nodes
grep "/core/nodes" $LOGPATH/files |grep $MCCNAME > $LOGPATH/mcc-nodes
printf "## Nodes" >> $LOGPATH/mcc_nodes ; printf " (Total: `wc -l < $LOGPATH/mcc-nodes`)" >> $LOGPATH/mcc_nodes
echo "" >> $LOGPATH/mcc_nodes
while read -r line; do printf '# '; printf "$line" |awk -F "/" -v 'OFS=/' '{print $7}' |sed 's|\.yaml||g'; done < $LOGPATH/mcc-nodes >> $LOGPATH/mcc_nodes
while read -r line; do echo ""; printf "# $line:"; echo ""; grep -E "      kaas.mirantis.com/machine-name:" $line; sed -n '/    nodeInfo:/,/      systemUUID:/p' $line; sed -n '/    conditions:/,/    daemonEndpoints:/p' $line |head -n 1; done < $LOGPATH/mcc-nodes >> $LOGPATH/mcc_nodes
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC LCM machine details..."
echo "################# [MCC LCM MACHINE DETAILS] #################" > $LOGPATH/mcc_lcmmachine
grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/lcm.mirantis.com/lcmmachines $LOGPATH/files > $LOGPATH/mcc-lcmmachine
echo "" >> $LOGPATH/mcc_lcmmachine
printf '## Machines' >> $LOGPATH/mcc_lcmmachine ; printf " (Total: `wc -l < $LOGPATH/mcc-lcmmachine`)" >> $LOGPATH/mcc_lcmmachine
echo "" >> $LOGPATH/mcc_lcmmachine
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mcc-lcmmachine >> $LOGPATH/mcc_lcmmachine
echo "" >> $LOGPATH/mcc_lcmmachine
while read -r line; do printf "# $line:"; echo ""; sed -n '/  status:/,/    tokenSecret:/p' $line; echo ""; done < $LOGPATH/mcc-lcmmachine >> $LOGPATH/mcc_lcmmachine
echo "" >> $LOGPATH/mcc_lcmmachine
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC Mariadb details and logs..."
echo "################# [MCC MARIADB DETAILS] #################" > $LOGPATH/mcc_mariadb
echo "" >> $LOGPATH/mcc_mariadb
echo "## Configmap:" >> $LOGPATH/mcc_mariadb
printf '# ' >> $LOGPATH/mcc_mariadb; ls ./$MCCNAME/objects/namespaced/kaas/core/configmaps/iam-mariadb-state.yaml >> $LOGPATH/mcc_mariadb
sed -n '/  data:/,/    creationTimestamp:/p' ./$MCCNAME/objects/namespaced/kaas/core/configmaps/iam-mariadb-state.yaml >> $LOGPATH/mcc_mariadb
echo "" >> $LOGPATH/mcc_mariadb
echo "## Logs from controller pod (Errors/Warnings):" >> $LOGPATH/mcc_mariadb
printf '# ' >> $LOGPATH/mcc_mariadb; ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-controller-*/controller.log >> $LOGPATH/mcc_mariadb
grep -iE 'error|fail|warn' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-controller-*/controller.log |sed -r '/^\s*$/d' >> $LOGPATH/mcc_mariadb
echo "" >> $LOGPATH/mcc_mariadb
echo "## Logs from server-0 pods (Errors/Warnings):" >> $LOGPATH/mcc_mariadb
printf '# ' >> $LOGPATH/mcc_mariadb; ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log >> $LOGPATH/mcc_mariadb
grep -E 'ERR|WARN' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log |sed -r '/^\s*$/d'  >> $LOGPATH/mcc_mariadb
echo "" >> $LOGPATH/mcc_mariadb
echo "## Logs from server-1 pods (Errors/Warnings):" >> $LOGPATH/mcc_mariadb
printf '# ' >> $LOGPATH/mcc_mariadb; ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-1/mariadb.log >> $LOGPATH/mcc_mariadb
grep -E 'ERR|WARN' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-1/mariadb.log |sed -r '/^\s*$/d'  >> $LOGPATH/mcc_mariadb
echo "" >> $LOGPATH/mcc_mariadb
echo "## Logs from server-2 pods (Errors/Warnings):" >> $LOGPATH/mcc_mariadb
printf '# ' >> $LOGPATH/mcc_mariadb; ls ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-2/mariadb.log >> $LOGPATH/mcc_mariadb
grep -E 'ERR|WARN' ./$MCCNAME/objects/namespaced/kaas/core/pods/mariadb-server-2/mariadb.log |sed -r '/^\s*$/d'  >> $LOGPATH/mcc_mariadb
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC certificates..."
echo "################# [MCC CERTIFICATE DETAILS] #################" > $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## UI certificates:" >> $LOGPATH/mcc_certs
printf '# ' >> $LOGPATH/mcc_certs; ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/ui-tls-certs.yaml >> $LOGPATH/mcc_certs
echo "## tls.crt:" >> $LOGPATH/mcc_certs
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/ui-tls-certs.yaml |sed "s|    tls.crt: ||g" |base64 -d |sed -r '/^\s*$/d' > $LOGPATH/mcc-ui-crt
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/ui-tls-certs.yaml |sed "s|    tls.crt: ||g" |base64 -d |sed -r '/^\s*$/d' >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## tls.key:" >> $LOGPATH/mcc_certs
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/ui-tls-certs.yaml |sed "s|    tls.key: ||g" |base64 -d |sed -r '/^\s*$/d' > $LOGPATH/mcc-ui-key
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/ui-tls-certs.yaml |sed "s|    tls.key: ||g" |base64 -d |sed -r '/^\s*$/d' >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## UI Key and certificate verification match:" >> $LOGPATH/mcc_certs
echo "# openssl rsa -check -noout -in tls.key" >> $LOGPATH/mcc_certs
openssl rsa -check -noout -in $LOGPATH/mcc-ui-key >> $LOGPATH/mcc_certs
echo "# openssl rsa -modulus -noout -in tls.key |openssl md5" >> $LOGPATH/mcc_certs
openssl rsa -modulus -noout -in $LOGPATH/mcc-ui-key |openssl md5 >> $LOGPATH/mcc_certs
echo "# openssl x509 -modulus -noout -in tls.crt |openssl md5" >> $LOGPATH/mcc_certs
openssl x509 -modulus -noout -in $LOGPATH/mcc-ui-crt |openssl md5 >> $LOGPATH/mcc_certs
echo "## Is the UI certificate still valid?" >> $LOGPATH/mcc_certs
echo "# openssl x509 -enddate -noout -in tls.crt" >> $LOGPATH/mcc_certs
openssl x509 -enddate -noout -in $LOGPATH/mcc-ui-crt >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## MCC CA certificates:" >> $LOGPATH/mcc_certs
printf '# ' >> $LOGPATH/mcc_certs; ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/mcc-ca-cert.yaml >> $LOGPATH/mcc_certs
echo "## tls.crt:" >> $LOGPATH/mcc_certs
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/mcc-ca-cert.yaml |sed "s|    tls.crt: ||g" |base64 -d |sed -r '/^\s*$/d' > $LOGPATH/mcc-ca-crt
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/mcc-ca-cert.yaml |sed "s|    tls.crt: ||g" |base64 -d |sed -r '/^\s*$/d' >> $LOGPATH/mcc_certs
echo "## tls.key:" >> $LOGPATH/mcc_certs
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/mcc-ca-cert.yaml |sed "s|    tls.key: ||g" |base64 -d |sed -r '/^\s*$/d' > $LOGPATH/mcc-ca-key
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/mcc-ca-cert.yaml |sed "s|    tls.key: ||g" |base64 -d |sed -r '/^\s*$/d' >> $LOGPATH/mcc_certs
echo "## CA Key and certificate verification match:" >> $LOGPATH/mcc_certs
echo "# openssl rsa -check -noout -in tls.key" >> $LOGPATH/mcc_certs
openssl rsa -check -noout -in $LOGPATH/mcc-ca-key >> $LOGPATH/mcc_certs
echo "# openssl rsa -modulus -noout -in tls.key |openssl md5" >> $LOGPATH/mcc_certs
openssl rsa -modulus -noout -in $LOGPATH/mcc-ca-key |openssl md5 >> $LOGPATH/mcc_certs
echo "# openssl x509 -modulus -noout -in tls.crt |openssl md5" >> $LOGPATH/mcc_certs
openssl x509 -modulus -noout -in $LOGPATH/mcc-ca-crt |openssl md5 >> $LOGPATH/mcc_certs
echo "## Is the MCC CA certificate still valid?" >> $LOGPATH/mcc_certs
echo "# openssl x509 -enddate -noout -in tls.crt" >> $LOGPATH/mcc_certs
openssl x509 -enddate -noout -in $LOGPATH/mcc-ca-crt >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## Keycloak certificates:" >> $LOGPATH/mcc_certs
printf '# ' >> $LOGPATH/mcc_certs; ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/keycloak-tls-certs.yaml >> $LOGPATH/mcc_certs
echo "## tls.crt:" >> $LOGPATH/mcc_certs
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/keycloak-tls-certs.yaml |sed "s|    tls.crt: ||g" |base64 -d |sed -r '/^\s*$/d' > $LOGPATH/mcc-keycloak-crt
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/keycloak-tls-certs.yaml |sed "s|    tls.crt: ||g" |base64 -d |sed -r '/^\s*$/d' >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## tls.key:" >> $LOGPATH/mcc_certs
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/keycloak-tls-certs.yaml |sed "s|    tls.key: ||g" |base64 -d |sed -r '/^\s*$/d' > $LOGPATH/mcc-keycloak-key
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/keycloak-tls-certs.yaml |sed "s|    tls.key: ||g" |base64 -d |sed -r '/^\s*$/d' >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## Keycloak Key and certificate verification match:" >> $LOGPATH/mcc_certs
echo "# openssl rsa -check -noout -in tls.key" >> $LOGPATH/mcc_certs
openssl rsa -check -noout -in $LOGPATH/mcc-keycloak-key >> $LOGPATH/mcc_certs
echo "# openssl rsa -modulus -noout -in tls.key |openssl md5" >> $LOGPATH/mcc_certs
openssl rsa -modulus -noout -in $LOGPATH/mcc-keycloak-key |openssl md5 >> $LOGPATH/mcc_certs
echo "# openssl x509 -modulus -noout -in tls.crt |openssl md5" >> $LOGPATH/mcc_certs
openssl x509 -modulus -noout -in $LOGPATH/mcc-keycloak-crt |openssl md5 >> $LOGPATH/mcc_certs
echo "## Is the Keycloak certificate still valid?" >> $LOGPATH/mcc_certs
echo "# openssl x509 -enddate -noout -in tls.crt" >> $LOGPATH/mcc_certs
openssl x509 -enddate -noout -in $LOGPATH/mcc-keycloak-crt >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## OIDC certificates:" >> $LOGPATH/mcc_certs
printf '# ' >> $LOGPATH/mcc_certs; ls ./$MCCNAME/objects/namespaced/kaas/core/secrets/oidc-ca-cert.yaml >> $LOGPATH/mcc_certs
echo "## tls.crt:" >> $LOGPATH/mcc_certs
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/oidc-ca-cert.yaml |sed "s|    tls.crt: ||g" |base64 -d > $LOGPATH/mcc-oidc-crt
grep "    tls.crt: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/oidc-ca-cert.yaml |sed "s|    tls.crt: ||g" |base64 -d >> $LOGPATH/mcc_certs
echo "" >> $LOGPATH/mcc_certs
echo "## tls.key:" >> $LOGPATH/mcc_certs
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/oidc-ca-cert.yaml |sed "s|    tls.key: ||g" |base64 -d > $LOGPATH/mcc-oidc-key
grep "    tls.key: " ./$MCCNAME/objects/namespaced/kaas/core/secrets/oidc-ca-cert.yaml |sed "s|    tls.key: ||g" |base64 -d >> $LOGPATH/mcc_certs
echo "## OIDC Key and certificate verification match:" >> $LOGPATH/mcc_certs
echo "# openssl rsa -check -noout -in tls.key" >> $LOGPATH/mcc_certs
openssl rsa -check -noout -in $LOGPATH/mcc-oidc-key >> $LOGPATH/mcc_certs
echo "# openssl rsa -modulus -noout -in tls.key |openssl md5" >> $LOGPATH/mcc_certs
openssl rsa -modulus -noout -in $LOGPATH/mcc-oidc-key |openssl md5 >> $LOGPATH/mcc_certs
echo "# openssl x509 -modulus -noout -in tls.crt |openssl md5" >> $LOGPATH/mcc_certs
openssl x509 -modulus -noout -in $LOGPATH/mcc-oidc-crt |openssl md5 >> $LOGPATH/mcc_certs
echo "## Is the OIDC certificate still valid?" >> $LOGPATH/mcc_certs
echo "# openssl x509 -enddate -noout -in tls.crt" >> $LOGPATH/mcc_certs
openssl x509 -enddate -noout -in $LOGPATH/mcc-oidc-crt >> $LOGPATH/mcc_certs
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC Ipamhost details..."
echo "################# [MCC IPAMHOST DETAILS] #################" > $LOGPATH/mcc_ipamhost
echo "" >> $LOGPATH/mcc_ipamhost
grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/ipamhosts/ $LOGPATH/files > $LOGPATH/mcc-ipamhost
printf '## Ipamhosts' >> $LOGPATH/mcc_ipamhost ; printf " (Total: `wc -l < $LOGPATH/mcc-ipamhost`)" >> $LOGPATH/mcc_ipamhost
echo "" >> $LOGPATH/mcc_ipamhost
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mcc-ipamhost >> $LOGPATH/mcc_ipamhost
echo "" >> $LOGPATH/mcc_ipamhost
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mcc-ipamhost >> $LOGPATH/mcc_ipamhost
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC L2template details..."
echo "################# [MCC L2TEMPLATE DETAILS] #################" > $LOGPATH/mcc_l2template
echo "" >> $LOGPATH/mcc_l2template
grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/l2templates/ $LOGPATH/files > $LOGPATH/mcc-l2template
printf '## L2 templates' >> $LOGPATH/mcc_l2template ; printf " (Total: `wc -l < $LOGPATH/mcc-l2template`)" >> $LOGPATH/mcc_l2template
echo "" >> $LOGPATH/mcc_l2template
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mcc-l2template >> $LOGPATH/mcc_l2template
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC subnet details..."
echo "################# [MCC SUBNET DETAILS] #################" > $LOGPATH/mcc_subnet
grep ./$MCCNAME/objects/namespaced/$MCCNAMESPACE/ipam.mirantis.com/subnets/ $LOGPATH/files > $LOGPATH/mcc-subnet
echo "" >> $LOGPATH/mcc_subnet
printf '## Subnets' >> $LOGPATH/mcc_subnet ; printf " (Total: `wc -l < $LOGPATH/mcc-subnet`)" >> $LOGPATH/mcc_subnet
echo "" >> $LOGPATH/mcc_subnet
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mcc-subnet >> $LOGPATH/mcc_subnet
echo "" >> $LOGPATH/mcc_subnet
while read -r line; do printf "# $line:"; echo ""; sed -n '/  status:/,/    tokenSecret:/p' $line; echo ""; done < $LOGPATH/mcc-subnet >> $LOGPATH/mcc_subnet
echo "" >> $LOGPATH/mcc_subnet
fi

if [[ -n "$MCCNAME" ]] ; then
echo "Gathering MCC PV and PVC details..."
echo "################# [MCC PV AND PVC DETAILS] #################" > $LOGPATH/mcc_pv_pvc
grep ./$MCCNAME/objects/cluster/core/persistentvolumes/ $LOGPATH/files > $LOGPATH/mcc-pv
echo "" >> $LOGPATH/mcc_pv_pvc
printf '## Persistent Volumes' >> $LOGPATH/mcc_pv_pvc ; printf " (Total: `wc -l < $LOGPATH/mcc-pv`)" >> $LOGPATH/mcc_pv_pvc
echo "" >> $LOGPATH/mcc_pv_pvc
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $7}' |sed 's|\.yaml||g'; done < $LOGPATH/mcc-pv >> $LOGPATH/mcc_pv_pvc
echo "" >> $LOGPATH/mcc_pv_pvc
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mcc-pv >> $LOGPATH/mcc_pv_pvc
echo "" >> $LOGPATH/mcc_pv_pvc
grep persistentvolumeclaims $LOGPATH/files |grep $MCCNAME > $LOGPATH/mcc-pvc
printf '## Persistent Volume Claims' >> $LOGPATH/mcc_pv_pvc ; printf " (Total: `wc -l < $LOGPATH/mcc-pvc`)" >> $LOGPATH/mcc_pv_pvc   
echo "" >> $LOGPATH/mcc_pv_pvc
while read -r line; do printf "# "; printf "$line" |awk -F "/" -v 'OFS=/' '{print $8}' |sed 's|\.yaml||g'; done < $LOGPATH/mcc-pvc >> $LOGPATH/mcc_pv_pvc
echo "" >> $LOGPATH/mcc_pv_pvc
while read -r line; do printf "# $line:"; echo ""; sed -n '/  spec:/,/    state:/p' $line; echo ""; done < $LOGPATH/mcc-pvc >> $LOGPATH/mcc_pv_pvc
fi

if [[ -n "$MCCNAME" ]] || [[ -n "$MOSNAME" ]] ; then
# Delete temporary files generated:
echo "Removing temp files..."
rm $LOGPATH/*-* 2> /dev/null

# Rename report files to .yaml so text editors can recognise the syntax
echo "Converting report files to yaml..."
for file in $LOGPATH/*_*; do mv $file $file.yaml; done

echo "Report Complete. Opening files..."
# Run nvim to load all files:
#nvim -R -c 'silent argdo set syntax=yaml' -p $LOGPATH/*_*
#nvim -R -p $LOGPATH/*.yaml

# Run sublime text to load all files:
/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl --new-window --command $LOGPATH/*.yaml 2> /dev/null
fi

if [[ -z "$MCCNAME" ]] && [[ -z "$MOSNAME" ]] ; then
# Delete myrha folder as neither MCC and MOS clusters were found:
rm -rf $LOGPATH 2> /dev/null
fi
