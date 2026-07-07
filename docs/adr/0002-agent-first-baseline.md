# ADR 0002：Agent-First Baseline 与文档 Reader-Role

- **状态**：Accepted
- **日期**：2026-06-25
- **关联**：CONTEXT.md（*Agent-Operated* / *Human Supervisor* / *Prebuilt Image* / *AI Agent Toolchain*）、ADR 0001（修订其「thin 慢变基线」的「给人用」前提）、Issue #3（文档去重，决策 C）、Issue「Slim the Prebuilt Image for agent-first operation」（决策 B）
- **后续修订**：[ADR 0004](0004-template-validation-policy.md) 把下方归属表中「缓存持久化实现（符号链接映射）」的唯一 owner 由 `devimage-build/README.md` 改为 Dockerfile 代码注释（对齐 ADR 0003 §6）；其余归属不变。

本 ADR 固化一次定位转变：开发容器从**给人用的环境**转为**给 agent 用的环境**，并定义随之而来的镜像精简方向与文档 reader-role 模型。

## Context

模板初衷是「人在容器里日常开发」，因此：

- **Prebuilt Image** 烘焙了一整层**交互式 shell 工效**：`common-utils` Feature 开了 `installZsh` / `installOhMyZsh` / `configureZshAsDefaultShell`，Dockerfile 又装了 zsh-autosuggestions / zsh-syntax-highlighting / zshrc-addon、tmux + tpm + tmux.conf，以及 `bat` / `eza` / `htop` / `tree` / `xclip` 这些「更好看的人类替代品」。
- 三份 user-facing 文档（根 `README.md`、`.devcontainer/README.md`、`devimage-build/README.md`）按「人类开发者」读者撰写，大量篇幅是 tmux 快捷键表、shell 工效、人类向 FAQ。

实际用法已转向 **agent 操作、人基本不交互**：**AI Agent Toolchain**（claude / codex / gemini / hapi）以**非交互**方式 shell out 到 `bash`，不消费提示符主题、不按 tmux 快捷键、不需要 `eza` 的配色。于是那层工效成了**纯负担**（镜像体积、构建时间、维护面），而三份 README 里大量「人类使用」散文**失去了读者**——这也是 Issue #3「文档重复」之所以越积越多的深层原因：在为一个其实已不存在的「日常人类用户」反复书写。

## Decision

1. **Agent-Operated 基线**：开发容器的主操作者是 **AI Agent Toolchain**；人退为 **Human Supervisor**——负责 provision、监督、偶尔进容器 debug，而非日常在里面写码。

2. **薄人类兜底（agent-first，非 agent-only）**：为 Human Supervisor 保留**一条裸 `bash` 逃生口**即可，不再为人优化交互体验。
   - **砍**（纯装饰 / 人类工效）：oh-my-zsh、zsh 插件（autosuggestions / syntax-highlighting）、zshrc-addon、`bat` / `eza` / `htop` / `tree` 等。
   - **留**（agent 与 debug 双方都需）：`bash`、`ripgrep` / `fd` / `jq`、`git`，以及 node / python / rust / gh-cli 运行时。
   - **具体砍到哪、tmux 作为「进程托管」留不留、默认 shell 是否回退 `bash`** —— 留给决策 B（Issue「Slim the Prebuilt Image」）单独 grill，本 ADR 只定方向与边界。

3. **文档 Reader-Role（导览 / 用 / 造）与「一事一 owner」**：
   - 根 `README.md` = **导览 + 路由**（首次接触者；薄、链接为主）。
   - `.devcontainer/README.md` = **「用」**（消费端运行时指南）。其读者在本 ADR 下重定义为 **agent-operator + Human Supervisor**：以「agent 怎么装/怎么跑、HAPI Local Hub 怎么连」为主体，人类工效内容（tmux / shell）压缩成一小节「Human Supervisor：进容器后用裸 bash」，而非主体。
   - `devimage-build/README.md` = **「造」**（镜像维护者构建 + 发布指南）。
   - 重复的事实**只由一个 owner 拥有，其余文档链接**。归属表见下。

   | 事实 | 唯一 owner | 其余文档 |
   |------|-----------|---------|
   | HAPI Local Hub、Cloudflare Tunnel、tmux、dev-cache / dev-home volume、工具用法、env/WSL_HOME、人类向 FAQ、隔离说明 | `.devcontainer/README.md` | 根 README 一句话 + 链接 |
   | tmux/zsh 配置改法、缓存持久化实现（符号链接映射）、加系统工具 / Features | `devimage-build/README.md` | `.devcontainer` 链接 |
   | 发布 / Release | `devimage-build/README.md`（ADR 0001 已定） | 根 + `.devcontainer` 链接 |

4. **对 ADR 0001 的修订**：ADR 0001 把 Prebuilt Image 描述为「被刻意做薄的 thin 慢变基线」，其隐含前提是「给人用」。本 ADR 把该前提改为「**agent-first** 的 thin 慢变基线」——发布契约（触发、`:latest` 语义、pin 策略、CI 不变量）**其余不变**，只是「薄」的判据从「人需不需要」改为「**agent 需不需要 + 是否留一条裸 bash 兜底**」。

## Consequences

- **顺序 A → B → C**：本 ADR（A）现在定；**Issue B（精简镜像）先做**；**Issue #3（文档去重，C）排在 B 之后**，照精简后的现实重写文档，避免「先精心去重、回头又删」的返工。
- **B**：改 `devimage-build/.devcontainer/devcontainer.json` 的 `common-utils` 选项与 `Dockerfile`，去掉工效层；需重新评估 dev-cache 里 `zsh` / `tmux` 符号链接映射的去留。属一次 Prebuilt Image 发版（走 ADR 0001 的 Release Tag 契约）。
- **C（#3）**：在 B 落地后，按导览/用/造 + 归属表去重，并把 `.devcontainer/README.md` 重心移到 agent 操作、人类工效压缩成兜底小节。
- **CONTEXT.md**：新增 *Agent-Operated*、*Human Supervisor* 两个领域词。
- **可逆**：保留裸 bash 兜底使该转变低风险、可回退；若日后又需要人类日常使用，恢复工效层是一次普通的镜像发版。
