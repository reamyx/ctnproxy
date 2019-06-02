#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

SKDTMP="/tmp/sockd86tmp12"
SKDIF="inet0"
ETCDU="./Etcd.Url"
CLTDB="./skdlog.db"

#历史实例终止
for I in {1..10}; do pkill "^sockd$" || break; [ "$I" == 10 ] && exit 1; sleep 0.5; done
[ "$1" == "stop" ] && exit 0

#测试程序运行的必然要条件
 ip link show dev "$SKDIF" || exit 1

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"
echo "$SRVCFG" | jq -r ".proxydante3|.etcdnm,.lncgrp|strings" > "$ETCDU"
GRP="$( echo "$SRVCFG" | jq -r ".proxydante3.lncgrp|strings" )"
SKPORT="$( echo "$SRVCFG" | jq -r ".proxydante3.skport|numbers" )"
SKPORT="${SKPORT:-1080}"

#初始化状态数据库
./stdb.create.sh

#sockd服务配置文件
echo "\
logoutput: stdout
internal.protocol: ipv4
internal: 0.0.0.0 port = $SKPORT
external.protocol: ipv4
external: $SKDIF
#external.rotation: same-same
user.privileged: root
user.unprivileged: nobody
#extension: bind
udp.connectdst: no
clientmethod: none
socksmethod: username
#连接到服务器的客户端(TCP连接)
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    #log: connect disconnect error
}
#socks协议上的源目标过滤
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    udp.portrange: 3000-9999
    log: connect disconnect
}
" > ./sockd.conf

#日志格式化脚本
echo '#!/bin/env awk

#sockd日志数据整理成json串记录并构造和输出相关sql语句

#状态初始化,部分参数由命令行-v选项指定
# tnm= 缓存表名称, lnm= 线路名称
BEGIN{
    print(".timeout 3000");fflush("");
    rn=2999;uf="/proc/sys/kernel/random/uuid";}

#目标记录过滤
$8$9!~/tcp\/connect\]:/{next;}
$6$7!~/info:pass\([0-9]+\):/{next;}

#缓存库超容清理,保留最近10000条
++rn>=3000{
rn=0;print("DELETE FROM "tb" WHERE cctm<\
(SELECT cctm FROM "tb" ORDER BY cctm DESC LIMIT 1 OFFSET 10000);");}

{
#实例ID生成
ud="";getline ud<uf;close(uf);
if(!ud){"uuidgen"|getline ud;close("uuidgen");}
gsub("-","",ud);ud=toupper(substr(ud,15,16));

#数据字段格式化
$8="tcp-connect";$9=$12;$20=$19;
match($4,"[0-9]+");$4=substr($4,RSTART,RLENGTH);
gsub("^.*%","",$9);gsub("@.*$","",$9);
gsub("^.*@","",$12);gsub(/\.[0-9]*$/,"",$12);
gsub(/\.[0-9]*$/,"",$13);gsub(/\.[0-9]*$/,"",$18);
gsub(/\.[0-9]*$/,"",$19);gsub(/^.*\./,"",$20);
gsub(/[^0-9]+$/,"",$NF);
$4=strftime("%Y-%m-%d/%H:%M:%S/%Z",$4-$NF);
if($13==$18){$18="-";};

#JOSN数据构造
js="{\"instid\":\""ud"\",\"cdname\":\""$9"\",\
\"lncgrp\":\""grp"\",\"linenm\":\""lnm"\",\
\"protcl\":\""$8"\",\"sraddr\":\""$12"\",\"lnaddr\":\""$13"\",\
\"praddr\":\""$18"\",\"dsaddr\":\""$19"\",\"dsport\":"$20",\
\"uptime\":\""$4"\",\"cntime\":"$NF",\"upflow\":"$16",\"dwflow\":"$10"}";

#转义JSON串中的引号(经测试sqllite会将两个双引号转义成一个双引字符作为字串内容)
gsub(/\"/,"\"\"",js);

#构造和输出SQL语句
print("INSERT INTO "tb"(inst, psst, data) \
VALUES(\""ud"\", \"ready\", \""js"\");");fflush("");}
' > ./skdlog.awk

#sockd日志发送至awk执行格式化处理并条件生成sql语句由sqlite3更新到日志缓存数据库 
mkdir -p "$SKDTMP"
TMPDIR="$SKDTMP" sockd -f "./sockd.conf" | \
( exec -a "awk-skd-log" awk -v lnm="$HOSTNAME" \
  -v tb="stlog" -v grp="$GRP" -f "./skdlog.awk" ) | \
( exec -a "sqlite3-skd-log" sqlite3 "$CLTDB" ) &

exit 0


#日志原始格式

# May  5 20:28:02 (1557059282.705554) sockd[19553]: info: pass(1): tcp/connect [:
# username%abc@113.134.93.92.52566 42.242.117.232.1080 -> 42.242.117.232.52566 219.151.27.93.80
# May  5 20:28:03 (1557059283.015113) sockd[19553]: info: pass(1): tcp/connect ]:
# 556 -> username%abc@113.134.93.92.52566 42.242.117.232.1080 -> 43, 43 -> 42.242.117.232.52566
# 219.151.27.93.80 -> 556: local client error (Connection reset by peer).  Session duration: 1s

# May  5 20:32:53 (1557059573.012844) sockd[20261]: info: pass(1): udp/udpassociate [:
# username%abc@0.0.0.0.62956 42.242.117.232.5082
# May  5 20:32:53 (1557059573.049038) sockd[19553]: info: pass(1): udp/udpassociate ]:
# 0/0 -> # username%abc@0.0.0.0.62956 42.242.117.232.5082 -> 0/0: local client closed.
# Session duration: 1s
