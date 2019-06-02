#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3

#持锁运行,避免重入
LKFL="./ProxyLog.Lock"; exec 5<>"$LKFL" && flock -x -n 5 || exit 1

#DDNS注册
DDNSREG="./PeriodicRT-ddns-update"
[ -f "$DDNSREG" ] && ( chmod +x "$DDNSREG"; setsid "$DDNSREG" & )

#日志库表创建过程($1服务器名称,$2端口,$3账号,$4密码,$5库名称)
#操作过程仅尝试建立必要的数据库和表,不代表数据库连接或账号的有效性
PBRSRVDB_CREATE() {
    mysql -h"$1" -P"$2" -u"$3" -p"$4" -e "CREATE DATABASE IF NOT EXISTS $5;"
    mysql -h"$1" -P"$2" -u"$3" -p"$4" -D"$5" -e \
    "CREATE TABLE IF NOT EXISTS linelogs (
        llogid  INTEGER     PRIMARY KEY AUTO_INCREMENT,
        instid  CHAR(16)    NOT NULL,
        lncgrp  CHAR(16)    NOT NULL,
        linenm  CHAR(16)    NOT NULL,
        lnstat  CHAR(16)    NOT NULL,
        lnaddr  CHAR(16)    NOT NULL,
        uptime  DATETIME    NOT NULL,
        cntime  INTEGER     DEFAULT NULL,
        upflow  BIGINT      DEFAULT NULL,
        dwflow  BIGINT      DEFAULT NULL,
        lacmac  VARCHAR(20) DEFAULT NULL,
        gwaddr  VARCHAR(16) DEFAULT NULL,
        lndlnm  VARCHAR(16) DEFAULT NULL,
        UNIQUE  KEY (instid, lncgrp, linenm)
        ) ENGINE = INNODB;"
    mysql -h"$1" -P"$2" -u"$3" -p"$4" -D"$5" -e \
    "CREATE TABLE IF NOT EXISTS vpnlogs (
        vlogid  INTEGER     PRIMARY KEY AUTO_INCREMENT,
        instid  CHAR(16)    NOT NULL,
        lncgrp  CHAR(16)    NOT NULL,
        linenm  CHAR(16)    NOT NULL,
        cdname  CHAR(16)    NOT NULL,
        lnaddr  CHAR(16)    NOT NULL,
        cnstat  CHAR(16)    NOT NULL,
        rladdr  CHAR(16)    NOT NULL,
        uptime  DATETIME    NOT NULL,
        cntime  INTEGER     DEFAULT NULL,
        upflow  BIGINT      DEFAULT NULL,
        dwflow  BIGINT      DEFAULT NULL,
        srvtnm  VARCHAR(16) DEFAULT NULL,
        usaddr  VARCHAR(16) DEFAULT NULL,
        actype  VARCHAR(16) DEFAULT NULL,
        prline  VARCHAR(16) DEFAULT NULL,
        praddr  VARCHAR(16) DEFAULT NULL,
        UNIQUE  KEY (instid, lncgrp, linenm, cdname)
        ) ENGINE = INNODB;"
    mysql -h"$1" -P"$2" -u"$3" -p"$4" -D"$5" -e \
    "CREATE TABLE IF NOT EXISTS sk5logs (
        slogid  INTEGER     PRIMARY KEY AUTO_INCREMENT,
        instid  CHAR(16)    NOT NULL,
        lncgrp  CHAR(16)    NOT NULL,
        linenm  CHAR(16)    NOT NULL,        
        cdname  CHAR(16)    NOT NULL,
        protcl  CHAR(16)    NOT NULL,
        sraddr  CHAR(16)    NOT NULL,
        lnaddr  CHAR(16)    NOT NULL,
        praddr  CHAR(16)    NOT NULL,
        dsaddr  CHAR(16)    NOT NULL,
        dsport  INTEGER     NOT NULL,
        uptime  DATETIME    NOT NULL,
        cntime  INTEGER     NOT NULL,
        upflow  BIGINT      DEFAULT NULL,
        dwflow  BIGINT      DEFAULT NULL,
        UNIQUE  KEY (instid, lncgrp, linenm, cdname)
        ) ENGINE = INNODB;"; }

#数据库连通性测试,失败时终止运行
SQLSER_CHECK() {
    for ID in {1..20}; do \
    mysqladmin ping -h"$1" -P"$2" -u"$3" -p"$4" && break
    (( ID == 20 )) && exit 1; sleep 0.5; done; }

#环境变量未能提供配置数据时从配置文件读取
[ -z "$SRVCFG" ] && SRVCFG="$( jq -scM ".[0]|objects" "./workcfg.json" )"

