![alt text](https://upload.wikimedia.org/wikipedia/commons/thumb/8/86/Commiphora_myrrha_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-019.jpg/250px-Commiphora_myrrha_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-019.jpg) 

# myrha
Summarize supportdump files from Mirantis MCC/MOS clusters<br>

# Features
- ***Graphical dashboard for easy analyzis:***
<img width="1798" height="909" alt="Screenshot From 2026-03-09 16-01-14" src="https://github.com/user-attachments/assets/a9f80518-2139-4871-b38f-06fd4aee1b20" />

- ***MKE, MOS and MCC cluster summary with a directly link to release notes and Jira tickets. Example:***
```
################# [MCC CLUSTER DETAILS] #################

## MCC Version release details: 2.30.5
https://docs.mirantis.com/container-cloud/latest/release-notes/releases/2-30-5.html
https://docs.mirantis.com/container-cloud/latest/release-notes/releases/2-30-5/known-2-30-5.html

## MCC Bugs - 2.30.5:
https://mirantis.jira.com/issues?jql=affectedversion%20%3D%20%22KaaS%202.30.5%20%2F%20MOSK%2025.2.5%20(Patch%20release5)%22

## MKE Version release details: 3.7.28
https://docs.mirantis.com/mke/3.7/release-notes/3-7-28.html
https://docs.mirantis.com/mke/3.7/release-notes/3-7-28/known-issues.html
```
- ***Cluster WARNING and ERROR event messages ordered by time and date. Example:***
```
################# [MCC EVENTS (WARNING+ERRORS)] #################

## Analyzed files:
# ./kaas-mgmt/objects/events.log
2026-02-11T05:44:17+01:00	Warning	mos	Cluster	mos	ClusterStackLightNotReady	not ready: statefulSets: stacklight/opensearch-master got 2/3 replicas, stacklight/patroni-13 got 2/3 replicas, stacklight/prometheus-server got 1/2 replicas
2026-02-11T05:48:42+01:00	Warning	mos	Machine	mos-ctl-03	MachineLCMAgentNotReady	LCM agent has not reported its state since 2026-02-11 04:43:26.829955 +0000 UTC
2026-02-14T05:09:00+01:00	Warning	mos	Machine	mos-ceph-01	FailedUpdatingMachineStatus	Failed to update Machine status. Error: failed to update status for the machine mos-ceph-01/mos: Operation cannot be fulfilled on machines.cluster.k8s.io "mos-ceph-01": the object has been modified; please apply your changes to the latest version and try again
2026-02-14T17:44:56+01:00	Warning	default	Cluster	kaas-mgmt	ClusterKubernetesNotReady	not ready: deployments: kaas/host-os-modules-controller got 2/3 replicas
2026-02-17T07:48:33+01:00	Warning	mos	Machine	mos-ctl-03	MachineSwarmNotReady	Swarm state of the machine is down
2026-02-17T07:49:10+01:00	Warning	mos	Cluster	mos	ClusterKubernetesNotReady	not ready: deployments: stacklight/stacklight-helm-controller got 2/3 replicas; statefulSets: stacklight/opensearch-master got 2/3 replicas, stacklight/patroni-13 got 
```

***- Mariadb logs sorted and filtered only with error messages and configmap in the same file for quick overview. Example:***
```
################# [MCC MARIADB DETAILS] #################

## Configmap:
# ./kaas-mgmt/objects/namespaced/kaas/core/configmaps/iam-mariadb-state.yaml
  data:
    initial-bootstrap-completed.cluster: COMPLETED
    safe_to_bootstrap.mariadb-server-0: "0"
    safe_to_bootstrap.mariadb-server-1: "0"
    safe_to_bootstrap.mariadb-server-2: "0"
    sample_time.mariadb-server-0: "2026-02-24T15:40:44.292641Z"
    sample_time.mariadb-server-1: "2026-02-24T15:40:39.821140Z"
    sample_time.mariadb-server-2: "2026-02-24T15:40:40.709131Z"
    seqno.mariadb-server-0: "-1"
    seqno.mariadb-server-1: "-1"
    seqno.mariadb-server-2: "-1"
    uuid.mariadb-server-0: afe5dc36-cee6-11ed-97a9-cb1e45ace00a
    uuid.mariadb-server-1: afe5dc36-cee6-11ed-97a9-cb1e45ace00a
    uuid.mariadb-server-2: afe5dc36-cee6-11ed-97a9-cb1e45ace00a
    version.mariadb-server-0: "2.1"
    version.mariadb-server-1: "2.1"
    version.mariadb-server-2: "2.1"
  kind: ConfigMap
  metadata:
    annotations:
      openstackhelm.openstack.org/cluster.state: live
      openstackhelm.openstack.org/leader.expiry: "2026-02-24T15:42:27.404224Z"
      openstackhelm.openstack.org/leader.node: mariadb-server-2
      openstackhelm.openstack.org/reboot.node: mariadb-server-2
    creationTimestamp: "2023-03-30T10:36:09Z"

## Logs from controller pod (Errors/Warnings):
# ./kaas-mgmt/objects/namespaced/kaas/core/pods/mariadb-controller-7fd59f4ff6-4gxxt/controller.log
./kaas-mgmt/objects/namespaced/kaas/core/pods/mariadb-controller-7fd59f4ff6-s8djj/controller.log

## Logs from server-0 pods (Errors/Warnings):
# ./kaas-mgmt/objects/namespaced/kaas/core/pods/mariadb-server-0/mariadb.log
2026-02-23 05:18:02,171 - OpenStack-Helm Mariadb - WARNING - Collision writing configmap: (409)
2026-02-23 12:10:51,696 - OpenStack-Helm Mariadb - WARNING - Collision writing configmap: (409)
2026-02-23 15:04:11,802 - OpenStack-Helm Mariadb - WARNING - Collision writing configmap: (409)
2026-02-23 15:44:17,515 - OpenStack-Helm Mariadb - WARNING - Collision writing configmap: (409)
2026-02-23 15:47:18,951 - OpenStack-Helm Mariadb - WARNING - Collision writing configmap: (409)
```

- ***Certificate analysis with MD5 checks between certs and keys. Myrha will also validate the cert against the CA. Example:***
```
################# [MOS CERTIFICATE DETAILS] #################

## TF certificates:
# ./mos/objects/namespaced/tf/core/secrets/tungstenfabric-operator-webhook-server-cert.yaml
====================================================
🔍 AUDIT REPORT: tungstenfabric-operator-webhook-server-cert.yaml
====================================================
--- Field: [ca.cert] ---
-----BEGIN CERTIFICATE-----
(...)
-----END CERTIFICATE-----

----------------------------------------------------
📋 CN:      tungstenfabric-(...).svc
🌐 SAN:     None
📅 Expires: Oct 22 11:14:30 2035 GMT
🔢 Cert Modulus MD5: d6eb7572a73026063556228d83949983
🏢 Role:    CA/Root Certificate
```

- And many more. We are always open for improvements. Please reach me if you have any suggestions

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
Once the script is complete, a new folder called "myrha" will be created, where yaml files will be created, containing the summary of different cluster aspects (MCC and/or MOS). The generated folder content should look like this:

```
$ ~/Downloads/test/kaas-bootstrap/logs/ ls myrha 
files             mos_nodes.yaml       mos_openstack.yaml  mos_l2template.yaml  mcc_cluster.yaml  mcc_lcmmachine.yaml  mcc_ipamhost.yaml    mcc_pv_pvc.yaml
mos_cluster.yaml  mos_lcmmachine.yaml  mos_mariadb.yaml    mos_subnet.yaml      mcc_events.yaml   mcc_mariadb.yaml     mcc_l2template.yaml  
mos_events.yaml   mos_ceph.yaml        mos_ipamhost.yaml   mos_pv_pvc.yaml      mcc_nodes.yaml    mcc_certs.yaml       mcc_subnet.yaml      
```

By default, the script is set to automatically open the default browser with all files generated. You can also open them up on sublime text or vim by commenting the following lines:<br>

```
xdg-open "$HTML_REPORT" 2>/dev/null || open "$HTML_REPORT" 2>/dev/null
```

and uncommenting the following one for sublime text:<br>

```
#/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl --new-window --command $LOGPATH/*.yaml 2> /dev/null
```

or these ones for vim:<br>
```
#nvim -R -c 'silent argdo set syntax=yaml' -p $LOGPATH/*_*
#nvim -R -p $LOGPATH/*.yaml
```
