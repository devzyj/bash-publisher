#!/bin/bash

# link: https://github.com/devzyj/bash-publisher
# author: JerryZhang <zhangyanjiong@163.com>

# 处理 键盘终端 的退出信号 
trap 'exitScript 1' SIGINT

# 脚本版本号
version="1.0"

# 脚本所在目录的绝对路径
rootDir=$(dirname $(readlink -f $0))

# 函数库目录
funcDir="$rootDir/func.d"

# 函数文件路径
funcPath="$funcDir/common.sh"

# 配置文件目录
confDir="$rootDir/conf.d"

# 配置文件路径
confPath="$confDir/common.conf"

# 环境配置目录
envConfDir="$confDir/env.d"

# SSH 配置目录
sshConfDir="$confDir/ssh.d"

# 临时文件目录
tempDir="$rootDir/temp.d"

# 归档文件目录
archiveDir="$rootDir/archive.d"

# 日志目录
logDir="$rootDir/log.d"

# 运行日志文件路径
runtimeLogPath="$logDir/runtime.log"

# 发布环境
envName=$1

# 应用名称
appName=$2

# 仓库类型
repoType=$3

# 仓库值
# repoType = git 或 svn 时，表示分支或标签名称
# repoType = archive 时，表示归档文件路径，支持的文件类型：tar.gz
repoValue=$4

# 是否执行应用程序的初始化脚本（Y/N）
isInitApp=$5

# 是否备份应用程序（Y/N）
isBackupApp=$6

# 是否发布应用程序（Y/N）
isPublishApp=$7

# 本次发布的临时目录
publishTempDir=""

# 需要发布的文件名称
releaseName=""

# 需要发布的文件路径
releasePath=""

# 方法：退出脚本
exitScript(){
    local code=$1
    local before="exitScriptBefore"
    
    if [ ! -n "$code" ]; then
        local code=0
    fi
    
    if [ "`type -t $before`" == "function" ]; then
        # 退出前的回调方法
        $before $code
    fi
    
    exit $code
}

# 方法：退出脚本前的回调
exitScriptBefore(){
    local code=$1
    
    # 删除临时目录
    if [ -d "$publishTempDir" ]; then
        echo ""
        echo "  删除临时目录 ..." | tee -a "$runtimeLogPath"
        rm -rf "$publishTempDir" >> "$runtimeLogPath" 2>&1
    fi
    
    echo ""
    echo "################################## 退出 [$code] - $(date "+%Y-%m-%d %H:%M:%S") ###################################" | tee -a "$runtimeLogPath"
    echo ""
}

# 方法：脚本入口
main(){
    echo "" | tee -a "$runtimeLogPath"
    echo "############################ 应用程序发布工具 v$version - $(date "+%Y-%m-%d %H:%M:%S") ############################" | tee -a "$runtimeLogPath"

    # 初始化
    init
    
    # 确定发布环境
    ensureEnv

    # 确定应用程序
    ensureApp

    # 确定仓库类型
    ensureRepoType

    # 确定仓库值
    ensureRepoValue

    # 准备发布内容
    preparePublish
    
    # 确认发布信息
    confirmPublishMessage
    
    # 发布应用程序
    publishApplication
}

# 方法：初始化
init(){
    # 判断函数文件是否存在
    if [ ! -f "$funcPath" ]; then
        local errorMsg="  ERROR：'$funcPath' 不存在。"
        echo ""
        echo -e "\033[31m$errorMsg\033[0m"
        echo "$errorMsg" >> "$runtimeLogPath"
        exitScript 1
    fi
    
    # 导入函数文件
    . "$funcPath"
    
    # 检查 `expect` 函数是否存在
    local ret=`commandExists "expect"`
    if [ "$ret" != "true" ]; then
        echo ""
        echoError "  ERROR：命令 'expect' 不存在。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 导入配置文件
    importFile "$confPath"
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：配置文件 '$confPath' 不存在。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 创建存放临时文件的目录
    if [ ! -d "$tempDir" ]; then
        mkdir "$tempDir"
    fi
}

