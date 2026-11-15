# Dawnwatch

Dawnwatch 是一个面向值班团队的运维协作平台。从服务健康检查和事件聚合，到 AI 证据诊断、人工审阅和结果回填，处理过程可在同一工作台中追溯。

## 主要功能

| 功能 | 说明 |
| --- | --- |
| 服务监控 | 登记服务和 HTTP 健康检查，查看检查历史、延迟和最新健康状态。 |
| 事件处理 | 按连续失败阈值生成事故，记录确认、排查、恢复观察、解决和关闭。 |
| AI 故障诊断 | 从冻结的检查和已发布的运行手册生成诊断报告，区分观测、推断和未知，并附上可核对的引用。 |
| 人工审阅 | 由授权值班人员批准或拒绝建议，线下处理后回填结果。平台中的诊断工具只有读取权限。 |
| 运维知识库 | 编辑和发布版本化运行手册，旧诊断继续引用当时的版本。 |

Uptime Kuma 是可选集成。Dawnwatch 通过 Push 将健康状态发送到已配置的 Kuma Monitor。

## 本地启动

需要 Git、Java 21、Maven 3.9、Python 3.13、Node.js 22.12 或更高版本，以及 PostgreSQL 17。将 JAVA_HOME 指向 Java 21。首次安装需要访问依赖仓库。

在 Windows PowerShell 中克隆仓库并安装锁定依赖。

```powershell
git clone https://github.com/kevin-sanas/Dawnwatch.git
Set-Location Dawnwatch
.\scripts\agent.ps1 Install -Dev
npm --prefix frontend ci --ignore-scripts --no-fund --no-audit
```

按照指南依次启动 PostgreSQL、Python Agent、IDEA 后端和前端。工作台默认位于 [127.0.0.1:5174](http://127.0.0.1:5174)，首次登录使用启动时设置的管理员账户。监控与诊断可以用合成故障和 mock provider 体验。这个分支的界面可能显示早期名称 AgentOps AI。

[IDEA 启动与验收指南](IDEA启动与验收指南.md)

## 架构与目录

Vue 工作台通过同源 API 访问 Spring Boot 后端。Java 管理用户权限、监控、事故和审计，通过 Outbox 将诊断任务交给 Python Agent。Agent 使用 FastAPI 和 LangGraph，由独立 PostgreSQL 保存诊断检查点。Flyway 管理业务库迁移。

| 目录 | 用途 |
| --- | --- |
| [`frontend/`](frontend/) | Vue 3、TypeScript、Vite 和 ECharts 工作台 |
| [`backend/`](backend/) | Java 21、Spring Boot 业务 API 与后台调度 |
| [`agent-service/`](agent-service/) | FastAPI、LangGraph、模型适配和离线评测 |
| [`db/migration/`](db/migration/) | PostgreSQL 业务库的 Flyway 迁移 |
| [`scripts/`](scripts/) | 本机启动、开发验证、演示和隔离恢复工具 |
| [`docs/`](docs/) | 设计说明、架构、数据模型与接口契约 |

查看[架构与技术选型](docs/05-架构与技术选型.md)、[数据库设计](docs/06-数据模型ERD与SQL.md)和[公共 API 契约](docs/07-API契约.md)。

## 开发与测试

先按本地启动一节安装依赖，再在项目根目录运行以下检查。

```powershell
.\scripts\agent.ps1 Test
.\scripts\backend.ps1 verify
npm --prefix frontend test
npm --prefix frontend run build
```

前端测试建议使用 Node.js 24。运行 `.\scripts\demo.ps1 -Check` 可验证隔离演示。完整验证入口和覆盖范围见[测试指南](docs/13-测试矩阵与阶段门.md)，CI 定义见 [GitHub Actions 工作流](.github/workflows/backend.yml)。

## 反馈与贡献

反馈问题时，请注明版本、运行环境、复现步骤和脱敏后的错误信息。提交 Pull Request 时，请说明变更范围和验证方式。请从反馈与提交中移除 API Key、密码、会话令牌、真实业务证据和本机配置。[GitHub Issues](https://github.com/kevin-sanas/Dawnwatch/issues) · [安全与权限说明](docs/09-安全隐私与权限.md)

## 许可证

Dawnwatch 的原创源码和文档采用 [MIT 许可证](LICENSE)。第三方组件依各自的许可条款分发，参见 [Python 依赖声明](agent-service/THIRD_PARTY_NOTICES.txt)、[前端依赖声明](frontend/public/THIRD_PARTY_NOTICES.txt)和[上游许可与接口说明](docs/15-开源许可证与接口核验.md)。
