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

**Host Tunnel Port**:
A container port deliberately bound to the host loopback interface so host-side tunnel software can expose a tool without publishing it on the LAN.
_Avoid_: Public port, forwarded port

**Local Hub**:
A remote-control process started inside the development container that is reachable from the host machine but not published beyond the host unless the user adds a tunnel.
_Avoid_: Public service, relay
