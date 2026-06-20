# Changelog

## V1.3.0 - 2026-06-21

### 新增

- 新增AI和Android公众号主题文章配置：`config/topics/<topic>/wechat-editorial.json`。
- 新增`wechat-editorial-writer` Skill，统一选题、事实引用、人话表达、克制幽默、合理篇幅和视觉质量规则。
- 新增公众号主题文章四阶段工作流：
  - 近3至5天日报选题与75分发布门槛；
  - 初稿和10个标题候选；
  - 80分独立质量审核与事实硬门槛；
  - 封面、正文图和视觉方案生成。
- 新增完整工作流入口`New-WeChatEditorialWorkflowPrompt.ps1`，同时保留分阶段脚本，便于局部重跑。
- Android主题文章支持版本与工具解读、升级迁移指南、政策影响和工程深度拆解。

### 调整

- 渠道脚本按职责重新划分：
  - `scripts/channels/feishu/`；
  - `scripts/channels/wechat/common/`；
  - `scripts/channels/wechat/daily-radar/`；
  - `scripts/channels/wechat/editorial/`。
- 微信运行产物同步划分为`channels/wechat/common/`、`daily-radar/`和`editorial/`。
- 公众号日报默认文章路径迁移到`channels/wechat/daily-radar/wechat-article.md`。
- 微信公共临时运行文件迁移到`channels/wechat/common/.baoyu-runtime/`。
- 更新AI与Android自动任务提示、Skill中的飞书路径和README命令示例。

### 修复

- 改进Windows下`bun`/`npx`命令发现、参数传递和UTF-8输出处理。
- 为`npx`回退设置项目内npm缓存，减少受限用户目录导致的失败。
- 微信草稿发布时将`NPX_COMMAND`传递给内部渲染进程，并增加执行超时。
- 微信草稿凭据统一读取`config/local.secrets.json`，运行后清理临时凭据文件和进程环境变量。

### 路径迁移

旧路径：

```text
scripts/channels/<script>.ps1
.runs/<topic>/YYYY-MM-DD/channels/wechat/wechat-article.md
```

新路径：

```text
scripts/channels/feishu/
scripts/channels/wechat/common/
scripts/channels/wechat/daily-radar/
scripts/channels/wechat/editorial/
.runs/<topic>/YYYY-MM-DD/channels/wechat/daily-radar/wechat-article.md
.runs/<topic>/YYYY-MM-DD/channels/wechat/editorial/wechat-article.md
```

### 兼容性说明

- 日报采集、Markdown/JSON生成和飞书发送逻辑保持不变，仅脚本路径发生迁移。
- 原公众号日报链路继续保留；主题文章链路是新增能力，可按选题结果选择使用。
- `Run-DailyRadar.ps1`创建微信草稿时，默认读取新的`daily-radar`文章路径。
