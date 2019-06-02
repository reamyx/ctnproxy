#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#附加任务: 清理密码缓存
PWDCC="./pswdcc.db"
sqlite3 --cmd ".timeout 3000" "$PWDCC" "
DELETE FROM usinfo WHERE strftime('%s')-time>60;" &


#持锁操作
WKFL="./skdlog.list"; exec 5<>"$WKFL" && flock -x -n 5 || exit 1

#缓存库名称和etcd名称
CLTDB="./skdlog.db"; ETCDU="./Etcd.Url"
read -t 1 ETCDNM < "$ETCDU"
[[ -f "$CLTDB" && -n "$ETCDNM" ]] || exit 2

LNNM="$HOSTNAME"; LOG=""; CNT=0; LPC=0; INST=""

#分批次(最早期120秒内)标记处理,直到缓存为空时结束本次操作
while true; do
    sqlite3 --cmd ".timeout 5000" "$CLTDB" "
    UPDATE stlog SET psst=\"pushing\" WHERE
    cctm<((SELECT min(cctm) FROM stlog)+120);
    SELECT inst,data FROM stlog WHERE psst==\"pushing\";" >"$WKFL"
    #逐条推送到远程缓存目录
    while read LOG; do
        INST="${LOG%%|*}"; LOG="$( echo "${LOG##*|}" | jq "." )"
        [ -z "$LOG" ] && continue
        #推送操作尝试三次失败时结束本次操作
        for ID in {1..3}; do
            etcdctl --endpoints "$ETCDNM" set --ttl 1209600 \
            "/proxysklog/$LNNM/$INST" "$LOG" && break
            (( ID == 3 )) && exit 3; sleep 1; done
        (( LPC++ )); done <"$WKFL"
    #成功后清除相关缓存
    sqlite3 --cmd ".timeout 5000" "$CLTDB" "
    DELETE FROM stlog WHERE psst==\"pushing\";"
    (( LPC == 0 )) && break; LPC=0; done

exit 0
