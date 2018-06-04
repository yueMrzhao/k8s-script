#! /bin/bash

# 红帽包管理工具（RPM）¶  安装 Ceph
sudo yum install -y yum-utils && sudo yum-config-manager --add-repo https://dl.fedoraproject.org/pub/epel/7/x86_64/ && sudo yum install --nogpgcheck -y epel-release && sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 && sudo rm /etc/yum.repos.d/dl.fedoraproject.org*

sudo yum update && sudo yum install ceph-deploy  ntp ntpdate ntp-doc -y


# 优先级/首选项 确保你的包管理器安装了优先级/首选项包且已启用。在 CentOS 上你也许得安装 EPEL ，在 RHEL 上你也许得启用可选软件库。

sudo yum install yum-plugin-priorities -y 
# 比如在 RHEL 7 服务器上，可用下列命令安装 yum-plugin-priorities并启用 rhel-7-server-optional-rpms 软件库：

sudo yum install yum-plugin-priorities --enablerepo=rhel-7-server-optional-rpms






[ceph]
name=ceph
baseurl=http://mirrors.163.com/ceph/rpm-luminous/el7/x86_64/
gpgcheck=0
[ceph-noarch]
name=cephnoarch
baseurl=http://mirrors.163.com/ceph/rpm-luminous/el7/noarch/
gpgcheck=0


echo "关闭防火墙"
systemctl disable firewalld.service
systemctl stop firewalld.service

echo "关闭Selinux"
setenforce  0
echo 'sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux
sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/sysconfig/selinux
sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config'| sh
getenforce


#优先级/首选项
#确保你的包管理器安装了优先级/首选项包且已启用。在 CentOS 上你也许得安装 EPEL ，在 RHEL 上你也许得启用可选软件库。

sudo yum install yum-plugin-priorities
#如在 RHEL 7 服务器上，可用下列命令安装 yum-plugin-priorities并启用 rhel-7-server-optional-rpms 软件库：

sudo yum install yum-plugin-priorities --enablerepo=rhel-7-server-optional-rpms

# 关闭ipv6
cat <<EOF >/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl -p

# admin node
su - cephnode
ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa -q
ssh-copy-id ...


# 注意在控制服务器上加,先测试下不要加错,不然错误多多......
# all node 国内加速
cat >> ~/.bashrc <<EOF
export CEPH_DEPLOY_REPO_URL=http://mirrors.163.com/ceph/rpm-jewel/el7
export CEPH_DEPLOY_GPG_URL=http://mirrors.163.com/ceph/keys/release.asc
EOF
#或者香港
cat >> ~/.bashrc <<EOF
export CEPH_DEPLOY_REPO_URL=http://hk.ceph.com/rpm-jewel/el7
export CEPH_DEPLOY_GPG_URL=http://hk.ceph.com/keys/release.asc
EOF

# add dns
cat >> /etc/resolv.conf<<EOF
nameserver 202.96.128.166
nameserver 202.96.128.66
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 4.4.4.4
EOF

# add cephnode user /*当然,我是用 root 来搞的*/
useradd cephnode 
echo '123' | passwd --stdin cephnode
echo "cephnode ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephnode
chmod 0440 /etc/sudoers.d/cephnode 

# install ntp server sync
yum install ntp ntpdate ntp-doc -y
crontab -e
*/1 * * * * /usr/sbin/ntpdate time7.aliyun.com >/dev/null 2>&1


# node1 install ceph-deploy
yum -y install ceph-deploy


# STARTING OVER
# if at any point you run into trouble and you want to start over, execute the following to purge the Ceph packages, and erase all its data and configuration:
ceph-deploy purge {ceph-node} [{ceph-node}]
ceph-deploy purgedata {ceph-node} [{ceph-node}]
ceph-deploy forgetkeys
rm ceph.*

