# AI Daily Radar

每天抓取、筛选并生成 AI 行业中文日报，然后推送到飞书群。

这个项目把流程拆成三层：

- `skills/ai-daily-industry-radar/`：固化选题口味、评分规则和日报格式。
- `scripts/Collect-AiNewsCandidates.ps1`：从 RSS/Google News RSS 拉取候选新闻，输出 `candidates.json`。
- `scripts/Generate-AiDailyRadar.ps1`：读取候选池并生成正式的 `generate-prompt.md`，供 Codex 写日报。
- `scripts/Invoke-AiDailyRadar.ps1`：创建当天运行目录，并生成给 Codex 自动任务使用的工作提示。
- `scripts/Run-AiDailyRadar.ps1`：总入口，串起初始化、采集、生成 prompt，以及可选飞书 dry run/发送。
- `scripts/Send-FeishuDailyRadar.ps1`：把本地 Markdown 日报导入飞书云文档，并把摘要和链接发到群。

## 目录

```text
.
|-- README.md
|-- config/
|   |-- sources.json
|   |-- collection-feeds.json
|   `-- automation-prompt.md
|-- scripts/
|   |-- Collect-AiNewsCandidates.ps1
|   |-- Generate-AiDailyRadar.ps1
|   |-- Invoke-AiDailyRadar.ps1
|   |-- Run-AiDailyRadar.ps1
|   `-- Send-FeishuDailyRadar.ps1
|-- skills/
|   `-- ai-daily-industry-radar/
|       `-- SKILL.md
`-- templates/
    `-- daily-ai-radar.md
```

## 版本管理

项目使用 Git 管理源码，主分支为 `main`。

当前版本：`V1.0.1`

建议提交范围：

- 提交：`README.md`、`config/`、`scripts/`、`skills/`、`templates/` 等源码、配置和模板文件。
- 不提交：`.runs/`、`.env*`、`*.log` 等运行产物、本地环境变量和日志文件。

常用流程：

```powershell
git status
git add README.md config scripts skills templates
git commit -m "Describe the change"
git push
```

发布稳定版本时，建议使用语义化版本标签：

```powershell
git tag V1.0.1
git push origin V1.0.1
```

## 飞书环境变量

先在当前 PowerShell 会话里配置：

```powershell
$env:FEISHU_APP_ID = "cli_xxx"
$env:FEISHU_APP_SECRET = "xxx"
$env:FEISHU_CHAT_ID = "oc_xxx"
```

可选：

```powershell
$env:FEISHU_FOLDER_TOKEN = "fld_xxx"
$env:FEISHU_OPEN_API_BASE = "https://open.feishu.cn"
```

飞书应用建议开通这些权限：

- `im:message`
- `docs:document:import`
- `drive:drive`
- `drive:drive:readonly`
- 文件上传相关权限

## 手动运行

推荐先用一键启动脚本：

```powershell
.\scripts\Run-AiDailyRadar.ps1 -LookbackHours 24
```

它会完成：

```text
初始化运行目录 -> 采集候选新闻 -> 生成 generate-prompt.md -> 写 run-metadata.json
```

接着对 Codex 说：

```text
读取今天的 generate-prompt.md，生成日报，但先不要发飞书
```

如果想分步执行，也可以按下面流程。

先生成当天运行目录和任务提示：

```powershell
.\scripts\Invoke-AiDailyRadar.ps1
```

它会创建类似：

```text
.runs\daily-ai-radar\2026-06-02\
|-- daily-ai-radar.md
|-- daily-ai-radar.json
|-- run-prompt.md
`-- sources.json
```

采集候选新闻：

```powershell
.\scripts\Collect-AiNewsCandidates.ps1 -LookbackHours 48
```

它会生成：

```text
.runs\daily-ai-radar\YYYY-MM-DD\candidates.json
```

然后让 Codex 结合 `candidates.json`、`run-prompt.md` 和 `skills/ai-daily-industry-radar/SKILL.md` 生成日报。

生成正式写作 prompt：

```powershell
.\scripts\Generate-AiDailyRadar.ps1
```

它会生成：

```text
.runs\daily-ai-radar\YYYY-MM-DD\generate-prompt.md
```

让 Codex 按 `run-prompt.md` 的要求完成搜索、筛选、写作后，再发送飞书：

```powershell
.\scripts\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\daily-ai-radar\2026-06-02\daily-ai-radar.md
```

只发纯文本摘要，不导入云文档：

```powershell
.\scripts\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\daily-ai-radar\2026-06-02\daily-ai-radar.md -TextOnly
```

## Codex 自动任务建议

建议创建一个每天早上运行的 cron automation，工作目录指向本项目，prompt 使用 `config/automation-prompt.md`。

推荐执行时间：

- 中国时间每天 `08:30`
- 覆盖过去 `24` 小时
- 如果当天信息较少，也保留高置信的一句话快讯，避免硬凑 Top 5

自动任务要点：

1. 使用 `skills/ai-daily-industry-radar/SKILL.md` 的筛选和输出规则。
2. 必须核验信息发布时间，优先官方来源、产品博客、论文、GitHub Release、可信媒体。
3. 先运行 `scripts/Collect-AiNewsCandidates.ps1` 生成候选新闻。
4. 结合候选新闻继续搜索核验，生成 Markdown 和 JSON 两份结果。
5. 运行 `scripts/Send-FeishuDailyRadar.ps1` 推送飞书。

## 输出文件约定

- Markdown：`.runs/daily-ai-radar/YYYY-MM-DD/daily-ai-radar.md`
- JSON：`.runs/daily-ai-radar/YYYY-MM-DD/daily-ai-radar.json`
- 候选新闻：`.runs/daily-ai-radar/YYYY-MM-DD/candidates.json`
- 生成提示：`.runs/daily-ai-radar/YYYY-MM-DD/generate-prompt.md`
- 运行提示：`.runs/daily-ai-radar/YYYY-MM-DD/run-prompt.md`
- 运行元数据：`.runs/daily-ai-radar/YYYY-MM-DD/run-metadata.json`

JSON 建议结构见 `templates/daily-ai-radar.md` 末尾说明。
