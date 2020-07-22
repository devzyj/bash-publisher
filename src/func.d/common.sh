#!/bin/bash

# link: https://github.com/devzyj/bash-publisher
# author: JerryZhang <zhangyanjiong@163.com>

# 判断数组中是否存在值
inArray(){
    local -a array="($1)"
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
functionExists(){
    local name=$1
    
    if [ "`type -t $name`" == "function" ]; then
        echo "true"
        return 0
    fi
    
    echo "false"
    return 1
}

# 判断命令是否存在
commandExists(){
    local cmd="$1"
    
    if type "$cmd" >/dev/null 2>&1; then 
        echo "true"
        return 0
    fi
    
    echo "false"
    return 1
}

# 显示红色文本
echoRedText(){
    local message=$1
    local log=$2
    
    echo -e "\033[31m$message\033[0m"
    
    if [ -n "$log" ]; then
        echo "$message" >> "$log"
    fi
}

# 显示并记录错误信息
echoError(){
    local message=$1
    local log=$2
    
    echoRedText "$message" "$log"
}

# 导入文件
importFile(){
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
strtolower(){
    local str="$1"
    
    echo "$str" | tr 'A-Z' 'a-z'
    return 0
}

# 将字符串转化为大写
strtoupper(){
    local str="$1"
    
    echo "$str" | tr 'a-z' 'A-Z'
    return 0
}

# 根据数组，显示选择列表，并且等待用户输入。
# 需要在方法外部定义 $answer 参数，用于接收用户输入的值。
userSelect(){
    local -a list="($1)"
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
userInput(){
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
gitClone(){
    local repo="$1"
    local branch="$2"
    local target="$3"
    
    git clone -q -b "$branch" "$repo" "$target"
    return $?
}

# SSH
funcSSH(){
    local useExpectCmd=$1
    local timeout="$2"
    local command="$3"
    local host="$4"
    local username="$5"
    local password="$6"
    local mode="$7"
    local port="$8"
    
    # 端口为空时设置默认值
    if [ ! -n "$port" ]; then
        local port=22
    fi

    # 使用 expect 命令
    if [ $useExpectCmd -eq 1 ]; then
        local ret=`commandExists "expect"`
        if [ "$ret" == "true" ]; then
            $funcDir/ssh.expect "$timeout" "$command" "$host" "$username" "$password" "$mode" "$port" >> "$runtimeLogPath" 2>&1
            return $?
        fi
    fi
    
    # 使用 ssh 命令
    # 判断登录方式
    if [ "$mode" == "privateKey" ]; then
        # 使用密钥登录
        ssh -o ConnectTimeout=$timeout -p $port -i $password -l $username $host "$command"
        return $?
    fi
    
    # 使用密码登录
    ssh -o ConnectTimeout=$timeout -p $port -l $username $host "$command"
    return $?
}

# SCP
funcSCP(){
    local useExpectCmd=$1
    local timeout="$2"
    local source="$3"
    local target="$4"
    local password="$5"
    local mode="$6"
    local port="$7"
    
    # 端口为空时设置默认值
    if [ ! -n "$port" ]; then
        local port=22
    fi

    # 使用 expect 命令
    if [ $useExpectCmd -eq 1 ]; then
        local ret=`commandExists "expect"`
        if [ "$ret" == "true" ]; then
            $funcDir/scp.expect "$timeout" "$source" "$target" "$password" "$mode" "$port" >> "$runtimeLogPath" 2>&1
            return $?
        fi
    fi
    
    # 使用 scp 命令
    # 判断登录方式
    if [ "$mode" == "privateKey" ]; then
        # 使用密钥登录
        scp -r -o ConnectTimeout=$timeout -P $port -i $password $source $target
        return $?
    fi
    
    # 使用密码登录
    scp -r -o ConnectTimeout=$timeout -P $port $source $target
    return $?
}