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

# 切换到 vscode 用户
USER vscode
WORKDIR /home/vscode

# 创建缓存目录和符号链接
RUN mkdir -p ~/.cache-volumes/{npm,pnpm,pip,poetry,vscode-extensions,tmux/plugins,zsh} \
    && rm -rf ~/.npm \
    && rm -rf ~/.local/share/pnpm \
    && rm -rf ~/.cache/pip \
    && rm -rf ~/.cache/pypoetry \
    && rm -rf ~/.vscode-server/extensions \
    && ln -sf ~/.cache-volumes/npm ~/.npm \
    && ln -sf ~/.cache-volumes/pnpm ~/.local/share/pnpm \
    && ln -sf ~/.cache-volumes/pip ~/.cache/pip \
    && ln -sf ~/.cache-volumes/poetry ~/.cache/pypoetry \
    && ln -sf ~/.cache-volumes/vscode-extensions ~/.vscode-server/extensions

# 配置 tmux（持久化到 dev-cache）
RUN mkdir -p ~/.cache-volumes/tmux/plugins \
    && git clone https://github.com/tmux-plugins/tpm ~/.cache-volumes/tmux/plugins/tpm
COPY --chown=vscode:vscode configs/tmux.conf /home/vscode/.cache-volumes/tmux/.tmux.conf
RUN rm -rf ~/.tmux \
    && rm -rf ~/.tmux.conf \
    && ln -sf ~/.cache-volumes/tmux ~/.tmux \
    && ln -sf ~/.cache-volumes/tmux/.tmux.conf ~/.tmux.conf

# 配置 zsh（持久化到 dev-cache）
RUN mkdir -p ~/.cache-volumes/zsh/zsh-autosuggestions \
    && mkdir -p ~/.cache-volumes/zsh/zsh-syntax-highlighting \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ~/.cache-volumes/zsh/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.cache-volumes/zsh/zsh-syntax-highlighting
COPY --chown=vscode:vscode configs/zshrc-addon /tmp/zshrc-addon
RUN cat /tmp/zshrc-addon >> ~/.zshrc \
    && rm /tmp/zshrc-addon \
    && rm -rf ~/.zsh \
    && ln -sf ~/.cache-volumes/zsh ~/.zsh
