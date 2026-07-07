# ADR 0003：持久化政策——home 短命，清单点名持久

- **状态**：Accepted
- **日期**：2026-07-07
- **关联**：CONTEXT.md（*Agent Home* / *Rebuildable Cache* / *Persistence Manifest* / *Volume-Backed* / *Host-Backed*）、ADR 0001（Rebuild → 最新基线的发布契约）、ADR 0002（Agent-Operated 定位）、Issue #4（本政策的 grilling 来源）

本 ADR 固化开发容器的持久化政策：哪些状态在容器重建后存活、由什么机制存活、以及模板对此承诺到哪条边界为止。

## Context

模板通过 `dev-home`（Agent Home）、`dev-cache`、WSL bind mount、符号链接等多种机制持久化状态，但没有统一政策。每接入一个新工具（最近是 HAPI）都是一次一次性布线，已造成实际分叉：`.devcontainer/post-create.sh` 链接 4 个 dotdir，`agent-compose/bootstrap.sh` 只链接 3 个——HAPI 状态在 agent-compose 下根本不持久化；post-create.sh 的条件链接（目录已存在才建链）还使全新 Volume-Backed 用户的登录态写进容器文件系统、rebuild 即丢。

## Decision

1. **分类标准 = 丢失代价**，只有两类持久状态：
   - **Agent Home**：丢了需要人工介入恢复（重登录、重配置、历史不可再生）。
   - **Rebuildable Cache**：丢了只损失时间，机器可自动重建（包下载、编辑器扩展）。
   - 分类粒度是**工具 dotdir 整体**，模板永不拆分 dotdir 内部（不把日志、缓存从工具目录里单独挑出去）——拆分要求模板理解每个工具的内部布局，工具一升级就碎。

2. **home 短命，清单点名持久**：容器 home 每次 rebuild 重置到镜像基线，只有 **Persistence Manifest**（声明式 dotdir 清单）点名的目录经符号链接进入 Agent Home。**否决了「整个 home 持久化」**：
   - named volume 只在首建时从镜像拷贝内容，之后冻结——整 home 持久化会使镜像基线更新（`.gitconfig`、新增 cache 链接）永远到不了老用户，直接违背 ADR 0001「Rebuild → 最新基线」；
   - 两类丢失代价的状态会物理混桶，清缓存陪葬登录态，「Rebuild 即净」的排障手段也随之失效；
   - Host-Backed 模式下等于把容器的 `.vscode-server`/`.bashrc` 直接写进用户真实 WSL home，与发行版自身文件互踩。
   - home 的短命性是**特性**：它正是基线更新能落地的机制。加新工具的成本被压缩为清单加一行，这一行就是政策声明本身。

3. **布线机制收敛为一个共享脚本**：Persistence Manifest 与链接逻辑（无条件 `mkdir -p` + `ln -sfn`）只写一份，`.devcontainer/post-create.sh` 与 `agent-compose/bootstrap.sh` 共同调用（agent-compose 侧像 bootstrap.sh 一样以 volume 挂进容器，因 `WORKSPACE_DIR` 可指向任意项目）。

4. **按安装层分工布线**：镜像烘焙的工具由 Dockerfile 布线（npm/pip/poetry 等 cache 链接维持烘焙，不搬进启动脚本——镜像是其唯一运行时来源，无分叉风险，且短命 home 使链接永远与镜像版本一致）；Startup Install 的工具由 Persistence Manifest 布线。

5. **Agent Home 双后端，切换不搬货**：
   - **Volume-Backed**（默认）：Docker named volume；**Host-Backed**：宿主（WSL）目录 bind mount。
   - Host-Backed 的第一目的是**外部管理**——让宿主侧工具（如 Windows 上的 cc-switch）能经 WSL 中转层切换 agent 配置；容器内外共享登录态是附带好处。
   - 两后端是**相互独立的存储**，切换 = 换店面不搬货，模板不做自动迁移（对装着凭据的目录做自动搬运，需维护后端记忆、解决双向冲突，出错代价远超收益）；手动迁移配方进用户文档。
   - 外部管理是**用户模式而非模板职责**：模板承诺止于「把目录挂进来」，容器内只见纯 POSIX 的 Agent Home；Windows↔WSL 的路径翻译、逐文件混搭由用户在宿主侧自行编排。

6. **文档分界 = 用户需要据此做决定的才进用户文档**：丢失代价模型（尤其「清单之外每次 rebuild 重置」）、双后端选择与切换语义、加新工具指引进 `.devcontainer/README.md`；`~/.cache-volumes` 内部布局、链接语义等布线细节下沉到代码注释。

## Consequences

- 实现工作（共享脚本 + 修复三处分叉 bug + 文档按分界重写）拆为 ready-for-agent 的 follow-up issue。
- CONTEXT.md 新增 *Rebuildable Cache*、*Persistence Manifest*、*Volume-Backed*、*Host-Backed*，并把 *Agent Home* 的定义从枚举改为丢失代价标准。
- 未来任何工具接入的持久化问题都先问一句「丢了要不要人工恢复」，答案直接决定进清单还是进 cache——不再产生一次性布线。
- **可逆性**：清单机制本身易扩展；「否决整 home 持久化」是本 ADR 真正难逆转的部分，若要翻案需先解决 named volume 初始化冻结与基线更新的矛盾。
