#!/bin/bash
set -e

apt update -y

# Java
apt install -y openjdk-17-jre openjdk-17-jdk-headless

# Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu


# Jenkins Installation with Updated GPG Key Handling (for Ubuntu 22.04+)
set -o pipefail
LOG_JENKINS="/var/log/jenkins_install.log"
echo "--- Jenkins installation started at $(date) ---" | tee -a $LOG_JENKINS

# Download and add the new Jenkins GPG key
if curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg; then
  echo "Jenkins key added." | tee -a $LOG_JENKINS
else
  echo "Failed to add Jenkins key" | tee -a $LOG_JENKINS >&2
  exit 1
fi

# Add the Jenkins apt repository
if echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null; then
  echo "Jenkins repo added." | tee -a $LOG_JENKINS
else
  echo "Failed to add Jenkins repo" | tee -a $LOG_JENKINS >&2
  exit 1
fi

echo "Running apt update..." | tee -a $LOG_JENKINS
if apt update -y >> $LOG_JENKINS 2>&1; then
  echo "apt update successful." | tee -a $LOG_JENKINS
else
  echo "apt update failed!" | tee -a $LOG_JENKINS >&2
  exit 1
fi

echo "Installing Jenkins..." | tee -a $LOG_JENKINS
if apt install -y jenkins >> $LOG_JENKINS 2>&1; then
  echo "Jenkins installed." | tee -a $LOG_JENKINS
  systemctl enable jenkins >> $LOG_JENKINS 2>&1
  systemctl start jenkins >> $LOG_JENKINS 2>&1
  usermod -aG docker jenkins
  echo "Jenkins service started and added to docker group." | tee -a $LOG_JENKINS
else
  echo "Jenkins installation failed! See $LOG_JENKINS for details." | tee -a $LOG_JENKINS >&2
  exit 1
fi
echo "--- Jenkins installation ended at $(date) ---" | tee -a $LOG_JENKINS

# AWS CLI
apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
./aws/install

# kubectl
snap install kubectl --classic


# eksctl
curl -s https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz \
  | tar xz -C /tmp
chmod +x /tmp/eksctl
mv /tmp/eksctl /usr/local/bin/
export PATH=$PATH:/usr/local/bin
if command -v eksctl >/dev/null 2>&1; then
  echo "eksctl installed successfully: $(eksctl version)"
else
  echo "eksctl installation failed" >&2
  exit 1
fi


# Apache Tomcat 9.0.27 with JAVA_HOME and systemd service
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))
echo "JAVA_HOME is set to $JAVA_HOME"
wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.27/bin/apache-tomcat-9.0.27.tar.gz

if [ -f apache-tomcat-9.0.27.tar.gz ]; then
  tar xzf apache-tomcat-9.0.27.tar.gz
  mv apache-tomcat-9.0.27 /opt/tomcat9
  chmod +x /opt/tomcat9/bin/*.sh
  echo "Tomcat 9.0.27 installed at /opt/tomcat9"
  # Create systemd service for Tomcat
  cat <<EOF > /etc/systemd/system/tomcat9.service
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=/opt/tomcat9/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat9
Environment=CATALINA_BASE=/opt/tomcat9
ExecStart=/opt/tomcat9/bin/startup.sh
ExecStop=/opt/tomcat9/bin/shutdown.sh
User=root
Group=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable tomcat9
  systemctl start tomcat9
else
  echo "Tomcat 9.0.27 download failed" >&2
fi

# Run custom JAR if present
if [ -f /opt/app/app.jar ]; then
  echo "Found app.jar, running as a service."
  cat <<EOF > /etc/systemd/system/appjar.service
[Unit]
Description=Custom Java Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=$JAVA_HOME/bin/java -jar /opt/app/app.jar
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable appjar
  systemctl start appjar
else
  echo "No app.jar found in /opt/app, skipping JAR execution."
fi


reboot
