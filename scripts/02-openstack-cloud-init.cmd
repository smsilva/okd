cat <<EOF > /osp/cloud-init/bastion.example.com.yml
#cloud-config
hostname: bastion
fqdn: bastion.example.com
EOF

cat <<EOF > /osp/cloud-init/master.example.com.yml
#cloud-config
cloud_config_modules:
- disk_setup
- mounts

hostname: master
fqdn: master.example.com

write_files:
- path: "/etc/sysconfig/docker-storage-setup"
  permissions: "0644"
  owner: "root"
  content: |
    DEVS='/dev/vdb'
    VG=docker_vol
    DATA_SIZE=95%VG
    STORAGE_DRIVER=overlay2
    CONTAINER_ROOT_LV_NAME=dockerlv
    CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
    CONTAINER_ROOT_LV_SIZE=100%FREE

fs_setup:
- label: emptydir
  filesystem: xfs
  device: /dev/vdc
  partition: auto
- label: etcd_storage
  filesystem: xfs
  device: /dev/vdd
  partition: auto

runcmd:
- mkdir -p /var/lib/origin/openshift.local.volumes
- mkdir -p /var/lib/etcd

mounts:
- [ /dev/vdc, /var/lib/origin/openshift.local.volumes, xfs, "defaults,gquota" ]
- [ /dev/vdd, /var/lib/etcd, xfs, "defaults" ]
EOF

cat <<EOF > /osp/cloud-init/infra.example.com.yml
#cloud-config
cloud_config_modules:
- disk_setup
- mounts

hostname: infra
fqdn: infra.example.com

write_files:
- path: "/etc/sysconfig/docker-storage-setup"
  permissions: "0644"
  owner: "root"
  content: |
    DEVS='/dev/vdb'
    VG=docker_vol
    DATA_SIZE=95%VG
    STORAGE_DRIVER=overlay2
    CONTAINER_ROOT_LV_NAME=dockerlv
    CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
    CONTAINER_ROOT_LV_SIZE=100%FREE

fs_setup:
- label: emptydir
  filesystem: xfs
  device: /dev/vdc
  partition: auto

runcmd:
- mkdir -p /var/lib/origin/openshift.local.volumes

mounts:
- [ /dev/vdc, /var/lib/origin/openshift.local.volumes, xfs, "defaults,gquota" ]
EOF

for node in {1..2}; do
cat <<EOF > /osp/cloud-init/node${node}.example.com.yml
#cloud-config
cloud_config_modules:
- disk_setup
- mounts

hostname: node${node}
fqdn: node${node}.example.com

write_files:
- path: "/etc/sysconfig/docker-storage-setup"
  permissions: "0644"
  owner: "root"
  content: |
    DEVS='/dev/vdb'
    VG=docker_vol
    DATA_SIZE=95%VG
    STORAGE_DRIVER=overlay2
    CONTAINER_ROOT_LV_NAME=dockerlv
    CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
    CONTAINER_ROOT_LV_SIZE=100%FREE

fs_setup:
- label: emptydir
  filesystem: xfs
  device: /dev/vdc
  partition: auto

runcmd:
- mkdir -p /var/lib/origin/openshift.local.volumes

mounts:
- [ /dev/vdc, /var/lib/origin/openshift.local.volumes, xfs, "defaults,gquota" ]
EOF
done