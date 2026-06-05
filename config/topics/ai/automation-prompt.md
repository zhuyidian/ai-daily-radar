请在当前项目目录执行一次 AI 行业日报工作流。

要求：

1. 使用 `skills/ai-daily-industry-radar/SKILL.md` 中的筛选、评分和输出规则。
2. 关注过去 24 小时内的 AI 行业最新信息。如果今天是周一，可适度回看周末。
3. 优先核验官方来源、产品博客、论文、GitHub Release、可信媒体和一手公告。
4. 重点关注模型发布、AI Agent、AI 编程、AI 视频、图像、多模态、AI 基础设施、产业融资并购、监管政策，以及对中国用户/开发者/内容创作者有实际影响的变化。
5. 去重并保留 5-8 条最重要内容，另给 3-8 条一句话快讯。
6. 先运行候选新闻采集脚本：
   `.\scripts\Collect-NewsCandidates.ps1 -Topic ai -LookbackHours 24`
7. 运行生成提示脚本：
   `.\scripts\Generate-DailyRadar.ps1 -Topic ai`
8. 读取 `.runs\daily-ai-radar\YYYY-MM-DD\generate-prompt.md`，结合候选新闻继续搜索核验，不要只依赖候选列表。
9. 生成中文 Markdown 日报和 JSON 数据文件：
   - `.runs\daily-ai-radar\YYYY-MM-DD\daily-ai-radar.md`
   - `.runs\daily-ai-radar\YYYY-MM-DD\daily-ai-radar.json`
10. Markdown 写完后运行：
   `.\scripts\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\daily-ai-radar\YYYY-MM-DD\daily-ai-radar.md`

写作标准：

- 每条必须说明：发生了什么、为什么重要、影响谁、推荐关注指数、原文链接。
- 不写泛泛而谈的流水账。
- 对没有充分来源支撑的信息，降级到“一句话快讯”或剔除。
- 标注具体日期，不用“昨天/今天”代替事实发生时间。
