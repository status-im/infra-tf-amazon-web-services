#!/usr/bin/env bash
mkdir -p /root/.ssh
cat <<EOK >> /root/.ssh/authorized_keys
${ssh_keys}
EOK
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chown root:root /root/.ssh -R
