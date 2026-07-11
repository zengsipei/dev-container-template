# ADR 0005：pull-image.sh 从 compose 派生镜像标识

- **状态**：Accepted
- **日期**：2026-07-11
- **关联**：[ADR 0001](0001-image-release-contract.md)（镜像标识默认值单一真相源）、[ADR 0004](0004-template-validation-policy.md)（决策 1：可消除的重复直接消除，不上保险）、`.devcontainer/pull-image.sh`、`.devcontainer/compose.yaml`、`agent-compose/compose.yaml`、`.github/workflows/build-image.yml`
- **后续修订**：本 ADR 是 ADR 0001 在消费端的实现细节，不另行修订。

本 ADR 消除 ADR 0001 在「消费端（宿主侧拉取脚本）」落地的最后一处**可消除重复**：pull-image.sh 曾自带一份
`DEFAULT_USER/DEFAULT_IMAGE/DEFAULT_TAG` 默认值字面量，与 build-image.yml、两份 compose.yaml 共**四处**声明
镜像标识默认值；而 check-release-contract.sh 的不变量①只守护 workflow↔compose 两处，pull-image.sh 那份
**完全无守护**——全新克隆在宿主侧会静默按这份字面量拉错 Latest Pointer。

## Context

ADR 0001 早已把镜像标识默认值定为单一真相源，但「默认值存在哪」与「谁守护它」并不等价：

- `build-image.yml`（`env: vars.IMAGE_NAME || 'ai-dev-container'` / `vars.DOCKERHUB_USERNAME || 'xiao806852034'`）是一处声明；
- `.devcontainer/compose.yaml` 与 `agent-compose/compose.yaml` 各用 `${IMAGE_NAME:-ai-dev-container}` / `${DOCKERHUB_USERNAME:-xiao806852034}` 声明，是**不可消除**的重复（两份 compose 分处不同目录，compose 变量替换必须在内联写 `:-` 默认值，无法跨文件共享），故按 ADR 0004 决策 1 应**守卫**而非消除；
- `pull-image.sh` 的 `DEFAULT_*` 则是**可消除**的重复：它在宿主机运行（`devcontainer.json` 的 `initializeCommand`），仓库就在手边，能直接读到 `.devcontainer/compose.yaml`，无需自己再存一份默认值。

原脚本用一份手搓的 `read_env`（grep `.env`）+ 三级回退（`env > .env > 默认值`）拼出 `USER/IMAGE:TAG`，逻辑比「让 compose 自己解析」更复杂，且无任何自动覆盖。这是典型的「为假想的灵活性手写解析器」——违反 AGENTS.md 的简洁优先与 ADR 0004 决策 1。

## Decision

1. **pull-image.sh 不再自带默认值，改从 compose 派生**：用
   `REF="$(docker compose -f "$SCRIPT_DIR/compose.yaml" config --images | head -n1)"`
   让 compose 自己的解析器落定 `${...:-}` 默认值。`.devcontainer/compose.yaml` 成为镜像标识的**唯一**
   默认值源；fork / 改默认值只需改 compose 一处。

2. **派生失败 best-effort 非阻塞**：docker 缺失、compose 解析报错或输出为空时，打印一条警告并跳过本次
   拉取、回退本地缓存——**不留任何残留字面量**，保持「单一真相源」纯粹，也与原有契约（拉取失败不阻塞容器创建）一致。

3. **pin-skip 挂在 ref 末段**：`TAG="${REF##*:}"`，仅 `latest` 才拉；`image@sha256:...` 的 digest pin 也落入
   「非 latest」分支而跳过。不再有独立的 `IMAGE_TAG` 读取路径，单一来源贯通到 tag 判定。

4. **不变量①扩展到三处互匹**：check-release-contract.sh 现在断言 build-image.yml ↔ `.devcontainer/compose.yaml`
   ↔ `agent-compose/compose.yaml` 三处默认值全部相等，填补原来 agent-compose 完全未守护的缺口。

5. **新增防回归守卫**（不变量①b）：grep 检查 pull-image.sh 不得出现 `DEFAULT_(USER|IMAGE|TAG)=` 赋值。
   与 ADR 0001 不变量③（防退役声明复发）同构——把「已消除的重复」钉死，防止未来编辑悄悄加回字面量。

6. **首个自动测试**：`scripts/check-template.sh` 的 static tier 新增一条——`PULL_IMAGE_DRYRUN=1` 跑
   pull-image.sh，断言其打印的 ref 等于 `docker compose config --images` 的输出。这是 pull-image.sh 第一次
   有自动覆盖，也锁住了「派生与 compose 一致」。

## Consequences

- `.devcontainer/pull-image.sh`：删除 `DEFAULT_*` 字面量、`read_env`、`ENV_FILE` 与三级回退；行为语义（仅 latest
  拉取、best-effort、DRYRUN）完全不变，故是运行时无感改动。
- `scripts/check-release-contract.sh`：不变量①扩到三处互匹；新增不变量①b 防回归 grep。
- `scripts/check-template.sh`：static tier 新增 DRYRUN 一致性断言。
- 真值分布收敛为：1 处可执行默认值（compose.yaml）+ 1 处机制（build-image.yml，同样读 `vars.*`）+ 守卫。
  pull-image.sh 从「第四份声明点（且无守护）」变为「消费方（派生，无声明）」。
