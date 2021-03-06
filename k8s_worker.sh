#! /bin/bash

#-- Firewall ----------------------------------------------------------------------------------------------
echo -e "\n----------------- Firewall Configuration, Openning Ports ------------------"
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=30000-32767/tcp
echo -e "...............Firewall Reloading, Saving All Changes..............."
firewall-cmd --reload


#-- Iptables ----------------------------------------------------------------------------------------------
echo -e "\n----------------- Bridged Network Traffic ------------------"

echo -e "\n----------------- Checking br_netfilter Module ------------------"
lsmod | grep br_netfilter

echo "net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.d/k8s.conf

if grep -q "ip6tables" "/etc/sysctl.d/k8s.conf"; then
    echo -e "\n------------------net.bridge Configuration Added Successfully------------------"
    sysctl --system

else
    echo -e "\n------------------ Failure In Configuring net.bridge ------------------"
    echo -e "\nExiting The Script...\n"
    exit

fi


#-- Primary Packages Installation -------------------------------------------------------------------------
echo -e "\n------------------ Updating yum Packages ------------------"
yum update -y

echo -e "\n------------------Installing Neccessary Packages------------------"
yum install tracerouteipvsadm tree bind-utils gcc git wget curl rpm scp tar unzip bzip2wget createrepo reposync yum-utils ntp pdsh python-devel net-tools nmap telnet openconnect –y

echo -e "\n------------------ Fetching eple-7 Repository------------------"
wget https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-13.noarch.rpm

echo -e "\n------------------ Installing eple-release------------------"
rpm -ivh epel-release-7-13.noarch.rpm


#-- Disabling Service/Storage------------------------------------------------------------------------------
echo -e "\n------------------ Disabling Swap ------------------"
swapon --summary
swapoff /dev/dm-0
swapoff -a

echo -e "\n------------------ Disabling Firewall ------------------"
systemctl stop firewalld
systemctl disable firewalld
# Calling Function
system_reboot


#-- Network -----------------------------------------------------------------------------------------------
echo -e "\n------------------ Setting Up Network Configurations ------------------"
nmtui


#-- NTP ---------------------------------------------------------------------------------------------------
echo -e "\n------------------ Installing NTP ------------------"
yum install ntpd
systemctl start ntpd

echo -e "\n------------------ Configuring NTP ------------------"
time_zone_1="server 0.centos.pool.ntp.org iburst"
time_zone_2="server 1.centos.pool.ntp.org iburst"
time_zone_3="server 2.centos.pool.ntp.org iburst"
time_zone_4="server 3.centos.pool.ntp.org iburst"

# Calling Function
replace_timezone $time_zone_1
replace_timezone $time_zone_2
replace_timezone $time_zone_3
replace_timezone $time_zone_4
sed -i '/#server 3.centos.pool.ntp.org iburst/i server 129.6.15.28 iburst' /etc/ntp.conf

echo -e "\n------------------ Restarting NTP ------------------"
systemctl restart ntpd

echo -e "\n------------------ DateTime Output ------------------"
timedatectl

echo -e "\n------------------ Setting NTP Timezone ------------------"
timedatectl set-timezone UTC


#-- Runtime - Docker Installation ------------------------------------------------------------------------
echo -e "\n------------------ Fetching Packages ------------------"
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

echo -e "\n------------------ Installing Docker CE ------------------"
yum install -y containerd.io-1.2.13 docker-ce-20.10.3 docker-ce-cli-20.10.3

echo -e "\n------------------ Creating Docker Directory------------------"
mkdir /etc/docker
echo '{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"],
   "insecure-registries": ["ip1:port1","ip2:port2"]
}' > /etc/docker/daemon.json

if grep -q "ip1_port1" "/etc/docker/daemon.json"; then
    echo -e "\nDocker Daemon Configured Successfully.\n"
    mkdir -p /etc/systemd/system/docker.service.d

    echo -e "\n------------------ Starting Docker ------------------"
    systemctl daemon-reload
    systemctl enable docker
    systemctl restart docker
    systemctl status docker

elif ! grep -q "192.168.100.81:8082" "/etc/docker/daemon.json"; then
    echo -e "\nDocker Daemon Configuration Failed. Exiting The Process...\n"
    exit

else
    echo -e "\nDocker Daemon Can Not Be Started. Please Check Your Network Connection Type And Try Again. Exiting The Process For Now...\n"
    exit
fi

#-- Kubernetes Repository  ------------------------------------------------------------------------------
echo -e "\n----------------- Kubernetes Repository Configuration ------------------"
echo "[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl" > /etc/yum.repos.d/kubernetes.repo


#-- SELinux ---------------------------------------------------------------------------------------------
echo -e "\n----------------- SELinux Configuration ------------------"
selinux_enabled='cat /selinux'
if getenforce | grep "Enabled"; then
    echo -e "\n----------------- Disabling SELinux ------------------"
    setenforce 0
    sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
    getenforce 0
    system_reboot 

else
    echo -e "\nSELinux Is Disabled."

fi


#-- Kubelet, Kubeadm, Kubectl ---------------------------------------------------------------------------
echo -e "\n-----------------Installing Kubelet, Kubeadm And Kubectl------------------"
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

echo -e "\n-----------------Starting Kubelet ------------------"
systemctl enable --now kubelet
systemctl restart kubelet


#-- Cgroup Driver ---------------------------------------------------------------------------------------
echo -e "\n----------------- Checking Docker Cgroup Driver ------------------"
if docker info | grep "systemd"; then
    echo -e "\nDocker Cgroup Recognized As Systemd."
else
    echo -e "\nDocker Cgroup Not Configured As Systemd."
fi
echo -e "\n----------------- Checking Kubelet Cgroup Driver ------------------"
if grep -q "systemd" "/var/lib/kubelet/kubeadm-flags.env"; then
    echo -e "\nKubelet Cgroup Recognizedss As Systemd."

else
    echo -e "\n----------------- Configuring Kubelet Cgroup Driver ------------------"
    echo "‫‪KUBELET_EXTRA_ARGS=--cgroup-driver=systemd‬‬" > /etc/sysconfig/kubelet
fi

echo "\nPre-requisites Installation And Configuration Completed."



 
