# 方法：确定发布环境
ensureEnv(){
    if [ ! -n "$envName" ]; then
        echo ""
        echo "  ------------------------------"
        echo "  您想发布应用程序到哪个环境中？"
        
        # 显示并选择环境
        echo ""
        userSelect "${envNames[*]}" "  " "$envNameDefault"
        if [ $? -ne 0 ]; then
            exitScript 1
        fi
        
        # 用户选择的环境
        envName=${envNames[$answer]}
    fi
    
    # 判断环境名称是否存在
    local result=`inArray "${envNames[*]}" "$envName"`
    if [ "$result" != "true" ]; then
        echo ""
        echoError "  ERROR：不支持 '$envName' 环境。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 导入环境配置文件
    local envConfPath="$envConfDir/$envName.conf"
    importFile "$envConfPath"
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：环境配置文件 '$envConfPath' 不存在。" "$runtimeLogPath"
        exitScript 1
    fi
}

# 方法：确定应用程序
ensureApp(){
    if [ ! -n "$appName" ]; then
        echo ""
        echo "  ----------------------"
        echo "  您想发布哪个应用程序？"

        # 显示并选择应用程序
        echo ""
        userSelect "${appNames[*]}" "  " "$appNameDefault"
        if [ $? -ne 0 ]; then
            exitScript 1
        fi

        # 用户选择的应用程序
        appName="${appNames[$answer]}"
    fi
    
    # 判断应用名称是否存在
    local result=`inArray "${appNames[*]}" "$appName"`
    if [ "$result" != "true" ]; then
        echo ""
        echoError "  ERROR：不支持 '$appName' 应用程序。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 导入应用程序配置文件
    local appConfPath="$envConfDir/$envName.$appName.conf"
    importFile "$appConfPath"
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：应用程序配置文件 '$appConfPath' 不存在。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 判断配置参数
    if [ ! -n "$appServerHost" ]; then
        echo ""
        echoError "  ERROR：未配置应用程序 '$appName' 的服务器地址。" "$runtimeLogPath"
        exitScript 1
    elif [ ! -n "$appServerDir" ]; then
        echo ""
        echoError "  ERROR：未配置应用程序 '$appName' 的所在目录。" "$runtimeLogPath"
        exitScript 1
    fi
}

# 方法：确定仓库类型
ensureRepoType(){
    if [ ! -n "$repoType" ]; then
        echo ""
        echo "  ----------------------"
        echo "  您想使用哪种版本控制？"

        # 显示并选择仓库类型
        echo ""
        userSelect "${repoTypes[*]}" "  " "$repoTypeDefault"
        if [ $? -ne 0 ]; then
            exitScript 1
        fi

        # 用户选择的仓库类型
        repoType="${repoTypes[$answer]}"
    fi
    
    # 判断仓库类型是否存在
    local result=`inArray "${repoTypes[*]}" "$repoType"`
    if [ "$result" != "true" ]; then
        echo ""
        echoError "  ERROR：不支持 '$repoType' 仓库类型。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 应用程序仓库
    if [ "$repoType" != "archive" ]; then
        if [ ! -n "$appRepo" ]; then
            echo ""
            echoError "  ERROR：未配置应用程序 '$appName' 的仓库地址。" "$runtimeLogPath"
            exitScript 1
        fi
    fi
}

# 方法：确定仓库值
ensureRepoValue(){
    if [ ! -n "$repoValue" ]; then
        if [ "$repoType" == "archive" ]; then
            echo ""
            echo "  ------------------------------"
            echo "  您想使用哪个归档文件进行发布？"
            
            # 用户输入，归档文件路径
            userInput "  请输入 [文件路径], 或 Enter 退出: "
            repoValue="$answer"
            if [ ! -n "$repoValue" ]; then
                exitScript 1
            fi
        else
            echo ""
            echo "  --------------------------"
            echo "  您想使用哪个分支进行发布？"
            
            # 用户输入，分支名称
            userInput "  请输入 [分支名称], 默认 [$repoValueDefault]: " "$repoValueDefault"
            repoValue="$answer"
        fi
    fi
    
    if [ "$repoType" == "archive" ]; then
        # 判断归档文件是否存在
        if [ ! -f "$repoValue" ]; then
            local archivePath="$archiveDir/$repoValue"
            if [ ! -f "$archivePath" ]; then
                echo ""
                echoError "  ERROR：归档文件 '$repoValue' 不存在。" "$runtimeLogPath"
                exitScript 1
            fi
            
            repoValue="$archivePath"
        fi
    fi
}

