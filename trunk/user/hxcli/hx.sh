#!/bin/sh

hxcli_enable=$(nvram get hxcli_enable)
HXCLI="$(nvram get hxcli_bin)"
hxcli_token="$(nvram get hxcli_token)"
hxli_ip="$(nvram get hxcli_ip)"
hxcli_localadd="$(nvram get hxcli_localadd)"
hxcli_serip="$(nvram get hxcli_serip)"
hxcli_model="$(nvram get hxcli_model)"
hxcli_key="$(nvram get hxcli_key)"
hxcli_log="$(nvram get hxcli_log)"
hxcli_proxy="$(nvram get hxcli_proxy)"
hxcli_first="$(nvram get hxcli_first)"
hxcli_wg="$(nvram get hxcli_wg)"
hxcli_finger="$(nvram get hxcli_finger)"
hxcli_serverw="$(nvram get hxcli_serverw)"
hxcli_desname="$(nvram get hxcli_desname)"
hxcli_id="$(nvram get hxcli_id)"
hxcli_tunname="$(nvram get hxcli_tunname)"
hxcli_mtu="$(nvram get hxcli_mtu)"
hxcli_dns="$(nvram get hxcli_dns)"
hxcli_stun="$(nvram get hxcli_stun)"
hxcli_port="$(nvram get hxcli_port)"
hxcli_punch="$(nvram get hxcli_punch)"
hxcli_comp="$(nvram get hxcli_comp)"
hxcli_relay="$(nvram get hxcli_relay)"
hxcli_wan="$(nvram get hxcli_wan)"

user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
github_proxys="$(nvram get github_proxy)"
[ -z "$github_proxys" ] && github_proxys=" "
if [ ! -z "$hxcli_port" ] ; then
	if [ ! -z "$(echo $hxcli_port | grep ',' )" ] ; then
		hx_tcp_port="${hxcli_port%%,*}"
	else
		hx_tcp_port="$hxcli_port"
	fi
fi
hxcli_renum=`nvram get hxcli_renum`

hxcli_restart () {
relock="/var/lock/hxcli_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set hxcli_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	hxcli_renum=${hxcli_renum:-"0"}
	hxcli_renum=`expr $hxcli_renum + 1`
	nvram set hxcli_renum="$hxcli_renum"
	if [ "$hxcli_renum" -gt "3" ] ; then
		I=19
		echo $I > $relock
		logger -t "【HX客户端】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get hxcli_renum)" = "0" ] && break
   			#[ "$(nvram get hxcli_enable)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set hxcli_renum="1"
	fi
	[ -f $relock ] && rm -f $relock
fi
start_hxcli
}

get_tag() {
	curltest=`which curl`
	logger -t "【HX客户端】" "开始获取最新版本..."
    	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
      		tag="$( wget --no-check-certificate -T 5 -t 3 --user-agent "$user_agent" --output-document=-  https://api.github.com/repos/lmq8267/vnt-cli/releases/latest 2>&1 | grep 'tag_name' | cut -d\" -f4 )"
	 	[ -z "$tag" ] && tag="$( wget --no-check-certificate -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=-  https://api.github.com/repos/lmq8267/vnt-cli/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
    	else
      		tag="$( curl -k --connect-timeout 3 --user-agent "$user_agent"  https://api.github.com/repos/lmq8267/vnt-cli/releases/latest 2>&1 | grep 'tag_name' | cut -d\" -f4 )"
       	[ -z "$tag" ] && tag="$( curl -Lk --connect-timeout 3 --user-agent "$user_agent" -s  https://api.github.com/repos/lmq8267/vnt-cli/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
        fi
	[ -z "$tag" ] && logger -t "【HX客户端】" "无法获取最新版本"  
	nvram set hxcli_ver_n=$tag
	if [ -f "$HXCLI" ] ; then
		chmod +x $HXCLI
		hxcli_ver=$($HXCLI -h | grep 'version:' | awk -F 'version:' '{print $2}' | tr -d ' ' | tr -d '\n')
		if [ -z "$hxcli_ver" ] ; then
			nvram set hxcli_ver=""
		else
			nvram set hxcli_ver="v${hxcli_ver}"
		fi
	fi
}

