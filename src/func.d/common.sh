#!/bin/bash

# author: ZhangYanJiong
# date: 2020-06-16

# 判断数组中是否存在值
function inArray(){
	local array=($1)
	local value=$2
	
	for i in "${!array[@]}"
	do
		if [ "${array[$i]}" == "$value" ]; then
			echo "true"
			return 0
		fi
	done
	
	echo "false"
	return 1
}

# 判断函数是否存在
function functionExists(){
	local name=$1
	
	if [ "`type -t $name`" == "function" ]; then
		echo "true"
		return 0
	fi
	
	echo "false"
	return 1
}

# 判断命令是否存在
function commandExists(){
	local cmd="$1"
	
	if type "$cmd" >/dev/null 2>&1; then 
		echo "true"
		return 0
	fi
	
	echo "false"
	return 1
}

# 显示红色文本
function echoRedText(){
	local message=$1
	
	echo -e "\033[31m$message\033[0m"
}

# 显示并记录错误信息
function echoError(){
	local message=$1
	local log=$2
	
	echoRedText "$message"
	
	if [ -n "$log" ]; then
		echo "$message" >> "$log"
	fi
}

# 导入文件
function importFile(){
	local file=$1
	
	# 判断需要导入的文件是否存在
	if [ -f "$file" ]; then
		# 导入文件
		. "$file"
		return 0
	fi
	
	return 1
}

# 将字符串转化为小写
function strtolower(){
	local str="$1"
	
	echo "$str" | tr 'A-Z' 'a-z'
	return 0
}

# 将字符串转化为大写
function strtoupper(){
	local str="$1"
	
	echo "$str" | tr 'a-z' 'A-Z'
	return 0
}

# 根据数组，显示选择列表，并且等待用户输入。
# 需要在方法外部定义 $answer 参数，用于接收用户输入的值。
function userSelect(){
	local list=($1)
	local prefix=$2
	local default=$3
	
	for i in "${!list[@]}"
	do
		printf "$prefix[%s] %s\n" "$i" "${list[$i]}"
	done
	
	local defaultValue="${list[$default]}"
	
	if [ -n "$defaultValue" ]; then
		echo ""
		echo -n "$prefix请输入 [0-$((${#list[@]}-1))], 默认 [$defaultValue]: "
		read answer
		
		if [ ! -n "$answer" ]; then
			answer=$default
		fi
	else
		echo ""
		echo -n "$prefix请输入 0-$((${#list[@]}-1)), 或 Enter 退出: "
		read answer
	fi
	
	if [ ! -n "$answer" ] || [ ! -n "$(echo $answer| sed -n "/^[0-9]\+$/p")" ] || [ "$answer" -lt 0 ] || [ "$answer" -gt "$((${#list[@]}-1))" ]; then
		return 1
	fi
	
	return 0
}

# 显示提示信息，并且等待用户输入。
# 需要在方法外部定义 $answer 参数，用于接收用户输入的值。
function userInput(){
	local message="$1"
	local default="$2"
	
	echo ""
	echo -n "$message"
	read answer
	
	if [ ! -n "$answer" ]; then
		answer="$default"
	fi
	
	return 0
}

# 克隆 GIT 仓库
function gitClone(){
	local repo="$1"
	local branch="$2"
	local target="$3"
	
	git clone -q -b "$branch" "$repo" "$target"
	return $?
}