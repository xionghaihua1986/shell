#!/usr/bin/bash
#description: install mongodb 4.0.4 on centos7.5
SOFTDIR=/data/soft
INSTALLDIR=/data/app
VERSION=4.0.4
IP=$(ip addr|grep ens32|awk 'NR==2{print $2}'|cut -d/ -f1)

#加载functions函数
. /etc/init.d/functions 

[ -d $SOFTDIR ] || mkdir -p $SOFTDIR
[ -d $INSTALLDIR ] || mkdir -p $INSTALLDIR

install(){
	#测试网络是否正常
	ping -c2 www.jd.com &>/dev/null
	if [ $? -ne 0 ];then
		echo "网络不正常，请检查...."
	fi
	#安装依赖
        yum install libcurl openssl openssl-devel boost boost-devel -y &>/dev/null
	#下载mongodb4.0.2的二进制文件
	cd $SOFTDIR
	if [ ! -f mongodb-linux-x86_64-${VERSION}.tgz ] ;then
		 wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${VERSION}.tgz 
		 tar -xf mongodb-linux-x86_64-${VERSION}.tgz -C ${INSTALLDIR}/
		 ln -s $INSTALLDIR/mongodb-linux-x86_64-${VERSION} $INSTALLDIR/mongodb	
	fi
	#创建软链接
	ln -s ${INSTALLDIR}/mongodb/bin/mongod /usr/bin/mongod
	ln -s ${INSTALLDIR}/mongodb/bin/mongo /usr/bin/mongo
}

#单实例配置文件如下
DBPATH=${INSTALLDIR}/mongodb/dbdata
#以普通用户mongo启动mongodb数据库
single_config(){
       [ -d $DBPATH ] || mkdir -p $DBPATH
	#创建用户
	if ! id mongo &>/dev/null;then
		groupadd -g 27017 mongo
		useradd -g mongo -u 27017 -M -s /sbin/nologin mongo
	fi
	#编写配置文件
	cat >${INSTALLDIR}/mongodb/mongodb.conf <<-EOF
systemLog:
  destination: file
  logAppend: true
  path: ${INSTALLDIR}/mongodb/mongodb.log
storage:
  dbPath: $DBPATH
  journal:
     enabled: true
  directoryPerDB: true   #指定存储每个数据库文件到单独的数据目录
processManagement:
  fork: true  #以后台运行
  pidFilePath: "${INSTALLDIR}/mongodb/mongod.pid"
net:
  bindIp: $IP
  port: 27017
EOF
	#配置启动脚本
	cat >/usr/lib/systemd/system/mongod.service <<-EOF
[Unit]
Description=mongodb
After=network.target remote-fs.target nss-lookup.target
[Service]
Type=forking
ExecStart=${INSTALLDIR}/mongodb/bin/mongod --config ${INSTALLDIR}/mongodb/mongodb.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=${INSTALLDIR}/mongodb/bin/mongod --shutdown --config ${INSTALLDIR}/mongodb/mongodb.conf
PrivateTmp=true
User=mongo
Group=mongo
RuntimeDirectory=mongo

[Install]
WantedBy=multi-user.target
EOF
	#授权mongo
	chown -R mongo.mongo ${INSTALLDIR}/mongodb/
	#优化启动选项
	echo '* - nproc 65536' >> /etc/security/limits.conf
	echo '* soft  nproc 65536' >> /etc/security/limits.d/20-nproc.conf
	echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
	echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
	#将以上优化命令添加到rc.local
	echo "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.locl
	echo "echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag" >> /etc/rc.locl
	chmod +x /etc/rc.local
	
	#启动mongodb服务
	chmod +x /usr/lib/systemd/system/mongod.service
	systemctl daemon-reload
	systemctl start mongod.service
}

#主函数
main(){
	install
	single_config
}
main
