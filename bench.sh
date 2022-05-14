#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE="\033[0;35m"
CYAN='\033[0;36m'
SUFFIX='\033[0m'

check_system() {
  if [ -f /etc/redhat-release ]; then
    PACKAGE_TYPE="RPM"
  elif grep -qi 'alpine' /etc/issue; then
    PACKAGE_TYPE="APK"
  elif grep -qi 'debian\|ubuntu' /etc/issue; then
    PACKAGE_TYPE="DEB"
  elif grep -qi 'centos\|red hat\|redhat' /etc/issue; then
    PACKAGE_TYPE="RPM"
  elif grep -qi 'alpine' /proc/version; then
    PACKAGE_TYPE="APK"
  elif grep -qi 'debian\|ubuntu' /proc/version; then
    PACKAGE_TYPE="DEB"
  elif grep -qi 'centos\|red hat\|redhat' /proc/version; then
    PACKAGE_TYPE="RPM"
  else
    echo -e "${RED}Warning: Unknown package management${SUFFIX}"
  fi
}

curl_setup() {
  if type curl > /dev/null 2>&1; then return; fi
  echo -n "Installing curl..."
  if [ $EUID -ne 0 ]; then
    echo -e "\n${RED}Error: You must be root user${SUFFIX}"
    exit 1
  fi
  if [ "${PACKAGE_TYPE}" == "RPM" ]; then
    yum update > /dev/null 2>&1 && yum -y install curl > /dev/null 2>&1
  elif [ "${PACKAGE_TYPE}" == "DEB" ]; then
    apt update > /dev/null 2>&1 && apt -y install curl > /dev/null 2>&1
  elif [ "${PACKAGE_TYPE}" == "APK" ]; then
    apk update > /dev/null 2>&1 && apk add curl > /dev/null 2>&1
  else
    echo -e "\n${RED}Error: Unknown package management${SUFFIX}"
    echo -e "Please install ${YELLOW}curl${SUFFIX} manual"
    exit 1
  fi
  if type curl > /dev/null 2>&1; then
    echo -e "${GREEN}OK${SUFFIX}"
  else
    echo -e "${RED}ERROR${SUFFIX}"
    exit 1
  fi
}

speedtest_setup() {
  [[ -e './st-temp/speedtest' ]] && return
  echo -n "Getting speedtest-cli..."
  user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.54"
  html=$(curl -sL "https://www.speedtest.net/apps/cli" --user-agent "${user_agent}")
  version=$(echo "$html" | grep -oP 'ookla-speedtest-.*?-' | head -n 1 | cut -b 17- | rev | cut -c 2- | rev)
  url="https://install.speedtest.net/app/cli/ookla-speedtest-${version}-linux-$(uname -m).tgz"
  mkdir ./st-temp/ && cd ./st-temp || exit 1
  curl "${url}" -o ./speedtest.tgz > /dev/null 2>&1
  tar xf ./speedtest.tgz speedtest && rm -f ./speedtest.tgz
  cd ../
  if [ -e './st-temp/speedtest' ]; then
    echo -e "${GREEN}OK${SUFFIX}"
  else
    echo -e "${RED}ERROR${SUFFIX}"
    exit 1
  fi
}

