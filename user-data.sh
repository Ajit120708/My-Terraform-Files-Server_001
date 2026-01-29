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


# Jenkins Installation with GPG Fix - Use allow-insecure=yes for Release.gpg issues
set -o pipefail
LOG_JENKINS="/var/log/jenkins_install.log"
echo "--- Jenkins installation started at $(date) ---" | tee -a $LOG_JENKINS

# Ensure required tools are installed
apt-get update -y && apt-get install -y gpg curl ca-certificates

# Remove any old Jenkins key or repo files
rm -f /usr/share/keyrings/jenkins-keyring.asc /usr/share/keyrings/jenkins-keyring.gpg /etc/apt/sources.list.d/jenkins.list

# Step 1: Download the Jenkins GPG key as .asc
echo "Downloading Jenkins GPG key..." | tee -a $LOG_JENKINS
if curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key -o /usr/share/keyrings/jenkins-keyring.asc; then
  echo "Jenkins key downloaded as .asc" | tee -a $LOG_JENKINS
else
  echo "Failed to download Jenkins key" | tee -a $LOG_JENKINS >&2
  exit 1
fi

# Step 2: Convert .asc to .gpg format
echo "Converting Jenkins key to .gpg format..." | tee -a $LOG_JENKINS
if gpg --dearmor < /usr/share/keyrings/jenkins-keyring.asc -o /usr/share/keyrings/jenkins-keyring.gpg; then
  echo "Jenkins key converted to .gpg format" | tee -a $LOG_JENKINS
else
  echo "Failed to convert Jenkins key to .gpg" | tee -a $LOG_JENKINS >&2
  exit 1
fi

# Verify the .gpg key file is valid and non-empty
if [ ! -s /usr/share/keyrings/jenkins-keyring.gpg ]; then
  echo "Jenkins .gpg keyring file is missing or empty!" | tee -a $LOG_JENKINS >&2
  exit 1
fi
echo "Jenkins .gpg keyring verified: $(ls -lh /usr/share/keyrings/jenkins-keyring.gpg)" | tee -a $LOG_JENKINS

# Step 3: Add the Jenkins apt repository with allow-insecure option for Release.gpg issues
echo "Adding Jenkins apt repository..." | tee -a $LOG_JENKINS
if echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg allow-insecure=yes] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null; then
  echo "Jenkins repo added to /etc/apt/sources.list.d/jenkins.list" | tee -a $LOG_JENKINS
else
  echo "Failed to add Jenkins repo" | tee -a $LOG_JENKINS >&2
  exit 1
fi

echo "Running apt update..." | tee -a $LOG_JENKINS
if apt update -y >> $LOG_JENKINS 2>&1; then
  echo "apt update successful." | tee -a $LOG_JENKINS
else
  echo "apt update failed!" | tee -a $LOG_JENKINS >&2
  cat /var/log/apt/term.log >> $LOG_JENKINS 2>&1 || true
  exit 1
fi

echo "Installing Jenkins..." | tee -a $LOG_JENKINS
if apt install -y --allow-unauthenticated jenkins >> $LOG_JENKINS 2>&1; then
  echo "Jenkins installed successfully." | tee -a $LOG_JENKINS
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
set -o pipefail
LOG_TOMCAT="/var/log/tomcat_install.log"
echo "--- Tomcat installation started at $(date) ---" | tee -a $LOG_TOMCAT
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))
echo "JAVA_HOME is set to $JAVA_HOME" | tee -a $LOG_TOMCAT

TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.27/bin/apache-tomcat-9.0.27.tar.gz"
TOMCAT_ARCHIVE="apache-tomcat-9.0.27.tar.gz"
DOWNLOAD_SUCCESS=0
for i in {1..5}; do
  echo "Attempt $i: Downloading Tomcat..." | tee -a $LOG_TOMCAT
  curl -fSL --retry 5 --retry-delay 5 -o "$TOMCAT_ARCHIVE" "$TOMCAT_URL" && DOWNLOAD_SUCCESS=1 && break
  echo "Tomcat download attempt $i failed, retrying in 5s..." | tee -a $LOG_TOMCAT
  sleep 5
done

if [ $DOWNLOAD_SUCCESS -eq 1 ] && [ -f "$TOMCAT_ARCHIVE" ] && [ $(stat -c%s "$TOMCAT_ARCHIVE") -gt 10000000 ]; then
  if tar tzf "$TOMCAT_ARCHIVE" > /dev/null 2>&1; then
    tar xzf "$TOMCAT_ARCHIVE"
    mv apache-tomcat-9.0.27 /opt/tomcat9
    chmod +x /opt/tomcat9/bin/*.sh
    echo "Tomcat 9.0.27 installed at /opt/tomcat9" | tee -a $LOG_TOMCAT
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
    echo "Tomcat service started." | tee -a $LOG_TOMCAT
  else
    echo "Downloaded Tomcat archive is corrupted. Removing file." | tee -a $LOG_TOMCAT >&2
    rm -f "$TOMCAT_ARCHIVE"
  fi
else
  echo "Tomcat 9.0.27 download failed, file missing, or file is too small!" | tee -a $LOG_TOMCAT >&2
  rm -f "$TOMCAT_ARCHIVE"
fi
echo "--- Tomcat installation ended at $(date) ---" | tee -a $LOG_TOMCAT

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
