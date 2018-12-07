#!/usr/bin/bash
#管理主机与远程主机秘钥认证
#先判断用户是否存在
SecretPath="/home/admin/.ssh"
Passwd="123456"
if ! id admin &>/dev/null;then
    sudo groupadd admin
    sudo useradd -g admin admin
    echo "$Passwd"|passwd --stdin admin
fi

[ -d ${SecretPath} ] || mkdir  -p $SecretPath

#判断expect是否安装
sudo rpm -q expect &>/dev/null || sudo yum -y install expect

#在管理机上生成秘钥

ssh-keygen -t rsa -f /home/admin/.ssh/id_rsa -P ""

#循环推送秘钥到客户端
while read ip;do
   expect <<-EOF
	set timeout 5
        spawn ssh-copy-id -i /home/admin/.ssh/id_rsa.pub  admin@$ip
        expect {
	"yes/no" { send "yes\n";exp_continue}
        "password" { send "$Passwd\n" }
    }
expect eof
EOF
done < /home/admin/iplist.txt
