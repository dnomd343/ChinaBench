#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE="\033[0;35m"
CYAN='\033[0;36m'
PLAIN='\033[0m'

check_root(){
    [[ $EUID -ne 0 ]] && echo -e "${RED}请切换为root用户执行${PLAIN}" && exit 1
}

check_system() {
    if [ -f /etc/redhat-release ]; then
        package_type="RPM"
    elif cat /etc/issue | grep -Eqi "debian"; then
        package_type="DEB"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        package_type="DEB"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        package_type="RPM"
    elif cat /proc/version | grep -Eqi "debian"; then
        package_type="DEB"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        package_type="DEB"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        package_type="RPM"
    fi
}

python_setup() {
    [[ -e '/usr/bin/python' ]] && return
    echo -e "正在安装Python...\c"
    if [ "${package_type}" == "RPM" ]; then
        yum update > /dev/null 2>&1
        yum -y install python > /dev/null 2>&1
    else
        apt-get update > /dev/null 2>&1
        apt-get -y install python > /dev/null 2>&1
    fi
    if [ -e '/usr/bin/python' ]; then
        echo -e "${GREEN}OK${PLAIN}"
    else
        echo -e "${RED}ERROR${PLAIN}"
        exit 1
    fi
}

curl_setup() {
    [[ -e '/usr/bin/curl' ]] && return
    echo -e "正在安装Curl...\c"
    if [ "${package_type}" == "RPM" ]; then
        yum update > /dev/null 2>&1
        yum -y install curl > /dev/null 2>&1
    else
        apt-get update > /dev/null 2>&1
        apt-get -y install curl > /dev/null 2>&1
    fi
    if [ -e '/usr/bin/curl' ]; then
        echo -e "${GREEN}OK${PLAIN}"
    else
        echo -e "${RED}ERROR${PLAIN}"
        exit 1
    fi
}

wget_setup() {
    [[ -e '/usr/bin/wget' ]] && return
    echo -e "正在安装Wget...\c"
    if [ "${package_type}" == "RPM" ]; then
        yum update > /dev/null 2>&1
        yum -y install wget > /dev/null 2>&1
    else
        apt-get update > /dev/null 2>&1
        apt-get -y install wget > /dev/null 2>&1
    fi
    if [ -e '/usr/bin/wget' ]; then
        echo -e "${GREEN}OK${PLAIN}"
    else
        echo -e "${RED}ERROR${PLAIN}"
        exit 1
    fi
}

speedtest_setup() {
    [[ -e './st-temp/speedtest' ]] && return
    echo -e "正在获取Speedtest-cli...\c"
    mkdir -p ./st-temp/speedtest-cli
    wget --no-check-certificate -qO ./st-temp/speedtest.tgz https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-$(uname -m)-linux.tgz > /dev/null 2>&1
    tar zxvf ./st-temp/speedtest.tgz -C ./st-temp/speedtest-cli/ > /dev/null 2>&1
    mv ./st-temp/speedtest-cli/speedtest ./st-temp/speedtest-cli/speedtest.5 ./st-temp/
    chmod a+rx ./st-temp/speedtest
    rm -rf ./st-temp/speedtest.tgz ./st-temp/speedtest-cli
    if [ -e './st-temp/speedtest' ]; then
        echo -e "${GREEN}OK${PLAIN}"
    else
        echo -e "${RED}ERROR${PLAIN}"
        clear_env
        exit 1
    fi
}

get_server() {
	echo -e "正在获取服务器列表...\c"
	rm -f ./st-temp/ALL.dat
	rm -f ./st-temp/DX.dat
	rm -f ./st-temp/LT.dat
	rm -f ./st-temp/YD.dat
    wget -P ./st-temp/ https://st.343.re/cn/ALL.dat > /dev/null 2>&1
	wget -P ./st-temp/ https://st.343.re/cn/DX.dat > /dev/null 2>&1
	wget -P ./st-temp/ https://st.343.re/cn/LT.dat > /dev/null 2>&1
	wget -P ./st-temp/ https://st.343.re/cn/YD.dat > /dev/null 2>&1
    [[ ! -e './st-temp/ALL.dat' ]] && echo -e "${RED}ERROR${PLAIN}" && clear_env && exit 1
	[[ ! -e './st-temp/DX.dat' ]] && echo -e "${RED}ERROR${PLAIN}" && clear_env && exit 1
    [[ ! -e './st-temp/LT.dat' ]] && echo -e "${RED}ERROR${PLAIN}" && clear_env && exit 1
    [[ ! -e './st-temp/YD.dat' ]] && echo -e "${RED}ERROR${PLAIN}" && clear_env && exit 1
	echo -e "${GREEN}OK${PLAIN}"
}

