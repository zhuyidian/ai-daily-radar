请在当前项目目录执行一次 Android 开发日报工作流。

要求：

1. 使用 `skills/android-daily-developer-radar/SKILL.md` 中的筛选、评分和输出规则。
2. 关注过去 24 小时内 Android 开发生态的高价值信息。如果今天是周一，可适度回看周末。
3. 优先核验官方文档、Release Notes、Changelog、GitHub Release、AOSP 页面、安全公告、Google Play 政策页和项目一手博客。
4. 重点关注 Android 平台、Android Studio、Android Gradle Plugin、Gradle、Kotlin、Jetpack、Compose、Google Play 政策、安全公告、兼容性、性能和重要开源库。
5. 去重并保留最重要内容，另给一句话快讯。
6. 先运行候选新闻采集脚本：
   `.\scripts\common\Collect-NewsCandidates.ps1 -Topic android -LookbackHours 24`
7. 运行生成提示脚本：
   `.\scripts\common\Generate-DailyRadar.ps1 -Topic android`
8. 读取 `.runs\android-daily-radar\YYYY-MM-DD\common\generate-prompt.md`，结合候选新闻继续搜索核验，不要只依赖候选列表。
9. 生成中文 Markdown 日报和 JSON 数据文件：
   - `.runs\android-daily-radar\YYYY-MM-DD\common\android-daily-radar.md`
   - `.runs\android-daily-radar\YYYY-MM-DD\common\android-daily-radar.json`
10. Markdown 写完后运行：
   `.\scripts\channels\feishu\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\android-daily-radar\YYYY-MM-DD\common\android-daily-radar.md`

写作标准：

- 每条必须说明：发生了什么、为什么重要、影响谁、建议动作、风险点、原文链接。
- 工具和库更新要写清楚是否建议立即升级。
- 政策和上架要求要写清楚生效日期、影响范围和开发者动作。
- 对没有充分来源支撑的信息，降级到“一句话快讯”或剔除。
- 标注具体日期，不用“昨天/今天”代替事实发生时间。
