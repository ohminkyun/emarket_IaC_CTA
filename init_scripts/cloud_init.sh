#!/bin/sh
###############################################################################################
# Terraform이 EC2 인스턴스를 생성할 때 사용하는 user_data (cloud-init) script
# 보안정책과 EKS를 관리하기 위한 각종 설치파일들이 설치된다.
###############################################################################################
sed -i 's,http://.*ubuntu.com,https://mirror.kakao.com,g' /etc/apt/sources.list
apt-get update

# install unzip
echo "[installation] unzip"
apt-get install -y unzip

#install expect
echo "[installation] expect"
apt-get install -y expect

# install net-tools (ifconfig, nc etc ...)
echo "[installation] net-tools"
apt-get install -y net-tools

# install libpam-pwquality 
echo "[installation] libpam-pwquality"
apt-get install -y libpam-pwquality

# aws cli install
echo "[installation] aws_cli v2"
curl --silent --location https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# kubectl install
echo "[installation] kubectl"
curl --silent --location https://s3.us-west-2.amazonaws.com/amazon-eks/1.24.9/2023-01-11/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# iam-authenticator install
echo "[installation] iam-authenticator"
curl --silent --location https://s3.us-west-2.amazonaws.com/amazon-eks/1.24.9/2023-01-11/bin/linux/amd64/aws-iam-authenticator -o /usr/local/bin/aws-iam-authenticator
chmod +x /usr/local/bin/aws-iam-authenticator

# eksctl install
echo "[installation] eksctl"
curl --silent --location https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz | tar xz -C /tmp
mv -v /tmp/eksctl /usr/local/bin
chmod +x /usr/local/bin/eksctl

# Helm3 install
echo "[installation] helm3"
curl --silent --location https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 -o /tmp/get_helm.sh
chmod +x /tmp/get_helm.sh
/tmp/get_helm.sh

# terraform install
echo "[installation] terraform"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update
apt-get install terraform

# argocd cli install
echo "[installation] argocd cli"
curl -sSL --silent https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 -o /tmp/argocd-linux-amd64
install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd

# argo-rollout kubectl plugin install
echo "[installation] argo-rollouts kubectl plugins"
curl --silent --location -o /usr/local/bin/kubectl-argo-rollouts https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x /usr/local/bin/kubectl-argo-rollouts

# mysql client install
echo "[installation] mysql client"
apt-get install -y mysql-client-core-8.0

# install node_exporter for prometheus monitoring
echo "[installation] node_exporter"
useradd -m -s "/sbin/nologin" node_exporter
curl --silent --location https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz | tar xz -C /tmp
mv -v /tmp/node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/node_exporter
cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network-online.target

[Service]
Type=simple
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable node_exporter.service
systemctl start node_exporter.service

# install k9s
echo "[installation] k9s"
curl --silent --location https://github.com/derailed/k9s/releases/download/v0.27.3/k9s_Linux_amd64.tar.gz | tar xz -C /tmp
mv -v /tmp/k9s /usr/local/bin/k9s

# Copy and Config kubeconfig
echo "[configuration] making kubeconfig"
mkdir /home/ubuntu/.kube
echo "${KUBECONFIG}" > /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/
chown ubuntu:ubuntu /home/ubuntu/.kube/config && chmod 600 /home/ubuntu/.kube/config
echo "source <(helm completion bash)" >> /home/ubuntu/.bashrc
echo "source <(kubectl completion bash)" >> /home/ubuntu/.bashrc
echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
echo 'complete -F __start_kubectl k' >> /home/ubuntu/.bashrc
touch /etc/skel/.rhosts; chmod 000 /etc/skel/.rhosts
touch /root/.rhosts; chmod 000 /root/.rhosts
touch /etc/hosts.equiv; chmod 000 /etc/hosts.equiv

# Configure hostname
# echo "[configuration] hostname"
# sed -i "s/127.0.0.1 localhost/127.0.0.1 localhost ${HOSTNAME}/g" /etc/hosts
# hostname ${HOSTNAME}
# echo ${HOSTNAME} > /etc/hostname
# sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg

