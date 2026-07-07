# agent-compose —— 不用 devcontainer 跑 coding agent

用纯 Docker Compose 在 Prebuilt Image 里运行 claude / codex / gemini 这类 coding agent,**不依赖 VS Code devcontainer**。适合:

- 只想在终端里跑 agent,不开 VS Code
- 在服务器 / CI 等没有 devcontainer 工具链的环境复用同一套镜像
- 同时给多个项目各起一个 agent 容器

复用与 `.devcontainer/` 相同的镜像和同名 volume(`dev-home` / `dev-cache`),因此 **agent 登录态与缓存两边共享**——在 devcontainer 里登录过的 claude,这里直接可用,反之亦然。持久化语义(哪些状态存活、双后端、如何加新工具)归 [.devcontainer/README.md 的「持久化」](../.devcontainer/README.md#持久化)所有。

## 使用

```bash
cd agent-compose

# （可选）配置目标项目目录等
cp .env.example .env

docker compose up -d          # 启动并完成 Startup Install
docker compose exec agent claude   # 或 codex / gemini / bash
docker compose down           # 用完关掉
```

首次 `up` 时引导脚本(`bootstrap.sh`)会安装缺失的 agent CLI(Startup Install,镜像刻意不烘焙,见 [ADR 0001](../docs/adr/0001-image-release-contract.md)),并经共享的 Persistence Manifest 脚本(`scripts/link-agent-home.sh`)链接 Agent Home——与 devcontainer 完全同一份链接逻辑,详见[持久化](../.devcontainer/README.md#持久化)。

## 换一个项目

编辑 `.env` 的 `WORKSPACE_DIR` 指向目标项目,然后 `docker compose up -d --force-recreate`。

要同时跑多个项目,用 `-p` 起独立实例:

```bash
WORKSPACE_DIR=/path/to/app docker compose -p agent-app up -d
docker compose -p agent-app exec agent claude
```

## 更新镜像

这里没有 devcontainer 的 `initializeCommand` 自动拉取(那是给 VS Code rebuild 用的,见 [ADR 0001](../docs/adr/0001-image-release-contract.md)),手动拉:

```bash
docker compose pull && docker compose up -d --force-recreate
```

pin 版本:`.env` 里设 `IMAGE_TAG=vX.Y.Z`。

## 与 `.devcontainer/` 的关系

| | `.devcontainer/` | `agent-compose/` |
|---|---|---|
| 入口 | VS Code Reopen in Container | `docker compose up -d` |
| 镜像 | 同一个 Prebuilt Image | 同一个 Prebuilt Image |
| Agent 登录态 | `dev-home` volume | 同一个 `dev-home` volume |
| 缓存 | `dev-cache` volume | 同一个 `dev-cache` volume |
| Startup Install | `post-create.sh`(含 HAPI Local Hub) | `bootstrap.sh`(仅 agent CLI) |

> HAPI Local Hub 属于 devcontainer 工作流,本目录不拉起;需要时进容器手动 `npm i -g @twsxtd/hapi` 使用。
