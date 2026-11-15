# Dawnwatch IDEA 启动与验收指南

更新于 2026-11-15。以下路径均从克隆后的项目根目录计算。

## 1. 环境准备

| 组件 | 要求 |
| --- | --- |
| Java / Maven | Java 21，Maven 3.9.x |
| Python | Python 3.13，项目环境位于 `agent-service/.venv` |
| 前端 | Node.js 22.12 或更高版本，测试建议使用 Node.js 24 |
| PostgreSQL | 17.x。日常运行使用 `agentops` 与独立的 `agentops_checkpoint`。隔离演示自行创建临时实例。 |

在项目根目录打开 PowerShell，安装锁定依赖。

```powershell
.\scripts\agent.ps1 Install -Dev
npm --prefix frontend ci --ignore-scripts --no-fund --no-audit
```

使用 PATH 中的 Maven 和指向 Java 21 的 `JAVA_HOME`，也可使用项目内 `.tools/java21/` 和 `.tools/maven/`。首次构建会下载依赖。

## 2. 隔离演示

在项目根目录运行隔离演示。

```powershell
.\scripts\demo.ps1
```

打开终端打印的工作台地址。使用同一个终端打印的 `demo-admin`（管理员兼值班）或 `demo-observer`（观察员）及本次随机密码。保留终端运行，端口以当次输出为准。演示使用临时 PostgreSQL、合成数据和 mock 诊断，无需先运行日常服务。

1. 输入 `down`，进入「告警与事件 → 事件列表」，打开生成的事故。
2. 按页面提示确认事故、开始排查，发起 AI 诊断。检查状态、503 证据和手册引用。
3. 在「立即审阅」批准线下处理。同步后可以回填「未执行」，用于只验收流程。
4. 回到终端输入 `up`，在事件时间线核对恢复证据及解决状态，再手动关闭事故。
5. 切换观察员，核对已授权的详情可读，处置与审批操作不可用。
6. 输入 `quit`，等待终端确认结束。演示最长两小时，临时数据库和本次凭据随会话清除。

`status` 可查询当前合成目标和事故状态。需要从另一个终端控制 `-NoInput` 演示时，用启动时打印的目录替换下方命令中的参数。

```powershell
node scripts/demo-session.mjs '<DEMO_SESSION 目录>' status
```

命令末尾也支持 `down`、`up` 或 `quit`。启动失败时，查看同一会话目录的 `compile.log`、`runtime.*.log` 和 `frontend.*.log`。自动验证演示使用 `.\scripts\demo.ps1 -Check`，完整核心验收使用 `.\scripts\acceptance.ps1`。详细覆盖见[测试指南](docs/13-测试矩阵与阶段门.md)。

## 3. 日常 IDEA 启动

### 3.1 准备数据库

启动本机 PostgreSQL。为业务库分配可运行 Flyway 迁移的角色，为 checkpoint 库分配独立的非超级用户应用角色。下面是创建 checkpoint 库的 SQL 模板，由数据库管理员在首次配置时执行。在执行前替换示例密码。已有数据库和角色可以直接沿用。

```sql
CREATE ROLE agentops_checkpoint LOGIN PASSWORD '<设置独立强密码>'
  NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE DATABASE agentops_checkpoint OWNER agentops_checkpoint;
```

升级前备份业务库和 checkpoint 库。Java 启动时通过 Flyway 应用未运行的迁移，迁移文件见 [db/migration](db/migration/)。

### 3.2 启动 Python Agent

打开项目根目录的 PowerShell，将 checkpoint 角色、主机、端口和库名调整为实际配置。每次出现隐藏输入提示时只输入对应的秘密值。

```powershell
$checkpointSecret = Read-Host 'Checkpoint 数据库密码' -AsSecureString
$checkpointEncoded = [uri]::EscapeDataString([Net.NetworkCredential]::new('', $checkpointSecret).Password)
$env:AGENT_CHECKPOINT_DSN = "postgresql://agentops_checkpoint:${checkpointEncoded}@127.0.0.1:5432/agentops_checkpoint"
Remove-Variable checkpointSecret, checkpointEncoded

$internalSecret = Read-Host '内部服务令牌，与 Java 配置相同' -AsSecureString
$env:AGENT_INTERNAL_TOKEN = [Net.NetworkCredential]::new('', $internalSecret).Password
Remove-Variable internalSecret
.\scripts\agent.ps1 Run
```

