#!/bin/bash

ORG=${ORG}
ENV=${ENV}
REALM=${REALM}
JOIN_DOMAIN=${JOIN_DOMAIN}
JOIN_USER=${JOIN_USER}
JOIN_PASS=${JOIN_PASS}
RHN_USER=${RHN_USER}
RHN_PASS=${RHN_PASS}

set -o errexit -o errtrace -o pipefail
trap signal_and_exit ERR

function my_instance_id
{
  curl -sL http://169.254.169.254/latest/meta-data/instance-id/
}

function my_az
{
  curl -sL http://169.254.169.254/latest/meta-data/placement/availability-zone/
}

function my_aws_region
{
  local az
  az=$$(my_az)
  echo "$${az%?}"
}

# Signaling that this instance is unhealthy allows AWS auto scaling to launch a copy 
# Provides for self healing and helps mitigate transient failures (e.g. package transfers)
function signal_and_exit
{
  status=$$?
  if [ $$status -gt 0 ]; then
    sleep 180 # give me a few minutes to look around before croaking
    aws autoscaling set-instance-health \
      --instance-id "$$(my_instance_id)" \
      --health-status Unhealthy \
      --region "$$(my_aws_region)"
  fi
}

#-----^ AWS safety guards ^-----

# All of this, just to install python-pip.
for i in rhscl extras optional ; do 
  yum-config-manager --enable rhui-REGION-rhel-server-$$i > /dev/null 2>&1
done

yum -y install python27-python-pip python-setuptools awscli

if [ "X$$JOIN_DOMAIN" == "Xtrue" ]; then
  yum -y install \
   sssd \
   realmd \
   krb5-workstation \
   oddjob \
   oddjob-mkhomedir \
   samba-common-tools \
   adcli

  echo "${JOIN_PASS}" \
   | realm join -U $${JOIN_USER}@$${REALM} $${REALM} \
     --client-software=sssd \
     --server-software=active-directory \
     --membership-software=adcli
fi

mkdir -p /tmp/ansible

cat > /tmp/ansible/hosts <<EOF
#!/usr/bin/python
# Meant to replace the /etc/ansible/hosts script on hosts and allow for
# local environment & role based ansible runs.

import sys
import os
import json


def main():
    inventory = {"_meta": {"hostvars": {}}}

    # Puts this host in the given HOSTGROUP
    try:
        host_group = os.environ.get("HOSTGROUP", 'default')
        inventory[host_group] = ["127.0.0.1"]
    except KeyError:
        pass

    print json.dumps(inventory)

if __name__ == '__main__':
    sys.exit(main())
EOF
chmod 755 /tmp/ansible/hosts

cat > /tmp/ansible/requirements.yml <<EOF
---
- src: zaxos.lvm-ansible-role
  name: volumes
- src: bennojoy.ntp
  name: ntp
- src: https://github.com/gswallow/ansible-satellite6-install.git
  # version is draft for testing before we push changes to master
  version: master
  name: satellite-deployment
EOF

cat > /tmp/ansible/config.yml <<EOF
---
- hosts: satellite-server
  roles:
    - role: volumes
    - role: ntp
      ntp_server:
        - '169.254.169.123'
    - { role: satellite-deployment, tags: ['install', 'rhn'] }
  vars_files:
    - "{{ satellite_deployment_vars }}"
EOF

cat > /tmp/ansible/seed <<EOF
---
# Volumes
lvm_volumes:
  - vg_name: vg00
    lv_name: pulp_cache
    disk: xvdf
    filesystem: xfs
    mount: /var/cache/pulp
    mount_options: defaults,noatime,nodiratime,discard
  - vg_name: vg01
    lv_name: pulp_storage
    disk: xvdg
    filesystem: xfs
    mount: /var/lib/pulp
    mount_options: defaults,noatime,nodiratime,discard
  - vg_name: vg02
    lv_name: mongodb
    disk: xvdh
    filesystem: xfs
    mount: /var/lib/mongodb
    mount_options: defaults,noatime,nodiratime,discard
  - vg_name: vg03
    lv_name: pgsql
    disk: xvdi
    filesystem: xfs
    mount: /var/lib/pgsql
    mount_options: defaults,noatime,nodiratime,discard

# Satellite
# main vars
satellite_deployment_hostname_short: "satellite"
satellite_deployment_hostname_full: "satellite.ivytech.edu"
satellite_deployment_admin_username: "admin"
satellite_deployment_admin_password: "123456"
satellite_deployment_organization: "ivytech.edu"
satellite_deployment_location: "Indianapolis"
satellite_deployment_version: 6.2

#satellite_deployment_plugin_ports

# install
satellite_deployment_plugin_packages:
  - "foreman-discovery-image"

# registration vars
satellite_deployment_rhn_user: "$${RHN_USER}"
satellite_deployment_rhn_password: "$${RHN_PASS}"

# answers for sattelite installer
satellite_deployment_answers:
  "foreman-initial-organization": "{{ satellite_deployment_organization }}"
  "foreman-initial-location": "{{ satellite_deployment_location }}"
  "foreman-admin-username": "{{ satellite_deployment_admin_username }}"
  "foreman-admin-password": "{{ satellite_deployment_admin_password }}"
  "foreman-proxy-dns": "false"
  "foreman-proxy-dhcp": "false"
  "foreman-proxy-tftp": "false"
  "foreman-proxy-puppetca": "false"
  "capsule-puppet": "false"

# configure_satellite:
satellite_deployment_manifest_path: "http://my.local.server/sat-manifest.zip"
EOF

yum -y install ansible git
cd /tmp/ansible 
ansible-galaxy install -f -r requirements.yml -p roles/

HOSTGROUP=satellite-server ansible-playbook -i /tmp/ansible/hosts -e '{satellite_deployment_vars: /tmp/ansible/seed}' config.yml -c local