load_server() {
    local dat
    while read temp_line
    do
        dat=(${temp_line//,/ })
        id_arr[${#id_arr[@]}+1]=${dat[0]}
        addr_arr[${#addr_arr[@]}+1]=${dat[1]}
        isp_arr[${#isp_arr[@]}+1]=${dat[2]}
    done <<< "$(cat $1)"
    server_num=${#id_arr[@]}
}

select_isp() {
    echo -e "${GREEN}1.${PLAIN} 三网测速"
    echo -e "${GREEN}2.${PLAIN} 电信节点"
    echo -e "${GREEN}3.${PLAIN} 联通节点"
    echo -e "${GREEN}4.${PLAIN} 移动节点"
    echo -e "${GREEN}5.${PLAIN} 取消测速\c"
    while :; do echo
		read -p "请选择: " selection
		if [[ ! $selection =~ ^[1-5]$ ]]; then
			echo -e "${RED}输入无效${PLAIN}\c"
		else
			break   
	    fi
	done
	[[ ${selection} == 5 ]] && clear_env && exit 1
	[[ ${selection} == 1 ]] && load_server './st-temp/ALL.dat'
	[[ ${selection} == 2 ]] && load_server './st-temp/DX.dat'
	[[ ${selection} == 3 ]] && load_server './st-temp/LT.dat'
	[[ ${selection} == 4 ]] && load_server './st-temp/YD.dat'
}

speedtest() {
    speedLog="./st-temp/speedtest.log"
	touch $speedLog
    ./st-temp/speedtest -p no -s $1 --accept-license > $speedLog 2>&1
    echo -en "\r"
    echo -en "                                                          "
    echo -en "\r"
    is_upload=$(cat $speedLog | grep 'Upload')
    if [[ ${is_upload} ]]; then
        local REDownload=$(cat $speedLog | awk -F ' ' '/Download/{print $3}')
        local reupload=$(cat $speedLog | awk -F ' ' '/Upload/{print $3}')
        local relatency=$(cat $speedLog | awk -F ' ' '/Latency/{print $2}')
        local nodeID=$1
        local nodeLocation=$2
        local nodeISP=$3
        strnodeLocation="${nodeLocation}　　　　　　"
        LANG=C
        temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
            printf "${RED}%-6s${YELLOW}%s%s${GREEN}%-24s${CYAN}%s%-10s${BLUE}%s%-10s${PURPLE}%-8s${PLAIN}\n" "${nodeID}"  "${nodeISP}" "|" "${strnodeLocation:0:24}" "↑ " "${reupload}" "↓ " "${REDownload}" "${relatency}" | tee -a $log
        fi
    else
        local cerror="ERROR"
    fi
}

runtest() {
    echo -en "\033[?25l"
    echo "——————————————————————————————————————————————————————————"
    curl "ip.343.re/info"
    echo "——————————————————————————————————————————————————————————"
    echo "ID    测速服务器信息       上传/Mbps   下载/Mbps   延迟/ms"
    start=$(date +%s)
	for ((i=1;i<=$server_num;i++)) do
        echo -e "正在测试 ${YELLOW}${isp_arr[i]}|${PLAIN}${GREEN}${addr_arr[i]}${PLAIN} ...\c"
        speedtest  ${id_arr[i]} ${addr_arr[i]} ${isp_arr[i]}
	done
    end=$(date +%s)
    echo "——————————————————————————————————————————————————————————"
    time=$(( $end - $start ))
    if [[ $time -gt 60 ]]; then
        min=$(expr $time / 60)
        sec=$(expr $time % 60)
        echo -e "测试完成, 共耗时${CYAN} ${min} 分 ${sec} 秒${PLAIN}"
    else
        echo -e "测试完成, 共耗时${CYAN} ${time} 秒${PLAIN}"
    fi
    echo -e "\033[?25h"
}

clear_env() {
    rm -rf ./st-temp
}

init() {
	check_root
	check_system
	python_setup
	curl_setup
	wget_setup
	speedtest_setup
	get_server
}

main() {
	init
	select_isp
	clear
	runtest
    clear_env
}

main