#提取SQL配置参数(服务器,账号,密码,库名称),可以指示启用一个本地mysql服务
DBSER="$( echo "$SRVCFG" | jq -r ".proxylog.sqlser|strings"  )"
DBSPT="$( echo "$SRVCFG" | jq -r ".proxylog.sqlport|numbers" )"
DBUNM="$( echo "$SRVCFG" | jq -r ".proxylog.sqluser|strings" )"
DBPWD="$( echo "$SRVCFG" | jq -r ".proxylog.sqlpwd|strings"  )"
DBSNM="$( echo "$SRVCFG" | jq -r ".proxylog.dbname|strings"  )"
ETCDS="$( echo "$SRVCFG" | jq -r ".proxylog.etcdnm|strings"  )"
RTLOG="$( echo "$SRVCFG" | jq -r ".proxylog.rtlogs|strings"  )"
NOBTH="$( echo "$SRVCFG" | jq -r ".proxylog.nobth|numbers"   )"

#参数缺省时使用默认值,使用默认sql账号时会配置默认关联密码
DBSER="${DBSER:-localhost}"
DBSPT="${DBSPT:-3306}"
DBSNM="${DBSNM:-proxylogdb}"
[ -z "$DBUNM" ] && { DBUNM="proxyadmin"; DBPWD="proxypw000"; }
ETCDS="${ETCDS:-http://etcdser:2379}"
NOBTH="${NOBTH:-100}"

#休眠指示,主机名称
DLTM="0"; LH="$HOSTNAME"

#测试SQL服务可用时配置目标库表或SQL服务失败时终止
SQLSER_CHECK "$DBSER" "$DBSPT" "$DBUNM" "$DBPWD"
PBRSRVDB_CREATE "$DBSER" "$DBSPT" "$DBUNM" "$DBPWD" "$DBSNM"

#实时日志收集: [暂未实现]

#缓存日志收集:

#JSON解析和SQL构造参数(当前,动态配置)
JSON_PM="" ASQL_PM=""

