# bash-publisher

发布工具

# 安装

```bash
composer create-project --prefer-dist devzyj/bash-publisher publisher
```

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
    - $envNames：环境列表，使用空格分隔多个，默认为：dev(开发)、test(测试)、prod(生产)
    - $appNames：应用列表，使用空格分隔多个，需要修改成项目名称，例如：("DemoApp" "DemoApp2")

- 将 ./src/conf.d/env.d/env.conf-example 改名为 ./src/conf.d/env.d/dev.conf
    - 文件名 dev.conf 中的 `dev` 为 common.conf 中 $envNames 列表中的某一个值
    - 修改 dev.conf 文件用于覆盖 common.conf 中的配置内容

- 将 ./src/conf.d/env.d/env.app.conf-example 改名为 ./src/conf.d/env.d/dev.DemoApp.conf
    - 文件名 dev.DemoApp.conf 中的 `dev` 为 common.conf 文件内 $envNames 列表中的某一个值
    - 文件名 dev.DemoApp.conf 中的 `DemoApp` 为 common.conf 文件内 $appNames 列表中的某一个值
    - $appServerHost：应用程序服务器地址，使用空格分隔多个
    - $appServerDir：应用程序所在服务器中的目录
    - $appBackupExclude：备份时，需要排除的文件或目录，使用空格分隔多个
    - $appRepo：应用程序仓库地址
    - $appInitScript：应用程序初始化脚本，如果不为空，并且文件存在，则运行脚本

### 运行脚本

```bash
sudo sh ./src/publisher.sh
```

- 使用传参方式

```bash
# sudo sh ./src/publisher.sh [ENV] [APP_NAME] [REPO_TYPE] [REPO_VALUE] [IS_INIT_APP] [IS_BACKUP_APP] [IS_PUBLISH_APP]

# [ENV]：需要发布到的环境名称；
# [APP_NAME]：需要发布的应用名称；
# [REPO_TYPE]：仓库类型（git, archive）；
# [REPO_VALUE]：仓库值；当 [REPO_TYPE] 为 git 时，表示分支名称；当 [REPO_TYPE] 为 archive 时，表示归档文件路径（*.tar.gz）；
# [IS_INIT_APP]：是否执行应用程序的初始化脚本（Y/N）
# [IS_BACKUP_APP]：是否备份应用程序（Y/N）
# [IS_PUBLISH_APP]：是否发布应用程序（Y/N）

# 使用 GIT 仓库中的 master 分支，将 DemoApp 应用发布到 dev 开发环境中
sudo sh ./src/publisher.sh dev DemoApp git master Y Y Y
```

### 备份应用程序

在发布时，如果选择备份应用程序，会将 $appServerHost 中的首台服务器上的程序打包，并备份到 ./archive.d 目录中，文件名以 backup- 开头
