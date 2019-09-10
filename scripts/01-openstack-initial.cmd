openstack_project=okd
openstack_internal_network=okd_net
openstack_internal_subnet=okd_subnet
openstack_user_admin=okd

. keystonerc_admin

openstack image create \
--public \
--disk-format qcow2 \
--min-disk 15 \
--min-ram 512 \
--file "/osp/images/centos7.qcow2" \
centos7

openstack network create \
--share \
--external \
--provider-network-type flat \
--provider-physical-network physnet1 \
public_network

openstack subnet create \
--dhcp \
--subnet-range 192.168.1.0/24 \
--allocation-pool start=192.168.1.20,end=192.168.1.90 \
--dns-nameserver 192.168.1.1 \
--network public_network \
public_subnet
		  
openstack project create ${openstack_project}

openstack quota set \
--volumes 100 \
${openstack_project}

openstack user create \
--project ${openstack_project} \
--password openstack \
${openstack_user_admin}

openstack role add \
--project ${openstack_project} \
--user ${openstack_user_admin} \
admin

openstack role add \
--project ${openstack_project} \
--user ${openstack_user_admin} \
heat_stack_owner

openstack role assignment list \
--project ${openstack_project} \
--names

cat <<EOF > keystonerc_${openstack_user_admin}
unset OS_SERVICE_TOKEN
export OS_USERNAME=${openstack_user_admin}
export OS_PASSWORD='openstack'
export OS_AUTH_URL=http://192.168.1.101:5000/v3
export OS_PROJECT_NAME=${openstack_project}
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_IDENTITY_API_VERSION=3
export PS1='[\u@\h (${openstack_user_admin}) \W]\$ '
export openstack_project=${openstack_project}	
export openstack_internal_network=${openstack_internal_network}
export openstack_internal_subnet=${openstack_internal_subnet}
export openstack_user_admin=${openstack_user_admin}
EOF

. keystonerc_${openstack_user_admin}

openstack network create \
--internal \
--provider-network-type vxlan \
${openstack_internal_network}

openstack subnet create \
--subnet-range 10.0.0.0/24 \
--allocation-pool start=10.0.0.10,end=10.0.0.200 \
--gateway 10.0.0.1 \
--dns-nameserver 192.168.1.1 \
--network ${openstack_internal_network} \
${openstack_internal_subnet}

openstack router create \
--project ${openstack_project} \
${openstack_project}_router1

openstack router add subnet \
${openstack_project}_router1 \
${openstack_internal_subnet}

openstack keypair create \
--private-key .ssh/id_rsa_${openstack_user_admin} \
${openstack_user_admin}

openstack keypair show ${openstack_user_admin} \
--public-key > .ssh/id_rsa_${openstack_user_admin}.pub

chmod 600 .ssh/id_rsa_${openstack_user_admin}

neutron router-gateway-set ${openstack_project}_router1 public_network

openstack_public_network_id=$(openstack network show public_network -c id -f value)

openstack_internal_network_id=$(openstack network show ${openstack_internal_network} -c id -f value)

openstack_internal_subnet_id=$(openstack subnet show ${openstack_internal_subnet} -c id -f value)

for port in 71 72 73 74 75; do
  openstack port create \
  --disable-port-security \
  --no-security-group \
  --fixed-ip subnet=${openstack_internal_subnet_id},ip-address=10.0.0.${port} \
  --network ${openstack_internal_network_id} \
  port-${port};
done

for port in 71 72 73 74 75; do
  openstack floating ip create \
  --project ${openstack_project} \
  --port port-${port} \
  --floating-ip-address 192.168.1.${port} \
  ${openstack_public_network_id};
done
