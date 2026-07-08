# Dev Container 运行时参考

面向日常供给与排障的 Human Supervisor:持久化、HAPI Local Hub、环境变量、端口与 FAQ 的单一所有者。

> 项目概览与快速开始见[根 README](../README.md);镜像内容与发布见 [devimage-build/README.md](../devimage-build/README.md)。

## 预装工具

### AI Agent Toolchain(Startup Install)

以下工具**不烘焙进镜像**,由 `scripts/install-agent-clis.sh`(经 `post-create.sh` 调用)在容器创建时安装/更新,始终保持最新:

- **Claude Code**(`claude`)- Anthropic 的 AI 编程助手
- **OpenAI Codex**(`codex`)- OpenAI 的代码生成工具
- **Gemini CLI**(`gemini`)- Google Gemini 命令行工具
- **HAPI**(`hapi`)- Local Hub,远程访问容器内的 coding agent(见 [HAPI Local Hub](#hapi-local-hub))

### 镜像烘焙的基线

Node.js、Python、Rust、GitHub CLI、jq/rg/fd 等慢变基线由 Prebuilt Image 提供,清单归 [devimage-build/README.md](../devimage-build/README.md#预装内容) 所有;取舍原因见 [ADR 0002](../docs/adr/0002-agent-first-baseline.md)。默认登录 shell 为 `bash`。

## 环境变量配置

### 可选:设置 WSL_HOME

**重要**:`WSL_HOME` 是可选的。即使不设置,容器也能正常启动。

**设置方式**:在 `.devcontainer/.env` 文件中设置

```bash
# 复制示例文件
cp .devcontainer/.env.example .devcontainer/.env

# 编辑 .env 文件
WSL_HOME=/home/<username>
```

**工作原理**:`WSL_HOME` 选择 Agent Home 的后端——不设即 **Volume-Backed**(named volume),设了即 **Host-Backed**(bind mount 该目录)。两种模式的语义、切换与管理见[持久化](#持久化)。compose.yaml 自动处理,无需手动创建 volume。

## 持久化

政策见 [ADR 0003](../docs/adr/0003-persistence-policy.md):**home 短命,清单点名持久**。任何状态会不会在 rebuild 后存活,只看丢失代价:

- **Agent Home**(`.claude` / `.codex` / `.gemini` / `.hapi`):丢了需要人工恢复(重登录、重配置、历史不可再生),由 Persistence Manifest 点名,符号链接进 Agent Home 后端,**rebuild 后存活**。
- **Rebuildable Cache**(包管理器缓存、VS Code 扩展):丢了只损失时间,机器自动重建,存于 `dev-cache` volume,rebuild 后存活。
- **其余一切 home 内容**(`.gitconfig`、shell 历史、临时安装的工具……):**每次 rebuild 重置到镜像基线**。这是特性而非缺陷——正因 home 短命,镜像基线的更新才能在 rebuild 时落地。

### 让一个新工具持久化

在 Persistence Manifest 加一行:编辑 [`scripts/link-agent-home.sh`](../scripts/link-agent-home.sh) 的 `PERSISTENCE_MANIFEST` 列表,加上该工具的 dotdir。判据只有一个问题——丢了要不要人工恢复?要,进清单;不要,属于 Rebuildable Cache(镜像烘焙工具的缓存链接在 Dockerfile 布线,见 ADR 0003 §4)。

### Agent Home 双后端

Agent Home 存在哪里由 `WSL_HOME` 决定(设置方式见[上文](#环境变量配置)),两种模式:

- **Volume-Backed**(默认,不设 `WSL_HOME`):存 Docker named volume `dev-home`,宿主文件系统不可见,用 `docker volume` 工具管理。适合从零开始的用户。
- **Host-Backed**(设 `WSL_HOME`):bind mount 宿主(WSL)目录。第一目的是**外部管理**——让宿主侧工具(如 Windows 上的 cc-switch 经 WSL 目录中转)切换 agent 配置;容器内外共享登录态是附带好处。模板的职责止于把目录挂进来:容器内只见纯 POSIX 目录,Windows↔WSL 的路径翻译、逐文件混搭由用户在宿主侧自行编排。

**切换不搬货**:两个后端是相互独立的存储,改 `WSL_HOME` 后重建容器只是换了存储位置,数据**不会自动迁移**——模板不对装着凭据的目录做自动搬运。需要带走登录态时手动搬:

```bash
# Volume-Backed → Host-Backed:把 volume 内容导出到 WSL 目录
docker run --rm -v dev-home:/from -v /home/<username>:/to alpine cp -a /from/. /to/

# Host-Backed → Volume-Backed:只搬清单点名的 dotdir(不要把整个 WSL home 灌进 volume;
# dotdir 清单以 scripts/link-agent-home.sh 为准,没用过的 agent 目录自动跳过)
docker run --rm -v /home/<username>:/from -v dev-home:/to alpine sh -c \
    'for d in .claude .codex .gemini .hapi; do if [ -d "/from/$d" ]; then cp -a "/from/$d" /to/; fi; done'
```

**分后端管理命令**(`docker volume` 命令只适用于 Volume-Backed):

```bash
# Volume-Backed
docker volume inspect dev-home    # 查看
docker run --rm -v dev-home:/data -v $(pwd):/backup alpine \
    tar czf /backup/dev-home.tar.gz /data    # 备份
docker volume rm dev-home         # 清空登录态(重启容器后重建为空)

# Host-Backed:就是一个普通 WSL 目录,用常规文件工具(ls / tar / rsync)管理即可
```

### Rebuildable Cache 管理

缓存存于 named volume `dev-cache`,丢了只损失重新下载的时间:

```bash
docker volume inspect dev-cache   # 查看
docker volume rm dev-cache        # 清缓存(重启容器后自动重建)
```

> 内部布局与逐条链接映射是布线细节,见 `devimage-build/.devcontainer/Dockerfile` 注释。

## HAPI Local Hub

[HAPI](https://github.com/tiann/hapi)(npm 包 `@twsxtd/hapi`)是一个让你从手机或浏览器远程访问 coding agent 的工具。本模板把它作为 **Local Hub** 运行:进程在容器内启动,可从宿主机本机访问,但**模板自身不会把它发布到 LAN 或公网**——公开访问是用户的一次有意操作。

### 行为概览

| 方面 | 做法 |
|------|------|
| 安装方式 | **Startup Install**:`post-create.sh` 里 `npm install -g @twsxtd/hapi --registry=https://registry.npmjs.org`,每次创建容器都安装/更新,保持最新(不烘焙进镜像) |
| 状态持久化 | `~/.hapi` 在 Persistence Manifest 里,与其它 agent dotdir 一致(见[持久化](#持久化)) |
| hub 启动 | 后台监听 `0.0.0.0:3006`(容器内全接口,便于 Docker 端口映射) |
| runner 启动 | hub 端口就绪后自动启动 runner,工作目录为 `/home/vscode/workspace` |
| 宿主映射 | `compose.yaml`:`127.0.0.1:3006:3006`(Host Tunnel Port,仅本机回环) |
| 端口转发 | `devcontainer.json` 的 `forwardPorts` 含 `3006` |
| 日志 | `~/.hapi/logs/hub.log`、`~/.hapi/logs/runner.log` |

### 启动流程

容器创建时,`post-create.sh`:

1. 经 `scripts/link-agent-home.sh` 链接 Agent Home(`~/.hapi` 在 Persistence Manifest 里)
2. 安装/更新 HAPI
3. 后台调用 `.devcontainer/hapi-up.sh`(不阻塞容器创建)

`hapi-up.sh` 负责实际拉起,且**幂等**:

- hub:先用 `/dev/tcp` 探测 3006 端口,已被占用则跳过启动
- runner:`hapi runner start` 会先停掉已有 runner 再启动(内置锁文件),重复运行不会产生重复进程

可手动重新拉起:

```bash
bash .devcontainer/hapi-up.sh
```

### 首次使用:配置令牌

HAPI 需要 `CLI_API_TOKEN` 才能正常工作。在容器内执行一次即可(令牌保存在 `~/.hapi`,已持久化,重建容器不丢失):

```bash
hapi auth login        # 交互式输入并保存令牌
hapi auth status       # 查看认证状态
hapi doctor            # 系统诊断
hapi runner status     # 查看 runner 状态
```

未配置令牌时 hub 可能直接退出,启动脚本仍保持非阻塞,相关信息写入 `~/.hapi/logs/hub.log`。配置好令牌后重建容器或重新运行 `hapi-up.sh` 即可。

### 自定义

通过环境变量调整(在调用 `hapi-up.sh` 前设置):

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HAPI_LISTEN_HOST` | `0.0.0.0` | hub 在容器内监听的接口 |
| `HAPI_LISTEN_PORT` | `3006` | hub 端口(同时需同步 `compose.yaml` 与 `forwardPorts`) |
| `HAPI_WORKSPACE_ROOT` | `~/workspace` | runner 创建新会话的工作目录 |

### 公开访问:宿主侧 Cloudflare Tunnel

模板只把 hub 绑定到 `127.0.0.1:3006`。若要从公网访问,在**宿主机**(不是容器内)自行配置隧道。以 Cloudflare Tunnel 为例:

```bash
# 快速试用(临时随机域名)
cloudflared tunnel --url http://127.0.0.1:3006

# 或绑定到自有域名的命名隧道
cloudflared tunnel create hapi
cloudflared tunnel route dns hapi hapi.example.com
cloudflared tunnel run --url http://127.0.0.1:3006 hapi
```

> ⚠️ 公开暴露是一次有意的用户操作,不在模板职责范围内。开启隧道前请确认已配置 `CLI_API_TOKEN` 等访问控制。

## 工作目录说明

### 项目挂载位置

项目目录通过 `compose.yaml` 手动配置挂载:

- **挂载位置**:`/home/vscode/workspace`
- **配置方式**:`compose.yaml` 中的 `..:/home/vscode/workspace`

**说明**:
- `..` 表示项目根目录(`.devcontainer` 的上级目录)
- 所有项目文件在容器内可通过 `/home/vscode/workspace` 访问

### 用户主目录

`/home/vscode` 是用户主目录。哪些内容在 rebuild 后存活由持久化政策决定,见[持久化](#持久化):Persistence Manifest 点名的 agent dotdir 与 Rebuildable Cache 存活,其余(`.gitconfig` 等)重置到镜像基线。

## 端口转发说明

### 重要:修改端口不需要重构镜像

`forwardPorts` 配置变更**不会触发镜像重建**,只会重启容器。

**原理**:
- 镜像构建:只执行 Dockerfile 和 Features
- 容器启动:读取 devcontainer.json 的运行时配置

**修改端口后**:
1. VS Code 检测到 devcontainer.json 变化
2. 自动重启容器(几秒钟)
3. 新端口立即生效

**需要重构镜像的情况**:
- 修改 Dockerfile
- 添加/删除 Features
- 修改系统包(apt-get)

## 目录结构

```
.devcontainer/
├── devcontainer.json    # 主配置(运行时配置)
├── compose.yaml         # Docker Compose 配置
├── pull-image.sh        # 宿主侧预拉取上游 :latest(由 devcontainer.json 的 initializeCommand 调用)
├── post-create.sh       # 初始化脚本(容器首次创建时执行)
├── hapi-up.sh           # HAPI Local Hub 后台拉起脚本(由 post-create.sh 调用)
├── .env.example         # 环境变量示例
└── README.md            # 本文件
```

## 预构建镜像

默认使用上游 Prebuilt Image `xiao806852034/ai-dev-container:latest`(可在 `.env` 设 `DOCKERHUB_USERNAME`/`IMAGE_NAME` 改为自己的)。镜像构建源码见 `devimage-build/` 目录。

发布行为(`:latest` 指向什么、要不要 pin 版本)由发布契约定义,见 [docs/adr/0001-image-release-contract.md](../docs/adr/0001-image-release-contract.md)。

**更新镜像(消费 `:latest`,默认)**:

无需手动 `docker pull`。每次 `Dev Containers: Rebuild Container` 前,`devcontainer.json` 的
`initializeCommand` 会在宿主侧调 `.devcontainer/pull-image.sh` 自动拉取上游 `:latest`,rebuild
即跑到最新发布的镜像。

> 为什么不用 compose 的 `pull_policy: always`:VS Code 生成临时合并 compose 时会把 `image`
> 改写成本地派生镜像引用,该策略会去 registry 拉一个本地名而失败。`initializeCommand` 在宿主机、
> 派生构建之前运行,拉的是真正的上游 tag,不受影响。脚本是 best-effort:离线拉取失败不阻塞容器创建。

```bash
# 一步:Rebuild Container(自动拉取 + 重建)
# VS Code F1 → Dev Containers: Rebuild Container
```

**pin 到具体版本(可选)**:

需要可复现 / 团队统一时,在 `.devcontainer/.env` 设 `IMAGE_TAG=vX.Y.Z`。pin 后不会被自动拉取,
容器固定在该 digest,直到改回。

## 自定义配置

### 添加新工具

**方式一:修改预构建镜像**(推荐)

编辑 `devimage-build/.devcontainer/Dockerfile`,然后重新构建镜像(注意遵守 [ADR 0002](../docs/adr/0002-agent-first-baseline.md) 的 agent-first 基线)。

**方式二:在项目中添加**

编辑 `.devcontainer/post-create.sh`,添加安装命令(Startup Install,适合需要保持最新的工具)。

### 修改资源限制

编辑 `compose.yaml`:

```yaml
services:
  devcontainer:
    deploy:
      resources:
        limits:
          memory: 16G    # 内存限制
        reservations:
          memory: 8G     # 内存预留
```

### 添加端口转发

```json
"forwardPorts": [3000, 8080, 5173, 9000]
```

修改后容器会自动重启,无需重构镜像。

## 常见问题

### Q: 脚本报错 `$'\r': command not found`?

这是 Windows CRLF 行尾问题。已在 `.gitattributes` 中配置强制 LF,但首次克隆后需要重新规范化:

```bash
# 在 WSL 中执行
cd /path/to/dev-container-template
git add .gitattributes
git rm --cached -r .
git reset --hard
```

或重新克隆仓库:

```bash
git clone https://github.com/zengsipei/dev-container-template.git
```

### Q: 文件权限问题?

容器内使用 UID 1000,确保宿主机项目目录权限匹配:
```bash
# Windows 上通常无需处理
# Linux/Mac 上:
sudo chown -R 1000:1000 your-project/
```

### Q: 性能慢?

1. 使用 named volume 存储缓存(已配置)
2. Docker Desktop 设置中使用 WSL2 后端
3. 排除项目目录的 Windows Defender 扫描

### Q: 如何更新工具?

重建容器:`F1` → `Dev Containers: Rebuild Container`。AI Agent Toolchain 是 Startup Install,每次重建都会装最新版。

### Q: 如何保留数据?

见[持久化](#持久化)。要点:项目代码在宿主机,不受容器影响;Agent Home(清单点名的 dotdir)与缓存在 rebuild 后存活;**其余 home 内容每次 rebuild 重置到镜像基线**。想让新工具的状态存活,在 Persistence Manifest 加一行即可。

### Q: WSL home 挂载失败?

检查以下几点:

1. **确认 .env 文件已创建**:
   ```bash
   ls .devcontainer/.env
   ```

2. **确认 WSL_HOME 已设置**:
   ```bash
   cat .devcontainer/.env
   ```

3. **确认 WSL 正在运行**:
   ```bash
   wsl --list --verbose
   ```

4. **确认路径正确**:
   ```bash
   # 在 WSL 中测试路径是否存在
   ls /home/<username>
   ```

如果路径不存在,检查 WSL 中的用户名是否正确。

## 团队协作

将 `.devcontainer/` 目录提交到 Git,团队成员可一键获得相同开发环境。

```bash
git add .devcontainer/
git commit -m "Add dev container configuration"
```
