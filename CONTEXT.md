# Dev Container Template

This repo defines a reusable development container template for AI-assisted software work. Its domain language describes how the template packages tools, persists user state, and separates reusable image contents from per-project startup behavior.

## Language

**Prebuilt Image**:
A reusable Docker image that provides the baseline development environment shared by projects.
_Avoid_: Base image, baked environment

**Startup Install**:
A tool installation performed when a development container is created so the user receives the latest available tool version.
_Avoid_: Image install, baked install

**AI Agent Toolchain**:
The set of command-line AI coding tools made available inside the development container.
_Avoid_: AI tools, agent stack

**Agent Home**:
Persistent per-user state for AI coding tools, including credentials, settings, local databases, and session state.
_Avoid_: Cache, tool cache

**Agent-Operated**:
The development container is run primarily by the AI Agent Toolchain rather than an interactive human; a person only provisions and supervises it. Shapes what the Prebuilt Image bakes (agent-essential tooling plus a thin human fallback) and who user-facing docs address. See [docs/adr/0002-agent-first-baseline.md](docs/adr/0002-agent-first-baseline.md).
_Avoid_: developer workstation, human IDE

**Human Supervisor**:
A person who provisions, debugs, or oversees the Agent-Operated container through a minimal plain-`bash` path, without the ergonomic shell tooling a daily human user would expect.
_Avoid_: developer, end user

**Host Tunnel Port**:
A container port deliberately bound to the host loopback interface so host-side tunnel software can expose a tool without publishing it on the LAN.
_Avoid_: Public port, forwarded port

**Local Hub**:
A remote-control process started inside the development container that is reachable from the host machine but not published beyond the host unless the user adds a tunnel.
_Avoid_: Public service, relay

**Release Tag**:
A `v*` git tag whose push publishes an immutable Prebuilt Image at `:vX.Y.Z`. The unit of release for the template.
_Avoid_: version, build number

**Latest Pointer**:
The `:latest` image tag, defined as an alias for the most recent Release Tag. Moved only by a Release Tag push.
_Avoid_: newest, current

**Release Trigger**:
An event that publishes the Prebuilt Image — either a Release Tag push or a Manual Rebuild naming an existing Release Tag. Excludes pushes to `main`.
_Avoid_: build trigger

**Manual Rebuild**:
A `workflow_dispatch` run that takes a Release Tag as input and republishes that exact version. Does not create a new version and does not move the Latest Pointer.
_Avoid_: rerun, redeploy

See [docs/adr/0001-image-release-contract.md](docs/adr/0001-image-release-contract.md) for the release contract that owns these terms.
