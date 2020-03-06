#!/bin/bash

mongoAdminUser=$1
mongoAdminPasswd=$2
certUri=$3

install_mongo3() {
    #install
	wget https://repo.mongodb.org/yum/redhat/7/mongodb-org/3.6/x86_64/RPMS/mongodb-org-server-3.6.17-1.el7.x86_64.rpm
	wget https://repo.mongodb.org/yum/redhat/7/mongodb-org/3.6/x86_64/RPMS/mongodb-org-shell-3.6.17-1.el7.x86_64.rpm
	rpm -i mongodb-org-server-3.6.17-1.el7.x86_64.rpm
	rpm -i mongodb-org-shell-3.6.17-1.el7.x86_64.rpm
	PATH=$PATH:/usr/bin; export PATH

	#disable selinux
	sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
	sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
	setenforce 0

	#kernel settings
	if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]];then
		echo never > /sys/kernel/mm/transparent_hugepage/enabled
	fi
	if [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]];then
		echo never > /sys/kernel/mm/transparent_hugepage/defrag
	fi

	#configure
	sed -i 's/\(bindIp\)/#\1/' /etc/mongod.conf
	
}

yum install wget -y
echo "Downloading the ssl cert"
wget $certUri -O /etc/MongoAuthCert.pem
install_mongo3


#start mongod
mongod --dbpath /var/lib/mongo/ --bind_ip 0.0.0.0 --logpath /var/log/mongodb/mongod.log --fork

sleep 30
n=`ps -ef |grep "mongod --dbpath /var/lib/mongo/"|grep -v grep | wc -l`
if [[ $n -eq 1 ]];then
    echo "mongod started successfully"
else
    echo "mongod started failed!"
fi

#create users
mongo <<EOF
use admin
db.createUser({user:"$mongoAdminUser",pwd:"$mongoAdminPasswd",roles:[{role: "userAdminAnyDatabase", db: "admin" },{role: "readWriteAnyDatabase", db: "admin" },{role: "root", db: "admin" }]})
exit
EOF
if [[ $? -eq 0 ]];then
    echo "mongo user added succeefully."
else
    echo "mongo user added failed!"
fi

#stop mongod
sleep 15
MongoPid=`ps -ef |grep "mongod --dbpath /var/lib/mongo/"|grep -v grep |awk '{print $2}'`
kill -2 $MongoPid



#set keyfile
echo "vfr4CDE1" > /etc/mongokeyfile
chown mongod:mongod /etc/mongokeyfile
chmod 600 /etc/mongokeyfile
sed -i 's/^#security/security/' /etc/mongod.conf
sed -i '/^security/akeyFile: /etc/mongokeyfile' /etc/mongod.conf
sed -i 's/^keyFile/  keyFile/' /etc/mongod.conf

sleep 15
MongoPid1=`ps -ef |grep "mongod --dbpath /var/lib/mongo/"|grep -v grep |awk '{print $2}'`
if [[ -z $MongoPid1 ]];then
    echo "shutdown mongod successfully"
else
    echo "shutdown mongod failed!"
    kill $MongoPid1
    sleep 15
fi

#restart mongod with auth and config replica set
mongod --configsvr --replSet crepset --bind_ip 0.0.0.0 --port 27019 --dbpath /var/lib/mongo/ --logpath /var/log/mongodb/config.log --fork --config /etc/mongod.conf --keyFile /etc/mongokeyfile --sslMode requireSSL --sslPEMKeyFile /etc/MongoAuthCert.pem --sslPEMKeyPassword Mongo123


#initiate config replica set

for((i=1;i<=3;i++))
do
    sleep 15
    n=`ps -ef |grep "mongod --configsvr"|grep -v grep |wc -l`
    if [[ $n -eq 1 ]];then
        echo "mongo config replica set started successfully"
        break
    else
        mongod --configsvr --replSet crepset --bind_ip 0.0.0.0 --port 27019 --dbpath /var/lib/mongo/ --logpath /var/log/mongodb/config.log --fork --config /etc/mongod.conf --keyFile /etc/mongokeyfile --sslMode requireSSL --sslPEMKeyFile /etc/MongoAuthCert.pem --sslPEMKeyPassword Mongo123
        continue
    fi
done

n=`ps -ef |grep "mongod --configsvr"|grep -v grep |wc -l`
if [[ $n -ne 1 ]];then
    echo "mongo config replica set tried to start 3 times but failed!"
fi


mongo --port 27019 --ssl --sslCAFile /etc/MongoAuthCert.pem --sslAllowInvalidHostnames<<EOF
use admin
db.auth("$mongoAdminUser","$mongoAdminPasswd")
config={_id: "crepset", configsvr: true, members: [{ _id: 0, host: "10.0.0.240:27019" },{ _id: 1, host: "10.0.0.241:27019" },{ _id: 2, host: "10.0.0.242:27019" }]}
rs.initiate(config)
exit
EOF
if [[ $? -eq 0 ]];then
    echo "mongod config replica set initiated succeefully."
else
    echo "mongod config replica set initiated failed!"
fi



#set mongod auto start
cat > /etc/init.d/mongod1 <<EOF
#!/bin/bash
#chkconfig: 35 84 15
#description: mongod auto start
. /etc/init.d/functions

Name=mongod1
start() {
if [[ ! -d /var/run/mongodb ]];then
mkdir /var/run/mongodb
chown -R mongod:mongod /var/run/mongodb
fi
mongod --configsvr --replSet crepset --bind_ip 0.0.0.0 --port 27019 --dbpath /var/lib/mongo/ --logpath /var/log/mongodb/config.log --fork --config /etc/mongod.conf --keyFile /etc/mongokeyfile --sslMode requireSSL --sslPEMKeyFile /etc/MongoAuthCert.pem --sslPEMKeyPassword Mongo123
}
stop() {
pkill mongod
}
restart() {
stop
sleep 15
start
}

case "\$1" in
    start)
	start;;
	stop)
	stop;;
	restart)
	restart;;
	status)
	status \$Name;;
	*)
	echo "Usage: service mongod1 start|stop|restart|status"
esac
EOF
chmod +x /etc/init.d/mongod1
chkconfig mongod1 on
