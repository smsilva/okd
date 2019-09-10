openstack server create \
--image centos7 \
--flavor m1.small \
--key-name ${openstack_user_admin} \
--port port-61 \
--user-data /osp/cloud-init/bastion.example.com.yml \
bastion.example.com

ping 192.168.1.61

scp -i .ssh/id_rsa_${openstack_project} .ssh/id_rsa_${openstack_project} .ssh/id_rsa_${openstack_project}.pub centos@192.168.1.84:~/tmp/

ssh -i .ssh/id_rsa_${openstack_project} centos@192.168.1.84

yum update -y

yum install -y epel-release

yum install -y ansible

yum install -y vim git python-pip python-devel python

pip install pip --upgrade

pip install ansible==2.6.5

sed -i 's/#callback_whitelist = timer, mail/callback_whitelist = profile_tasks, timer/g' /etc/ansible/ansible.cfg

sed -i 's/#log_path = /log_path = /g' /etc/ansible/ansible.cfg

sed -i 's/#roles_path/roles_path/g' /etc/ansible/ansible.cfg

sed -i 's/#host_key_checking/host_key_checking/g' /etc/ansible/ansible.cfg

sed -i 's/#private_key_file/private_key_file/g' /etc/ansible/ansible.cfg

sed -i 's/private_key_file = \/path\/to\/file/private_key_file = ~\/.ssh\/id_rsa_okd/g' /etc/ansible/ansible.cfg
