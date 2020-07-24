# bash-publisher

发布工具

# 目录结构

- ./src/archive.d 归档文件目录，存放将要发布和已经发布的，以及备份的应用文件
- ./src/conf.d 配置文件目录
- ./src/conf.d/env.d 环境和应用配置目录
- ./src/conf.d/ssh.d 服务器 SSH 配置目录
- ./src/func.d 内部方法目录
- ./src/log.d 日志文件目录
- ./src/temp.d 临时文件目录
- ./src/publisher.sh 发布脚本

# 使用方法

### 配置文件

- 将 ./src/conf.d/common.conf-example 改名为 ./src/conf.d/common.conf
    - $envNames：环境列表，默认为：dev（开发）、test（测试）、prod（生产）
    - $envNameDefault：默认的环境，$envNames 中的索引值

- 将 ./src/conf.d/env.d/[ENV].conf-example 改名为 ./src/conf.d/env.d/dev.conf
    - 文件名 dev.conf 中的 `dev` 为 common.conf 中 $envNames 列表中的某一个值
    - $appNames：应用列表，例如：("DemoApp" "DemoApp2")
    - $appNameDefault：默认的应用程序，$appNames 中的索引值
    
- 将 ./src/conf.d/env.d/[ENV].[APP].conf-example 改名为 ./src/conf.d/env.d/dev.DemoApp.conf
    - 文件名 dev.DemoApp.conf 中的 `dev` 为 common.conf 中 $envNames 列表中的某一个值
    - 文件名 dev.DemoApp.conf 中的 `DemoApp` 为 common.conf 中 $appNames 列表中的某一个值
    - $appServerHost：应用程序服务器地址
    - $appServerDir：应用程序所在服务器中的目录
    - $appBackupExclude：备份时，需要排除的文件或目录
    - $appRepoTypes：仓库类型（archive：表示归档文件路径）
    - $appRepoTypeDefault：默认的仓库类型，$appRepoTypes 中的索引值
    - $appRepo：仓库地址
    - $appRepoValueDefault：默认的仓库分支名称
    - $appInitScript：应用程序初始化脚本，如果设置了该值，而且文件存在，并且仓库类型不为 archive 时，则会执行脚本，脚本运行时会传入 $envNames 中选中的值，例如：prod
    
- 将 ./src/conf.d/ssh.d/[SERVER_HOST].conf-example 改名为 ./src/conf.d/ssh.d/10.111.222.123.conf
    - 文件名 10.111.222.123.conf 中的 `10.111.222.123` 为 dev.DemoApp.conf 中 $appServerHost 列表中的某一个值
    - $sshPort：端口号
    - $sshUsername：登录用户名
    - $sshLoginMode：登录方式，password=密码登录；privateKey=密钥登录，密码登录时推荐设置 $useExpectCmd=1
    - $sshPassword：登录密码（密钥登录时，应该是密钥路径，支持 $sshConfDir 变量，路径为 ./src/conf.d/ssh.d 目录，修改密钥文件权限：`sudo chmod 600 ./src/conf.d/ssh.d/privateKey`）
    - $useExpectCmd：当 expect 命令存在时，是否使用 expect 命令（1=是；0=否）
    - $sshTimeout：SSH 超时时间（秒），使用 expect 时，为 expect 中的超时时间
    - $scpTimeout：SCP 超时时间（秒），使用 expect 时，为 expect 中的超时时间，如果发送或下载文件超时，需要增加超时时间

### 运行脚本

- 根据提示，逐步执行

```bash
sudo bash ./src/publisher.sh
```

- 传入参数的方式

```bash
# sudo bash ./src/publisher.sh [ENV] [APP_NAME] [REPO_TYPE] [REPO_VALUE] [IS_INIT_APP] [IS_BACKUP_APP] [IS_PUBLISH_APP]

# [ENV]：需要发布到的环境名称；
# [APP_NAME]：需要发布的应用名称；
# [REPO_TYPE]：仓库类型（git, archive）；
# [REPO_VALUE]：仓库值；当 [REPO_TYPE] 为 git 时，表示分支名称；当 [REPO_TYPE] 为 archive 时，表示归档文件路径（*.tar.gz）；
# [IS_INIT_APP]：是否执行应用程序的初始化脚本（Y/N）
# [IS_BACKUP_APP]：是否备份应用程序（Y/N）
# [IS_PUBLISH_APP]：是否发布应用程序（Y/N）

# 使用 GIT 仓库中的 master 分支，将 DemoApp 应用发布到 dev 开发环境中
sudo bash ./src/publisher.sh dev DemoApp git master Y Y Y
```

### 备份应用程序

在发布时，如果选择备份应用程序，会将 $appServerHost 中的首台服务器上的程序打包，并备份到 ./src/archive.d 目录中，文件名以 backup- 开头

### Expect 命令

使用 `expect` 命令，可以实现对服务器的自动交互，在使用密码方式登录服务器时，可以自动输入配置好的密码，无需手动输入。