#JSON解析参数( 0:线路, 1:VPN, 2:SK5 )
JSON_PMS=(
    '.instid+" "+.lncgrp+" "+.linenm+" "+.lnstat+" "+.lnaddr+" "+
    .uptime+" "+(.cntime|numbers|tostring)+" "+(.upflow|numbers|tostring)
    +" "+(.dwflow|numbers|tostring)+" "+.lacmac+" "+.gwaddr+" "+.lndlnm'
    
    '.instid+" "+.lncgrp+" "+.linenm+" "+.cdname+" "+
    .lnaddr+" "+.cnstat+" "+.rladdr+" "+.uptime+" "+
    (.cntime|numbers|tostring)+" "+(.upflow|numbers|tostring)+" "+
    (.dwflow|numbers|tostring)+" "+.srvtnm+" "+.usaddr+" "+.actype+" "+
    .prline+" "+.praddr'
    
    '.instid+" "+.lncgrp+" "+.linenm+" "+.cdname+" "+
    .protcl+" "+.sraddr+" "+.lnaddr+" "+.praddr+" "+
    .dsaddr+" "+(.dsport|numbers|tostring)+" "+.uptime+" "+
    (.cntime|numbers|tostring)+" "+(.upflow|numbers|tostring)+" "+
    (.dwflow|numbers|tostring)' )

#SQL构造参数( 0:线路, 1:VPN, 2:SK5 )
ASQL_PMS=(
    'NF==12{print "INSERT INTO linelogs(instid,lncgrp,linenm,\
    lnstat,lnaddr,uptime,cntime,upflow,dwflow,lacmac,gwaddr,lndlnm)\
    VALUES(\""$1"\",\""$2"\",\""$3"\",\""$4"\",\""$5"\",\""$6"\",\
    "$7","$8","$9",\""$10"\",\""$11"\",\""$12"\")\
    ON DUPLICATE KEY UPDATE \
    lnstat=VALUES(lnstat),lnaddr=VALUES(lnaddr),uptime=VALUES(uptime),\
    cntime=VALUES(cntime),upflow=VALUES(upflow),dwflow=VALUES(dwflow),\
    lacmac=VALUES(lacmac),gwaddr=VALUES(gwaddr),lndlnm=VALUES(lndlnm);"}'
    
    'NF==16{print "INSERT INTO vpnlogs(instid,lncgrp,linenm,cdname,lnaddr,\
    cnstat,rladdr,uptime,cntime,upflow,dwflow,srvtnm,usaddr,actype,prline,praddr)\
    VALUES(\""$1"\",\""$2"\",\""$3"\",\""$4"\",\""$5"\",\""$6"\",\""$7"\",\
    \""$8"\","$9","$10","$11",\""$12"\",\""$13"\",\""$14"\",\""$15"\",\""$16"\")\
    ON DUPLICATE KEY UPDATE \
    lnaddr=VALUES(lnaddr),cnstat=VALUES(cnstat),rladdr=VALUES(rladdr),\
    uptime=VALUES(uptime),cntime=VALUES(cntime),upflow=VALUES(upflow),\
    dwflow=VALUES(dwflow),srvtnm=VALUES(srvtnm),actype=VALUES(actype),\
    usaddr=VALUES(usaddr),prline=VALUES(prline),praddr=VALUES(praddr);"}'
    
    'NF==14{print "INSERT INTO sk5logs(instid,lncgrp,linenm,cdname,protcl,\
    sraddr,lnaddr,praddr,dsaddr,dsport,uptime,cntime,upflow,dwflow)\
    VALUES(\""$1"\",\""$2"\",\""$3"\",\""$4"\",\""$5"\",\""$6"\",\
    \""$7"\",\""$8"\",\""$9"\","$10",\""$11"\","$12","$13","$14")\
    ON DUPLICATE KEY UPDATE \
    protcl=VALUES(protcl),sraddr=VALUES(sraddr),lnaddr=VALUES(lnaddr),\
    praddr=VALUES(praddr),dsaddr=VALUES(dsaddr),dsport=VALUES(dsport),\
    uptime=VALUES(uptime),cntime=VALUES(cntime),upflow=VALUES(upflow),\
    dwflow=VALUES(dwflow);"}' )

#JSON数据解析过程: $1批次KEY文件,返回批次记录
JSON_EXTRACT() {
    local KEY="" RCDFL="./rcd.list"
    while read KEY; do etcdctl --endpoints "$ETCDS" get "$KEY" | \
    jq -rcM "$JSON_PM"; done < "$1" > "$RCDFL"; mv -f "$RCDFL" "$1"; }

#批次更新过程: $1列表KEY文件
BATCH_UPDATA_DB() {
    local KEY="" LNS="${NOBTH:-200}" BTHFL="./bth.list" DELFL="./del.list"
    #分批次提取日志key依次进行数据解析和入库操作
    while [ -s "$1" ]; do
        sed -n "1,${LNS}p" "$1" > "$BTHFL"; sed -i "1,${LNS}d" "$1"
        cat "$BTHFL" > "$DELFL"; JSON_EXTRACT "$BTHFL"
        #数据库可用时构造sql语句并执行到数据库,成功后从etcd目录清除日志缓存
        SQLSER_CHECK "$DBSER" "$DBSPT" "$DBUNM" "$DBPWD"
        awk "$ASQL_PM" "$BTHFL" | \
        mysql -h"$DBSER" -P"$DBSPT" -u"$DBUNM" -p"$DBPWD" -D"$DBSNM" && \
        while read KEY; do etcdctl --endpoints "$ETCDS" rm "$KEY"; done < "$DELFL"
        done; }

#持锁处理过程: $1加锁目录文件
PROCESS_WITH_LOCK() {
    local UDIR="" KEYFL="./key.list"
    #遍历且锁定目标目录成功时获取KEY列表分批处理
    while read UDIR; do
        etcdctl --endpoints "$ETCDS" mk -ttl 60 "${UDIR}Lock/LogSrv" "$LH" || continue
        etcdctl --endpoints "$ETCDS" ls -p "${UDIR}" | grep -E "[^/]$" > "$KEYFL"
        BATCH_UPDATA_DB "$KEYFL"; done < "$1"; }

#日志处理主LOOP
while true; do
    #重置日志计数器和锁定单元列表文件
    LOGCNT=0 DLTM=40 UNMFL="./unm.list"; > "$UNMFL"
    
    #线路日志收集
    echo "/proxylnlog/" > "$UNMFL"
    JSON_PM="${JSON_PMS[0]}" ASQL_PM="${ASQL_PMS[0]}"; PROCESS_WITH_LOCK "$UNMFL"
    
    #VPN日志收集
    etcdctl --endpoints "$ETCDS" ls -p "/proxyvclog" | grep -E "/$" > "$UNMFL"
    JSON_PM="${JSON_PMS[1]}" ASQL_PM="${ASQL_PMS[1]}"; PROCESS_WITH_LOCK "$UNMFL"
    
    #SK5日志收集
    etcdctl --endpoints "$ETCDS" ls -p "/proxysklog" | grep -E "/$" > "$UNMFL"
    JSON_PM="${JSON_PMS[2]}" ASQL_PM="${ASQL_PMS[2]}"; PROCESS_WITH_LOCK "$UNMFL"
    
    #根据日志计数器重新确定周期延时
    (( LOGCNT > 50 )) && DLTM=20; (( LOGCNT > 100 )) && continue
    ECHO "Extract $LOGCNT logs,Delay for $DLTM seconds."; sleep "$DLTM"; done

exit 0
