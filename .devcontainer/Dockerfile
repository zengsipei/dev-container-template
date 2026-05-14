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

# 配置 tmux
RUN git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm \
    && echo "set -g @plugin 'tmux-plugins/tpm'" > ~/.tmux.conf \
    && echo "set -g @plugin 'tmux-plugins/tmux-sensible'" >> ~/.tmux.conf \
    && echo "set -g mouse on" >> ~/.tmux.conf \
    && echo "set -g prefix C-a" >> ~/.tmux.conf \
    && echo "bind C-a send-prefix" >> ~/.tmux.conf

# 配置 zsh 插件
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting

RUN echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> ~/.zshrc \
    && echo 'alias ll="exa -la"' >> ~/.zshrc \
    && echo 'alias cat="bat"' >> ~/.zshrc \
    && echo 'alias find="fd"' >> ~/.zshrc \
    && echo 'alias grep="rg"' >> ~/.zshrc
