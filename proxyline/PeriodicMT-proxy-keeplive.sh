#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#确定线路状态(由IPCP脚本维护),参数缺失放弃状态更新
# $LNST $INST $LCAD $DLNM $PPPD_PID $IFNAME $IPLOCAL $IPREMOTE $MACREMOTE
# $UPTIME $CONNECT_TIME $BYTES_SENT $BYTES_RCVD
STFL="./Line.Stat" PM=( $1 ) IPCP="Y"
[ -z "${PM[0]}" ] && read -t 1 PM[0] < "$STFL" && PM=( ${PM[0]} ) && IPCP=""
[[ "${PM[0]}" =~ ^"Active"|"Inactive"|"Clean"$ ]] || exit 1

LN="$HOSTNAME"
LOGDT=""
export SRVCFG=""

#服务组状态,路径,启用指示
SRVNM=( "poptop" "xl2tpd" "openvpn" "3proxy" )
SRVEN=() SRVUP=() SRVST=()
for ID in {0..3}; do SRVEN[$ID]="./Srv.${SRVNM[$ID]}.Enabled"; done

#清理过程完成后直接结束运行
[[ "${PM[0]}" == "Clean" && "${PM[1]}" == "FromLineStart" ]] && {
    for ID in {0..3}; do [ -f "$SRVEN[$ID]" ] || continue
    rm -f "$SRVEN[$ID]"; ../${SRVNM[$ID]}/srvstart.sh "stop"; done; exit 0; }

#读取缓存的线路配置(由启动程序从远程提取)
ETCDU="./Etcd.Url" ETCDNM="" SRVCFG=""
{ read -t 1 ETCDNM; read -t 1 SRVCFG; } < "$ETCDU"
for ID in {0..3}; do \
SRVUP[$ID]="$( echo "$SRVCFG" | jq -r ".${SRVNM[$ID]}srvup|strings" )"; done
GRP="$( echo "$SRVCFG" | jq -r ".lncgrp|strings" )"
RNM="$( echo "$SRVCFG" | jq -r ".regname|strings" )"

GRP="${GRP:-Default}" RNM="${RNM:-$GRP}"

#线路UP: 测试和构造代理服务状态数据
[[ "${PM[0]}" == "Active" && "${#PM[@]}" == 10 ]] && {
    #DDNS注册
    URL="http://ddns.local:1253/namemapv2"; TAGT="${PM[6]}"
    curl --connect-timeout 3 -X "POST" -d "SIMPLEPM;$LN;V4HOST;$TAGT;20" "$URL" &
    curl --connect-timeout 3 -X "POST" -d "SIMPLEPM;$RNM;V4CLUT;$TAGT" "$URL" &
    #服务状态测试和重启
    for ID in {0..3}; do
        [[ "${SRVUP[$ID]}" =~ ^"YES"|"yes"$ ]] || continue; > "${SRVEN[$ID]}"
        ../${SRVNM[$ID]}/PeriodicST-srvstck.sh && { 
            ../${SRVNM[$ID]}/PeriodicMT-stlogpush.sh & continue; }
        SRVCFG="{\"${SRVNM[$ID]}\":{\"etcdnm\":\"$ETCDNM\",\"lncgrp\":\"$GRP\"}}"
        setsid "../${SRVNM[$ID]}/srvstart.sh"; SRVST[$ID]="DOWN"; done
    #对重启动服务进行二次状态测试
    [ -n "${SRVST[*]}" ] && {
        sleep 2; for ID in {0..3}; do [ -z "${SRVST[$ID]}" ] && continue
        ../${SRVNM[$ID]}/PeriodicST-srvstck.sh && SRVST[$ID]=""; done; }
    #服务状态收集,或未启用服务时进行清理操作
    LOGDT=" "; for ID in {0..3}; do
        [[ "${SRVUP[$ID]}" =~ ^"YES"|"yes"$ ]] && \
        LOGDT="$LOGDT, \"${SRVNM[$ID]}srvst\": \"${SRVST[$ID]:-UP}\"" && continue
        [ -f "$SRVEN[$ID]" ] && { rm -f "$SRVEN[$ID]"; ../${SRVNM[$ID]}/srvstart.sh "stop" & }
        LOGDT="$LOGDT, \"${SRVNM[$ID]}srvst\": \"DISABLED\""; done; }

#线路DOWN: 收集统计数据,关闭代理服务
[[ "${PM[0]}" == "Inactive" && "${#PM[@]}" == 13 ]] && {
    echo "[LINE.DOWN] ${PM[@]} [TO.BE.END]" > "$STFL"
    LOGDT=", \"cntime\": ${PM[10]}, \"upflow\": ${PM[11]}, \"dwflow\": ${PM[12]}"
    for ID in {0..3}; do [ -f "$SRVEN[$ID]" ] || continue
    rm -f "$SRVEN[$ID]"; ../${SRVNM[$ID]}/srvstart.sh "stop" & done; }

[[ -n "$LOGDT" && -n "$ETCDNM" ]] && {
    #构造日志数据
    LOGDT="{ \"lnstat\": \"${PM[0]}\",  \"instid\": \"${PM[1]}\",
             \"lncgrp\": \"$GRP\",      \"lcaddr\": \"${PM[2]}\",
             \"lnaddr\": \"${PM[6]}\",  \"gwaddr\": \"${PM[7]}\",
             \"lacmac\": \"${PM[8]}\",  \"lndlnm\": \"${PM[3]}\",
             \"uptime\": \"${PM[9]}\",  \"linenm\": \"$LN\" $LOGDT }"
    LOGDT="$( echo "$LOGDT" | jq -M "." )" STKEY="$GRP-$LN-${PM[6]}"
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
