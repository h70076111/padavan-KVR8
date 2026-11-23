#!/bin/sh

killall vnts
#关闭vnts的防火墙规则
iptables -t filter -D INPUT -p tcp --dport 29872 -j ACCEPT
iptables -t filter -D INPUT -p udp --dport 29872 -j ACCEPT
logger -t "vnt" "启动服务器"
sleep 5 && /usr/bin/vnts -p 29872 -P 29870 -U hong -W Aa123567890 -l /dev/null &
sleep 8
if [ ! -z "`pidof vnts`" ] ; then
 logger -t "vnts" "服务器启动成功"
#放行vnts防火墙
iptables -t filter -I INPUT -p tcp --dport 29872 -j ACCEPT
iptables -t filter -I INPUT -p udp --dport 29872 -j ACCEPT
else
logger -t "vnts" "服务器启动失败"
fi
