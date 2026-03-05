# OpenClaw 多 Gateway 工作汇报（修订版，独立仓库模式）

## 1. 架构修订结论
- 已采用“各 gateway workspace 独立仓库”模式：
  - `openclaw-workspace-main`
  - `openclaw-workspace-sub1`
  - `openclaw-workspace-sub2`
- `team-work-repo` 保持共享模式，不拆分。
- 旧统一运维仓库 `openclaw-multi-agent-workspace` 已从运行依赖中移除（后续执行删除）。

## 2. 当前仓库管理方式

### 2.1 workspace（独立）
- main workspace 本地：`/home/zhangzhouyang/.openclaw/workspace`
  - 远端：`https://github.com/Zhang-zhouyang/openclaw-workspace-main.git`
  - 分支：`main`
- sub1 workspace 本地：`/srv/openclaw/gateways/sub1/workspace`
  - 远端：`https://github.com/Zhang-zhouyang/openclaw-workspace-sub1.git`
  - 分支：`main`
- sub2 workspace 本地：`/srv/openclaw/gateways/sub2/workspace`
  - 远端：`https://github.com/Zhang-zhouyang/openclaw-workspace-sub2.git`
  - 分支：`main`

### 2.2 team-work（共享）
- 远端：`https://github.com/Zhang-zhouyang/team-work-repo.git`
- gateway 分支：
  - `gateway/main`
  - `gateway/sub1`
  - `gateway/sub2`

## 3. 运行控制脚本（新主路径）
- 统一控制面已迁移到主 workspace：
  - `~/.openclaw/workspace/ops/gateway-registry.yaml`
  - `~/.openclaw/workspace/ops/scripts/registry_tool.py`
  - `~/.openclaw/workspace/ops/scripts/sync-team-repo.sh`
  - `~/.openclaw/workspace/ops/scripts/workspace-sync.sh`
  - `~/.openclaw/workspace/ops/scripts/mailbox-send.sh`

## 4. 同步机制（按新需求）

### 4.1 team-work 同步（定时）
- `openclaw-team-sync@main.timer`
- `openclaw-team-sync@sub1.timer`
- `openclaw-team-sync@sub2.timer`
- 已改为调用新路径脚本：`~/.openclaw/workspace/ops/scripts/sync-team-repo.sh`

### 4.2 workspace 同步（事件触发）
- 事件触发策略：脚本事件触发。
- `mailbox-send.sh` 在消息提交后会触发发送方 workspace 同步：
  - 调用 `workspace-sync.sh --name <from> --reason "mailbox:<subject>"`
- 手动触发：
  - `workspace-sync.sh --name main --reason manual-sync`

## 5. Skill 修订结果
- `openclaw-gateway-factory` 已修订并通过校验。
- 已移除对 `openclaw-multi-agent-workspace` 与 `gatewayctl.sh` 的依赖。
- 新 skill 入口：
  - `scripts/sync-team-repo.sh`
  - `scripts/workspace-sync.sh`
  - `scripts/mailbox-send.sh`

## 6. 运行状态摘要
- 主 gateway 服务：`openclaw-gateway.service` 运行中。
- 子 gateway 容器：`openclaw-gateway-sub1`、`openclaw-gateway-sub2` healthy。
- team-work 三路同步服务可成功执行。

## 7. 变更审查结论（针对旧方案）
- 需要修正项已落地：
  - skill 路径和行为已修订。
  - 汇报文档已按新模式覆盖。
  - systemd 同步服务路径已迁移。
- 待最终收口：
  - `openclaw-multi-agent-workspace` 本地目录已删除。
  - 远端仓库删除需 `gh` token 增加 `delete_repo` scope 后执行。
