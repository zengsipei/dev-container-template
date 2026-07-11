# ADR 0001：Prebuilt Image Release Contract

- **状态**：Accepted
- **日期**：2026-06-24
- **关联**：CONTEXT.md（*Prebuilt Image* / *Startup Install* / *Release Tag* / *Latest Pointer* / *Release Trigger* / *Manual Rebuild*）、`.github/workflows/build-image.yml`、`.devcontainer/compose.yaml`、Issue #2
- **后续修订**：[ADR 0002](0002-agent-first-baseline.md) 把本 ADR「thin 慢变基线」的隐含前提由「给人用」改为「agent-first」；发布契约其余不变。[ADR 0005](0005-pull-image-derives-from-compose.md) 把消费端 pull-image.sh 改为从 compose 派生镜像标识，并扩展不变量①到三处互匹 + 防回归守卫。

本 ADR 是 Prebuilt Image 发布契约的**单一真相源**。散文文档（根 `README.md`、`devimage-build/README.md`、`.devcontainer/README.md`）只**链接**到这里，不得各自复述发布事实；`build-image.yml` 是发布**机制**的可执行真相。

## Context

一次架构审查发现"文档"与"自动化"之间存在漂移：`devimage-build/README.md` 声称镜像会在"推送到 main 分支"时构建、要求配置一个 `DOCKER_HUB_USERNAME` secret、并以 `docker/build-push-action@v5` 为例——这三点都与实际 workflow 不符；根 `README.md` 的"重新构建镜像"指引直接 `docker push :latest`（无版本 tag），与 workflow 的"先版本 tag 再 latest"模型矛盾；`workflow_dispatch` 由于用 `${github.ref_name}` 命名镜像，从 `main` 手动触发会构建 `:main` 并把 `:latest` 指过去——一个契约漏洞。此外没有任何 CI 防止这类漂移复发。

关键设计事实决定了整个契约：**Prebuilt Image 是一个被刻意做薄的慢变基线**。`Dockerfile` + Features 只烘焙慢变内容（系统工具、Node/Python/Rust/gh 运行时、git/tmux/zsh 配置）；所有快变的 **AI Agent Toolchain**（claude/codex/gemini/hapi）通过 **Startup Install** 在容器创建时 `npm install -g`，刻意**不**烘焙进镜像。因此镜像只有在改动 `Dockerfile`/Features/configs 时才需要重新发布——这是低频、有意为之的动作，而不是每次提交都要发的东西。

## Decision

1. **Release Trigger（触发）**：镜像仅由两种事件发布——push 一个 `v*` 形态的 **Release Tag**，或一次指名某个已存在 Release Tag 的 `workflow_dispatch`（**Manual Rebuild**）。**不**在 push 到 `main` 时自动发布。理由：基线慢变，发布应是版本化、有意的动作；per-commit 发布只会无谓地搅动 `:latest`。

2. **Latest 语义**：**Latest Pointer**（`:latest`）定义为"最近一个 Release Tag"的别名。**只有 Release Tag push 能移动它**。Manual Rebuild 重建指定版本的镜像，但**绝不**移动 Latest Pointer，因此不会出现 `:latest` 指向 `:main` 之类分支构建的情况。漏洞就此堵死。

3. **消费端 pin 策略**：模板默认消费 `:latest`（常见场景＝总是拿到最新基线，因波动已外移到 Startup Install，所以安全）。pin 到具体 `:vX.Y.Z` 作为**可选**项写进文档，面向需要可复现或团队统一的用户。

4. **所有权**：本 ADR 拥有持久决策与 why（单一真相源）；`build-image.yml` 是机制的可执行真相；`devimage-build/README.md` 的"发布"节是面向维护者的**唯一散文所有者**（怎么发版、怎么 Manual Rebuild）；根 `README.md`、`.devcontainer/README.md` 只保留一句话 + 链接，不复述。

5. **CI 不变量**：`scripts/check-release-contract.sh`（由 `.github/workflows/release-contract-check.yml` 在 PR/push 时运行）断言三条不变量：
   - ① `compose.yaml` 的默认镜像引用 = `build-image.yml` 的默认 `DOCKERHUB_USERNAME`/`IMAGE_NAME`；
   - ② `build-image.yml` 的 `on:` 恰为 `{ push tags 'v*', workflow_dispatch }`，且**不含** `branches:`；
   - ③ grep-guard：已退役的错误声明（main 分支触发、`DOCKER_HUB_USERNAME` secret、`docker/build-push-action`）不得在散文文档中复现。

6. **可 fork**：镜像所有者标识不再硬编码。`DOCKERHUB_USERNAME` 与 `IMAGE_NAME` 提为 GitHub repo variables（`vars.*`，带默认值 `xiao806852034` / `ai-dev-container`）；`compose.yaml` 用 docker-compose 变量替换 `${DOCKERHUB_USERNAME:-…}/${IMAGE_NAME:-…}`，由 `.devcontainer/.env` 驱动（GitHub `vars` 在本地读不到，故消费端走 `.env`）。Docker Hub access token 仍是 secret（`DOCKER_HUB_TOKEN`）。

## Consequences

- `build-image.yml`：`workflow_dispatch` 新增 required 输入 `tag`；构建版本取 `inputs.tag`（dispatch）或 `github.ref_name`（tag push）；checkout 该 tag；移动 `:latest` 的步骤加 `if: github.event_name == 'push'` 守卫；username/image 改读 `vars.*`。
- `compose.yaml`：镜像引用参数化；`.env.example` 增补 `DOCKERHUB_USERNAME`/`IMAGE_NAME` 示例。
- 文档：`devimage-build/README.md` 发布节重写为真相、修掉三处漂移；根 README 与 `.devcontainer/README.md` 的镜像章节缩为链接。
- fork 者：在 repo Settings → Variables 设 `DOCKERHUB_USERNAME`/`IMAGE_NAME`，在 `.env` 设同名变量，并配 `DOCKER_HUB_TOKEN` secret，即可发布到自己的 registry，无需改 workflow。

### 消费端拉取机制（Issue #6，已解决）

`:latest` 消费者「rebuild 如何真正拉到更新」的问题已解决，方式与本契约一致：

- 不在 `compose.yaml` 用 `pull_policy: always`——VS Code 生成临时合并 compose 时会把 service 的 `image` 改写成本地派生镜像引用，该策略会去 registry 拉一个只存在于本地的名字而失败。
- 改由 `devcontainer.json` 的 `initializeCommand` 调 `.devcontainer/pull-image.sh`，在**宿主机**上、VS Code 处理 compose / 派生构建**之前**（含每次 Rebuild）拉取真正的上游 tag；随后的派生构建 `FROM` 这个刚刷新的本地 `:latest`，于是 rebuild 跑到新发布的镜像上。
- 仅当消费 `:latest` 时拉取；pin 到 `:vX.Y.Z`（`.env` 设 `IMAGE_TAG`）的用户跳过、不被强制拉取，保持在固定 digest。拉取失败（离线）不阻塞容器创建，回退本地缓存。
- `compose.yaml` 的 tag 参数化为 `${IMAGE_TAG:-latest}`，与不变量①的 user/image 默认值检查不冲突。