# 方法：准备发布内容
preparePublish(){
    # 本次发布的临时目录
    publishTempDir="$tempDir/$(date "+%Y%m%d%H%M%S")"
    
    # 创建本次发布的临时目录
    if [ ! -d $publishTempDir ]; then
        mkdir $publishTempDir
    fi
    
    # 根据不同的仓库类型进行操作
    if [ "$repoType" == "archive" ]; then
        # 使用归档文件准备发布内容
        preparePublishByArchive
    elif [ "$repoType" == "git" ]; then
        # 使用 GIT 仓库准备发布内容
        preparePublishByGit
    else
        echo ""
        echoError "  ERROR：不支持的仓库类型。" "$runtimeLogPath"
        exitScript 1
    fi
}

# 方法：使用归档文件准备发布内容
preparePublishByArchive(){
    local atchive="$repoValue"
    local packageName="${atchive##*/}"
    local packagePath="$archiveDir/$packageName"
    
    # 拷贝文件
    if [ "$packagePath" != "$atchive" ]; then
        echo ""
        echo "  拷贝归档文件 ..." | tee -a "$runtimeLogPath"
        \cp -rfv "$atchive" "$packagePath" >> "$runtimeLogPath" 2>&1
        if [ $? -ne 0 ]; then
            echo ""
            echoError "  ERROR: 拷贝归档文件失败。" "$runtimeLogPath"
            exitScript 1
        fi
    fi
    
    # 设置需要发布的文件
    releaseName="$packageName"
    releasePath="$packagePath"
}

# 方法：使用 GIT 仓库准备发布内容
preparePublishByGit(){
    local repoUrl="$appRepo"
    local branch="$repoValue"
    local initScript="$appInitScript"
    local packageName="$appName-$envName-$branch"
    local packageExtension=".tar.gz"
    local packageFilename="$packageName""$packageExtension"
    local packagePath="$archiveDir/$packageFilename"
    
    # clone 仓库
    echo ""
    echo "  克隆 Git 存储库 ..." | tee -a "$runtimeLogPath"
    gitClone "$repoUrl" "$branch" "$publishTempDir" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR: 克隆 Git 存储库失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 进入仓库目录
    cd "$publishTempDir"
    
    # 归档仓库
    echo ""
    echo "  归档存储库 ..." | tee -a "$runtimeLogPath"
    local archiveFolder="$packageName-archive"
    local archiveFilename="$archiveFolder""$packageExtension"
    git archive --prefix="$archiveFolder/" -o "$archiveFilename" "$branch"
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR: 归档存储库失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 解压归档文件
    echo ""
    echo "  解压归档文件 ..." | tee -a "$runtimeLogPath"
    tar -xzf "$archiveFilename"
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR: 解压归档文件失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 解压后的归档目录
    local archiveDir="$publishTempDir/$archiveFolder"
    
    # 应用程序初始化脚本路径
    local initScriptPath="$archiveDir/$initScript"
    
    # 判断应用程序初始化脚本是否存在
    if [ -f "$initScriptPath" ]; then
        if [ ! -n "$isInitApp" ]; then
            # 提示用户是否执行初始化脚本
            echo ""
            echo "  --------------------------------------------"
            userInput "  是否执行初始化脚本 '$initScriptPath'? [Y/n] " "Y"
            isInitApp=`strtoupper "$answer"`
        fi
        
        if [ "$isInitApp" == "YES" ] || [ "$isInitApp" == "Y" ]; then
            # 执行应用程序初始化脚本
            echo ""
            echo "  执行应用程序初始化脚本 ..." | tee -a "$runtimeLogPath"
            sh "$initScriptPath" "$envName" >> "$runtimeLogPath" 2>&1
            if [ $? -ne 0 ]; then
                echo ""
                echoError "  ERROR: 应用程序初始化失败。" "$runtimeLogPath"
                exitScript 1
            fi
        fi
    fi
    
    # 进入解压后的归档目录
    cd "$archiveDir"
    
    # 打包文件
    echo ""
    echo "  打包文件 ..." | tee -a "$runtimeLogPath"
    tar -czf "$packagePath" * >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR: 打包文件失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 设置需要发布的文件
    releaseName="$packageName"
    releasePath="$packagePath"
}