server_list() {
  echo -n "Getting server list..."
  rm -f ./st-temp/*.list
  curl -sL "https://st.343.re/cn/ALL.list" > ./st-temp/ALL.list
  curl -sL "https://st.343.re/cn/DX.list" > ./st-temp/DX.list
  curl -sL "https://st.343.re/cn/LT.list" > ./st-temp/LT.list
  curl -sL "https://st.343.re/cn/YD.list" > ./st-temp/YD.list
  [[ ! -e './st-temp/ALL.list' ]] && echo -e "${RED}ERROR${SUFFIX}" && clear_env && exit 2
  [[ ! -e './st-temp/DX.list' ]] && echo -e "${RED}ERROR${SUFFIX}" && clear_env && exit 2
  [[ ! -e './st-temp/LT.list' ]] && echo -e "${RED}ERROR${SUFFIX}" && clear_env && exit 2
  [[ ! -e './st-temp/YD.list' ]] && echo -e "${RED}ERROR${SUFFIX}" && clear_env && exit 2
  echo -e "${GREEN}OK${SUFFIX}"
}

load_servers() {
  local dat
  while read -r line
  do
    dat=(${line//,/ })
    id_arr[${#id_arr[@]}+1]=${dat[0]}
    addr_arr[${#addr_arr[@]}+1]=${dat[1]}
    isp_arr[${#isp_arr[@]}+1]=${dat[2]}
  done <<< "$(cat "$1")"
  server_num=${#id_arr[@]}
}

select_isp() {
  echo -e "${GREEN}1.${SUFFIX} 三网测速"
  echo -e "${GREEN}2.${SUFFIX} 电信节点"
  echo -e "${GREEN}3.${SUFFIX} 联通节点"
  echo -e "${GREEN}4.${SUFFIX} 移动节点"
  echo -e "${GREEN}5.${SUFFIX} 国内测速"
  echo -e "${GREEN}0.${SUFFIX} 取消测速\c"
  while :; do echo
    read -rp "请选择: " selection
    if [[ ! $selection =~ ^[0-5]$ ]]; then
      echo -e "${RED}输入无效${SUFFIX}\c"
    else
      break
    fi
  done
  [[ ${selection} == 0 ]] && clear_env && exit 1
  [[ ${selection} == 1 ]] && load_servers './st-temp/ALL.list'
  [[ ${selection} == 2 ]] && load_servers './st-temp/DX.list'
  [[ ${selection} == 3 ]] && load_servers './st-temp/LT.list'
  [[ ${selection} == 4 ]] && load_servers './st-temp/YD.list'
  [[ ${selection} == 4 ]] && load_servers './st-temp/CN.list'
}

speedtest() {
  speed_log="./st-temp/speedtest.log"
  LANG=C
  echo -e "\r\c"
  touch $speed_log
  node_loc="$2　　　　　　"
  ./st-temp/speedtest -p no -s "$1" --accept-license > $speed_log 2>&1
  if grep 'Upload' "$speed_log" > /dev/null 2>&1; then
    latency=$(awk -F " " '/Latency/{print $2}' "$speed_log")
    download=$(awk -F " " '/Download/{print $3}' "$speed_log")
    upload=$(awk -F " " '/Upload/{print $3}' "$speed_log")
    temp=$(echo "${download}" | awk -F ' ' '{print $1}')
    if [[ $(awk -v num1="${temp}" -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
      printf "${RED}%-6s${YELLOW}%s%s${GREEN}%-24s${CYAN}%s%-10s${BLUE}%s%-10s${PURPLE}%-8s${SUFFIX}\n" \
        "$1" "$3" "|" "${node_loc:0:24}" "↑ " "${upload}" "↓ " "${download}" "${latency}"
    fi
  else
    printf "${RED}%-6s${YELLOW}%s%s${GREEN}%-24s${RED}%s${SUFFIX}\n" "$1" "$3" "|" "${node_loc:0:24}" "ERROR"
  fi
}

start_test() {
  echo -e "\033[?25l\c"
  echo "——————————————————————————————————————————————————————————"
  curl "ip.343.re/info"
  echo "——————————————————————————————————————————————————————————"
  echo "ID    测速服务器信息       上传/Mbps   下载/Mbps   延迟/ms"
  start=$(date +%s)
  for ((i=1; i<=server_num; i++)) do
    echo -e "正在测试 ${YELLOW}${isp_arr[i]}|${SUFFIX}${GREEN}${addr_arr[i]}${SUFFIX} ...\c"
    speedtest "${id_arr[i]}" "${addr_arr[i]}" "${isp_arr[i]}"
  done
  end=$(date +%s)
  echo "——————————————————————————————————————————————————————————"
  time=$((end - start))
  if [[ $time -gt 60 ]]; then
    min=$(expr $time / 60)
    sec=$(expr $time % 60)
    echo -e "测试完成, 共耗时${CYAN} ${min} 分 ${sec} 秒${SUFFIX}"
  else
    echo -e "测试完成, 共耗时${CYAN} ${time} 秒${SUFFIX}"
  fi
  echo -e "\033[?25h"
}

clear_env() {
  rm -rf ./st-temp
}

check_system
curl_setup
speedtest_setup
server_list
select_isp
clear
start_test
clear_env
