openstack_public_network_id=$(openstack network show public_network -c id -f value)

openstack_internal_network_id=$(openstack network show ${openstack_internal_network} -c id -f value)

openstack_internal_subnet_id=$(openstack subnet show ${openstack_internal_subnet} -c id -f value)

openstack flavor create \
--disk 100 \
--vcpus 4 \
--ram 12288 \
ocp.compute

openstack volume create \
--size 30 \
openshift-registry

openstack volume create \
--size 25 \
master-etcd

master_volume_vdd_etcd_id=$(openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep master-etcd | awk '{ print $1}')

for name in master infra node1; do
  openstack volume create \
  --size 15 \
  ${name}-docker;
done

export master_volume_vdb_docker_id=$(openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep master-docker | awk '{ print $1}')

for name in master infra node1; do
  openstack volume create \
  --size 30 \
  ${name}-openshift-local;
done

export master_volume_vdc_openshift_id=$(openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep master-openshift-local | awk '{ print $1}')

openstack server create \
--image centos7 \
--flavor m1.large \
--key-name ${openstack_user_admin} \
--port port-71 \
--user-data /osp/cloud-init/master.example.com.yml \
--block-device-mapping vdb=${master_volume_vdb_docker_id}:volume:15:false \
--block-device-mapping vdc=${master_volume_vdc_openshift_id}:volume:30:false \
--block-device-mapping vdd=${master_volume_vdd_etcd_id}:volume:25:false \
master.example.com

export volume_vdb_docker_id=$(openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep infra-docker | awk '{ print $1}') && \
export volume_vdc_openshift_id=$(openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep infra-openshift-local | awk '{ print $1}')

openstack server create \
--image centos7 \
--flavor m1.large \
--key-name ${openstack_user_admin} \
--port port-72 \
--user-data /osp/cloud-init/infra.example.com.yml \
--block-device-mapping vdb=${volume_vdb_docker_id}:volume:15:false \
--block-device-mapping vdc=${volume_vdc_openshift_id}:volume:30:false \
infra.example.com

export port_node_1=port-73
export port_node_2=port-74

for node in {1..1}; do
  export port_node=port_node_${node} && \
  export port_name=$(eval "echo $"{"${port_node}"}) && \
  export port_id=$(openstack port list --project ${openstack_project} -c ID -c Name -f value | grep ${port_name} | awk '{ print $1 }') && \
  export volume_vdb_docker_id=$(openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep node${node}-docker | awk '{ print $1}') && \
  export volume_vdc_openshift_id=$(openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep node${node}-openshift-local | awk '{ print $1}') && \
  openstack server create \
    --image centos7 \
    --flavor ocp.compute \
    --key-name ${openstack_user_admin} \
    --port ${port_id} \
    --user-data /osp/cloud-init/node${node}.example.com.yml \
    --block-device-mapping vdb=${volume_vdb_docker_id}:volume:15:false \
    --block-device-mapping vdc=${volume_vdc_openshift_id}:volume:30:false \
  node${node}.example.com;
done

openstack volume list --project ${openstack_project} -c ID -c Name -f value | grep openshift-registry | awk '{ print $1}'

ssh -i .ssh/id_rsa_${openstack_user_admin} centos@192.168.1.84

sudo su -

cat <<EOF > inventory.ini
[OSEv3:children]
masters
nodes
etcd

[masters]
master.example.com

[etcd]
master.example.com

[nodes]
master.example.com openshift_node_group_name="node-config-master"
infra.example.com openshift_node_group_name="node-config-infra"
node1.example.com openshift_node_group_name="node-config-compute"

[OSEv3:vars]
ansible_user=centos
ansible_become=yes

debug_level=4

os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'

openshift_deployment_type=origin
openshift_release="3.11"

openshift_additional_repos=[{'id': 'centos-okd-ci', 'name': 'centos-okd-ci', 'baseurl' :'https://cbs.centos.org/repos/paas7-openshift-origin311-testing/x86_64/os/', 'gpgcheck' :'0', 'enabled' :'1'}]

containerized=True

osm_use_cockpit=True

openshift_docker_options="--selinux-enabled --insecure-registry=172.30.0.0/16 --log-opt max-size=1M --log-opt max-file=3"

openshift_router_selector='node-role.kubernetes.io/infra=true'
openshift_registry_selector='node-role.kubernetes.io/infra=true'

openshift_metrics_install_metrics=False
openshift_logging_install_logging=False

openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
openshift_master_cluster_hostname=master.example.com
openshift_master_default_subdomain=apps.example.com
openshift_master_api_port=8443
openshift_master_console_port=8443

openshift_disable_check=disk_availability,docker_storage,memory_availability,docker_image_availability

openshift_cloudprovider_kind=openstack
openshift_cloudprovider_openstack_auth_url=http://192.168.1.101:5000/v3
openshift_cloudprovider_openstack_username=okd
openshift_cloudprovider_openstack_password=openstack
openshift_cloudprovider_openstack_tenant_name=okd
openshift_cloudprovider_openstack_domain_name=Default
openshift_cloudprovider_openstack_region=RegionOne

openshift_hosted_registry_storage_kind=openstack
openshift_hosted_registry_storage_access_modes=['ReadWriteOnce']
openshift_hosted_registry_storage_openstack_filesystem=ext4
openshift_hosted_registry_storage_volume_size=30Gi
openshift_hosted_registry_storage_openstack_volumeID=8f051378-f92a-4a41-b40d-50d499d6b8ea
EOF

