---
name: android-daily-developer-radar
description: Use this skill whenever the user wants an Android developer daily briefing, Android 开发日报, Kotlin/Compose/AGP/Android Studio update radar, Google Play policy monitor, or recurring Android ecosystem intelligence workflow.
---

# Android Daily Developer Radar

Use this skill to turn raw Android ecosystem news into a concise Chinese daily briefing for Android developers and engineering leads. Prioritize changes that affect development workflow, build behavior, runtime compatibility, publishing, security, performance, or migration decisions.

## Workflow

1. Establish the reporting window.
   - Default to the past 24 hours.
   - If running on Monday morning, include meaningful weekend items.
   - Use absolute dates in the final report.
2. Gather candidates from official, developer, policy, and China-facing sources.
   - Use `config/topics/android/sources.json` when present.
   - If `candidates.json` or `generate-prompt.md` is present in the run directory, treat it as the starting candidate pool.
3. Verify and deduplicate.
   - Prefer official docs, release notes, changelogs, GitHub releases, AOSP pages, security bulletins, Google Play policy pages, and primary project blogs.
   - Use credible secondary media only when primary sources are unavailable.
   - Merge duplicate coverage into one item and keep the strongest source link.
4. Score each candidate.
5. Keep the strongest top items and one-line briefs.
6. Write the requested Markdown and JSON files in the run directory.
7. If Feishu delivery is requested, send the Markdown through the project script.

## Priority Sources

Start with these categories:

- Official Android sources: Android Developers Blog, Android Studio release notes, Android Gradle Plugin release notes, Jetpack and AndroidX release notes, Compose release notes, Android Security Bulletins, AOSP docs.
- Language and build sources: Kotlin Blog, Gradle Blog, KSP/kotlinx release notes, JetBrains updates.
- Publishing and policy sources: Google Play policy updates, Play Console announcements, target SDK deadlines, privacy and permission changes.
- Developer ecosystem sources: GitHub releases for important Android/Kotlin libraries, Firebase Blog, major open-source Android projects.
- China-facing sources: 掘金 Android, InfoQ Android, and domestic ecosystem changes that affect Android developers.

## Keep / Drop Rules

Keep items that match at least one of these:

- Android platform, SDK, target SDK, security, permission, privacy, or compatibility change.
- Android Studio, AGP, Gradle, Kotlin, KSP, Jetpack, Compose, Firebase, or major library release with developer impact.
- Google Play policy, deadline, review, billing, privacy, or publishing requirement change.
- AOSP, security bulletin, CVE, or device ecosystem change that affects app behavior.
- Performance, build speed, migration, testing, or debugging improvement with practical value.
- Important open-source release likely to affect Android app teams.

Drop or downgrade:

- Generic tutorials without new facts.
- Reposts of already-covered release notes.
- Rumors without reliable source.
- Tiny library updates with no migration or workflow impact.
- Opinion pieces without actionable technical or policy consequence.

## Scoring

Score each candidate from 1 to 10:

- Impact: 0-3 points. Does it change build, runtime, release, policy, security, or developer workflow?
- Novelty: 0-2 points. Is it genuinely new in the reporting window?
- Relevance: 0-2 points. Does it matter to Android developers, app teams, or release owners?
- Source strength: 0-2 points. Is there a primary source?
- Actionability: 0-1 point. Can readers upgrade, defer, migrate, test, or monitor?

Interpretation:

- 9-10: Lead story.
- 7-8: Top item.
- 5-6: One-line brief or watchlist.
- Below 5: Usually omit.

## Report Structure

Always write in Chinese. Keep it practical and specific.

```markdown
# Android 开发日报 | YYYY-MM-DD

> 覆盖时间：YYYY-MM-DD HH:mm - YYYY-MM-DD HH:mm

## 今日最值得关注

### 1. 标题

- 发生了什么：
- 为什么重要：
- 影响谁：
- 建议动作：
- 风险点：
- 推荐关注指数：/10
- 可信度：高/中/低
- 原文链接：

## 版本与工具更新

- ...

## 政策与生态变化

- ...

## 一句话快讯

- ...

## 今日观察

一小段编辑判断。

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
      "recommended_action": "",
      "risk": "",
      "score": 8,
      "confidence": "high",
      "source_url": "",
      "source_name": "",
      "published_at": "YYYY-MM-DD"
    }
  ],
  "tool_updates": [],
  "policy_updates": [],
  "briefs": [],
  "watchlist": []
}
```

## Writing Voice

- Be direct, practical, and developer-focused.
- Explain migration and release consequences, not just facts.
- For upgrades, say one of: upgrade now, test first, monitor, or ignore for now.
- For policies, include effective dates and required developer actions.
- Avoid hype. Prefer concrete engineering impact.
