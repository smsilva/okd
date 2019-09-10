openstack_public_network_id=$(openstack network show public_network -c id -f value)

openstack_internal_network_id=$(openstack network show ${openstack_internal_network} -c id -f value)

openstack_internal_subnet_id=$(openstack subnet show ${openstack_internal_subnet} -c id -f value)

openstack port create \
--disable-port-security \
--no-security-group \
--fixed-ip subnet=${openstack_internal_subnet_id},ip-address=10.0.0.4 \
--network ${openstack_internal_network_id} \
port-dns

export port_dns_id=$(openstack port list --project ${openstack_project} -c ID -c Name | grep port-dns | awk '{print $2}')

dns_floating_ip=192.168.1.84

openstack floating ip create \
--project ${openstack_project} \
--port ${port_dns_id} \
--floating-ip-address ${dns_floating_ip} \
${openstack_public_network_id}

openstack subnet set \
--no-dns-nameservers \
--dns-nameserver 192.168.1.1 \
${openstack_internal_subnet_id}

cat <<EOF > /osp/cloud-init/dns.example.com.yml
#cloud-config
hostname: dns
fqdn: dns.example.com
EOF

openstack server create \
--image centos7 \
--flavor m1.small \
--key-name ${openstack_user_admin} \
--port ${port_dns_id} \
--user-data /osp/cloud-init/dns.example.com.yml \
dns.example.com

ssh -i .ssh/id_rsa_${openstack_user_admin} centos@${dns_floating_ip}

sudo su -

yum update -y && \
yum install -y dnsmasq

cat <<EOF > /etc/dnsmasq.d/example.com
address=/dns.example.com/10.0.0.4
address=/master.example.com/10.0.0.71
address=/console.example.com/10.0.0.71
address=/.apps.example.com/10.0.0.72
address=/infra.example.com/10.0.0.72
address=/node1.example.com/10.0.0.73
address=/node2.example.com/10.0.0.74
address=/bastion.example.com/10.0.0.75

no-dhcp-interface=eth0
bogus-priv
domain=example.com
expand-hosts
local=/example.com/
domain-needed
no-resolv
no-poll
server=192.168.1.1
EOF

systemctl enable dnsmasq && \
systemctl restart dnsmasq && \
systemctl status dnsmasq

cat /etc/resolv.conf
# Generated by NetworkManager
search openstacklocal example.com
nameserver 10.0.0.4

exit

exit

openstack subnet set \
--no-dns-nameservers \
--dns-nameserver 10.0.0.4 \
${openstack_internal_subnet_id}

openstack server reboot dns.example.com
