#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"

#初始化状态数据库
# instid cdname linenm lnaddr cnstat rladdr uptime cntime 
# upflow dwflow srvtnm usaddr actype prline praddr ifname ctlpid
CLTDB="./Client.State.db"
rm -f "$CLTDB"
sqlite3 "$CLTDB" "
CREATE TABLE usinfo(
    name CHAR(16)       PRIMARY KEY NOT NULL,
    info VARCHAR(5120)  NOT NULL,
    time TIMESTAMP      NOT NULL DEFAULT (strftime('%s')));
CREATE TABLE stlog(
    instid CHAR(16)     NOT NULL,
    cdname CHAR(16)     NOT NULL,
    linenm CHAR(16)     NOT NULL,
    lnaddr CHAR(16)     NOT NULL,
    cnstat CHAR(16)     NOT NULL,
    rladdr CHAR(16)     NOT NULL,
    uptime CHAR(32)     NOT NULL,
    cntime INTEGER,
    upflow INTEGER,
    dwflow INTEGER,
    srvtnm VARCHAR(16),
    usaddr VARCHAR(16),
    actype VARCHAR(16),
    prline VARCHAR(16),
    praddr VARCHAR(16),
    ifname VARCHAR(16)  NOT NULL,
    ctlpid INTEGER      NOT NULL,
    PRIMARY KEY (instid, cdname));"
