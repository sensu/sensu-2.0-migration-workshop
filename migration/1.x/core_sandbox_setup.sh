# Add the Sensu Core YUM repository
echo '[sensu]
name=sensu
baseurl=https://sensu.global.ssl.fastly.net/yum/$releasever/$basearch/
gpgcheck=0
enabled=1' | tee /etc/yum.repos.d/sensu.repo

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
yum install -y curl jq nc vim ntp redis sensu influxdb grafana uchiwa nagios-plugins-ssh
systemctl stop firewalld
systemctl disable firewalld

# Update Redis "bind" and "protected-mode" configs to allow external connections
sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis.conf
sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis.conf

# Set grafana to port 4000 to not conflict with uchiwa dashboard
sed -i 's/^;http_port = 3000/http_port = 4000/' /etc/grafana/grafana.ini

# Install Sensu plugins
sensu-install -p influxdb
sensu-install -p logs
sensu-install -p slack 
sensu-install -p sensu-plugins-cpu-checks

# Make event log directories
mkdir -p /var/log/sensu/events
mkdir -p /varlog/sensu/filtered_events
chown -R sensu:sensu /var/log/sensu

# Copy Sensu configuration files
cp -r /vagrant_files/sensu/* /etc/sensu/
chmod +x /etc/sensu/plugins/*
chown -R sensu:sensu /etc/sensu
cp -r /vagrant_files/grafana/* /etc/grafana/
chown -R grafana:grafana /etc/grafana


# Configure the shell
echo 'export PS1="demo $ "' >> ~/.bash_profile
echo 'alias l="pwd"' >> ~/.bashrc
echo 'alias ll="ls -Flag --color=auto"' >> ~/.bashrc

# Enable services to start on boot
systemctl start ntpd
systemctl enable ntpd
systemctl start redis
systemctl enable redis
systemctl start sensu-server
systemctl enable sensu-server
systemctl start sensu-api
systemctl enable sensu-api
systemctl enable uchiwa
systemctl start uchiwa
systemctl start influxdb
systemctl enable influxdb
systemctl start grafana-server
systemctl enable grafana-server.service
systemctl start sensu-client
systemctl enable sensu-client

# Create the InfluxDB database
influx -execute "CREATE DATABASE sensu;"

# Print the VM IP Address and exit
echo
echo "This sandbox VM is up and running with the following network interfaces:"
ip address
echo "Happy Sensu-ing!"