保留此终端运行，默认监听 `127.0.0.1:8090`。原生命令使用当前进程的环境变量。

### 3.3 启动 Java 后端

1. 在 IDEA 打开项目根目录，给项目和模块设置 SDK 21。在项目树中右键 `backend/pom.xml`，选择「添加为 Maven 项目」。
2. 打开 `backend/src/main/java/dev/agentops/AgentOpsApplication.java`，创建 Spring Boot 运行配置，主类选择 `dev.agentops.AgentOpsApplication`，模块选择 `agentops-backend`。Maven 主路径选本机 Maven 3.9.x；项目使用本地工具时可选择 `.tools/maven/` 下的安装目录。
3. 打开「运行 → 编辑配置 → 修改选项 → 环境变量」，使用本地运行配置保存下表中的环境值。

| 名称 | 值 |
| --- | --- |
| `PORT` | `18080` |
| `DB_URL` | `jdbc:postgresql://127.0.0.1:5432/agentops`，按实际库名调整 |
| `DB_USER`、`DB_PASSWORD` | 业务数据库角色与密码 |
| `SESSION_TOKEN_PEPPER` | 至少 32 字符的独立随机值。已有部署沿用原值。 |
| `AGENT_INTERNAL_TOKEN` | 至少 32 字符的独立随机值，与 Python 完全一致 |
| `AGENT_ENABLED` | `true` |
| `AGENT_SERVICE_ORIGIN` | `http://127.0.0.1:8090` |
| `BOOTSTRAP_ADMIN_USERNAME`、`BOOTSTRAP_ADMIN_PASSWORD` | 仅空用户表需要。用户名 3～80 位，由字母、数字、点、短横线或下划线组成；密码至少 12 字符，最多 72 UTF-8 字节。 |

点击运行，打开 [后端健康检查](http://127.0.0.1:18080/actuator/health)，确认 `status` 为 `UP`。Bootstrap 只用于初始化，已有管理员使用其账户密码登录。

### 3.4 启动前端

在另一个 PowerShell 的项目根目录启动前端。

```powershell
npm --prefix frontend run dev
```

打开终端显示的地址，默认是 [http://127.0.0.1:5174](http://127.0.0.1:5174)。Vite 将 `/api` 转发给 Java 18080；后端端口不同时，在启动 Vite 的终端设置 `BACKEND_API_ORIGIN` 为实际回环地址。

### 3.5 停止与排查

停止时分别在前端和 Python 终端按 `Ctrl+C`，在 IDEA 点击 Java 运行窗口的停止按钮。

| 现象 | 核对 |
| --- | --- |
| Maven 同步失败 | 检查 JDK 21、仓库设置与离线模式，查看 Maven 输出的第一条下载错误。 |
| Python 数据库认证失败 | 检查库名、角色和端口，确认 DSN 的密码已经 URL 编码。 |
| 登录 401 | 使用实际账号和密码。Bootstrap 变量只用于空用户表。 |
| 无法处理事故或发起诊断 | 账号需要 `ON_CALL` 和当前目标的操作权限。 |
| 诊断持续排队 | 检查 Python 是否运行、`AGENT_ENABLED`、Agent 地址及两端内部令牌。 |
| 前端连错后端 | 检查 IDEA 的 `PORT` 与前端的 `BACKEND_API_ORIGIN`。 |

## 4. 可选配置

### Uptime Kuma 与 Compose

Kuma 可选，用于向事先配置的 Push Monitor 转发健康状态。配置和监视器映射见 [Uptime Kuma 集成](docs/11-Uptime-Kuma集成边界.md)。

容器拓扑、数据卷和备份见[部署文档](docs/12-本地部署运维与CI-CD.md)。推荐先用本机方式熟悉主要流程。
