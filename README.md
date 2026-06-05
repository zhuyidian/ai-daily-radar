# Daily Radar

每天抓取、筛选并生成中文主题日报，然后推送到飞书群。

当前已支持：

- AI 行业日报
- Android 开发日报

项目的核心设计是“同一套脚本，不同主题配置”：

- `config/topics/<topic>/`：每个主题的抓取源、参考源、自动任务 prompt 和主题元信息。
- `skills/<topic-skill>/`：每个主题的筛选、评分和写作口径。
- `scripts/Run-DailyRadar.ps1`：多主题通用入口。
- `scripts/Send-FeishuDailyRadar.ps1`：把本地 Markdown 日报导入飞书云文档，并把摘要和链接发到群。

## 目录

```text
.
|-- README.md
|-- config/
|   |-- topics/
|   |   |-- ai/
|   |   |   |-- topic.json
|   |   |   |-- collection-feeds.json
|   |   |   |-- sources.json
|   |   |   `-- automation-prompt.md
|   |   `-- android/
|   |       |-- topic.json
|   |       |-- collection-feeds.json
|   |       |-- sources.json
|   |       `-- automation-prompt.md
|   |-- collection-feeds.json
|   |-- sources.json
|   `-- automation-prompt.md
|-- scripts/
|   |-- Run-DailyRadar.ps1
|   |-- Run-AiDailyRadar.ps1
|   |-- Run-AndroidDailyRadar.ps1
|   |-- Collect-NewsCandidates.ps1
|   |-- Generate-DailyRadar.ps1
|   |-- Invoke-DailyRadar.ps1
|   |-- Get-DailyRadarTopic.ps1
|   |-- Collect-AiNewsCandidates.ps1
|   |-- Generate-AiDailyRadar.ps1
|   |-- Invoke-AiDailyRadar.ps1
|   `-- Send-FeishuDailyRadar.ps1
|-- skills/
|   |-- ai-daily-industry-radar/
|   |   `-- SKILL.md
|   `-- android-daily-developer-radar/
|       `-- SKILL.md
`-- templates/
    |-- daily-ai-radar.md
    `-- android-daily-radar.md
```

## 版本管理

当前版本：`V1.1.0`

版本说明：升级为多主题日报框架，保留 AI 日报，并新增 Android 开发日报主题。

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

### AI 行业日报

旧命令仍然可用：

```powershell
.\scripts\Run-AiDailyRadar.ps1 -LookbackHours 24 -MaxItemsPerSource 10
```

等价的通用命令：

```powershell
.\scripts\Run-DailyRadar.ps1 -Topic ai -LookbackHours 24 -MaxItemsPerSource 10
```

输出目录：

```text
.runs\daily-ai-radar\YYYY-MM-DD\
```

### Android 开发日报

推荐命令：

```powershell
.\scripts\Run-AndroidDailyRadar.ps1 -LookbackHours 24 -MaxItemsPerSource 10
```

等价的通用命令：

```powershell
.\scripts\Run-DailyRadar.ps1 -Topic android -LookbackHours 24 -MaxItemsPerSource 10
```

输出目录：

```text
.runs\android-daily-radar\YYYY-MM-DD\
```

## 工作流

一键启动脚本会完成：

```text
初始化运行目录 -> 采集候选新闻 -> 生成 generate-prompt.md -> 写 run-metadata.json
```

然后对 Codex 说：

```text
读取今天的 generate-prompt.md，生成日报，但先不要发飞书
```

生成 Markdown 后，再发送飞书：

```powershell
.\scripts\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\daily-ai-radar\YYYY-MM-DD\daily-ai-radar.md
```

Android 日报对应：

```powershell
.\scripts\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\android-daily-radar\YYYY-MM-DD\android-daily-radar.md
```

只发纯文本摘要，不导入云文档：

```powershell
.\scripts\Send-FeishuDailyRadar.ps1 -MarkdownPath <markdown-path> -TextOnly
```

## 分步执行

初始化运行目录：

```powershell
.\scripts\Invoke-DailyRadar.ps1 -Topic ai
.\scripts\Invoke-DailyRadar.ps1 -Topic android
```

采集候选新闻：

```powershell
.\scripts\Collect-NewsCandidates.ps1 -Topic ai -LookbackHours 24
.\scripts\Collect-NewsCandidates.ps1 -Topic android -LookbackHours 24
```

生成正式写作 prompt：

```powershell
.\scripts\Generate-DailyRadar.ps1 -Topic ai
.\scripts\Generate-DailyRadar.ps1 -Topic android
```

兼容脚本仍保留：

```powershell
.\scripts\Run-AiDailyRadar.ps1
.\scripts\Invoke-AiDailyRadar.ps1
.\scripts\Generate-AiDailyRadar.ps1
.\scripts\Collect-AiNewsCandidates.ps1
```

## Codex 自动任务建议

建议每个主题建一个独立自动任务。

AI 日报：

```powershell
.\scripts\Run-DailyRadar.ps1 -Topic ai -LookbackHours 24 -MaxItemsPerSource 10
```

Android 日报：

```powershell
.\scripts\Run-DailyRadar.ps1 -Topic android -LookbackHours 24 -MaxItemsPerSource 10
```

自动任务要点：

1. 先运行对应主题的 `Run-DailyRadar.ps1`。
2. 读取当天生成的 `generate-prompt.md`。
3. 按对应主题 skill 继续核验、筛选、写 Markdown 和 JSON。
4. 再运行 `Send-FeishuDailyRadar.ps1` 推送飞书。

## 输出文件约定

AI：

- Markdown：`.runs/daily-ai-radar/YYYY-MM-DD/daily-ai-radar.md`
- JSON：`.runs/daily-ai-radar/YYYY-MM-DD/daily-ai-radar.json`
- 候选新闻：`.runs/daily-ai-radar/YYYY-MM-DD/candidates.json`
- 生成提示：`.runs/daily-ai-radar/YYYY-MM-DD/generate-prompt.md`
- 运行提示：`.runs/daily-ai-radar/YYYY-MM-DD/run-prompt.md`
- 运行元数据：`.runs/daily-ai-radar/YYYY-MM-DD/run-metadata.json`

Android：

- Markdown：`.runs/android-daily-radar/YYYY-MM-DD/android-daily-radar.md`
- JSON：`.runs/android-daily-radar/YYYY-MM-DD/android-daily-radar.json`
- 候选新闻：`.runs/android-daily-radar/YYYY-MM-DD/candidates.json`
- 生成提示：`.runs/android-daily-radar/YYYY-MM-DD/generate-prompt.md`
- 运行提示：`.runs/android-daily-radar/YYYY-MM-DD/run-prompt.md`
- 运行元数据：`.runs/android-daily-radar/YYYY-MM-DD/run-metadata.json`

## 新增主题

新增主题时，按下面结构添加：

```text
config/topics/<topic>/
|-- topic.json
|-- collection-feeds.json
|-- sources.json
`-- automation-prompt.md

skills/<topic-skill>/
`-- SKILL.md

templates/<topic-template>.md
```

然后运行：

```powershell
.\scripts\Run-DailyRadar.ps1 -Topic <topic>
```
