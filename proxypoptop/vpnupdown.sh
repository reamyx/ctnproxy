#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" 
cd "$(dirname "$0")"

#UD="UP","DOWN"分别指用户连接启停
UD="${CONNECT_TIME:+DW}"; UD="${UD:-UP}"

#连接信息,当前时间
RLAD="$6"
SRVT="${SRV_NAME:--}"
INST="${SESS_UUID:15:16}"
LNNM="$HOSTNAME"
EXIF="inet0"

#提取线路线名称,暂不需用
# ETCDU="./Etcd.Url" GRP=""; { read -t 1; read -t 1 GRP; } < "$ETCDU"

CLTDB="./Client.State.db"
[ -f "$CLTDB" ] || exit 

#用户连接UP
[ "$UD" == "UP" ] && {
    CLTST="Active"; TMNOW="$( date +%F/%T/%Z )"
    LNAD="$( ip -o -4 addr show dev "$EXIF" | awk '{print $4;exit}' )"
    
    #############################################################################
    #查询并根据账户类型配置出口网关(CREATE TABLE usinfo(name, info, time))
    #--当前仅使用缺省类型: 本地出口,无需配置策略路由
    PRTY="-"; PRLN="-"; PRAD="-"
    #############################################################################
    
    #添加用户状态到数据库
    sqlite3 --cmd ".timeout 5000" "$CLTDB" "
    INSERT INTO stlog(
        instid, cdname, linenm, lnaddr, cnstat, rladdr, uptime, srvtnm, usaddr, 
        ${PRTY:+actype,} ${PRLN:+prline,} ${PRAD:+praddr,} ifname, ctlpid )
    VALUES( \"$INST\", \"$PEERNAME\", \"$LNNM\", \"$LNAD\", \"$CLTST\",
        \"$RLAD\", \"$TMNOW\", \"$SRVT\", \"$IPREMOTE\", ${PRTY:+\"$PRTY\",} 
        ${PRLN:+\"$PRLN\",} ${PRAD:+\"$PRAD\",} \"$IFNAME\", $PPPD_PID );"; }

#用户连接DOWN
[ "$UD" == "DW" ] && {
	CLTST="Inactive"
    #更新用户状态到数据库
    sqlite3 --cmd ".timeout 5000" "$CLTDB" "
    UPDATE stlog SET
        cnstat=\"$CLTST\", cntime=$CONNECT_TIME,
        upflow=$BYTES_RCVD, dwflow=$BYTES_SENT
    WHERE instid==\"$INST\" AND cdname==\"$PEERNAME\";"; }

#执行连接状态注册
./PeriodicMT-stlogpush.sh "$INST" "$PEERNAME" &

exit 0



#环境变量
#  MACREMOTE=AC:4E:91:41:AD:98  [ PPPOE插件拨号时 ]
#  IFNAME=ppp120
#  CONNECT_TIME=23              [ 仅接口DOWN时可用 ]
#  IPLOCAL=192.168.16.20
#  PPPLOGNAME=root
#  BYTES_RCVD=43416             [ 仅接口DOWN时可用 ]
#  ORIG_UID=0
#  SPEED=115200
#  BYTES_SENT=73536             [ 仅接口DOWN时可用 ]
#  IPREMOTE=192.168.16.40
#  PPPD_PID=21420
#  PWD=/
#  PEERNAME=zxkt
#  DEVICE=/dev/pts/1
#  SESS_UUID=""                 [ expandpwd插件 ]
