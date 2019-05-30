#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"

#初始化日志缓存数据库
# slogid cdname linenm sraddr srport lnaddr lnport
# praddr prport dsaddr dsport protcl uptime cntime upflow dwflow

CLTDB="./skdlog.db"
PWDCC="./pswdcc.db"
rm -f "$CLTDB" "$PWDCC"

sqlite3 "$CLTDB" "
CREATE TABLE stlog(
    cctm TIMESTAMP      NOT NULL DEFAULT (strftime('%s')),
    inst CHAR(16)       NOT NULL,
    psst CHAR(16)       NOT NULL,
    data VARCHAR(5120)  NOT NULL );"

sqlite3 "$PWDCC" "
CREATE TABLE usinfo(
    name CHAR(16)       PRIMARY KEY NOT NULL,
    pswd CHAR(16)       NOT NULL,
    time TIMESTAMP      NOT NULL DEFAULT (strftime('%s')));"
