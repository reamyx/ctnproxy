#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" 
cd "$(dirname "$0")"

[ -n "$IFNAME" ] && [ -n "$PPPLOGNAME" ] && [ -n "$PPPD_PID" ] || exit 2

#LNUD="UP","DW"指示线路连接的启停
LNUD="${CONNECT_TIME:+DW}"; LNUD="${LNUD:-UP}"

IPPM=( $6 )
INST="${IPPM[0]}"
LCAD="${IPPM[1]}"
DLNM="${IPPM[2]}"

STFL="./Line.Stat"
TMFL="./Line.Uptime"
LNST=""
UPTIME=""
COUNT=""

#线路UP: 添加出口路由,记录启动时间
[ "$LNUD" == "UP" ] && {
    ip route del 0.0.0.0/1   dev "$IFNAME" metric 10
    ip route del 128.0.0.0/1 dev "$IFNAME" metric 10
    ip route add 0.0.0.0/1   dev "$IFNAME" metric 10
    ip route add 128.0.0.0/1 dev "$IFNAME" metric 10
    LNST="Active";  UPTIME="$( date "+%F/%T/%Z" )"
    echo "$UPTIME" > "$TMFL"; }

#线路状态数据记录
[ "$LNUD" == "DW" ] && {
    LNST="Inactive"; read -t 1 UPTIME < "$TMFL"
    COUNT="$CONNECT_TIME $BYTES_SENT $BYTES_RCVD"; }

PM="$LNST $INST $LCAD $DLNM $PPPD_PID $IFNAME \
    $IPLOCAL $IPREMOTE $MACREMOTE $UPTIME $COUNT"

echo "$PM" > "$STFL"; ./PeriodicMT-proxy-keeplive.sh "$PM" &

exit 0
