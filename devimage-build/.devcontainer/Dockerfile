FROM mcr.microsoft.com/devcontainers/base:ubuntu

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装系统依赖（Features 未覆盖的工具）
# fd-find 的二进制名为 fdfind；符号链接为 fd，便于 agent 与 Human Supervisor 直接调用
RUN apt-get update && apt-get install -y \
    jq \
    ripgrep \
    fd-find \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# 配置 Git（避免 Windows 换行符问题）
RUN git config --global core.autocrlf input \
    && git config --global init.defaultBranch main \
    && git config --global pull.rebase false

# 切换到 vscode 用户
USER vscode
WORKDIR /home/vscode

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