rm -rf /var/log/ansible.log

ansible -i inventory.ini all -m ping

ansible -i inventory.ini all -m command -a "lsblk -f"

ansible -i inventory.ini all -m command -a "cat /etc/resolv.conf"

ansible -i inventory.ini all -m command -a "cat /etc/dnsmasq.d/origin-dns.conf"

ansible -i inventory.ini all -m command -a "cat /etc/dnsmasq.d/origin-upstream-dns.conf"

ansible -i inventory.ini all -m command -a "ping master -c 2"

rm -rf /var/log/ansible.log

git clone https://github.com/openshift/openshift-ansible.git

cd openshift-ansible && git fetch && git checkout release-3.11 && cd ..

ansible-playbook -i inventory.ini openshift-ansible/playbooks/prerequisites.yml && \
ansible-playbook -i inventory.ini openshift-ansible/playbooks/deploy_cluster.yml -vvv

ssh -i .ssh/id_rsa_ocp centos@master

cat /etc/sysconfig/docker

###[Master]##################################################

oc login -u system:admin

oadm policy add-role-to-user \
  cluster-admin admin \
  --config=/etc/origin/master/admin.kubeconfig

oc delete all -l docker-registry=default

oc adm registry \
  --config=/etc/origin/master/admin.kubeconfig \
  --service-account=registry

oc set volume dc/docker-registry \
  --add \
  --overwrite -t persistentVolumeClaim \
  --claim-name=registry-claim \
  --name=registry-volume

htpasswd /etc/origin/master/htpasswd silvio

oc login -u system:admin

oc policy add-role-to-user registry-viewer silvio

oc policy add-role-to-user registry-editor silvio

oc login -u silvio

docker login -u openshift -p $(oc whoami -t) docker-registry.default.svc:5000

docker pull jboss/wildfly:14.0.1.Final

docker tag jboss/wildfly:14.0.1.Final docker-registry.default.svc:5000/pindaiba/wildfly:14.0.1

docker push docker-registry.default.svc:5000/pindaiba/wildfly:14.0.1

############################################################################################

cat <<EOF > cinder-pv-registry-volume.yml
apiVersion: "v1"
kind: "PersistentVolume"
metadata:
  name: "registry-volume" 
spec:
  capacity:
    storage: "30Gi" 
  accessModes:
    - "ReadWriteOnce"
  storageClassName: standard
  cinder: 
    fsType: "ext4" 
    volumeID: "a31ba1e8-61c5-44b9-8cb7-8b9ae35f836d"
EOF

cat <<EOF > registry-claim.yml
apiVersion: "v1"
kind: "PersistentVolumeClaim"
metadata:
  name: "registry-claim"
spec:
  accessModes:
    - "ReadWriteOnce"
  resources:
    requests:
      storage: "30Gi"
  storageClassName: standard
  volumeName: "registry-volume"
EOF

oc delete pvc registry-claim

oc delete pv registry-volume

oc create -f cinder-pv-registry-volume.yml

[root@master storage]# oc get pv
NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
registry-volume   30Gi       RWO            Retain           Available             standard                 10s

oc create -f registry-claim.yml

[root@master storage]# oc get pv
NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                    STORAGECLASS   REASON    AGE
registry-volume   30Gi       RWO            Retain           Bound     default/registry-claim   standard                 49s

[root@master storage]# oc get pvc
NAME             STATUS    VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS   AGE
registry-claim   Bound     registry-volume   30Gi       RWO            standard       22s

oc rollout latest docker-registry

###############################################

[root@openstack (okd) ~]$ openstack volume create --size 50 openshift-volume-01

cat <<EOF > cinder-pv-openshift-volume-01.yml
apiVersion: "v1"
kind: "PersistentVolume"
metadata:
  name: "openshift-volume-01" 
spec:
  capacity:
    storage: "50Gi" 
  accessModes:
    - "ReadWriteOnce"
  storageClassName: standard
  cinder: 
    fsType: "ext4" 
    volumeID: "67595950-79d4-4220-aec2-dcd80842909d"
EOF

cat <<EOF > mariadb-lb.yaml
apiVersion: v1
kind: Service
metadata:
  name: egress-mariadb
spec:
  ports:
  - name: db
    port: 3306 
  loadBalancerIP:
  type: LoadBalancer 
  selector:
    name: mariadb
EOF

##############################################

Expose

mysql -h 10.131.0.7 -P 3306 -u mydb -pmyuser mydb

mysql -h mariadb-pindaiba.apps.example.com -P 30821 -u mydb -pmyuser mydb

mysql -h mariadb-pindaiba.apps.example.com -P 3306 -u mydb -pmyuser mydb

cat <<EOF > mariadb-load-balancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: egress-mariadb
spec:
  ports:
  - name: db
    port: 3306 
  loadBalancerIP:
  type: LoadBalancer 
  selector:
    name: mariadb 
EOF

oc get -o template pod redis-pod --template={{.currentState.status}}

oc get svc egress-mariadb -o template --template={{.spec.ports}}

oc get svc egress-mariadb -o=jsonpath='{.spec.ports[0].nodePort}'

oc get svc -o=custom-columns="Type:.spec.type"

oc get svc -o=custom-columns="Name:.metadata.name,Type:.spec.type,Cluster IP:.spec.clusterIP"

oc get svc -o=custom-columns="Cluster IP:.spec.clusterIP" | awk 'NR > 1 {print $1}'