# Configure Time-zone & time server
echo "[configuration] Time server"
echo "NTP=169.254.169.123" >> /etc/systemd/timesyncd.conf
service systemd-timesyncd restart
timedatectl set-timezone Asia/Seoul

# security configuration (참고용)
# echo "[configuration] security policy"
# echo 'HISTTIMEFORMAT="%F %T "' >> /etc/profile
# echo "export TMOUT=1800" >> /etc/profile
# echo "umask 022" >> /etc/profile
# echo "source <(helm completion bash)" >> /etc/profile
# echo "source <(kubectl completion bash)" >> /etc/profile
# chmod 400 /etc/shadow
# chmod 700 /usr/bin/last /sbin/ifconfig
# chmod 600 /var/log/wtmp* /var/log/btmp*
# chmod 640 /var/log/auth.log*
# sed -i "s/rotate [0-9]/rotate 12/g" /etc/logrotate.d/rsyslog
# sed -i "s/daily/monthly/g" /etc/logrotate.d/rsyslog
# sed -i "s/weekly/monthly/g" /etc/logrotate.d/rsyslog
# sed -i "s/rotate [0-9]/rotate 12/g" /etc/logrotate.conf
# sed -i "s/create 0664 root utmp/create 0600 root utmp/g" /etc/logrotate.conf
# sed -i "s/create 0660 root utmp/create 0600 root utmp/g" /etc/logrotate.conf
#-------------------------Ubuntu 20.04 LTS configuration -----------------------------
#sed -i "s/rotate [0-9]/rotate 12/g" /etc/logrotate.d/btmp
#sed -i "s/create 0660 root utmp/create 0600 root utmp/g" /etc/logrotate.d/btmp
#sed -i "s/rotate [0-9]/rotate 12/g" /etc/logrotate.d/wtmp
#sed -i "s/create 0660 root utmp/create 0600 root utmp/g" /etc/logrotate.d/wtmp
#-------------------------Ubuntu 20.04 LTS configuration -----------------------------
# echo "PASS_MIN_LEN 8" >> /etc/login.defs
# echo "PASS_MAX_DAYS 90" >> /etc/login.defs
# echo "PASS_MIN_DAYS 7" >> /etc/login.defs
# # password 복잡도 (pam.cracklib.so lcredit, dcredit, ocredit)
# # password remember (pam.unix.so remember 2)
# sed -i "s/pam_pwquality.so retry=3/pam_pwquality.so retry=3 lcredit=-1 ocredit=-1 dcredit=-1 remember=2 minlen=8/g" /etc/pam.d/common-password
# # account lock (pam.tally.so deny: 3, unlock_time: 1800, no_magic_root: reset)
# sed -i "/pam_deny.so/a\auth    required                        pam_tally2.so deny=4 unlock_time=1800" /etc/pam.d/common-auth
# sed -i "s/pam_permit.so/pam_tally2.so/g" /etc/pam.d/common-account
# 사용자 계정별 권한 확인
#awk -F ":" '{if($7 == "/bin/bash") {print $6"/.profile"; print $6"/.bashrc"} }' /etc/passwd | xargs chmod 644
#awk -F ":" '{if($7 == "/bin/bash") print $6"/.bash_history"}' /etc/passwd | xargs chmod 600

# Change sshd port
echo "[configuration] change SSH port 22 -> ${SSHD_PORT}"
echo "Port ${SSHD_PORT}" >> /etc/ssh/sshd_config
echo "
     ******************************************************************
     * This system is for the use of authorized users only. Usage of  *
     * this system may be monitored and recorded by system personnel. *
     * Anyone using this system expressly consents to such monitoring *
     * and is advised that if such monitoring reveals possible        *
     * evidence of criminal activity, system personnel may provide    *
     * the evidence from such monitoring to law enforcement officials.*
     ******************************************************************
" > /etc/sshd_banner
echo "Banner /etc/sshd_banner" >> /etc/ssh/sshd_config
echo "[configuration] restarting sshd service"
systemctl restart ssh.service
