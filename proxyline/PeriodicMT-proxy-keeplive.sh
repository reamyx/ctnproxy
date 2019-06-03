#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

STFL="./Line.Stat"
LN="$HOSTNAME"
LOGDT=""
export SRVCFG=""

PPTPST=""
L2TPST=""
SK5PST=""

PPTPEN="./Srv.pptp.Enabled"
L2TPEN="./Srv.l2tp.Enabled"
SK5PEN="./Srv.sock.Enabled"

#确定线路参数(由IPCP脚本维护),参数缺失放弃状态更新
# $LNST $INST $LCAD $DLNM $PPPD_PID $IFNAME $IPLOCAL $IPREMOTE $MACREMOTE
# $UPTIME $CONNECT_TIME $BYTES_SENT $BYTES_RCVD
PM=( $1 ) IPCP="Y"
[ -z "${PM[0]}" ] && read -t 1 PM[0] < "$STFL" && PM=( ${PM[0]} ) && IPCP=""
[[ "${PM[0]}" == "Active" || "${PM[0]}" == "Inactive" ]] || exit 1

#读取缓存的线路配置(由启动程序从远程提取)
ETCDU="./Etcd.Url" ETCDNM="" SRVCFG=""
{ read -t 1 ETCDNM; read -t 1 SRVCFG; } < "$ETCDU"
PPTPUP="$( echo "$SRVCFG" | jq -r ".pptpup|strings" )"
L2TPUP="$( echo "$SRVCFG" | jq -r ".l2tpup|strings" )"
SK5PUP="$( echo "$SRVCFG" | jq -r ".sk5pup|strings" )"
SKPORT="$( echo "$SRVCFG" | jq -r ".skport|numbers" )"
GRP="$( echo "$SRVCFG" | jq -r ".lncgrp|strings" )"
RNM="$( echo "$SRVCFG" | jq -r ".regname|strings" )"

GRP="${GRP:-Default}" RNM="${RNM:-$GRP}"

#线路UP: 测试和构造代理服务状态数据
[[ "${PM[0]}" == "Active" && "${#PM[@]}" == 10 ]] && {
    #DDNS注册
    URL="http://ddns.local:1253/namemapv2"; TAGT="${PM[6]}"
    curl --connect-timeout 3 -X "POST" -d "SIMPLEPM;$LN;V4HOST;$TAGT;20" "$URL" &
    curl --connect-timeout 3 -X "POST" -d "SIMPLEPM;$RNM;V4CLUT;$TAGT" "$URL" &
    #poptop状态测试和重启
    [[ "$PPTPUP" =~ ^"YES"|"yes"$ ]] && {
        > "$PPTPEN"
        ../proxypoptop/PeriodicST-srvstck.sh && {
            ../proxypoptop/PeriodicMT-stlogpush.sh & } || {
            SRVCFG="{\"proxypoptop\":{\"etcdnm\":\"$ETCDNM\",\"lncgrp\":\"$GRP\"}}"
            setsid ../proxypoptop/srvstart.sh; PPTPST="DOWN"; }; }
    #xl2tpd状态测试和重启
    [[ "$L2TPUP" =~ ^"YES"|"yes"$ ]] && {
        > "$L2TPEN"
        ../proxyxl2tpd/PeriodicST-srvstck.sh && {
            ../proxyxl2tpd/PeriodicMT-stlogpush.sh & } || {
            SRVCFG="{\"proxyxl2tpd\":{\"etcdnm\":\"$ETCDNM\",\"lncgrp\":\"$GRP\"}}"
            setsid ../proxyxl2tpd/srvstart.sh; L2TPST="DOWN"; }; }
    #dante状态测试和重启
    [[ "$SK5PUP" =~ ^"YES"|"yes"$ ]] && {
        > "$SK5PEN"
        ../proxydante3/PeriodicST-srvstck.sh && {
            ../proxydante3/PeriodicMT-stlogpush.sh & } || {
            SRVCFG="{\"proxydante3\":{\"etcdnm\":\"$ETCDNM\",
            \"lncgrp\":\"$GRP\" ${SKPORT:+,\"skport\": $SKPORT} }}"
            setsid ../proxydante3/srvstart.sh; SK5PST="DOWN"; }; }
    #对重启动服务进行二次状态测试
    [ -n "$PPTPST$L2TPST$SK5PST" ] && { sleep 2
        [ -n "$PPTPST" ] && ../proxypoptop/PeriodicST-srvstck.sh && PPTPST=""
        [ -n "$L2TPST" ] && ../proxyxl2tpd/PeriodicST-srvstck.sh && L2TPST=""
        [ -n "$SK5PST" ] && ../proxydante3/PeriodicST-srvstck.sh && SK5PST=""; }
    #服务状态收集,或未启用服务时进行清理操作
    LOGDT=" "
    [[ "$PPTPUP" =~ ^"YES"|"yes"$ ]] && LOGDT="$LOGDT, \"pptpst\": \"${PPTPST:-UP}\"" \
    || { [ -f "$PPTPEN" ] && { rm -f "$PPTPEN"; ../proxypoptop/srvstart.sh "stop" & }; }
    [[ "$L2TPUP" =~ ^"YES"|"yes"$ ]] && LOGDT="$LOGDT, \"l2tpst\": \"${L2TPST:-UP}\"" \
    || { [ -f "$L2TPEN" ] && { rm -f "$L2TPEN"; ../proxyxl2tpd/srvstart.sh "stop" & }; }
    [[ "$SK5PUP" =~ ^"YES"|"yes"$ ]] && LOGDT="$LOGDT, \"sk5pst\": \"${SK5PST:-UP}\"" \
    || { [ -f "$SK5PEN" ] && { rm -f "$SK5PEN"; ../proxydante3/srvstart.sh "stop" & }; }; }

