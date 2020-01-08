#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

ETCDU="./Etcd.Url"

#历史实例终止
iptables -t filter -D SRVLCH -p tcp -m tcp --dport 1080 -m conntrack --ctstate NEW -j ACCEPT
iptables -t filter -D SRVLCH -p udp -m conntrack --ctstate NEW -j ACCEPT
iptables -t filter -D SRVLCH -p tcp -m tcp --dport 8081 -m conntrack --ctstate NEW -j ACCEPT
for I in {1..10}; do pkill "sk3proxy" || break; [ "$I" == 10 ] && exit 1; sleep 0.5; done
[ "$1" == "stop" ] && exit 0

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"
echo "$SRVCFG" | jq -r ".3proxy|.etcdnm,.lncgrp|strings" > "$ETCDU"

#初始化状态数据库
#./stdb.create.sh

#配置服务端口通行
iptables -t filter -A SRVLCH -p tcp -m tcp --dport 1080 -m conntrack --ctstate NEW -j ACCEPT
iptables -t filter -A SRVLCH -p udp -m conntrack --ctstate NEW -j ACCEPT
iptables -t filter -A SRVLCH -p tcp -m tcp --dport 8081 -m conntrack --ctstate NEW -j ACCEPT

#启动服务
exec -a "sk3proxy" 3proxy ./3proxy.conf

eixt 126