dowload_hxcli() {
	tag="$1"
	bin_path=$(dirname "$HXCLI")
	[ ! -d "$bin_path" ] && mkdir -p "$bin_path"
	logger -t "【HX客户端】" "开始下载 https://github.com/lmq8267/vnt-cli/releases/download/${tag}/vnt-cli_mipsel-unknown-linux-musl 到 $HXCLI"
	for proxy in $github_proxys ; do
 	length=$(wget --no-check-certificate -T 5 -t 3 "${proxy}https://github.com/lmq8267/vnt-cli/releases/download/${tag}/vnt-cli_mipsel-unknown-linux-musl" -O /dev/null --spider --server-response 2>&1 | grep "[Cc]ontent-[Ll]ength" | grep -Eo '[0-9]+' | tail -n 1)
 	length=`expr $length + 512000`
	length=`expr $length / 1048576`
 	hxcli_size0="$(check_disk_size $bin_path)"
 	[ ! -z "$length" ] && logger -t "【HX客户端】" "程序大小 ${length}M， 程序路径可用空间 ${hxcli_size0}M "
        curl -Lko "$HXCLI" "${proxy}https://github.com/lmq8267/vnt-cli/releases/download/${tag}/vnt-cli_mipsel-unknown-linux-musl" || wget --no-check-certificate -O "$VNTCLI" "${proxy}https://github.com/lmq8267/vnt-cli/releases/download/${tag}/vnt-cli_mipsel-unknown-linux-musl"
	if [ "$?" = 0 ] ; then
		chmod +x $HXCLI
		if [[ "$($HXCLI -h 2>&1 | wc -l)" -gt 3 ]] ; then
			logger -t "【HX客户端】" "HXCLI 下载成功"
			hxcli_ver=$($hxCLI -h | grep 'version:' | awk -F 'version:' '{print $2}' | tr -d ' ' | tr -d '\n')
			if [ -z "$hxcli_ver" ] ; then
				nvram set hxcli_ver=""
			else
				nvram set hxcli_ver="v${hxcli_ver}"
			fi
			break
       		else
	   		logger -t "【HX客户端】" "下载不完整，请手动下载 ${proxy}https://github.com/lmq8267/vnt-cli/releases/download/${tag}/vnt-cli_mipsel-unknown-linux-musl 上传到  $HXCLI"
	   		rm -f $VNTCLI
	  	fi
	else
		logger -t "【VNT客户端】" "下载失败，请手动下载 ${proxy}https://github.com/lmq8267/vnt-cli/releases/download/${tag}/vnt-cli_mipsel-unknown-linux-musl 上传到  $HXCLI"
   	fi
	done
}

update_hxcli() {
	get_tag
	[ -z "$tag" ] && logger -t "【HX客户端】" "无法获取最新版本" && exit 1
	tag=$(echo $tag | tr -d 'v' | tr -d ' ' | tr -d '\n')
	if [ ! -z "$tag" ] && [ ! -z "$hxcli_ver" ] ; then
		if [ "$tag"x != "$hxcli_ver"x ] ; then
			logger -t "【HX客户端】" "当前版本${hxcli_ver} 最新版本${tag}"
			dowload_hxcli $tag
		else
			logger -t "【HX客户端】" "当前已是最新版本 ${tag} 无需更新！"
		fi
	fi
	exit 0
}
scriptfilepath=$(cd "$(dirname "$0")"; pwd)/$(basename $0)
hx_keep() {
	logger -t "【HX客户端】" "守护进程启动"
	if [ -s /tmp/script/_opt_script_check ]; then
	sed -Ei '/【HX客户端】|^$/d' /tmp/script/_opt_script_check
	if [ -z "$hxcli_tunname" ] ; then
		tunname="hx-tun"
	else
		tunname="${hxcli_tunname}"
	fi
	cat >> "/tmp/script/_opt_script_check" <<-OSC
	[ -z "\`pidof hx-cli\`" ] && logger -t "进程守护" "HX客户端 进程掉线" && eval "$scriptfilepath start &" && sed -Ei '/【HX客户端】|^$/d' /tmp/script/_opt_script_check #【HX客户端】
	[ -z "\$(iptables -L -n -v | grep '$tunname')" ] && logger -t "进程守护" "hx-cli 防火墙规则失效" && eval "$scriptfilepath start &" && sed -Ei '/【HXC客户端】|^$/d' /tmp/script/_opt_script_check #【HX客户端】
	OSC
	if [ ! -z "hx_tcp_port" ] ; then
		cat >> "/tmp/script/_opt_script_check" <<-OSC
	[ -z "\$(iptables -L -n -v | grep '$hx_tcp_port')" ] && logger -t "进程守护" "hx-cli 防火墙规则失效" && eval "$scriptfilepath start &" && sed -Ei '/【HX客户端】|^$/d' /tmp/script/_opt_script_check #【HX客户端】
	OSC
	fi
	fi


}

