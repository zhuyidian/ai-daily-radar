# Daily Radar

每天抓取、筛选并生成中文主题日报，然后推送到飞书群。

当前已支持：

- AI 行业日报
- Android 开发日报

项目的核心设计是“同一套脚本，不同主题配置”：

- `config/topics/<topic>/`：每个主题的抓取源、参考源、自动任务 prompt 和主题元信息。
- `skills/<topic-skill>/`：每个主题的筛选、评分和写作口径。
- `scripts/common/Run-DailyRadar.ps1`：多主题通用入口。
- `scripts/topics/Run-*.ps1`：行业主题快捷入口。
- `scripts/channels/Send-FeishuDailyRadar.ps1`：把本地 Markdown 日报导入飞书云文档，并把摘要和链接发到群。
- `scripts/channels/New-WeChatDailyRadarPrompt.ps1`：为公众号版文章和插图生成 Codex handoff prompt。
- `scripts/channels/Convert-WeChatDailyRadarArticle.ps1`：把公众号版 Markdown 转成微信兼容 HTML 预览。
- `scripts/channels/Send-WeChatDailyRadarDraft.ps1`：把公众号版文章创建到微信公众号草稿箱。

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
|-- scripts/
|   |-- common/
|   |   |-- Run-DailyRadar.ps1
|   |   |-- Collect-NewsCandidates.ps1
|   |   |-- Collect-RssNewsCandidates.ps1
|   |   |-- Generate-DailyRadar.ps1
|   |   |-- Invoke-DailyRadar.ps1
|   |   `-- Get-DailyRadarTopic.ps1
|   |-- topics/
|   |   |-- Run-AiDailyRadar.ps1
|   |   `-- Run-AndroidDailyRadar.ps1
|   |-- channels/
|   |   |-- Send-FeishuDailyRadar.ps1
|   |   |-- New-WeChatDailyRadarPrompt.ps1
|   |   |-- Convert-WeChatDailyRadarArticle.ps1
|   |   `-- Send-WeChatDailyRadarDraft.ps1
|-- skills/
|   |-- ai-daily-industry-radar/
|   |   `-- SKILL.md
|   `-- android-daily-developer-radar/
|       `-- SKILL.md
`-- templates/
    |-- ai-daily-radar.md
    `-- android-daily-radar.md
```

## 版本管理

当前版本：`V1.2.1`

版本说明：公众号文章生成阶段保留正文内普通 Markdown 来源链接，便于后续转换为微信底部引用。

## 本地密钥配置

密钥不使用系统环境变量。先复制本地配置模板：

```powershell
Copy-Item .\config\local.secrets.example.json .\config\local.secrets.json
```

然后编辑 `config/local.secrets.json`：

```json
{
  "feishu": {
    "app_id": "cli_xxx",
    "app_secret": "xxx",
    "chat_id": "oc_xxx",
    "folder_token": "fld_xxx",
    "open_api_base": "https://open.feishu.cn"
  },
  "wechat": {
    "default_account": "ai-daily",
    "accounts": [
      {
        "alias": "ai-daily",
        "name": "AI Daily Radar",
        "app_id": "wx_xxx",
        "app_secret": "xxx",
        "author": "AI Daily Radar",
        "theme": "modern",
        "color": "blue",
        "need_open_comment": 1,
        "only_fans_can_comment": 0,
        "publish_method": "api",
        "chrome_profile_path": ""
      }
    ]
  }
}
```

`config/local.secrets.json` 已加入 `.gitignore`，不要提交真实密钥。

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
.\scripts\topics\Run-AiDailyRadar.ps1 -LookbackHours 24 -MaxItemsPerSource 10
```

等价的通用命令：

```powershell
.\scripts\common\Run-DailyRadar.ps1 -Topic ai -LookbackHours 24 -MaxItemsPerSource 10
```

输出目录：

```text
.runs\ai-daily-radar\YYYY-MM-DD\
```

### Android 开发日报

推荐命令：

```powershell
.\scripts\topics\Run-AndroidDailyRadar.ps1 -LookbackHours 24 -MaxItemsPerSource 10
```

等价的通用命令：

```powershell
.\scripts\common\Run-DailyRadar.ps1 -Topic android -LookbackHours 24 -MaxItemsPerSource 10
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
.\scripts\channels\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\common\ai-daily-radar.md
```

Android 日报对应：

```powershell
.\scripts\channels\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\android-daily-radar\YYYY-MM-DD\common\android-daily-radar.md
```

只发纯文本摘要，不导入云文档：

```powershell
.\scripts\channels\Send-FeishuDailyRadar.ps1 -MarkdownPath <markdown-path> -TextOnly
```

### 公众号草稿箱

公众号链路和飞书链路独立，推荐顺序：

```text
日报 JSON/Markdown
-> wechat-article-writer 生成公众号版文章
-> 去 AI 味编辑改写
-> imagegen 生成封面和插图
-> baoyu-markdown-to-html 排版预览
-> baoyu-post-to-wechat 创建公众号草稿
```

先生成公众号文章和插图的 handoff prompt：

```powershell
.\scripts\channels\New-WeChatDailyRadarPrompt.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\common\ai-daily-radar.md
```

然后对 Codex 说：

```text
读取 .runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\wechat-article-prompt.md，生成公众号版文章；
再读取 wechat-assets-prompt.md，用 imagegen 生成封面和插图。
```

