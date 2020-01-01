#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

VPNUD="./ovupdown.sh"
AUTHP="./ovpwdck.sh"
ETCDU="./Etcd.Url"
SRVPORT="1198"

#历史实例终止
iptables -t filter -D SRVLCH -p tcp -m tcp --dport "$SRVPORT" \
-m conntrack --ctstate NEW -j ACCEPT
for I in {1..10}; do pkill "^openvpn$" || break; [ "$I" == 10 ] && exit 1; sleep 0.5; done
[ "$1" == "stop" ] && exit 0

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"
echo "$SRVCFG" | jq -r ".openvpn|.etcdnm,.lncgrp|strings" > "$ETCDU"

#初始化状态数据库
#./stdb.create.sh

#配置服务端口通行
iptables -t filter -A SRVLCH -p tcp -m tcp --dport "$SRVPORT" \
-m conntrack --ctstate NEW -j ACCEPT

#配置和启动openvpn服务
echo "\
#lport 1198
dev tunov01
proto tcp-server

topology subnet
server 10.97.130.0 255.255.255.0

#daemon
user nobody
group nobody
persist-key
persist-tun

cipher AES-128-CBC
comp-lzo yes
auth SHA1

verb 0
script-security 3
status-version 2
status ovstatus.ser 10

float
keepalive 5 22
max-clients 96
duplicate-cn
client-config-dir ccd
verify-client-cert none
username-as-common-name
auth-user-pass-verify ovckpwd.sh via-env
#ccd-exclusive
script-security 3

push \"cipher AES-128-CBC\"
push \"comp-lzo yes\"
push \"dhcp-option DNS 114.114.114.114\"
push \"redirect-gateway def1\"

tls-server
" > ./ovser.conf
cat "ovsercert.txt" >> ./ovser.conf

exec openvpn --cd "./" --lport "$SRVPORT" --config "ovser.conf"

exit 0

###########################
