#!/bin/bash

SALT_VERSION=${SALT_VERSION:-2017.7}

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
  az=$(my_az)
  echo "${az%?}"
}

# Signaling that this instance is unhealthy allows AWS auto scaling to launch a copy 
# Provides for self healing and helps mitigate transient failures (e.g. package transfers)
function signal_and_exit
{
  status=$?
  if [ $status -gt 0 ]; then
    sleep 180 # give me a few minutes to look around before croaking
    aws autoscaling set-instance-health \
      --instance-id "$(my_instance_id)" \
      --health-status Unhealthy \
      --region "$(my_aws_region)"
  fi
}

#-----^ AWS safety guards ^-----

# All of this, just to install python-pip.
for i in rhscl extras optional ; do 
  yum-config-manager --enable rhui-REGION-rhel-server-$i > /dev/null 2>&1
done
sudo rpmkeys --import https://getfedora.org/static/352C64E5.txt
rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

yum -y install \
        python-pip \
        systemd-python \
        awscli

# open file descriptor limit
cat >> /etc/security/limits.conf <<EOF
root    soft    nofile  65536
root    hard    nofile  65536
EOF

# Hosts file so that the minion doesn't complain.
sed -i -e '/127.0.0.1/s/$/ salt/' /etc/hosts

curl -sL https://bootstrap.saltstack.com -o install_salt.sh
sh install_salt.sh -M stable "$SALT_VERSION"

cat > /etc/salt/master <<"EOF"
# Configured from AWS user-data.  
# See https://github.com/saltstack/salt/blob/develop/conf/master

# Each minion connecting to the master uses AT LEAST one file descriptor, the
# master subscription connection. If enough minions connect you might start
# seeing on the console (and then salt-master crashes):
#   Too many open files (tcp_listener.cpp:335)
#   Aborted (core dumped)
max_open_files: 65536

# Enable auto_accept, this setting will automatically accept all incoming
# public keys from the minions. Note that this is insecure.
auto_accept: True

# Use TLS/SSL encrypted connection between master and minion.
# Can be set to a dictionary containing keyword arguments corresponding to Python's
# 'ssl.wrap_socket' method.
# Default is None.
#ssl:
#    keyfile: <path_to_keyfile>
#    certfile: <path_to_certfile>
#    ssl_version: PROTOCOL_TLSv1_2

# The failhard option tells the minions to stop immediately after the first
# failure detected in the state execution, defaults to False
failhard: True

# The level of messages to send to the console.
# One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'.
log_level: info
EOF

systemctl restart salt-master.service
systemctl restart salt-minion.service
