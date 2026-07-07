# 裸 Debian 基线（ADR 0002 agent-first）：不用 devcontainers/base:*——那一族预烘焙了
# common-utils 默认配置，自带 zsh / oh-my-zsh / htop / tree 等交互工效层。
# devcontainer 必需品（sudo、用户配置等）由 common-utils Feature 在此镜像之上补齐。
FROM debian:trixie-slim

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装系统依赖：agent 与 Human Supervisor 双方都需要的工具，
# 以及 Features 安装脚本运行所需的基础组件（ca-certificates / curl）
# fd-find 的二进制名为 fdfind；符号链接为 fd，便于 agent 与 Human Supervisor 直接调用
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    jq \
    ripgrep \
    fd-find \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# 裸基础镜像没有非 root 用户；先建 vscode（uid/gid 1000），
# common-utils Feature 检测到同名用户已存在时会原样采用并补上 sudo 配置
RUN groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash vscode

# 切换到 vscode 用户
USER vscode
WORKDIR /home/vscode

# 配置 Git（避免 Windows 换行符问题）；须在 USER vscode 之后执行，
# 否则写入的是 /root/.gitconfig，对实际运行用户无效
RUN git config --global core.autocrlf input \
    && git config --global init.defaultBranch main \
    && git config --global pull.rebase false

# 创建缓存目录和符号链接（包管理器缓存持久化到 dev-cache volume）
RUN mkdir -p ~/.cache-volumes/npm \
    && mkdir -p ~/.cache-volumes/pnpm \
    && mkdir -p ~/.cache-volumes/pip \
    && mkdir -p ~/.cache-volumes/poetry \
    && mkdir -p ~/.cache-volumes/vscode-extensions \
    && mkdir -p ~/.local/share ~/.cache ~/.vscode-server \
    && ln -sf ~/.cache-volumes/npm ~/.npm \
    && ln -sf ~/.cache-volumes/pnpm ~/.local/share/pnpm \
    && ln -sf ~/.cache-volumes/pip ~/.cache/pip \
    && ln -sf ~/.cache-volumes/poetry ~/.cache/pypoetry \
    && ln -sf ~/.cache-volumes/vscode-extensions ~/.vscode-server/extensions
