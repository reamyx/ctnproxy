#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

LT="" ST=() COND="" IPCP="" LOGDT=""
CLTDB="./Client.State.db"

ETCDU="./Etcd.Url" ETCDNM="" GRP=""
{ read -t 1 ETCDNM; read -t 1 GRP;  } < "$ETCDU"

[[ -f "$CLTDB" && -n "$ETCDNM" ]] || exit 1

#IPCP调用时仅处理当前用户状态,周期调用时执行异常检测
[[ -n "$1" && -n "$2" ]] && \
COND="WHERE instid==\"$1\" AND cdname==\"$2\"" && IPCP="Y" || {
    #转换先前可能的异常状态到异常终止状态
    sqlite3 --cmd ".timeout 5000" "$CLTDB" \
    "UPDATE stlog SET cnstat=\"AbnormalTM\" WHERE cnstat==\"Abnormal\";"
    #遍历状态表中活动记录执行控制PID存活测试
    LVPID=" $( pidof "pppd" ) "; TMNOW=""
    for LT in $( sqlite3 --cmd ".timeout 5000" "$CLTDB" \
        "SELECT ctlpid,uptime FROM stlog WHERE cnstat==\"Active\";" ); do
        [ -z "${LVPID##* ${LT%%|*} *}" ] && continue
        #对失效状态记录设置异常状态标记
        [ -z "$TMNOW" ] && TMNOW="$( date +%s )"
        CNTM="$( echo "${LT##*|}" | tr "/" " " )"
        CNTM="$( date -d "$CNTM" +%s )"; (( CNTM = TMNOW - CNTM ))
        sqlite3 --cmd ".timeout 5000" "$CLTDB" \
        "UPDATE stlog SET cnstat=\"Abnormal\", cntime=$CNTM
        WHERE cnstat==\"Active\" AND ctlpid==${LT%%|*} AND cntime IS NULL;"
        done; }

#遍历用户列表执行状态更新
for LT in $( sqlite3 --cmd ".timeout 5000" -nullvalue "-" \
    "$CLTDB" "SELECT * FROM stlog $COND;" ); do 
    ST=( $( echo "$LT" | tr "|" " " ) )
    LOGDT="\"instid\": \"${ST[0]}\",  \"cdname\": \"${ST[1]}\",
           \"linenm\": \"${ST[2]}\",  \"lnaddr\": \"${ST[3]}\", 
           \"cnstat\": \"${ST[4]}\",  \"rladdr\": \"${ST[5]}\",
           \"uptime\": \"${ST[6]}\",  \"srvtnm\": \"${ST[10]}\",
           \"usaddr\": \"${ST[11]}\", \"actype\": \"${ST[12]}\",
           \"prline\": \"${ST[13]}\", \"praddr\": \"${ST[14]}\",
           \"lncgrp\": \"$GRP\""
    STKEY="${ST[2]}-${ST[1]}-${ST[0]}"
    #活动连接处理: 状态更新
    [ "${ST[4]}" == "Active" ] && {
        LOGDT="$( echo "{ $LOGDT }" | jq -M "." )"
        [ -z "$IPCP" ] && \
        etcdctl --endpoints "$ETCDNM" update --ttl "20" "/proxyvcst/CG-$GRP/$STKEY" "$LOGDT" || \
        etcdctl --endpoints "$ETCDNM" set --ttl "20" "/proxyvcst/CG-$GRP/$STKEY" "$LOGDT"; }
    #离线连接处理: 添加缓存日志,成功完成时清理目标记录
    [[ "${ST[4]}" == "Inactive" || "${ST[4]}" == "AbnormalTM" ]] && {
        LOGDT="$LOGDT, \"cntime\": ${ST[7]}, \"upflow\": ${ST[8]}, \"dwflow\": ${ST[9]}"
        LOGDT="$( echo "{ $LOGDT }" | jq -M "." )"
        etcdctl --endpoints "$ETCDNM" set -ttl "1209600" "/proxyvclog/${ST[2]}/${ST[0]}" "$LOGDT" && \
        sqlite3 --cmd ".timeout 5000" "$CLTDB" \
        "DELETE FROM stlog WHERE instid==\"${ST[0]}\" AND cdname==\"${ST[1]}\";"
        etcdctl --endpoints "$ETCDNM" set -ttl "1" "/proxyvcst/CG-$GRP/$STKEY" "$LOGDT"; }
    done

exit 0