hx_rules() {
	if [ -z "$hxcli_tunname" ] ; then
		tunname="hx-tun"
	else
		tunname="${hxcli_tunname}"
	fi
	iptables -I INPUT -i ${tunname} -j ACCEPT
	iptables -I FORWARD -i ${tunname} -o ${tunname} -j ACCEPT
	iptables -I FORWARD -i ${tunname} -j ACCEPT
	iptables -t nat -I POSTROUTING -o ${tunname} -j MASQUERADE
	[ "$hxcli_proxy" = "1" ] && sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
	if [ ! -z "$hx_tcp_port" ] ; then
		 iptables -I INPUT -p tcp --dport $vnt_tcp_port -j ACCEPT
		 ip6tables -I INPUT -p tcp --dport $vnt_tcp_port -j ACCEPT
	fi
	hx_keep
}

start_hxcli() {
	[ "$hxcli_enable" = "0" ] && exit 1
	logger -t "【HX客户端】" "正在启动hx-cli"
  	if [ -z "$HXCLI" ] ; then
  		etc_size=`check_disk_size /etc/storage`
      		if [ "$etc_size" -gt 1 ] ; then
			HXCLI=/etc/storage/bin/hx-cli
      		else
     			HXCLI=/usr/bin/hx-cli
      		else
     			HXCLI=/tmp/var/hx-cli
		fi
  		nvram set hxcli_bin=$HXCLI
    	fi
	get_tag
 	if [ -f "$HXCLI" ] ; then
		[ ! -x "$HXCLI" ] && chmod +x $HXCLI
  		[[ "$($HXCLI -h 2>&1 | wc -l)" -lt 2 ]] && logger -t "【HX客户端】" "程序${HXCLI}不完整！" && rm -rf $HXCLI
  	fi
 	if [ ! -f "$HXCLI" ] ; then
		logger -t "【HX客户端】" "主程序${HXCLI}不存在，开始在线下载..."
  		[ ! -d /etc/storage/bin ] && mkdir -p /etc/storage/bin
  		[ -z "$tag" ] && tag="v1.2.16"
  		dowload_hxcli $tag
  	fi
	sed -Ei '/【HX客户端】|^$/d' /tmp/script/_opt_script_check
	killall hx-cli >/dev/null 2>&1
	path=$(dirname "$HXCLI")
 	hxpath=$(dirname "$HXCLI")
	log_path="${path}"
	if [ "$hxcli_log" = "1" ] ; then
		
		if [ ! -f "${log_path}/log4rs.yaml" ] ; then
			mkdir -p ${log_path}
cat > "${log_path}/log4rs.yaml"<<EOF
refresh_rate: 30 seconds
appenders:
  rolling_file:
    kind: rolling_file
    path: /tmp/hx-cli.log
    append: true
    encoder:
      pattern: "{d(%Y-%m-%d %H:%M:%S vnt-cli:)} [{f}:{L}] {h({l})} {M}:{m}{n}"
    policy:
      kind: compound
      trigger:
        kind: size
        limit: 1 mb
      roller:
        kind: fixed_window
        pattern: /tmp/hx-cli.{}.log
        base: 1
        count: 2

root:
  level: info
  appenders:
    - rolling_file
EOF
		fi
		[ ! -L /tmp/hx-cli.1.log ] && ln -sf /tmp/hx-cli.log /tmp/hx-cli.1.log
		[ ! -L /tmp/hx-cli.2.log ] && ln -sf /tmp/vnt-cli.log /tmp/hx-cli.2.log
		sed -i 's|limit: 10 mb|limit: 1 mb|g' ${log_path}/log4rs.yaml
		sed -i 's|count: 5|count: 2|g' ${log_path}/log4rs.yaml
		logyaml=$(cat ${log_path}/log4rs.yaml | grep path: | awk -F'path: ' '{print $2}')
		logyaml2=$(cat ${log_path}/log4rs.yaml | grep pattern: | awk -F'pattern: ' '{print $2}')
		if [ "$logyaml" != "/tmp/hx-cli.log" ] ; then
			sed -i "s|${logyaml}|/tmp/hx-cli.log|g" ${log_path}/log4rs.yaml
			sed -i "s|${logyaml2}|/tmp/hx-cli.{}.log|g" ${log_path}/log4rs.yaml
		fi
	else
		[ -f "${log_path}/log4rs.yaml" ] && rm -f ${log_path}/log4rs.yaml
	fi
	CMD=""
	if [ "$hxcli_enable" = "1" ] ; then
	if [ -z "$hxcli_token" ] ; then
		logger -t "【HX客户端】" "识别码为必填项，不能为空！程序退出！"
		exit 1
	fi
	[ -z "$hxcli_token" ] || CMD="-k $hxcli_token"
	[ -z "$hxcli_ip" ] || CMD="${CMD} --ip ${hxcli_ip}"
	if [ ! -z "$hxcli_localadd" ] ; then
		hxcli_localadd=$(echo $hxcli_localadd | tr -d '\r')
		for localadd in $hxcli_localadd ; do
			[ -z "$localadd" ] && continue
			CMD="${CMD} -o ${localadd}"
		done	
	fi
	routenum=`nvram get hxcli_routenum_x`
	for r in $(seq 1 $routenum)
	do
		i=`expr $r - 1`
		hx_route=`nvram get hxcli_route_x$i`
		hx_ip=`nvram get hxcli_ip_x$i`
		hx_peer="${hx_route},${vnt_ip}"
		hx_peer="$(echo $hx_peer | tr -d ' ')"
		CMD="${CMD} -i ${hx_peer}"
	done
	[ -z "$hxcli_serip" ] || CMD="${CMD} -s ${hxcli_serip}"
	[ "$hxcli_model" = "1" ] && CMD="${CMD} --model xor"
	[ "$hxcli_model" = "2" ] && CMD="${CMD} --model aes_ecb"
	[ "$hxcli_model" = "3" ] && CMD="${CMD} --model chacha20"
	[ "$hxcli_model" = "4" ] && CMD="${CMD} --model chacha20_poly1305"
	[ "$hxcli_model" = "5" ] && CMD="${CMD} --model sm4_cbc"
	[ "$hxcli_model" = "6" ] && CMD="${CMD} --model aes_cbc"
	[ "$hxcli_model" = "7" ] && CMD="${CMD} --model aes_gcm"
	[ -z "$hxcli_key" ] || CMD="${CMD} -w ${hxcli_key}"
	[ "$hxcli_proxy" = "1" ] && CMD="${CMD} --no-proxy"
	[ "$hxcli_first" = "1" ] && CMD="${CMD} --first-latency"
	[ "$hxcli_wg" = "1" ] && CMD="${CMD}  --allow-wg"
	[ "$hxcli_finger" = "1" ] && CMD="${CMD} --finger"
	[ "$hxcli_serverw" = "1" ] && CMD="${CMD} -W"
	[ -z "$hxcli_desname" ] || CMD="${CMD} -n ${hxcli_desname}"
	if [ -z "$hxcli_id" ] ; then
		if [ ! -z "$hxcli_ip" ] ; then
			hxcli_id="$hxcli_ip"
			nvram set hxcli_id="$hxcli_ip"
			CMD="${CMD} -d ${$hxcli_id}"
		fi
	else
		CMD="${CMD} -d ${hxcli_id}"
	fi
	[ -z "$hxcli_tunname" ] || CMD="${CMD} --nic ${hxcli_tunname}"
	[ -z "$hxcli_mtu" ] || CMD="${CMD} -u ${hxcli_mtu}"
	
	if [ ! -z "$hxcli_dns" ] ; then
		hxcli_dns=$(echo $hxcli_dns | tr -d '\r')
		for dns in $hxcli_dns ; do
			[ -z "$dns" ] && continue
			CMD="${CMD} --dns ${dns}"
		done	
	fi
	if [ ! -z "$hxcli_stun" ] ; then
		hxcli_stun=$(echo $hxcli_stun | tr -d '\r')
		for stun in $hxcli_stun ; do
			[ -z "$stun" ] && continue
			CMD="${CMD} -e ${stun}"
		done	
	fi
	[ -z "$hxcli_port" ] || CMD="${CMD} --ports ${hxcli_port}"
	[ -z "$hxcli_wan" ] || CMD="${CMD} --local-dev ${hxcli_wan}"
	[ "$hxcli_punch" = "0" ] || CMD="${CMD} --punch ${hxcli_punch}"
	[ "$hxcli_comp" = "0" ] || CMD="${CMD} --compressor ${hxcli_comp}"
	[ "$hxcli_relay" = "0" ] || CMD="${CMD} --use-channel ${hxcli_relay}"
	mappnum=`nvram get vntcli_mappnum_x`
	for m in $(seq 1 $mappnum)
	do
		p=`expr $m - 1`
		hx_mappnet=`nvram get hxcli_mappnet_x$p`
		if [ "$hx_mappnet" = "1" ]  ; then
			hx_mappnet="udp"
		else
			hx_mappnet="tcp"
		fi
		hx_mappport=`nvram get hxcli_mappport_x$p`
		hx_mappip=`nvram get hxcli_mappip_x$p`
		hx_mapeerport=`nvram get hxcli_mapeerport_x$p`
		hx_mapping="${hx_mappnet}:0.0.0.0:${hx_mappport}-${hx_mappip}:${hx_mapeerport}"
		hx_mapping="$(echo $hx_mapping | tr -d ' ')"
		CMD="${CMD} --mapping ${hx_mapping}"
	done
	hxclicmd="cd $hxpath ; ./hx-cli ${CMD} --disable-stats >/tmp/hx-cli.log 2>&1"
	fi
	if [ "$hxcli_enable" = "2" ] ; then
		if [ -z "$(grep '^token: ' /etc/storage/hx.conf | awk -F 'token:' '{print $2}')" ] ; then
			logger -t "【HX客户端】" "Token为必填项，不能为空！程序退出！"
			exit 1
		fi
		hxclicmd="cd $hxpath ; ./hx-cli -f /etc/storage/hx.conf >/tmp/hx-cli.log 2>&1"
	
	fi
	echo "$hxclicmd" >/tmp/hx-cli.CMD 
	logger -t "【HX客户端】" "运行${hxclicmd}"
	eval "$hxclicmd" &
	sleep 4
	if [ ! -z "`pidof hx-cli`" ] ; then
 		mem=$(cat /proc/$(pidof hx-cli)/status | grep -w VmRSS | awk '{printf "%.1f MB", $2/1024}')
   		hxcpu="$(top -b -n1 | grep -E "$(pidof hx-cli)" 2>/dev/null| grep -v grep | awk '{for (i=1;i<=NF;i++) {if ($i ~ /hx-cli/) break; else cpu=i}} END {print $cpu}')"
		logger -t "【HX客户端】" "运行成功！"
  		logger -t "【HX客户端】" "内存占用 ${mem} CPU占用 ${vntcpu}%"
  		hxcli_restart o
		echo `date +%s` > /tmp/vntcli_time
		hx_rules
	else
		logger -t "【HX客户端】" "运行失败, 注意检查${HXCLI}是否下载完整,10 秒后自动尝试重新启动"
  		sleep 10
  		hxcli_restart x
	fi
	
	exit 0
}


