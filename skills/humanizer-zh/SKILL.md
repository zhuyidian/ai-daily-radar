---
name: humanizer-zh
description: Humanize Chinese AI-generated copy after facts and sources are already fixed. Use this skill whenever a WeChat article, Chinese newsletter, AI日报稿件, or editorial draft needs “去 AI 味”, more natural human voice, less template-like phrasing, better rhythm, and stronger editor-like judgment while preserving all facts, dates, numbers, names, links, thesis, and source qualifications.
---

# Humanizer-zh for Daily Radar

This project-local skill adapts the idea of `op7418/Humanizer-zh` for the Daily Radar WeChat workflow.

Attribution:
- Upstream: https://github.com/op7418/Humanizer-zh
- License: MIT
- Local adaptation: stricter factual guardrails for sourced editorial articles.

## Role

Turn a fact-checked Chinese draft into a more human, readable, editor-like article.

The job is not to create new content. The job is to make the existing content feel selected, judged, and edited by a real person.

Use this skill after the first draft exists and before independent review.

## Non-negotiable factual guardrails

Preserve these exactly unless the source report explicitly requires a correction:

- Dates and time ranges.
- Numbers, percentages, sample counts, model sizes, quotas, scores, and deadlines.
- Company, product, model, paper, framework, protocol, and person names.
- Markdown source links and their surrounding attribution.
- Thesis and article promise.
- Uncertainty markers such as “报道称”, “论文称”, “研究者称”, “如果属实”, “仍需验证”, “媒体转述”.

Do not:

- Add new facts, new sources, new cases, fake scenes, or invented quotes.
- Turn a reported claim into a verified fact.
- Remove important source links.
- Add emotional certainty to weak evidence.
- Rewrite the article into a motivational essay, marketing copy, or internet slang performance.
- Optimize for AI-detection bypass. Optimize for clarity, rhythm, and editorial credibility.

## Humanization targets

Improve these areas:

1. **Opening**
   - Start from the concrete tension, decision, or reader problem.
   - Avoid generic openings like “随着……快速发展”.

2. **Sentence rhythm**
   - Mix short and medium sentences.
   - Split overloaded sentences.
   - Remove repeated paragraph structures.

3. **Concrete language**
   - Prefer concrete nouns and verbs.
   - Replace vague words only when a more precise expression is already supported by the text.

4. **Visible editorial judgment**
   - Say what is more important, less convincing, still uncertain, or practically useful.
   - Keep judgment grounded in supplied evidence.

5. **Natural transitions**
   - Remove repeated “这意味着”, “值得关注的是”, “总体来看”, “综上所述”.
   - Use transitions that follow the argument, not template markers.

6. **Restraint**
   - Use light observational humor only when it clarifies.
   - Reduce humor for safety, attacks, policy, layoffs, medical, legal, or accident-related topics.

7. **Ending**
   - End with a useful judgment, decision criterion, or follow-up question.
   - Do not merely repeat the article summary.

## Common AI-flavored patterns to reduce

Avoid or rewrite:

- “随着……快速发展”
- “值得关注的是”
- “这意味着” repeated across paragraphs
- “总体来看”
- “综上所述”
- “从 A 到 B” as the default frame
- “赋能、生态、闭环、底层逻辑、范式、重塑” when not concretely needed
- mechanically symmetrical headings
- every paragraph ending with a generic “因此企业需要……”

## Required workflow

1. Read the original draft.
2. Read the editorial decision and source reports when provided.
3. Identify protected facts and links before rewriting.
4. Rewrite the article in-place at the expression level.
5. Keep the frontmatter valid.
6. Preserve local image references, if any.
7. Write a short report describing what changed and any risks.

## Output contract

When the project workflow asks for a humanized article, produce:

- `wechat-article-humanized.md`
- `humanizer-report.json`

The report must use this shape:

```json
{
  "pass": true,
  "facts_preserved": true,
  "links_preserved": true,
  "numbers_preserved": true,
  "thesis_preserved": true,
  "changes": [],
  "risk_notes": [],
  "protected_terms_checked": []
}
```

Set `pass=false` if you cannot preserve facts or links safely.

