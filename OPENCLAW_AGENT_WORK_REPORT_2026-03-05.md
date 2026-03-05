# OpenClaw 多 Gateway 落地工作全量汇报（2026-03-05）

## 1. 本轮目标
- 在保留宿主机主 gateway（默认 profile）的前提下，完成 2 个 Docker 子 gateway 的标准化部署基础。
- 建立统一的运维资产仓库与 mailbox 仓库。
- 将新增/纳管/sync 流程脚本化。
- 按 `skill-creator` 规范创建可复用 skill。
- 使用 `gh` 创建远端 GitHub 仓库并完成绑定推送。

## 2. 基线检查与事实确认（已完成）
- 确认主 gateway 仅存在 `openclaw-gateway.service` 且正常运行。
- 确认主配置路径：`~/.openclaw/openclaw.json`。
- 确认 Docker/Compose 可用。
- 确认 `gh` 已登录账号：`Zhang-zhouyang`。
- 确认主 workspace 路径：`/home/zhangzhouyang/.openclaw/workspace`。

## 3. 本地仓库与目录建设（已完成）
### 3.1 新建本地仓库目录
- `/home/zhangzhouyang/openclaw-multi-agent-workspace`
- `/home/zhangzhouyang/team-work-repo`

### 3.2 建立标准结构
在 `openclaw-multi-agent-workspace` 下建立：
- `gateways/main|sub1|sub2/{workspace-template,config-template}`
- `templates/`
- `ops/scripts/`
- `ops/systemd/`
- `skills/`

## 4. 标准化脚本与配置资产（已完成）
### 4.1 关键配置文件
- `ops/gateway-registry.yaml`
  - `main`：host-systemd，端口 `18789/18790`
  - `sub1`：docker，端口 `19789/19790`
  - `sub2`：docker，端口 `20789/20790`
  - 默认镜像：`ghcr.io/openclaw/openclaw:latest`
- `templates/providers-models.template.json`
  - provider: `ali`
  - models: `qwen3.5-plus` / `kimi-k2.5` / `glm-5`
  - 默认主模型：`ali/qwen3.5-plus`

### 4.2 关键脚本
- `ops/scripts/registry_tool.py`
  - 读取 registry，支持按 gateway/field 查询。
- `ops/scripts/render_compose.py`
  - 从 registry 生成 `ops/docker-compose.gateways.yml`。
- `ops/scripts/gatewayctl.sh`
  - `render-compose`
  - `add --name <gateway>`
  - `enroll-main --name main`
  - `remove --name <gateway>`
  - `status --name <gateway>`
- `ops/scripts/sync-team-repo.sh`
  - 执行 fetch/rebase/pull 同步流程。
- `ops/scripts/mailbox-send.sh`
  - 写 mailbox 消息并 commit/push。

### 4.3 已做关键修复
- 修复 compose 变量作用域问题：避免服务间端口/挂载变量串扰。
- 修复 `--bind` 命令参数渲染。
- 修复模板相对路径解析（基于 repo root）。
- 增加目录权限可写性提前检测（明确提示 `/srv` 权限问题）。
- 子 gateway 新增时自动继承主 gateway `ali.apiKey`（可被环境变量覆盖）。
- `datetime.utcnow()` 替换为 timezone-aware 写法。
- 自动配置 team-work 仓库 `git user.name/email`，避免提交失败。
- compose 启动增加 `--force-recreate`，确保 `.env` 变更生效。

## 5. 运行态部署（已完成）
### 5.1 主 gateway
- 保持现状，不迁移 profile：
  - 服务：`openclaw-gateway.service`
  - 状态：active/running

### 5.2 子 gateway
- 已执行：
  - `gatewayctl.sh add --name sub1`
  - `gatewayctl.sh add --name sub2`
- 容器状态：
  - `openclaw-gateway-sub1` healthy
  - `openclaw-gateway-sub2` healthy
- 映射端口：
  - sub1：`19789 -> 18789`, `19790 -> 18790`
  - sub2：`20789 -> 18789`, `20790 -> 18790`

### 5.3 /srv 目录
- 已创建并授权：
  - `/srv/openclaw/gateways/main/...`
  - `/srv/openclaw/gateways/sub1/...`
  - `/srv/openclaw/gateways/sub2/...`

## 6. Team-work mailbox 同步（已完成）
### 6.1 systemd 定时同步
- 安装并启用：
  - `openclaw-team-sync@main.timer`
  - `openclaw-team-sync@sub1.timer`
  - `openclaw-team-sync@sub2.timer`
- 定时周期：约每 2 分钟。

### 6.2 分支策略落地
- `team-work-repo` 使用：
  - `gateway/main`
  - `gateway/sub1`
  - `gateway/sub2`
- 已处理过一次 rebase 冲突问题：
  - 将 `gateway/*` 分支统一整理为可基于 `origin/main` 线性同步。

### 6.3 mailbox 推送实测
- 已由 `main -> sub1` 发送并提交一条消息：
  - `mailbox(main->sub1): ops-check`

## 7. Skill 创建与接入（已完成）
### 7.1 按 skill-creator 流程创建
- 使用 `init_skill.py` 初始化：
  - `~/.codex/skills/local/openclaw-gateway-factory`
- 完成内容：
  - `SKILL.md`
  - `references/*`
  - `scripts/*`（包装调用 workspace repo 内 ops 脚本）

### 7.2 校验与接入
- `quick_validate.py` 校验通过。
- 已复制到主 gateway managed skills 目录：
  - `~/.openclaw/skills/openclaw-gateway-factory`
- `openclaw skills list` 可见该 skill。

## 8. GitHub 远端仓库（已完成）
### 8.1 新建远端仓库（私有）
- `https://github.com/Zhang-zhouyang/openclaw-multi-agent-workspace`
- `https://github.com/Zhang-zhouyang/team-work-repo`

### 8.2 推送状态
- `openclaw-multi-agent-workspace`：`main` 已推送。
- `team-work-repo`：`main` 已推送。
- `team-work-repo` 分支已推送：
  - `gateway/main`
  - `gateway/sub1`
  - `gateway/sub2`

### 8.3 /srv 三个 team-work 副本
- 已全部绑定 origin：
  - `https://github.com/Zhang-zhouyang/team-work-repo.git`
- 本地分支跟踪关系已建立并正常。

## 9. 验证结果（已完成）
- 主 gateway systemd 状态：正常。
- 子 gateway 容器健康检查：healthy。
- 子 gateway 模型配置可读取，默认模型/fallback 正确。
- provider 直连调用验证：返回 HTTP 200（已覆盖关键模型组合）。
- 同步 timer：三个实例均正常触发执行。

## 10. 本轮产出清单（核心路径）
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/gateway-registry.yaml`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/templates/providers-models.template.json`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/docker-compose.gateways.yml`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/scripts/gatewayctl.sh`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/scripts/sync-team-repo.sh`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/scripts/mailbox-send.sh`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/scripts/registry_tool.py`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/scripts/render_compose.py`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/systemd/openclaw-team-sync@.service`
- `/home/zhangzhouyang/openclaw-multi-agent-workspace/ops/systemd/openclaw-team-sync@.timer`
- `/home/zhangzhouyang/.openclaw/skills/openclaw-gateway-factory/SKILL.md`

## 11. 当前状态结论
- 多 gateway 基础设施已可运行并进入可持续运维状态。
- 远端仓库、分支策略、定时同步、skill 化入口均已落地。
- 后续 agent 可在此基础上继续做安全加固、策略细化与自动化增强。
