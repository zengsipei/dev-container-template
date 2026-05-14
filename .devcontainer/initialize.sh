#!/bin/bash
# Dev Container 初始化脚本
# 在构建前执行，根据 WSL_HOME 环境变量创建 dev-home volume

set -e

echo "🔧 Initializing Dev Container..."

# ============================================
# 从 .env 文件读取环境变量
# ============================================
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
    echo "📄 Loading environment from .env file..."
    # 导出 .env 中的变量（忽略注释和空行）
    set -a
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$')
    set +a
fi

# 调试：显示 WSL_HOME 值
echo "🔍 WSL_HOME value: '${WSL_HOME:-<not set>}'"

# ============================================
# 检查 dev-home volume 是否已存在
# ============================================
if docker volume inspect dev-home &>/dev/null; then
    echo "ℹ️  dev-home volume already exists, skipping creation"
    echo "   To recreate, run: docker volume rm dev-home"
    echo "✅ Initialization complete"
    exit 0
fi

# ============================================
# dev-home 不存在，根据 WSL_HOME 创建
# ============================================
if [ -n "$WSL_HOME" ] && [ -d "$WSL_HOME" ]; then
    echo "📦 WSL_HOME detected: $WSL_HOME"
    echo "   Creating bind-mount volume..."
    
    # 创建 bind mount volume（指向 WSL_HOME）
    docker volume create \
        --driver local \
        --opt type=none \
        --opt device="$WSL_HOME" \
        --opt o=bind \
        dev-home
    
    echo "✅ dev-home volume created (bind mount to $WSL_HOME)"
else
    echo "📦 No WSL_HOME provided, creating regular volume..."
    
    # 创建普通 named volume
    docker volume create dev-home
    
    echo "✅ dev-home volume created (regular volume)"
fi

echo "✅ Initialization complete"
