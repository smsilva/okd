for server in master infra node{1..1}; do
  openstack server delete ${server}.example.com;
done

watch -n 5 openstack server list --sort-column Name

for vol_id in $(openstack volume list -c ID -f value); do
  openstack volume delete ${vol_id};
done

watch -n 5 openstack volume list
