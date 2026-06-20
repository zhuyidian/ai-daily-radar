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
- `scripts/channels/feishu/`：飞书渠道脚本。
- `scripts/channels/wechat/common/`：微信公众号各内容链路共用的排版和草稿发布脚本。
- `scripts/channels/wechat/daily-radar/`：现有“日报转公众号文章”链路。
- `scripts/channels/wechat/editorial/`：高质量“主题选题文章”链路。

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
|   |   |   |-- automation-prompt.md
|   |   |   `-- wechat-editorial.json
|   |   `-- android/
|   |       |-- topic.json
|   |       |-- collection-feeds.json
|   |       |-- sources.json
|   |       |-- automation-prompt.md
|   |       `-- wechat-editorial.json
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
|   |   |-- feishu/
|   |   |   `-- Send-FeishuDailyRadar.ps1
|   |   `-- wechat/
|   |       |-- common/
|   |       |   |-- Convert-WeChatDailyRadarArticle.ps1
|   |       |   `-- Send-WeChatDailyRadarDraft.ps1
|   |       |-- daily-radar/
|   |       |   `-- New-WeChatDailyRadarPrompt.ps1
|   |       `-- editorial/
|   |           |-- Editorial.Common.ps1
|   |           |-- New-WeChatEditorialWorkflowPrompt.ps1
|   |           |-- New-WeChatEditorialSelectionPrompt.ps1
|   |           |-- New-WeChatEditorialArticlePrompt.ps1
|   |           |-- New-WeChatEditorialReviewPrompt.ps1
|   |           `-- New-WeChatEditorialAssetsPrompt.ps1
|-- skills/
|   |-- ai-daily-industry-radar/
|   |   `-- SKILL.md
|   |-- android-daily-developer-radar/
|   |   `-- SKILL.md
|   `-- wechat-editorial-writer/
|       `-- SKILL.md
`-- templates/
    |-- ai-daily-radar.md
    `-- android-daily-radar.md
```

## 版本管理

当前版本：`V1.3.0`

版本记录：

| 版本 | 说明 |
| --- | --- |
| `V1.3.0` | 新增 AI/Android 公众号主题文章链路，支持跨日报选题、发布门槛、标题生成、独立质检和视觉规划；按飞书、微信公共能力、日报链路和主题链路重构渠道目录及运行输出。 |
| `V1.2.3` | 修复 Windows 下公众号 HTML 转换和草稿创建的 `bun`/`npx` 查找、命令引号与 npm 缓存问题；公众号草稿密钥统一从 `config/local.secrets.json` 读取。 |
| `V1.2.2` | 将 `wechat-article-writer`、`baoyu-markdown-to-html`、`baoyu-post-to-wechat` 内置到项目 `skills/` 目录，并让公众号脚本使用项目内 skill，不再依赖全局 skill。 |
| `V1.2.1` | 公众号文章生成阶段保留正文内普通 Markdown 来源链接，便于后续转换为微信底部引用。 |
| `V1.2.0` | 新增微信公众号草稿箱链路，并统一飞书和公众号密钥到本地配置文件。 |
| `V1.1.1` | 统一多主题输出命名，移除旧 AI-only 配置和脚本。 |
| `V1.1.0` | 升级为多主题日报框架，保留 AI 日报，并新增 Android 开发日报主题。 |
| `V1.0.1` | 发送飞书日报后会在运行目录写入发送结果 JSON，便于自动任务追踪 dry run 和正式发送状态。 |
| `V1.0.0` | 初始化 AI Daily Radar 工作流，支持 AI 行业日报生成和飞书推送。 |

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
.\scripts\channels\feishu\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\common\ai-daily-radar.md
```

Android 日报对应：

```powershell
.\scripts\channels\feishu\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\android-daily-radar\YYYY-MM-DD\common\android-daily-radar.md
```

只发纯文本摘要，不导入云文档：

```powershell
.\scripts\channels\feishu\Send-FeishuDailyRadar.ps1 -MarkdownPath <markdown-path> -TextOnly
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
.\scripts\channels\wechat\daily-radar\New-WeChatDailyRadarPrompt.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\common\ai-daily-radar.md
```

然后对 Codex 说：

```text
读取 .runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\wechat-article-prompt.md，生成公众号版文章；
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
.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\
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
.\scripts\channels\wechat\common\Convert-WeChatDailyRadarArticle.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\wechat-article.md
```

先 dry run 检查公众号草稿参数，不创建草稿：

```powershell
.\scripts\channels\wechat\common\Send-WeChatDailyRadarDraft.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\wechat-article.md `
  -CoverPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\imgs\cover.png `
  -DryRun
```

确认后创建公众号草稿箱：

```powershell
.\scripts\channels\wechat\common\Send-WeChatDailyRadarDraft.ps1 `
  -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\wechat-article.md `
  -CoverPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\imgs\cover.png
```

也可以通过通用入口触发已生成文章的草稿创建：

```powershell
.\scripts\common\Run-DailyRadar.ps1 `
  -Topic ai `
  -SkipCollect `
  -SkipGenerate `
  -CreateWeChatDraft `
  -WeChatCoverPath .\.runs\ai-daily-radar\YYYY-MM-DD\channels\wechat\daily-radar\imgs\cover.png
```

### 公众号主题选题文章

新链路与现有公众号日报链路并存。它读取最近几天的日报 JSON，但每篇只围绕一个核心判断写作：

```text
近 3-5 天日报 JSON
-> 选出一个主题并设置发布门槛
-> 生成文章初稿和 10 个标题候选
-> 独立核验事实、人话表达、篇幅与标题承诺
-> 通过 80 分质量门槛后生成最终文章
-> 规划非通用 AI 风格的封面和正文图
-> 复用公众号公共脚本进行排版和草稿发布
```

生成选题提示：

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialWorkflowPrompt.ps1 `
  -Topic ai `
  -LookbackDays 5
```

Android主题文章使用：

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialWorkflowPrompt.ps1 `
  -Topic android `
  -LookbackDays 5
```

该入口生成一份完整工作流提示，适合每天直接交给 Codex 执行。下面的分阶段脚本用于局部重跑或调试。

后续依次运行：

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialArticlePrompt.ps1 `
  -DecisionPath <editorial-decision.json>

.\scripts\channels\wechat\editorial\New-WeChatEditorialReviewPrompt.ps1 `
  -DraftPath <wechat-article-draft.md>

.\scripts\channels\wechat\editorial\New-WeChatEditorialAssetsPrompt.ps1 `
  -MarkdownPath <wechat-article.md>
```

完整分步说明见 `scripts/channels/wechat/editorial/README.md`。当选题评分不足或证据无法形成明确论点时，`editorial-decision.json` 应设置 `publish=false`，不强行生成主题文章。

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
- 公众号日报文章：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/daily-radar/wechat-article.md`
- 公众号日报 HTML：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/daily-radar/wechat-article.html`
- 公众号日报插图：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/daily-radar/imgs/`
- 公众号日报草稿结果：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/daily-radar/wechat-draft-result.json`
- 公众号主题文章：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/editorial/wechat-article.md`
- 微信公共运行文件：`.runs/ai-daily-radar/YYYY-MM-DD/channels/wechat/common/`

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
