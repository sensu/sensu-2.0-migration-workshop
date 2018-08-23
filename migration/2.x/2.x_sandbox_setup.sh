# Add the Sensu Beta repository
curl -s https://packagecloud.io/install/repositories/sensu/beta/script.rpm.sh | bash

# Add the InfluxDB YUM repository
echo "[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key" | tee /etc/yum.repos.d/influxdb.repo

# Add the Grafana YUM repository
echo "[grafana]
name=grafana
baseurl=https://packagecloud.io/grafana/stable/el/7/\$basearch
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packagecloud.io/gpg.key https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt" | tee /etc/yum.repos.d/grafana.repo

# Add the EPEL repositories (for installing Redis)
rpm -Uvh https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm

# Import GPG keys
 curl -O https://repos.influxdata.com/influxdb.key
 curl -O https://packagecloud.io/gpg.key
 curl -O https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
 cp influxdb.key gpg.key RPM-GPG-KEY-grafana /etc/pki/rpm-gpg/

# Install our packages
yum update
yum install -y gcc git curl rubygems ruby-devel jq nc vim ntp sensu-cli sensu-backend sensu-agent influxdb grafana  nagios-plugins-ssh
systemctl stop firewalld
systemctl disable firewalld

# Set grafana to port 4000 to not conflict with sensu dashboard
sed -i 's/^;http_port = 3000/http_port = 4000/' /etc/grafana/grafana.ini

# Install 1.x Sensu plugins
gem install sensu-plugins-influxdb sensu-plugins-slack  sensu-translator bundler 

# Special 2.x shim plugin
cp -r /vagrant_files/sensu-plugin /tmp/
cd /tmp/sensu-plugin
gem build sensu-plugin.gemspec
gem install sensu-plugin-2.6.0.gem

cp -r /vagrant_files/sensu-plugins-logs /tmp/
cd /tmp/sensu-plugins-logs
gem build sensu-plugins-logs.gemspec
gem install sensu-plugins-logs-1.3.3.gem

cp -r /vagrant_files/sensu-plugins-cpu-checks /tmp/
cd /tmp/sensu-plugins-cpu-checks
gem build sensu-plugins-cpu-checks
gem install sensu-plugins-cpu-checks-3.0.0.gem

# Install the golang influxdb handler
cd /tmp
wget https://github.com/nikkiki/sensu-influxdb-handler/releases/download/v1.5/sensu-influxdb-handler_1.5_linux_amd64.tar.gz
tar xvzf sensu-influxdb-handler_1.5_linux_amd64.tar.gz
cp sensu-influxdb-handler /usr/local/bin/

cd

# Install the filter gRPC PoC
cp -r /vagrant_files/sensu-1.x-filter-wrapper /home/vagrant/shim
chown -R vagrant:vagrant /home/vagrant/shim

# Make event log directories
mkdir -p /var/log/sensu/events
chown -R sensu:sensu /var/log/sensu
mkdir -p /opt/sensu
chown -R sensu:sensu /opt/sensu

# Copy Sensu configuration files
cp -r /vagrant_files/sensu/* /etc/sensu/
chmod +x /etc/sensu/plugins/*
chown -R sensu:sensu /etc/sensu
cp -r /vagrant_files/grafana/* /etc/grafana/
chown -R grafana:grafana /etc/grafana
cp -r /vagrant_files/var/lib/grafana/dashboards /var/lib/grafana
chown -R grafana:grafana /var/lib/grafana


# Configure the shell
echo 'export PS1="demo $ "' >> ~/.bash_profile
echo 'alias l="pwd"' >> ~/.bashrc
echo 'alias ll="ls -Flag --color=auto"' >> ~/.bashrc

# 


# Enable services to start on boot
systemctl start ntpd
systemctl enable ntpd
systemctl start sensu-backend
systemctl enable sensu-backend

echo "configuring sensuctl for root"
sensuctl configure -n --username admin --password P@ssw0rd! --url http://127.0.0.1:8080
sensuctl organization create "migration" --description "migrating 1.x to 2.x"
sensuctl environment create "development" --description "for development"
sensuctl config set-format "json"
sensuctl config view 

echo "configuring sensuctl for vagrant user"
sudo -u vagrant sensuctl configure -n --username admin --password P@ssw0rd! --url http://127.0.0.1:8080
sudo -u vagrant sensuctl config set-format "json"

sudo -u vagrant sensuctl config view 


systemctl start influxdb
systemctl enable influxdb
systemctl start grafana-server
systemctl enable grafana-server.service
systemctl start sensu-agent
systemctl enable sensu-agent

# Create the InfluxDB database
influx -execute "CREATE DATABASE sensu;"

# Print the VM IP Address and exit
echo
echo "This sandbox VM is up and running with the following network interfaces:"
ip address
echo "Happy Sensu-ing!"
