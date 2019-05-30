#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

VPNUD="./vpnupdown.sh"
AUTHP="./accountck.sh"
ETCDU="./Etcd.Url"

#历史实例终止
for I in {1..10}; do pkill "^xl2tpd$" || break; [ "$I" == 10 ] && exit 1; sleep 0.5; done
[ "$1" == "stop" ] && exit 0

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"
echo "$SRVCFG" | jq -r ".proxyxl2tpd|.etcdnm,.lncgrp|strings" > "$ETCDU"

#初始化状态数据库
./stdb.create.sh

#配置和启动xl2tpd服务
echo "\
lock
name L2TP
nolog
idle 0
lcp-echo-failure 5
lcp-echo-interval 4
auth
refuse-eap
refuse-pap
require-chap
require-mschap
require-mschap-v2
chap-interval 300
require-mppe-128
nomppe-stateful
noccp
noipv6
noipx
mtu 1420
mru 1420
ms-dns 223.5.5.5
ms-dns 114.114.114.114
ip-up-script   $PWD/$VPNUD
ip-down-script $PWD/$VPNUD
plugin expandpwd.so
pwdprovider $PWD/$AUTHP
" > ./options.xl2tpd

echo "\
[global]
    ipsec saref = yes
[lns default]
;   地址池: 10.97.130.0/23
    ip range = 10.97.130.0-255
    ip range = 10.97.131.0-255
    local ip = 10.97.255.255
    pass peer = yes
    pppoptfile = $PWD/options.xl2tpd
    length bit = yes
" > ./xl2tpd.conf
exec xl2tpd -c "./xl2tpd.conf"

exit 126
