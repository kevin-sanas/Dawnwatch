# 12｜本地部署、运维与 CI/CD

## 兼容标识与数据卷

Dawnwatch 继续沿用部分 AgentOps 技术标识，以兼容已有配置与数据。

为保护现有配置和数据，下列旧技术标识属于明确保留的兼容项，不能按品牌字符串批量替换：

| 保留位置 | 标识与原因 |
|---|---|
| Java | `dev.agentops`、`AgentOpsApplication`、`agentops-backend` artifactId/JAR 名；现有 IDEA 配置继续有效 |
| Python | `agentops_agent` 模块及内部 schema/表名；保留导入和 checkpoint 兼容性 |
| 数据库 | `agentops`、`agentops_checkpoint`、原角色、既有 Flyway 迁移；不更改已有迁移及校验和 |
| 配置与协议 | 既有环境变量（含 `VITE_AGENTOPS_DEMO`）、`agentops.theme` 本地主题键、内部属性/测试 fixture 标识和 `kuma.agentops.test`；保持已保存配置与测试协议兼容 |
| Compose 数据 | 原有物理卷前缀 `agentops-platform` 默认保留，详见下节 |

### Compose 升级：先核对卷，再启动

逻辑项目名已改为 `dawnwatch`。三个物理卷默认仍为 `agentops-platform_postgres-data`、`agentops-platform_checkpoint-data`、`agentops-platform_kuma-data`，不会仅因改名自动选择一套空卷。新增非敏感变量 `DAWNWATCH_DATA_PREFIX` 将数据身份和产品名称分开：

- 原先使用默认项目名：沿用 `.env.example` 的 `DAWNWATCH_DATA_PREFIX=agentops-platform`。
- 原先通过 `-p` 或 `COMPOSE_PROJECT_NAME` 使用自定义项目名：先用 `docker volume ls` 和 `docker volume inspect` 核对实际卷，将 `DAWNWATCH_DATA_PREFIX` 设置为原前缀。自定义的三个卷不符合此前缀规则时，先准备显式卷映射覆盖配置，不直接启动。
- 全新、独立安装：可以选择唯一的新前缀，例如 `dawnwatch-local`；不要与其他安装共享前缀。
- CI 同时设置 `COMPOSE_PROJECT_NAME=dawnwatch-ci` 和 `DAWNWATCH_DATA_PREFIX=dawnwatch-ci`，只清理其独立测试资源。

升级前保存配套备份，并停止旧 Compose 项目中的服务，再启动新项目。禁止两个 PostgreSQL 实例同时挂载同一个数据卷；不要执行 `down --volumes`，不要用删库或重建卷解决登录问题。开发工具本轮不会替用户停止服务或操作数据卷。

配置回归命令为 `node --test scripts/compose-identity.test.mjs`，需要 Docker Compose CLI，但不要求 Docker 引擎启动；验证默认卷身份及自定义前缀。容器实际启动与恢复演练仍须由对应提交的 Compose CI 单独证明。

## 本地运行

Compose 拓扑包含 `postgres`、`checkpoint-db`、`backend`、`agent-service` 和 `frontend`。初始化服务 `agent-tls` 在无网络的容器内准备证书，并在 Agent 启动前退出。Java 通过 `https://agent-service:8090` 连接，校验主机名及证书。Agent 只读挂载证书和私钥，Java 只读挂载含公开证书的信任库。

Uptime Kuma 通过 `kuma` profile 按需启用。Java 与前端的宿主机端口默认只绑定回环地址，Python 和数据库留在容器网络。原生运行、容器启动与隔离演示见 [IDEA 启动与验收指南](../IDEA启动与验收指南.md)。

证书有效期为一年。换证时先对当前项目执行 `docker compose down`，仅移除该项目的 `agent-tls` 与 `agent-trust` 两个证书卷，再重启。通过 `docker volume ls` 确认两卷的完整名称，避免删除数据库和 Kuma 数据卷。

## 配置

| 变量 | 用途 | 敏感 |
|---|---|---|
| `DB_URL/DB_USER/DB_PASSWORD` | PostgreSQL 连接 | 密码是 |
| `SESSION_TOKEN_PEPPER` | 用户不透明 bearer token 的 hash pepper | 是 |
| `AGENT_INTERNAL_TOKEN` | Java↔Python 服务认证 | 是 |
| `AGENT_CHECKPOINT_DSN` | IDEA 配套 Python 的独立 checkpoint 连接；schema 固定 agent_checkpoint | 含密码，是 |
| `CHECKPOINT_OWNER_PASSWORD/CHECKPOINT_PASSWORD` | Compose 独立集群管理角色/受限应用角色密码；DSN 由入口编码组装 | 是 |
| `KUMA_ENABLED/KUMA_BASE_URL` | 默认关闭；部署唯一允许 origin | 不含 token |
| `KUMA_ALLOW_HTTP/KUMA_ALLOWED_PRIVATE_CIDRS` | Kuma 专用的 HTTP/私网批准，不放宽目标探测策略 | 否 |
| `KUMA_PUSH_TOKEN_*` | 环境变量 secret；配置 API 仅提交 env:KUMA_PUSH_TOKEN_* 引用 | 是 |

不得提交 `.env`、真实 token、服务密码、生产 URL、真实运维日志或供应商响应数据。

还支持 `SESSION_DURATION`（默认 `PT30M`，正数且不超过 24 小时）、`BOOTSTRAP_ADMIN_USERNAME/BOOTSTRAP_ADMIN_PASSWORD`（仅空库初始化）和 Compose 的 `BACKEND_PORT/FRONTEND_PORT`（默认18080/5174）。IDEA 后端使用 `PORT=18080`。两个服务端秘密必须彼此不同且至少32字符；bootstrap密码至少12字符、不超过72 UTF-8字节。

## 运维手册

- **DB 不可用**：停止写操作/领取新 job；不返回“成功”；Outbox 租约过期后恢复重试。
- **Agent provider 不可用**：检查历史和事故界面继续工作；run 显示 FAILED/可重试，保留已采集事实。
- **探测误报**：暂停对应 check，检查 DNS/IP 策略和采集时段，修改配置后生成新版本；不删除历史记录。
- **Kuma 不可用/token 失效**：禁用 adapter 或轮换 secret；查看 IntegrationDelivery；主事故不受影响。
- **备份恢复**：停止 Java/Python 写入后，配套备份业务库及完整 checkpoint 库，保留匹配代码和 secret。恢复到两个新库，校验 Flyway、incident/agentRun/checkpoint 引用与模型调用记录；checkpoint 库所有者仍应是受限应用角色，否则 schema 初始化可能被 CREATE 权限拒绝。缺失/错配 checkpoint 的自动修复和 RECOVERY_REQUIRED 专门状态尚未实现，不得盲目重发模型任务。
- **关机**：停止领取新事件、等待短任务；剩余任务靠租约恢复。

## CI/CD

验证任务和运行条件以 [GitHub Actions 工作流](../.github/workflows/backend.yml)为准。容器镜像固定版本与摘要；本机开发验证入口见[测试指南](13-测试矩阵与阶段门.md)。
