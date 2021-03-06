#!/bin/bash


#-- Check IP Validation -----------------------------------------------------------------------------------
validate_IP(){

	if [[ $1 =~ ^192\.168\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	  echo "True"
	else
	  echo "False"
	fi
	
}


#-- Copy SSH RSA Key --------------------------------------------------------------------------------------
copy_ssh_key(){
	
	# Variables Declaration
	continue_option=0

	while [ $continue_option -lt 1 ] 
	do 
		read -p "\nEnter The Node IP Address, Please: " node_IP
		    
		if validate_IP $node_IP | grep "True"; then
		    echo -e "\n------------------ Copying RSA Key To Node ------------------"
		    ssh-copy-id -i /root/.ssh/id_rsa.pub root@$node_IP
		    
		else
		    echo -e "\nThe IP Addresse Can Not Be Substituted."
		    continue_option=0
		     
		fi

		read -p "Do You Want To Copy This Key To More Nodes? (y to approve and any character to deny): " add_node
		if [[ $add_node == "y" || $add_node == "Y" || $add_node == "yes" || $add_node == "YES" ]]; then
		    continue_option=0
		else
		    continue_option=1
		fi
	done
}


#-- Rebooting Machine -------------------------------------------------------------------------------------
system_reboot(){

	read -p "\nWe Need To Reboot Your Machine; Do You Want To Proceed With That? (y to approve and any character to deny): " reboot_reply
	if [[ $reboot_reply == "y" || $reboot_reply == "Y" || $reboot_reply == "yes" || $reboot_reply == "YES" ]]; then
	    echo -e "System Reboot Started...\n"
	    reboot
	else
	    echo -e "\nSystem Reboot Was Canceled; The Process Is Being Continued..."

	fi

}


#-- Replace Timezone --------------------------------------------------------------------------------------
replace_timezone(){
     	to_replace="#{$1}"
	sed -i 's/$1/$to_replace' /etc/ntp.conf
}


#-- Replace Timezone --------------------------------------------------------------------------------------
datetime_syncronocity(){
	
	read -p "\nEnter The IP_Address To Check Date And Time: " datetime_IP
	date && ssh $datetime_IP date
}


#-- Change Directory --------------------------------------------------------------------------------------
cd ~


#-- Firewall ----------------------------------------------------------------------------------------------
echo -e "\n----------------- Firewall Configuration, Openning Ports ------------------"
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp

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
#yum update -y

echo -e "\n------------------Installing Neccessary Packages------------------"
#yum install tracerouteipvsadm tree bind-utils gcc git wget curl rpm scp tar unzip bzip2wget createrepo reposync yum-utils ntp pdsh python-devel net-tools nmap telnet openconnect –y

echo -e "\n------------------ Fetching eple-7 Repository------------------"
#wget https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-13.noarch.rpm

echo -e "\n------------------ Installing eple-release------------------"
#rpm -ivh epel-release-7-13.noarch.rpm


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


#-- SSH ---------------------------------------------------------------------------------------------------
echo -e "\n------------------ Configuring SSH (No Password) ------------------"
echo -ne '\n' | ssh-keygen -t rsa
'\n'
'\n'
# Calling Function
copy_ssh_key


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

# Nodes NTP Syncronocity
sync=0

while [ $sync -lt 1 ]
do
   
    datetime_syncronocity 
    read -p "Do You Want To Check Other Nodes As Well? (y to approve and any character to deny): " other_nodes_sync
    if [[ $other_nodes_sync == "y" || $other_nodes_sync == "Y" || $other_nodes_sync == "yes" || $other_nodes_sync == "YES" ]]; then
	sync=0
    else
	sync=1
    fi
       

done


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

if grep -q "ip1:port1" "/etc/docker/daemon.json"; then
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

echo -e "\nPre-requisites Installation And Configuration On Master Completed.\n"


#-- Cluster Nodes ---------------------------------------------------------------------------------------
echo -e "\n----------------- Configuring Cluster Nodes ------------------\n"
# Variables Declaration
more_nodes=0

while [ $more_nodes -lt 1 ] 
do 
    read -p "Enter The Node IP Address, Please: " node
		    
    if validate_IP $node | grep "True"; then
	ssh root@$node 'bash -s' < /home/rojin/Desktop/Kubernetes_nodes-prerequisites.sh
		    
    else
        echo -e "\nThe IP Addresse Can Not Be Substituted."
	more_nodes=0
		     
    fi

    read -p "Do You Want To Configure More Nodes? (y to approve and any character to deny): " add_node_reply
    if [[ $add_node_reply == "y" || $add_node_reply == "Y" || $add_node_reply == "yes" || $add_node_reply == "YES" ]]; then
	more_nodes=0
    else
	more_nodes=1
    fi
done