# 方法：确认发布信息
confirmPublishMessage(){
    echo ""
    echo "  ------------------ 发布信息 ------------------" | tee -a "$runtimeLogPath"
    echo ""
    echoRedText "      环境名称：$envName" "$runtimeLogPath"
    echoRedText "      应用名称：$appName" "$runtimeLogPath"
    echoRedText "    应用服务器：${appServerHost[*]}" "$runtimeLogPath"
    echoRedText "      应用目录：$appServerDir" "$runtimeLogPath"
    echoRedText "      仓库类型：$repoType" "$runtimeLogPath"
    
    if [ "$repoType" != "archive" ]; then
        echoRedText "      仓库地址：$appRepo" "$runtimeLogPath"
        echoRedText "  仓库分支名称：$repoValue" "$runtimeLogPath"
    else
        echoRedText "  归档文件路径：$repoValue" "$runtimeLogPath"
    fi
    
    echoRedText "       Release：$releasePath" "$runtimeLogPath"
    
    echo ""
    echo "  ------------------ 发布信息 ------------------" | tee -a "$runtimeLogPath"
}

# 方法：发布应用程序
publishApplication(){
    # 循环测试 SSH 连接
    for i in "${!appServerHost[@]}" 
    do
        testSSH "${appServerHost[$i]}"
    done
    
    # 循环发布到远程
    for i in "${!appServerHost[@]}" 
    do
        local serverHost="${appServerHost[$i]}"
        
        # 导入服务器配置文件
        local sshConfPath="$sshConfDir/$serverHost.conf"
        importFile "$sshConfPath"
        if [ $? -ne 0 ]; then
            echo ""
            echoError "  ERROR：服务器配置文件 '$sshConfPath' 不存在。" "$runtimeLogPath"
            exitScript 1
        fi
        
        if [ $i -eq 0 ]; then
            if [ ! -n "$isBackupApp" ]; then
                # 首个服务器时，询问是否需要备份应用程序
                echo ""
                echo "  -----------------------------------------------"
                userInput "  是否从 $serverHost 备份应用程序到本地? [Y/n] " "Y"
                isBackupApp=`strtoupper "$answer"`
            fi
            
            if [ "$isBackupApp" == "YES" ] || [ "$isBackupApp" == "Y" ]; then
                # 从指定服务器上，备份应用程序到本地
                backupApplicationFromServer "$serverHost"
                if [ $? -ne 0 ]; then
                    echo ""
                    echoError "  ERROR：备份应用程序失败。" "$runtimeLogPath"
                    exitScript 1
                fi
            else
                echo ""
                echo "  取消备份！" | tee -a "$runtimeLogPath"
            fi
            
            if [ ! -n "$isPublishApp" ]; then
                # 首个服务器时，询问是否开始发布应用程序
                echo ""
                echo "  ----------------------------"
                userInput "  是否开始发布应用程序? [y/N] " "N"
                isPublishApp=`strtoupper "$answer"`
            fi
            
            if [ "$isPublishApp" != "YES" ] && [ "$isPublishApp" != "Y" ]; then
                echo ""
                echo "  取消发布！" | tee -a "$runtimeLogPath"
                exitScript 1
            fi
        fi
        
        # 发布应用程序到指定的服务器
        publishApplicationToServer "$serverHost"
    done
    
    # 成功发布应用程序到所有服务器
    echo ""
    echo "  成功发布应用程序到所有服务器！" | tee -a "$runtimeLogPath"
}

# 方法：测试 SSH 连接
testSSH(){
    local serverHost="$1"
    
    # 导入服务器配置文件
    local sshConfPath="$sshConfDir/$serverHost.conf"
    importFile "$sshConfPath"
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：服务器配置文件 '$sshConfPath' 不存在。" "$runtimeLogPath"
        exitScript 1
    fi
    
    local loginMode="$sshLoginMode"
    local username="$sshUsername"
    local password="$sshPassword"
    local port="$sshPort"
    
    echo ""
    echo "  测试 $serverHost 连接 ..." | tee -a "$runtimeLogPath"
    $funcDir/ssh.expect "$sshTimeout" " " "$serverHost" "$username" "$password" "$loginMode" "$port" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：测试 $serverHost 连接失败。" "$runtimeLogPath"
        exitScript 1
    fi
}