stop_hx() {
	logger -t "【HX客户端】" "正在关闭hx-cli..."
	sed -Ei '/【HX客户端】|^$/d' /tmp/script/_opt_script_check
	scriptname=$(basename $0)
	$HXCLI --stop >>/tmp/hx-cli.log
	if [ -z "$hxcli_tunname" ] ; then
		tunname="hx-tun"
	else
		tunname="${hxcli_tunname}"
	fi
	killall hx-cli >/dev/null 2>&1
	if [ ! -z "$hx_tcp_port" ] ; then
		 iptables -D INPUT -p tcp --dport $hx_tcp_port -j ACCEPT 2>/dev/null
		 ip6tables -D INPUT -p tcp --dport $hx_tcp_port -j ACCEPT 2>/dev/null
	fi
	iptables -D INPUT -i ${tunname} -j ACCEPT 2>/dev/null
	iptables -D FORWARD -i ${tunname} -o ${tunname} -j ACCEPT 2>/dev/null
	iptables -D FORWARD -i ${tunname} -j ACCEPT 2>/dev/null
	iptables -t nat -D POSTROUTING -o ${tunname} -j MASQUERADE 2>/dev/null
	[ ! -z "`pidof hx-cli`" ] && logger -t "【HX客户端】" "进程已关闭!"
	if [ ! -z "$scriptname" ] ; then
		eval $(ps -w | grep "$scriptname" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}')
		eval $(ps -w | grep "$scriptname" | grep -v $$ | grep -v grep | awk '{print "kill -9 "$1";";}')
	fi
}