`New-WeChatDailyRadarPrompt.ps1` 生成的公众号 prompt 默认会要求：

- 不直接照搬日报标题，改成更自然、有判断的公众号标题。
- 先基于 JSON/Markdown 写稿，再做一轮“去 AI 味编辑”。
- 关键事实在正文里保留普通 Markdown 来源链接，例如 `[TechCrunch 报道称](https://...)`，后续发布步骤会转换为微信底部引用。
- 1-2 条重点深写，低优先级信息压缩处理，避免每条新闻平均用力。
- 减少模板腔、重复转折和高频抽象词，不编造事实、不新增来源。
- 图片默认采用克制的中文商业科技杂志/信息图风格，避开发光大脑、赛博城市、雷达屏幕等高频 AI 视觉。

生成后的目录约定：

```text
.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\
|-- wechat-article.md
|-- wechat-article.html
|-- wechat-draft-result.json
`-- imgs\
    |-- cover.png
    |-- hero.png
    `-- item-01.png
```

排版预览：

```powershell
.\scripts\channels\Convert-WeChatDailyRadarArticle.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\wechat-article.md
```

先 dry run 检查公众号草稿参数，不创建草稿：

```powershell
.\scripts\channels\Send-WeChatDailyRadarDraft.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\wechat-article.md `
  -CoverPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\imgs\cover.png `
  -DryRun
```

确认后创建公众号草稿箱：

```powershell
.\scripts\channels\Send-WeChatDailyRadarDraft.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\wechat-article.md `
  -CoverPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\imgs\cover.png
```

也可以通过通用入口触发已生成文章的草稿创建：

```powershell
.\scripts\common\Run-DailyRadar.ps1 `
  -Topic ai `
  -SkipCollect `
  -SkipGenerate `
  -CreateWeChatDraft `
  -WeChatCoverPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\imgs\cover.png
```

## 分步执行

初始化运行目录：

```powershell
.\scripts\common\Invoke-DailyRadar.ps1 -Topic ai
.\scripts\common\Invoke-DailyRadar.ps1 -Topic android
```

采集候选新闻：

```powershell
.\scripts\common\Collect-NewsCandidates.ps1 -Topic ai -LookbackHours 24
.\scripts\common\Collect-NewsCandidates.ps1 -Topic android -LookbackHours 24
```

生成正式写作 prompt：

```powershell
.\scripts\common\Generate-DailyRadar.ps1 -Topic ai
.\scripts\common\Generate-DailyRadar.ps1 -Topic android
```

便捷入口仍保留：

```powershell
.\scripts\topics\Run-AiDailyRadar.ps1
.\scripts\topics\Run-AndroidDailyRadar.ps1
```

## Codex 自动任务建议

建议每个主题建一个独立自动任务。

AI 日报：

```powershell
.\scripts\common\Run-DailyRadar.ps1 -Topic ai -LookbackHours 24 -MaxItemsPerSource 10
```

Android 日报：

```powershell
.\scripts\common\Run-DailyRadar.ps1 -Topic android -LookbackHours 24 -MaxItemsPerSource 10
```

自动任务要点：

1. 先运行对应主题的 `Run-DailyRadar.ps1`。
2. 读取当天生成的 `generate-prompt.md`。
3. 按对应主题 skill 继续核验、筛选、写 Markdown 和 JSON。
4. 再运行 `Send-FeishuDailyRadar.ps1` 推送飞书。
5. 如果要同步公众号，先生成公众号版文章和插图，再运行 `Send-WeChatDailyRadarDraft.ps1` 创建草稿箱。

## 输出文件约定

AI：

- Markdown：`.runs/ai-daily-radar/YYYY-MM-DD/common/ai-daily-radar.md`
- JSON：`.runs/ai-daily-radar/YYYY-MM-DD/common/ai-daily-radar.json`
- 候选新闻：`.runs/ai-daily-radar/YYYY-MM-DD/common/candidates.json`
- 生成提示：`.runs/ai-daily-radar/YYYY-MM-DD/common/generate-prompt.md`
- 运行提示：`.runs/ai-daily-radar/YYYY-MM-DD/common/run-prompt.md`
- 运行元数据：`.runs/ai-daily-radar/YYYY-MM-DD/common/run-metadata.json`
- 飞书结果：`.runs/ai-daily-radar/YYYY-MM-DD/channels/feishu/`
- 公众号文章：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/wechat-article.md`
- 公众号 HTML 预览：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/wechat-article.html`
- 公众号插图：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/imgs/`
- 公众号草稿结果：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/wechat-draft-result.json`

Android：

- Markdown：`.runs/android-daily-radar/YYYY-MM-DD/common/android-daily-radar.md`
- JSON：`.runs/android-daily-radar/YYYY-MM-DD/common/android-daily-radar.json`
- 候选新闻：`.runs/android-daily-radar/YYYY-MM-DD/common/candidates.json`
- 生成提示：`.runs/android-daily-radar/YYYY-MM-DD/common/generate-prompt.md`
- 运行提示：`.runs/android-daily-radar/YYYY-MM-DD/common/run-prompt.md`
- 运行元数据：`.runs/android-daily-radar/YYYY-MM-DD/common/run-metadata.json`
- 飞书结果：`.runs/android-daily-radar/YYYY-MM-DD/channels/feishu/`

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
.\scripts\common\Run-DailyRadar.ps1 -Topic <topic>
```