# 清除 PurgeData 之后,发生admin_socket: exception getting command descriptions: [Errno 2] No such file or directory
rm -rf /etc/ceph/*
rm -rf /var/lib/ceph/*/*
rm -rf /var/log/ceph/*
rm -rf /var/run/ceph/*

前提:
将 /u06目录授权
chown -R 777 /u06
chown -R ceph:ceph /u06
----
ceph-deploy new master1 master2 --public-network=192.168.4.0/24 --cluster-network=172.16.171.0/24

ceph-deploy install master1 master2

ceph-deploy mon create-initial

ceph-deploy osd prepare master1:/u06 master2:/u06

ceph-deploy osd activate master1:/u06 master2:/u06

#---------------------------------------------------------------------------

# As a first exercise, create a Ceph Storage Cluster with one Ceph Monitor and three Ceph OSD Daemons. Once the cluster reaches a active + clean state, expand it by adding a fourth Ceph OSD Daemon, a Metadata Server and two more Ceph Monitors. For best results, create a directory on your admin node for maintaining the configuration files and keys that ceph-deploy generates for your cluster.
# 作为第一个练习，使用一个Ceph Monitor和三个Ceph OSD守护进程创建一个Ceph存储集群。 一旦集群达到 active+clean 状态，
# 通过添加第四个Ceph OSD守护程序，元数据服务器和两个Ceph监视器来扩展集群。 
# 为获得最佳结果，请在管理节点上创建一个目录，以维护ceph-deploy为集群生成的配置文件和密钥。

# node1 作为管理节点
mkdir my-cluster
cd my-cluster

# all node 每个磁盘60G
lsblk
parted  -s  /dev/sdb  mklabel gpt
parted /dev/sdb mkpart primary ext4 0 60G
#....
ssh k0 -n "mkdir /var/local/osd0 && chown -R 777 /var/local/osd0 && exit"
ssh k2 -n "mkdir /var/local/osd0 && chown -R 777 /var/local/osd0 && exit"
ssh k4 -n "mkdir /var/local/osd0 && chown -R 777 /var/local/osd0 && exit"
ssh k5 -n "mkdir /var/local/osd0 && chown -R 777 /var/local/osd0 && exit"

# new nodes mon
ceph-deploy new master2

echo "osd pool default size = 3" | tee -a ceph.conf
echo "rbd_default_features = 1 " >> ceph.conf     
echo "public_network = 192.168.4.0/24" >> ceph.conf   
echo "mon_pg_warn_max_per_osd = 1000" >> ceph.conf

#ceph-deploy new --cluster-network 172.16.171.0/24 --public-network 192.168.4.0/24
ceph-deploy install master2
# 或者每个节点
yum -y install ceph ceph-radosgw

ceph-deploy mon create-initial

# jewel 下可以用
ceph-deploy osd prepare ceph1:/dev/sdb1 ceph2:/dev/sdb1 ceph3:/dev/sdb1
ceph-deploy osd activate ceph1:/dev/sdb1 ceph2:/dev/sdb1 ceph3:/dev/sdb1


# add mon
ceph-deploy mon add ceph1 ceph2 ceph3 


# Luminous 
ceph-deploy  --version
# 2.0.0
ceph-deploy osd create --data /dev/sdb1 ceph1
ceph-deploy osd create --data /dev/sdb1 ceph2
ceph-deploy osd create --data /dev/sdb1 ceph3



ceph-deploy admin ceph1 ceph2 ceph3

chmod +r /etc/ceph/ceph.client.admin.keyring

ceph health


# -------------
1、新建一个ceph pool，（两个数字为 {pg-num} [{pgp-num}）
ceph osd pool create rbdpool 100 100

2、在pool中新建一个镜像
rbd create rbdpoolimages --size 80960 -p rbdpool
或者 
rbd create rbdpool/rbdpoolimages --size 102400
在内核为3.10的不能实现绝大部分features，使用此命令 在后边加上 --image-format 2 --image-feature  layering



3、查看相关pool以及image信息
查看池中信息
rbd ls rbdpool
查询一个池内的镜像信息
rbd --image rbdpoolimages -p rbdpool info

# 需要改 rbdimages 的权限
rbd feature disable rbdpool/rbdpoolimages exclusive-lock, object-map, fast-diff, deep-flatten


4、把镜像映射到pool块设备中，在安装了ceph以及执行过ceph-deploy admin node 命令的客户端上以root身份执行执行
rbd map rbdpoolimages -p rbdpool
# output
# /dev/rbd0

5、格式化映射的设备块

mkfs.ext4 /dev/rbd0

6、取消映射块设备、查看镜像映射map
取消映射块设备
rbd unmap /dev/rbd1
查看镜像映射map
rbd showmapped

7、扩容image
rbd resize -p rbdpool --size 150G rbdpoolimages


# other检查集群
ceph quorum_status --format json-pretty

# 密钥
grep key /etc/ceph/ceph.client.admin.keyring |awk '{printf "%s", $NF}'|base64
#example
#QVFCL1l1cGFpaExPTkJBQWxpc0dYT1podmV2U2U2T2tuSjRqb0E9PQ

# k8s 应用
# 在文件/home/ceph-secret.yaml 添加以下内容
apiVersion: v1
kind: Secret
metadata:
	name: ceph-secret
type: "kubernetes.io/rbd" 
data:
- key: QVFCZC8rdGFFNm1vQkJBQUtJeHFxOFBxaHcrdjlTRml0Y1RNRHc9PQ==


# 给 K8s 的网卡kubem1 eth1 加个地址
ifconfig eth1:0 192.168.5.240 netmask 255.255.255.0 up


# luminous dashboard ip:7000
ceph mgr module enable dashboard


# command
命令	功能
rbd create 	 创建块设备映像 
rbd ls 	 列出 rbd 存储池中的块设备 
rbd info 	 查看块设备信息 
rbd diff 	 可以统计 rbd 使用量 
rbd feature disable 	 禁止掉块设备的某些特性 
rbd map 	 映射块设备 
rbd remove 	 删除块设备 
rbd resize 	 更改块设备的大小


# IO 测试
rbd bench-write --io-threads 4 rbdpool/rbdpoolimages
# 清除掉刚刚上面测试的数据
rados ls  -p rbdpool | grep rbd_data |xargs rados rm -p rbdpool

# 查看集群统计信息
rados df
# 集群的 Pool
rados lspools 
# 集群信息
ceph osd tree

# 获取key base64 
ceph auth get-key client.admin | base64

apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret-rbd
type: "kubernetes.io/rbd"
data:
  key: QVFCTTJRdGJobVRoRUJBQW55UmZFeWROZ2NvWDVULzFwbE5yaEE9PQ==
---
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret
  namespace: kube-system
type: "kubernetes.io/rbd"
data:
  # ceph auth add client.kube mon 'allow r' osd 'allow rwx pool=kube'
  # ceph auth get-key client.kube | base64
  key: QVFDNDNRdGJEcHlvSFJBQUVxTVhBelkra3lkRGZVNEhiaG96R3c9PQ==






