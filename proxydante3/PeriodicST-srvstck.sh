#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" 

#sockd服务进程状态测试
pidof "sockd" && pidof "awk-skd-log" && pidof "sqlite3-skd-log" &> "/dev/null"

