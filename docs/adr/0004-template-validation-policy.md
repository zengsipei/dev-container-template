# ADR 0004：模板验证政策——dedupe 优先于 check，三层验证

- **状态**：Accepted
- **日期**：2026-07-07
- **关联**：CONTEXT.md（*Persistence Manifest* / *Agent Home* / *Rebuildable Cache* / *Startup Install* / *Host-Backed*）、ADR 0001（release-contract CI 不变量，归入静态层）、ADR 0002（本 ADR 修订其归属表一行）、ADR 0003（§3 共享脚本、§6 文档分界）、Issue #5（本政策的探讨来源）
- **修订**：本 ADR 把 ADR 0002 归属表中「缓存持久化实现（符号链接映射）」的唯一 owner 由 `devimage-build/README.md` 改为 Dockerfile 代码注释（对齐 ADR 0003 §6）。

本 ADR 固化模板的验证政策：验证什么、在哪一层验证、以及刻意**不**验证什么。

## Context

架构审查指出模板的正确性靠人工信心维持：JSON、Compose、shell 脚本、workflow 发布行为、端口与文档分散多处，改一处没有任何东西告诉你别处断了。仓库其实已有两块验证地基——`scripts/check-release-contract.sh`（静态、每 PR/push，ADR 0001 的三条不变量）与 `image-build-check.yml`（构建、path-filter 到 `devimage-build/**`，断言 agent-first 基线与镜像层缓存链接）——但**运行时层零覆盖**：`link-agent-home.sh`、`bootstrap.sh`、`post-create.sh` 从不在 CI 里执行，#10 修掉的三个持久化 bug（漏 `.hapi`、条件链接、`ln -sf` 嵌套）全部落在这一层。

同时，探讨暴露了一类方向性问题：`devimage-build/README.md` 复述 Dockerfile 注释拥有的缓存映射，「要不要写检查器盯文档与代码的同步」摆上台面；而 ADR 0002 归属表（符号链接映射 → README）与 ADR 0003 §6（布线细节下沉代码注释）在此互相矛盾，需要裁决。

## Decision

1. **dedupe 优先于 check**：只为**不可消除的重复**写检查器——两份都必须可执行、谁也无法引用谁的事实（如 workflow 与 compose 的镜像默认值，即 ADR 0001 不变量①）。散文复述代码这类**可消除的重复**直接消除（缩为链接），不为它写同步检查器：给不该存在的重复上保险等于允许它存在。防退役谬误复活的负面 grep-guard（不变量③）不是同步检查，保留并可按需扩展。

2. **修订 ADR 0002 归属表**：「缓存持久化实现（符号链接映射）」的 owner 改为 `devimage-build/.devcontainer/Dockerfile` 的缓存布线块（代码注释），`devimage-build/README.md` 相应章节缩为链接。这是决策 1 的第一个应用，同时消除 ADR 0002 与 ADR 0003 §6 的冲突。

3. **三层验证模型**：
   - **静态层**（恒跑：本地一条命令 + CI 每 PR/push）：shellcheck、JSON/JSONC 语法校验（devcontainer.json 按 devcontainer 规范可含注释，校验器必须接受 JSONC）、`docker compose config`（两份 compose 定义）、既有 `check-release-contract.sh`（原样编排，不改动）。
   - **构建层**（CI，path-filter `devimage-build/**`）：既有 `image-build-check.yml`，不动。
   - **运行时层**（新增；CI 为主、本地可选）：agent-compose 端到端检查，见决策 5。
4. **接口 = umbrella 命令**：`scripts/check-template.sh` 按 tier 参数编排各层，CI workflow 只是薄调用方。各层检查脚本独立可跑（运行时层为 `scripts/check-runtime.sh`），umbrella 不吞并它们。
5. **运行时检查走真实路径**：fresh Agent Home 起 agent-compose 服务，等 bootstrap 完整跑完（**不**跳过、不 mock Startup Install 的 npm install），三组断言：
   - **Persistence Manifest**：清单每个 dotdir 在 `$HOME` 是指向 Agent Home 挂载的符号链接（`readlink` 精确匹配）。清单本身（链接脚本内的数组）就是断言来源——新工具进清单即自动被覆盖，检查不得自带清单副本。
   - **幂等性**：restart 让 bootstrap 在链接已存在的 FS 上重跑，再验 `readlink` 无嵌套（`ln -sf` 嵌套类 bug 只在此时暴露）。
   - **Startup Install**：共享安装清单里的 agent CLI（claude/codex/gemini）在 PATH 上。HAPI 刻意不断言——agent-compose 有意不装它（devcontainer-only，见 agent-compose README）。
6. **volume 隔离安全约束**：compose 的 volume 是固定名（`name: dev-home` / `dev-cache`），不随 compose project 前缀隔离。运行时检查**必须**：fresh home 用 Host-Backed 临时目录（`WSL_HOME=<临时目录>`）实现，teardown **永不**带 `-v`。违反任一条，本地跑检查会删掉真实登录态。

## Consequences

- 实现拆为 4 个 ready-for-agent issue：① README 缓存节 dedupe（决策 2）；② Startup Install 安装块 dedupe 为共享脚本（bootstrap 与 post-create 的三段复制是与 #10 前链接分叉同类的问题，决策 1 对脚本的应用；HAPI delta 有意保留在 post-create）；③ 运行时检查 + CI 接线（依赖②，检查只盯一份安装真相）；④ 静态层 + umbrella。
- `check-release-contract.sh` 与 `image-build-check.yml` 原样保留，前者被 umbrella 编排。
- 新工具接入的验证零边际成本：Persistence Manifest 加一行，运行时检查自动覆盖。
- **可逆性**：各层独立、可单独撤除。「不写散文同步检查器」若要翻案，须先回答「这份重复为什么不能 dedupe」。
