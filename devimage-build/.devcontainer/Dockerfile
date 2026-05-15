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
    && mkdir -p ~/.local/share/pnpm \
    && mkdir -p ~/.cache/pip \
    && mkdir -p ~/.cache/pypoetry \
    && mkdir -p ~/.vscode-server/extensions \
    && ln -sf ~/.cache-volumes/npm ~/.npm \
    && ln -sf ~/.cache-volumes/pnpm ~/.local/share/pnpm \
    && ln -sf ~/.cache-volumes/pip ~/.cache/pip \
    && ln -sf ~/.cache-volumes/poetry ~/.cache/pypoetry \
    && ln -sf ~/.cache-volumes/vscode-extensions ~/.vscode-server/extensions

# 配置 tmux（持久化到 dev-cache）
# 先在目标目录操作，最后创建符号链接
RUN mkdir -p ~/.cache-volumes/tmux/plugins \
    && git clone https://github.com/tmux-plugins/tpm ~/.cache-volumes/tmux/plugins/tpm \
    && cat > ~/.cache-volumes/tmux/.tmux.conf << 'EOF'
# tmux 基础配置
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# 启用鼠标
set -g mouse on

# 修改前缀键为 Ctrl-a
set -g prefix C-a
bind C-a send-prefix

# 分屏快捷键
bind | split-window -h
bind - split-window -v

# 窗口导航
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
EOF
    && ln -sf ~/.cache-volumes/tmux ~/.tmux \
    && ln -sf ~/.cache-volumes/tmux/.tmux.conf ~/.tmux.conf

# 配置 zsh（持久化到 dev-cache）
# 先在目标目录操作，最后创建符号链接
RUN mkdir -p ~/.cache-volumes/zsh/zsh-autosuggestions \
    && mkdir -p ~/.cache-volumes/zsh/zsh-syntax-highlighting \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ~/.cache-volumes/zsh/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.cache-volumes/zsh/zsh-syntax-highlighting \
    && cat >> ~/.zshrc << 'EOF'

# zsh 主题（随机）
ZSH_THEME="random"

# zsh 插件
plugins=(git z sudo zsh-autosuggestions zsh-syntax-highlighting)

# 实用别名
alias ll="eza -la"
alias bat="batcat"
alias cat="bat"
alias find="fd"
alias grep="rg"

# tmux 快捷键
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'
alias tk='tmux kill-session -t'
EOF
    && ln -sf ~/.cache-volumes/zsh ~/.zsh

# 安装 AI Agents
RUN npm install -g @anthropic-ai/claude-code \
    && npm install -g @openai/codex \
    && npm install -g @google/gemini-cli
