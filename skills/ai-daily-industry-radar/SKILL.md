---
name: ai-daily-industry-radar
description: Use this skill whenever the user wants a daily AI industry radar, AI news digest, AI日报, AI行业日报, trend scan, Feishu-pushed AI briefing, or recurring AI intelligence workflow. It defines what sources to inspect, how to deduplicate and score signals, and how to produce a concise Chinese Markdown/JSON report suitable for Codex automations and Feishu delivery.
---

# AI Daily Industry Radar

Use this skill to turn raw AI news into a useful Chinese daily briefing. The skill is intentionally opinionated: prioritize material changes over traffic bait, explain why each item matters, and keep the report short enough that a busy reader can act on it.

## Workflow

1. Establish the reporting window.
   - Default to the past 24 hours.
   - If running on Monday morning, include meaningful weekend items.
   - Use absolute dates in the final report.
2. Gather candidates from official, developer, market, and China-facing sources.
   - Use `config/topics/ai/sources.json` when present.
   - If `candidates.json` or `generate-prompt.md` is present in the run directory, treat it as the starting candidate pool.
   - Search beyond the list only when a story is clearly important or sources are sparse.
3. Verify and deduplicate.
   - Prefer official announcements, paper/project pages, release notes, regulator pages, company blogs, GitHub repositories, or primary interviews.
   - Use credible secondary media only when primary sources are unavailable.
   - Merge duplicate coverage into one item and keep the strongest original link.
4. Score each candidate.
5. Keep 5-8 top items and 3-8 one-line briefs.
6. Write the requested Markdown and JSON files in the run directory.
7. If Feishu delivery is requested, send the Markdown through the project script.

## Priority Sources

Start with these categories:

- Official model/company sources: OpenAI, Anthropic, Google DeepMind, Google AI, Meta AI, Microsoft AI, NVIDIA, Hugging Face.
- Developer and research sources: GitHub Trending, GitHub Releases, arXiv cs.AI/cs.LG/cs.CL, model cards, benchmark/project pages.
- Market and startup sources: Product Hunt AI, TechCrunch AI, The Decoder, company funding announcements.
- China-facing sources: 机器之心, 量子位, 晚点 LatePost, major Chinese AI company announcements, regulator pages.

## Keep / Drop Rules

Keep items that match at least one of these:

- Model or product release with meaningful capability, pricing, availability, or integration change.
- AI Agent, AI coding, video, image, voice, robotics, multimodal, or inference infrastructure development.
- Open-source release likely to affect builders.
- Funding, acquisition, partnership, chip/cloud capacity, regulation, lawsuit, or policy change with industry impact.
- News that materially affects Chinese users, developers, content creators, founders, or enterprise buyers.

Drop or downgrade:

- Generic thought pieces without new facts.
- Reposts of already-covered announcements.
- Rumors without a reliable source.
- Tiny feature updates unless they change an important workflow.
- Research papers with no clear practical or strategic implication.

## Candidate Pool Handling

When working from `candidates.json`:

- Treat Google News RSS entries as discovery leads, not final sources.
- Replace Google News redirect URLs with primary sources whenever possible.
- If multiple media links describe the same event, merge them into one item and cite the official/company/regulator/source page.
- Keep arXiv papers only when they have a clear industry, product, model, safety, or developer impact.
- Preserve genuinely important low-score official items if the keyword scorer missed them.
- Do not include a story solely because it has a high candidate score.
- If verification is weak, downgrade the item to a one-line brief or watchlist item.

## Scoring

Score each candidate from 1 to 10:

- Impact: 0-3 points. Does it change capability, cost, access, regulation, or strategy?
- Novelty: 0-2 points. Is it genuinely new in the reporting window?
- Relevance: 0-2 points. Does it matter to AI builders, creators, companies, or Chinese readers?
- Source strength: 0-2 points. Is there a primary or highly credible source?
- Actionability: 0-1 point. Can readers do something useful with it?

Interpretation:

- 9-10: Lead story.
- 7-8: Top item.
- 5-6: One-line brief or watchlist.
- Below 5: Usually omit.

## Report Structure

Always write in Chinese. Keep it concise and specific.

```markdown
# AI 行业日报 | YYYY-MM-DD

> 覆盖时间：YYYY-MM-DD HH:mm - YYYY-MM-DD HH:mm

## 今日最值得关注

### 1. 标题

- 发生了什么：
- 为什么重要：
- 影响谁：
- 推荐关注指数：9/10
- 可信度：高/中/低
- 原文链接：

## 一句话快讯

- ...

## 今日观察

一小段编辑判断：今天的共同趋势、风险或机会。

## 值得继续跟踪

- ...
```

## JSON Structure

Also produce a machine-readable JSON file:

```json
{
  "date": "YYYY-MM-DD",
  "window_start": "YYYY-MM-DDTHH:mm:ssZ",
  "window_end": "YYYY-MM-DDTHH:mm:ssZ",
  "top_items": [
    {
      "rank": 1,
      "title": "",
      "category": "",
      "what_happened": "",
      "why_it_matters": "",
      "who_is_affected": "",
      "score": 9,
      "confidence": "high",
      "source_url": "",
      "source_name": "",
      "published_at": "YYYY-MM-DD"
    }
  ],
  "briefs": [],
  "watchlist": []
}
```

## Feishu Delivery

When the project contains `scripts/channels/feishu/Send-FeishuDailyRadar.ps1`, use it after writing the Markdown:

```powershell
.\scripts\channels\feishu\Send-FeishuDailyRadar.ps1 -MarkdownPath .\.runs\ai-daily-radar\YYYY-MM-DD\common\ai-daily-radar.md
```

Use `-TextOnly` only when the user does not want a cloud document or when import permissions are unavailable.

## Writing Voice

- Be direct, editorial, and useful.
- Explain consequences, not just facts.
- Avoid hype words unless the source itself demonstrates the claim.
- Prefer concrete user groups: developers, startups, enterprise buyers, content creators, researchers, Chinese users.
- Do not force exactly five items if the day is quiet; quality beats count.