# 方法：从指定服务器上，备份应用程序到本地
backupApplicationFromServer(){
    local serverHost="$1"
    local loginMode="$sshLoginMode"
    local username="$sshUsername"
    local password="$sshPassword"
    local port="$sshPort"
    local appDir="$appServerDir"
    local time="$(date "+%Y%m%d%H%M%S")"
    local backupName="backup-$appName-$envName-$time.tar.gz"
    local backupPath="/tmp/$backupName"
    
    echo ""
    echo "  开始从 $serverHost 备份应用程序到本地 ..." | tee -a "$runtimeLogPath"
    
    # 打包文件命令
    local tarCommand="sudo tar -czf \"$backupPath\""
    
    # 添加打包时需要排除的文件或目录
    if [ -n "$appBackupExclude" ]; then
        for i in "${!appBackupExclude[@]}"
        do
            local tarCommand="$tarCommand --exclude=\"${appBackupExclude[$i]}\""
        done
    fi
    
    local tarCommand="$tarCommand *"
    
    # 需要在远程服务器上执行的命令
    local command="cd \"$appDir\" ; $tarCommand ;"
    
    # 在远程服务器上打包备份应用程序
    echo ""
    echo "  打包 $serverHost 中的应用程序 ..." | tee -a "$runtimeLogPath"
    $funcDir/ssh.expect "$sshTimeout" "$command" "$serverHost" "$username" "$password" "$loginMode" "$port" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：打包 $serverHost 中的应用程序失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 拷贝远程服务器上的备份文件到本地
    echo ""
    echo "  下载 $serverHost 中打包好的文件 ..." | tee -a "$runtimeLogPath"
    local source="$username@$serverHost:$backupPath"
    local target="$archiveDir/$backupName"
    $funcDir/scp.expect "$scpTimeout" "$source" "$target" "$password" "$loginMode" "$port" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：下载 $serverHost 中打包好的文件失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 在远程服务器上删除备份文件
    echo ""
    echo "  删除 $serverHost 中打包好的文件 ..." | tee -a "$runtimeLogPath"
    local command="sudo rm -f $backupPath"
    $funcDir/ssh.expect "$sshTimeout" "$command" "$serverHost" "$username" "$password" "$loginMode" "$port" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：删除 $serverHost 中打包好的文件失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 备份成功
    echo ""
    echo "  备份应用程序成功：$target" | tee -a "$runtimeLogPath"
    return 0
}

# 方法：发布应用程序到指定的服务器
publishApplicationToServer(){
    local serverHost="$1"
    local loginMode="$sshLoginMode"
    local username="$sshUsername"
    local password="$sshPassword"
    local port="$sshPort"
    local appDir="$appServerDir"
    local releaseName="$releaseName"
    local releasePath="$releasePath"
    
    echo ""
    echo "  开始发布应用程序到 $serverHost ..." | tee -a "$runtimeLogPath"
    
    # 拷贝需要发布的文件到远程服务器
    echo ""
    echo "  发送文件到 $serverHost ..." | tee -a "$runtimeLogPath"
    local source="$releasePath"
    local targetPath="/tmp/$releaseName"
    local target="$username@$serverHost:$targetPath"
    $funcDir/scp.expect "$scpTimeout" "$source" "$target" "$password" "$loginMode" "$port" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：发送文件到 $serverHost 失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 解压 发送到远程服务器的文件
    echo ""
    echo "  解压发送到 $serverHost 的文件 ..." | tee -a "$runtimeLogPath"
    local command="sudo tar -xzf $targetPath -C $appDir"
    $funcDir/ssh.expect "$sshTimeout" "$command" "$serverHost" "$username" "$password" "$loginMode" "$port" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：解压发送到 $serverHost 的文件失败。" "$runtimeLogPath"
        exitScript 1
    fi
    
    # 删除 发送到远程服务器的文件
    echo ""
    echo "  删除发送到 $serverHost 的文件 ..." | tee -a "$runtimeLogPath"
    local command="sudo rm -f $targetPath"
    $funcDir/ssh.expect "$sshTimeout" "$command" "$serverHost" "$username" "$password" "$loginMode" "$port" >> "$runtimeLogPath" 2>&1
    if [ $? -ne 0 ]; then
        echo ""
        echoError "  ERROR：删除发送到 $serverHost 的文件失败。" "$runtimeLogPath"
    fi
    
    # 发布到远程服务器成功
    echo ""
    echo "  发布应用程序到 $serverHost 成功！" | tee -a "$runtimeLogPath"
    return 0
}

# 执行脚本入口方法
main

# 退出发布脚本
exitScript 0