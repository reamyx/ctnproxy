#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" 

pidof "proxyline-$HOSTNAME-pppd" &> "/dev/null"
