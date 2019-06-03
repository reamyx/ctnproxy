#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#本程序执行其它服务程序委托的账号检查及密码查询工作
#参数$1为JSON格式字符串,用于提供用户认证相关参数,具体内容及表义取决于调用程序
#标准输出首行提供密码,次行输出可选的描述信息
#输出字串中的'\0'被视作换行符'\n'处理,非0状态码指示认证失败

#SOCKD服务调用参数解释: $1:用户名称 $2:用户提交明文密码 $3:sockd服务主进程ID

#proxy集群etcd目录规划
# /proxyauth/LinesCommon/*    #常规认证卡密,低优先适用所有线路
# /proxyauth/<node>/*     #线路认证卡密,<node>:线路名称, KEY:账户名称
# 认证数据: '{"passwd":"abc000","limit":2,"expire":"","type":""}'

#用户名称
UNM="$1"

#测试数据
[ "$UNM" == "vtest" ] && { ECHO "2019"; ECHO "vtest-2019-ok"; exit 0; }

#优先从缓存查找用户账户信息,失败时从远程拉取并更新到缓存表
PWDCC="./pswdcc.db"
UPW="$( sqlite3 --cmd ".timeout 3000" "$PWDCC" "
    SELECT pswd FROM usinfo WHERE name=='$UNM';" )"

#缓存未命中时从远程拉取用户信息
[ -z "$UPW" ] && {
    LNNAME="$HOSTNAME" ETCDU="./Etcd.Url" ETCDNM="" GRP="" UPM=""
    { read -t 1 ETCDNM; read -t 1 GRP; } < "$ETCDU" && \
    [ -n "$ETCDNM" ] || { ECHO "Necessary Parameter Absence."; exit 1; }
    #依次尝试从当前线路和通用线路获取用户信息
    UPM="$( etcdctl --endpoints "$ETCDNM" get "/proxyauth/CG-$GRP/$LNNAME/$UNM" )"
    [ -z "$UPM" ] && \
    UPM="$( etcdctl --endpoints "$ETCDNM" get "/proxyauth/CG-$GRP/LinesCommon/$UNM" )"
    [ -z "$UPM" ] && { ECHO "Specified User Account Does Not Exist."; exit 2; }
    #账户过期检查
    USEXP="$( echo "$UPM" | jq -r ".expire|strings" | tr "/" " " )"
    [ -n "$USEXP" ] && (( "$( date -d "$USEXP" "+%s" )" < "$( date "+%s" )" )) && {
        ECHO "Specified User Account Expired."; exit 3; }
    #添加到用户密码缓存
    UPW="$( echo "$UPM" | jq -r ".passwd|strings" )"
    sqlite3 --cmd ".timeout 3000" "$PWDCC" "
    BEGIN; DELETE FROM usinfo WHERE name=='$UNM';
    INSERT INTO usinfo(name, pswd) VALUES('$UNM', '$UPW'); COMMIT;" & }

#并发数检查: socks5不适用

#密码响应
ECHO "$UPW"; ECHO "Welcome to use, Powered by Zhixia(reamyx@126.com)."
exit 0
