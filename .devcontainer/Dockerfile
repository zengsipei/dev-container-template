FROM mcr.microsoft.com/devcontainers/base:ubuntu

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装系统依赖（Features 未覆盖的工具）
RUN apt-get update && apt-get install -y \
    jq \
    ripgrep \
    fd-find \
    bat \
    eza \
    htop \
    tree \
    tmux \
    xclip \
    && rm -rf /var/lib/apt/lists/*

# 配置 Git（避免 Windows 换行符问题）
RUN git config --global core.autocrlf input \
    && git config --global init.defaultBranch main \
    && git config --global pull.rebase false
