# Dev Container Template

通用开发容器模板,预装 AI Agent Toolchain,完全隔离于 Windows/WSL 环境。容器是 **Agent-Operated** 的:主要由 AI coding agent 运行,人只负责供给和监督(见 [ADR 0002](docs/adr/0002-agent-first-baseline.md))。

> 本文档是项目地图与最短上手路径。运行时细节见 [.devcontainer/README.md](.devcontainer/README.md),镜像与发布见 [devimage-build/README.md](devimage-build/README.md)。

## 目录结构

```
dev-container-template/
├── .devcontainer/              # 使用模板(最终用户)
│   ├── devcontainer.json       # 主配置
│   ├── compose.yaml            # Docker Compose 配置
│   ├── pull-image.sh           # 宿主侧预拉取上游 :latest(initializeCommand 调用)
│   ├── post-create.sh          # 初始化脚本
│   ├── hapi-up.sh              # HAPI Local Hub 后台拉起脚本
│   ├── .env.example            # 环境变量示例
│   └── README.md               # 运行时参考(持久化、HAPI、FAQ)
│
├── devimage-build/             # 镜像构建源码(维护者向)
│   └── .devcontainer/
│       ├── Dockerfile          # 镜像定义
│       └── devcontainer.json   # Features 配置
│
├── docs/adr/                   # 架构决策记录
└── .github/workflows/          # 镜像构建与发布(Release Tag 契约)
```

## 快速开始

1. 用 VS Code 打开此目录
2. 安装扩展:`ms-vscode-remote.remote-containers`
3. 按 `F1` → `Dev Containers: Reopen in Container`
4. 等待镜像拉取完成(首次约 1-2 分钟)

使用 Prebuilt Image `xiao806852034/ai-dev-container:latest`,无需本地构建。

**可选**:绑定 WSL 中已有的 AI agent 配置(`.claude`、`.codex` 等)——在 `.devcontainer/.env` 设置 `WSL_HOME`,详见 [环境变量配置](.devcontainer/README.md#环境变量配置)。

## 里面有什么

- **AI Agent Toolchain**(Startup Install,容器创建时装最新版):Claude Code、OpenAI Codex、Gemini CLI、HAPI——详见 [.devcontainer/README.md](.devcontainer/README.md#预装工具)
- **镜像烘焙的慢变基线**(Node.js、Python、Rust、GitHub CLI、jq/rg/fd 等):清单归 [devimage-build/README.md](devimage-build/README.md#预装内容);为什么只烘焙这些,见 [ADR 0002](docs/adr/0002-agent-first-baseline.md)
- **持久化**:缓存与 AI agent 配置存放在 named volume,重建容器不丢失——详见 [配置管理](.devcontainer/README.md#配置管理)

## HAPI Local Hub

HAPI 让你从手机/浏览器远程访问容器里的 coding agent。模板把它作为 **Local Hub** 运行:仅绑定宿主机回环(`127.0.0.1:3006`),**模板自身不会把它暴露到 LAN 或公网**——公开暴露(如 Cloudflare Tunnel)是用户的一次有意操作。

安装、令牌配置、公开访问等全部细节见 [HAPI Local Hub](.devcontainer/README.md#hapi-local-hub)。

## 镜像构建与发布

预构建镜像源码在 `devimage-build/`,通过 GitHub Actions 按 Release Tag 契约发布(push `v*` tag 即构建并移动 `:latest`)。

契约的持久决策见 [ADR 0001](docs/adr/0001-image-release-contract.md);维护者发版操作见 [devimage-build/README.md](devimage-build/README.md#发布release)。

## 隔离说明

此容器完全独立于 Windows 环境、WSL 发行版和其他 Docker 容器:不污染宿主机,不受宿主机软件版本影响。

遇到问题?排障 FAQ 见 [.devcontainer/README.md](.devcontainer/README.md#常见问题)。
