#!/bin/env sh
exit 0

#VLN桥接实例,批量管理,非守护执行
OPT="stop"; \
for ID in {01..10}; do CNM="vln$ID"
SRVCFG='{"initdelay":3,
"workstart":"./proxylinestart.sh",
"workwatch":15,"workintvl":10,
"firewall":{"tcpportpmt":"1080,1723",
"udpportpmt":"500,1701,4500,3000:9999",
"icmppermit":"yes","grepermit":"yes","esppermit":""},
"proxyline":{"intaif":"","extdif":"",
"etcdnm":"http://etcdser:2379/"}}'; \
docker stop "$CNM"; docker rm "$CNM"; \
[ "$OPT" == "stop" ] && continue; \
docker container run --detach --rm \
--name "$CNM" --hostname "$CNM" \
--network imvn --cap-add NET_ADMIN \
--sysctl "net.ipv4.ip_forward=1" \
--device /dev/ppp --device /dev/net/tun \
--volume /etc/localtime:/etc/localtime:ro \
--dns 192.168.15.192 --dns-search local \
--env "SRVCFG=$SRVCFG" ctnproxy
docker network connect emvn "$CNM"; done

docker container exec -it vln01 bash


for ID in {128..159}; do CNM="vpr$ID"
docker container exec "$CNM" ip link show eth1 | \
awk '$1=="link/ether"{print $2}'
done


#数据库使用mrdb198,参看mariadb测试代码
#proxylog183 推荐无状态,集群管理暂缺时配置为持久容器
SRVCFG='{"initdelay":2,"workstart":"./proxylogstart.sh",
"workwatch":0,"workintvl":5,"firewall":{"icmppermit":"yes"},
"proxylog":{"sqlser":"mrdb198","etcdnm":"http://etcdser:2379"}}'; \
docker stop proxylog183; docker rm proxylog183; \
docker container run --detach --restart always \
--name proxylog183 --hostname proxylog183 \
--network imvn --cap-add NET_ADMIN \
--volume /etc/localtime:/etc/localtime:ro \
--ip 192.168.15.183 --dns 192.168.15.192 --dns-search local \
--env "SRVNAME=proxylog" --env "SRVCFG=$SRVCFG" ctnproxy

docker container exec -it proxylog183 bash


#手动配置数据库授权
GRANT ALL PRIVILEGES ON proxylogdb.* TO 'proxyadmin'@'%' IDENTIFIED BY 'proxypw000';
GRANT ALL PRIVILEGES ON proxylogdb.* TO 'proxyadmin'@'localhost' IDENTIFIED BY 'proxypw000'
FLUSH PRIVILEGES;
