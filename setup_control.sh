#!/bin/bash
set -euxo pipefail

# Log bootstrap progress for live troubleshooting.
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Frappe Press control-node bootstrap..."

# Ensure admin user can run automation without password prompts.
echo "${admin_username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${admin_username}-nopasswd
chmod 440 /etc/sudoers.d/90-${admin_username}-nopasswd

# Ensure admin user SSH directory and control-to-workers private key are present.
install -d -m 700 -o "${admin_username}" -g "${admin_username}" "/home/${admin_username}/.ssh"
echo "${control_private_key_b64}" | base64 -d > "/home/${admin_username}/.ssh/worker_access_key"
chown "${admin_username}:${admin_username}" "/home/${admin_username}/.ssh/worker_access_key"
chmod 600 "/home/${admin_username}/.ssh/worker_access_key"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install -y python3-dev python3-pip python3-venv mariadb-server mariadb-client redis-server nodejs npm nginx git curl cron sudo

# Configure MariaDB root password if this host uses auth_socket by default.
if mysql -e "SELECT 1" >/dev/null 2>&1; then
  mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${db_root_password_shell}';" || true
fi
mysql -uroot -p${db_root_password_shell} -e "DELETE FROM mysql.user WHERE User='';" || true
mysql -uroot -p${db_root_password_shell} -e "FLUSH PRIVILEGES;" || true

sudo -u "${admin_username}" -H bash <<EOF
set -euxo pipefail
cd /home/${admin_username}
export PATH=\$PATH:/home/${admin_username}/.local/bin

pip3 install --user frappe-bench

if [ ! -d press-bench ]; then
  /home/${admin_username}/.local/bin/bench init press-bench --frappe-branch version-15 --skip-redis-config-check
fi

cd press-bench
/home/${admin_username}/.local/bin/bench get-app https://github.com/frappe/press.git || true
/home/${admin_username}/.local/bin/bench new-site dashboard.${root_domain} --admin-password ${site_admin_password_shell} --mariadb-root-password ${db_root_password_shell} --install-app press --force || true
/home/${admin_username}/.local/bin/bench setup production ${admin_username} --yes || true
EOF

echo "Setup complete. Dashboard target: dashboard.${root_domain}"
