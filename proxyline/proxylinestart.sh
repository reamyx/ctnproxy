#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#功能: 配置转发规则,网络拨号,为代理和远程接入服务保障运行时环境

LN="$HOSTNAME"
LNPRNM="proxyline-$HOSTNAME-pppd"
IPCPSC="./lineupdown.sh"

#停止附加服务,终止历史实例
PPTPEN="./Srv.pptp.Enabled"
L2TPEN="./Srv.l2tp.Enabled"
SK5PEN="./Srv.sock.Enabled"
[ -f "$PPTPEN" ] && { rm -f "$PPTPEN"; ../proxypoptop/srvstart.sh "stop" & }
[ -f "$L2TPEN" ] && { rm -f "$L2TPEN"; ../proxyxl2tpd/srvstart.sh "stop" & }
[ -f "$SK5PEN" ] && { rm -f "$SK5PEN"; ../proxydante3/srvstart.sh "stop" & }
for ID in {1..20}; do pkill -f "$LNPRNM" || break; sleep 0.5; done
[ "$1" == "stop" ] && exit 0

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"
SRVCFG="$( echo "$SRVCFG" | jq -cM ".proxyline|objects" )"
INTACIF="$( echo "$SRVCFG" | jq -r ".intacif|strings" )"
EXTDLIF="$( echo "$SRVCFG" | jq -r ".extdlif|strings" )"
ETCDNM="$( echo "$SRVCFG" | jq -r ".etcdnm|strings" )"

#线路工作模式将优先使用远程配置数据(远程提供的基础环境配置数据将会被忽略)
ETCDU="./Etcd.Url"; echo "$ETCDNM" > "$ETCDU"
RMTCFG="" LNDPSWD="" LNDNAME=""
[ -n "$ETCDNM" ] && for PT in "$LN" "DefaultConfig"; do
    RMTCFG="$( etcdctl --endpoints "$ETCDNM" get "/proxylncfg/$PT" )"
    RMTCFG="$( echo "$RMTCFG" | jq -cM "." )"; [ -n "$RMTCFG" ] && break ; done

#缓存配置信息到指定文件,提取配置数据
SRVCFG="${RMTCFG:-$SRVCFG}"; echo "$SRVCFG" >> "$ETCDU"
LNDNAME="$( echo "$SRVCFG" | jq -r ".lndname|strings" )"
LNDPSWD="$( echo "$SRVCFG" | jq -r ".lndpswd|strings" )"

INTACIF="${INTACIF:-eth0}"
EXTDLIF="${EXTDLIF:-eth1}"
DLPPPIF="inet0"
INTADDR="$( ip -o addr show "$INTACIF" | awk '$3=="inet"{print $4}' )"
CLTADDR="10.97.128.0/22"

#转发放行
FWRL=( -s "$CLTADDR" -o "$DLPPPIF" -j ACCEPT )
iptables -t filter -D SRVFWD "${FWRL[@]}"; iptables -t filter -A SRVFWD "${FWRL[@]}"
FWRL=( -s "$INTADDR" -o "$DLPPPIF" -j ACCEPT )
iptables -t filter -D SRVFWD "${FWRL[@]}"; iptables -t filter -A SRVFWD "${FWRL[@]}"
#FWRL=( -s "$CLTADDR" -o "INTACIF" -j ACCEPT )
#iptables -t filter -D SRVFWD "${FWRL[@]}"; iptables -t filter -A SRVFWD "${FWRL[@]}"

#出口代理
FWRL=( -s "$CLTADDR" -o "$DLPPPIF" -m conntrack --ctstate NEW -j MASQUERADE )
iptables -t nat -D SRVSNAT "${FWRL[@]}"; iptables -t nat -A SRVSNAT "${FWRL[@]}"
FWRL=( -s "$INTADDR" -o "$DLPPPIF" -m conntrack --ctstate NEW -j MASQUERADE )
iptables -t nat -D SRVSNAT "${FWRL[@]}"; iptables -t nat -A SRVSNAT "${FWRL[@]}"
#FWRL=( -s "$CLTADDR" -o "$INTACIF" -m conntrack --ctstate NEW -j MASQUERADE )
#iptables -t nat -D SRVSNAT "${FWRL[@]}"; iptables -t nat -A SRVSNAT "${FWRL[@]}"

#TCP.MSS
FWRL=( -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu )
iptables -t mangle -D SRVMFW "${FWRL[@]}"; iptables -t mangle -A SRVMFW "${FWRL[@]}"

#生成线路拨号实例ID
read -t 1 INST < "/proc/sys/kernel/random/uuid" || INST="$(uuidgen)"
INST="$( echo "$INST" | tr "[a-z-]" "[A-Z\0]" )"; INST="${INST:15:16}"

#启动线路拨号,代理服务将由维护任务进行启动和保障运行
exec -a "$LNPRNM" pppd ifname "$DLPPPIF" \
lock nodetach maxfail 2 lcp-echo-failure 3 lcp-echo-interval 5 \
noauth refuse-eap nomppe user "$LNDNAME" password "$LNDPSWD" mtu 1492 mru 1492 \
ip-up-script "$PWD/$IPCPSC" ip-down-script "$PWD/$IPCPSC" usepeerdns \
nolog ipparam "$INST ${INTADDR%%/*} ${LNDNAME:-}" plugin "rp-pppoe.so" "$EXTDLIF"

exit 126
