#!/usr/bin/bash
SOFTDIR=/data/soft
INSTALLDIR=/data/app
PORT=6379
SOFTVERSION=redis-4.0.11
PIDFILE=/data/redis/redis-${PORT}.pid
LOGFILE=/data/redis/redis-${PORT}.log
IP=$(ip addr|grep ens32|awk 'NR==2{print $2}'|cut -d/ -f1)
AUTHPASS='123321'

install(){
	#判断目录是否存在
	[ -d $SOFTDIR ] || mkdir -p $SOFTDIR
	[ -d $INSTALLDIR ] || mkdir -p $INSTALLDIR
	#判断软件是否存在
	cd $SOFTDIR
	[ -f ${SOFTDIR}/${SOFTVERSION}.tar.gz ] || wget http://download.redis.io/releases/${SOFTVERSION}.tar.gz	
	#解压到INSTALL目录
	cd $SOFTDIR && tar xf ${SOFTVERSION}.tar.gz -C $INSTALLDIR
	ln -sv ${INSTALLDIR}/$SOFTVERSION ${INSTALLDIR}/redis
	#安装redis
	cd ${INSTALLDIR}/redis && make MALLOC=libc
	#判断是否安装成功，如果安装不成功就退出
	if [ $? -ne 0 ];then
		echo "安装redis失败"
		exit 1
	fi
}

config(){
	#初始配置Redis.conf，先备份redis.conf
	[ -f ${INSTALLDIR}/redis/redis.conf.bak ] || cp ${INSTALLDIR}/redis/redis.conf{,.bak}
	sed -i "s#\(bind\).*#\1 192.168.10.182#" ${INSTALLDIR}/redis/redis.conf
	sed -i "s#\(daemonize\).*#\1 yes#" ${INSTALLDIR}/redis/redis.conf
	sed -i "s#\(pidfile\).*#\1 ${INSTALLDIR}/redis/redis-6379.pid#" ${INSTALLDIR}/redis/redis.conf
	sed -i "s#\(logfile\).*#\1 ${INSTALLDIR}/redis/redis-6379.log#" ${INSTALLDIR}/redis/redis.conf
	sed -i "s#^\(appendonly\).*#\1 yes#" ${INSTALLDIR}/redis/redis.conf
	sed -i "s#\(dir\).*#\1 ${INSTALLDIR}/redis#" ${INSTALLDIR}/redis/redis.conf
	#sed -i "/^#[[:blank:]]*require.*/a requirepass ${AUTHPASS}" ${INSTALLDIR}/redis/redis.conf
	#编写redis的启动脚本
	cp ${INSTALLDIR}/redis/utils/redis_init_script /etc/init.d/redis
	chmod +x /etc/init.d/redis
	#根据实际情况修改redis脚本
	sed -i "s#^\(EXEC=\).*#\1${INSTALLDIR}/redis/src/redis-server#" /etc/init.d/redis
	sed -i "s#^\(CLIEXEC=\).*#\1${INSTALLDIR}/redis/src/redis-cli#" /etc/init.d/redis
	sed -i "s#^\(PIDFILE=\).*#\1${INSTALLDIR}/redis/redis-6379.pid#" /etc/init.d/redis
	sed -i "s#^\(CONF=\).*#\1${INSTALLDIR}/redis/redis.conf#" /etc/init.d/redis
	sed -i "13a IP=$IP" /etc/init.d/redis
	#sed -i "12a AUTHPASS=$AUTHPASS" /etc/init.d/redis
	sed -i 's@^[[:space:]]*$CLIEXEC@#&@' /etc/init.d/redis
	sed -i '/^#[[:space:]]*$CLIEXEC/a \$CLIEXEC -h \$IP  -p \$REDISPORT shutdown' /etc/init.d/redis
	#创建一个软链接
	ln -s ${INSTALLDIR}/redis/src/redis-cli /usr/bin/redis-cli
	#启动redis服务
	systemctl daemon-reload
	/etc/init.d/redis start
}

#redis安装配置主函数
main(){
	install
	config
}

#执行主函数
	main

