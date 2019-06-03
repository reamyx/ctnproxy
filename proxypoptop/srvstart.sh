#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

VPNUD="./vpnupdown.sh"
AUTHP="./accountck.sh"
ETCDU="./Etcd.Url"

#历史实例终止
for I in {1..10}; do pkill "^pptpd$" || break; [ "$I" == 10 ] && exit 1; sleep 0.5; done
[ "$1" == "stop" ] && exit 0

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"
echo "$SRVCFG" | jq -r ".proxypoptop|.etcdnm,.lncgrp|strings" > "$ETCDU"

#初始化状态数据库
./stdb.create.sh

#配置和启动PPTPD服务
echo "\
lock
name PPTP
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
mtu 1450
mru 1450
ms-dns 223.5.5.5
ms-dns 114.114.114.114
ip-up-script   $PWD/$VPNUD
ip-down-script $PWD/$VPNUD
plugin expandpwd.so
pwdprovider $PWD/$AUTHP
" > ./options.pptpd

echo "\
#地址池: 10.97.128.0/23
remoteip 10.97.128.0-255,10.97.129.0-255
localip 10.97.255.255
connections 512
option $PWD/options.pptpd
" > ./pptpd.conf

exec pptpd -c "./pptpd.conf"

exit 0