#线路DOWN: 收集统计数据,关闭代理服务 
[[ "${PM[0]}" == "Inactive" && "${#PM[@]}" == 13 ]] && {
    echo "[LINE.DOWN] ${PM[@]} [TO.BE.END]" > "$STFL"
    LOGDT=", \"cntime\": ${PM[10]}, \"upflow\": ${PM[11]}, \"dwflow\": ${PM[12]}"
    [ -f "$PPTPEN" ] && { rm -f "$PPTPEN"; ../proxypoptop/srvstart.sh "stop" & }
    [ -f "$L2TPEN" ] && { rm -f "$L2TPEN"; ../proxyxl2tpd/srvstart.sh "stop" & }
    [ -f "$SK5PEN" ] && { rm -f "$SK5PEN"; ../proxydante3/srvstart.sh "stop" & }; }

[[ -n "$LOGDT" && -n "$ETCDNM" ]] && {
    #构造日志数据
    LOGDT="{ \"lnstat\": \"${PM[0]}\",  \"instid\": \"${PM[1]}\",
             \"lncgrp\": \"$GRP\",      \"lcaddr\": \"${PM[2]}\",
             \"lnaddr\": \"${PM[6]}\",  \"gwaddr\": \"${PM[7]}\",
             \"lacmac\": \"${PM[8]}\",  \"lndlnm\": \"${PM[3]}\",
             \"uptime\": \"${PM[9]}\",  \"linenm\": \"$LN\" $LOGDT }"
    LOGDT="$( echo "$LOGDT" | jq -M "." )"
    STKEY="$GRP-$LN-${PM[6]}"
    #线路状态更新,注册出口网关
    [ "${PM[0]}" == "Active"  ] && { [ -z "$IPCP" ] && \
        etcdctl --endpoints "$ETCDNM" update --ttl "20" "/proxylnst/$STKEY" "$LOGDT" || \
        etcdctl --endpoints "$ETCDNM" set --ttl "20" "/proxylnst/$STKEY" "$LOGDT"; }
    #缓存日志更新,(为remove事件更新状态数据),注销出口网关
    [ "${PM[0]}" == "Inactive" ] && {
        etcdctl --endpoints "$ETCDNM" set -ttl "1209600" "/proxylnlog/$LN-${PM[1]}" "$LOGDT"
        etcdctl --endpoints "$ETCDNM" set -ttl "1" "/proxylnst/$STKEY" "$LOGDT"; }; }
    
#0状态码返回
exit 0
