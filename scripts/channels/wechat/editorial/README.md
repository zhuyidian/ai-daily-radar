# 主题选题文章链路

该链路从最近几天的日报 JSON 中选择一个主题，经过独立写稿、质检和视觉规划后，再复用 `../common/` 中的微信排版与草稿发布脚本。

## 推荐：生成完整工作流提示

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialWorkflowPrompt.ps1 `
  -Topic ai `
  -LookbackDays 5
```

将 `-Topic ai` 改为 `-Topic android`，即可使用Android专属读者、文章类型和视觉配置。

让 Codex 读取生成的 `editorial-workflow-prompt.md`，即可依次完成下面四个阶段。选题或质检未通过时会停止，不创建不合格文章。

## 1. 生成选题提示

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialSelectionPrompt.ps1 `
  -Topic ai `
  -LookbackDays 5
```

让 Codex 读取生成的 `editorial-selection-prompt.md`，写出 `editorial-decision.json`。当 `publish=false` 时终止主题文章链路，现有日报公众号链路不受影响。

## 2. 生成文章提示

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialArticlePrompt.ps1 `
  -DecisionPath <editorial-decision.json>
```

让 Codex 读取 `editorial-article-prompt.md`，写出10个标题候选和 `wechat-article-draft.md`。

## 3. 生成独立质检提示

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialReviewPrompt.ps1 `
  -DraftPath <wechat-article-draft.md>
```

让 Codex 读取 `editorial-review-prompt.md`。文章总分达到80分且无事实、论点、标题或引用硬伤时，才生成最终 `wechat-article.md`。

## 4. 生成视觉提示

```powershell
.\scripts\channels\wechat\editorial\New-WeChatEditorialAssetsPrompt.ps1 `
  -MarkdownPath <wechat-article.md>
```

让 Codex 读取 `editorial-assets-prompt.md`，先生成 `visual-plan.json`，再按需生成封面和1至2张有信息价值的正文图。

## 5. 排版并创建草稿

```powershell
.\scripts\channels\wechat\common\Convert-WeChatDailyRadarArticle.ps1 `
  -MarkdownPath <wechat-article.md>

.\scripts\channels\wechat\common\Send-WeChatDailyRadarDraft.ps1 `
  -MarkdownPath <wechat-article.md> `
  -CoverPath <imgs\cover.png>
```