hx_error="错误：${HXCLI} 未运行，请运行成功后执行此操作！"
hx_process=$(pidof hx-cli)
hxpath=$(dirname "$HXCLI")
cmdfile="/tmp/hx-cli_cmd.log"

hx_info() {
	if [ ! -z "$hx_process" ] ; then
		cd $vntpath
		./hx-cli --info >$cmdfile 2>&1
	else
		echo "$hx_error" >$cmdfile 2>&1
	fi
	exit 1
}

hx_all() {
	if [ ! -z "$hx_process" ] ; then
		cd $vntpath
		./hx-cli --all >$cmdfile 2>&1
	else
		echo "$hx_error" >$cmdfile 2>&1
	fi
	exit 1
}

hx_list() {
	if [ ! -z "$hx_process" ] ; then
		cd $vntpath
		./hx-cli --list >$cmdfile 2>&1
	else
		echo "$hx_error" >$cmdfile 2>&1
	fi
	exit 1
}

hx_route() {
	if [ ! -z "$hx_process" ] ; then
		cd $vntpath
		./hx-cli --route >$cmdfile 2>&1
	else
		echo "$hx_error" >$cmdfile 2>&1
	fi
	exit 1
}

hx_status() {
	if [ ! -z "$vnt_process" ] ; then
		hxcpu="$(top -b -n1 | grep -E "$(pidof hx-cli)" 2>/dev/null| grep -v grep | awk '{for (i=1;i<=NF;i++) {if ($i ~ /hx-cli/) break; else cpu=i}} END {print $cpu}')"
		echo -e "\t\t vnt-cli 运行状态\n" >$cmdfile
		[ ! -z "$hxcpu" ] && echo "CPU占用 ${hxcpu}% " >>$cmdfile 2>&1
		hxram="$(cat /proc/$(pidof hx-cli | awk '{print $NF}')/status|grep -w VmRSS|awk '{printf "%.2fMB\n", $2/1024}')"
		[ ! -z "$hxram" ] && echo "内存占用 ${hxram}" >>$cmdfile 2>&1
		hxtime=$(cat /tmp/hxcli_time) 
		if [ -n "$hxtime" ] ; then
			time=$(( `date +%s`-hxtime))
			day=$((time/86400))
			[ "$day" = "0" ] && day=''|| day=" $day天"
			time=`date -u -d @${time} +%H小时%M分%S秒`
		fi
		[ ! -z "$time" ] && echo "已运行 ${day}${time}" >>$cmdfile 2>&1
		cmdtart=$(cat /tmp/hx-cli.CMD)
		[ ! -z "$cmdtart" ] && echo "启动参数  $cmdtart" >>$cmdfile 2>&1
		
	else
		echo "$hx_error" >$cmdfile
	fi
	exit 1
}

case $1 in
start)
	start_hxcli &
	;;
stop)
	stop_hx
	;;
restart)
	stop_hx
	start_hxcli &
	;;
update)
	update_hxcli &
	;;
hxinfo)
	hx_info
	;;
hxall)
	hx_all
	;;
hxlist)
	hx_list
	;;
hxroute)
	vnt_route
	;;
hxstatus)
	hx_status
	;;
*)
	echo "check"
	#exit 0
	;;
esac
