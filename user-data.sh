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

# Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

apt update -y
apt install -y jenkins
systemctl enable jenkins
systemctl start jenkins
usermod -aG docker jenkins

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

# Apache Tomcat 9.0.27
wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.27/bin/apache-tomcat-9.0.27.tar.gz

if [ -f apache-tomcat-9.0.27.tar.gz ]; then
  tar xzf apache-tomcat-9.0.27.tar.gz
  mv apache-tomcat-9.0.27 /opt/tomcat9
  chmod +x /opt/tomcat9/bin/*.sh
  echo "Tomcat 9.0.27 installed at /opt/tomcat9"
  /opt/tomcat9/bin/startup.sh
else
  echo "Tomcat 9.0.27 download failed" >&2
fi


reboot
