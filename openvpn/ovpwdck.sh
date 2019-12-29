#!/bin/env sh
PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; cd "$(dirname "$0")"
exec 4>&1; ECHO(){ echo "${@}" >&4; }; exec 3<>"/dev/null"; exec 0<&3;exec 1>&3;exec 2>&3


#不接受空用户名和空密码
[[ -z "$$username" || -z "$password" ]] && exit 1

#本地用户密码文件检查
PWD=""; UPATH="./pwd/${username}.pwd"
[ -r "$UPATH" ] && read -t 1 PWD <"$UPATH" && [ "$PWD" == "${password}" ] && exit 0

#其它检查




exit 2
