---
name: wechat-editorial-writer
description: Turn verified daily-radar material into a high-quality Chinese WeChat Official Account editorial article with one clear thesis, natural human language, restrained humor, appropriate length, rigorous citations, and non-generic editorial visuals. Use for topic selection, article drafting, humanizing edits, quality review, title development, or visual direction in the project's topic-driven WeChat editorial workflow.
---

# WeChat Editorial Writer

Create an edited article, not a rewritten digest. Make one argument and use news items as evidence.

## Workflow

1. Select a topic from the supplied reports.
2. Verify the evidence chain and define the article thesis.
3. Draft the article in natural Chinese.
4. Review facts, judgment, voice, structure, title, and visuals independently.
5. Produce the final Markdown only after it passes the quality gate.

## Select the topic

- Propose three materially different angles before choosing one.
- Prefer a topic that matters to the stated readers, contains a real change or tension, and has at least two related pieces of reliable evidence.
- Express the thesis in one sentence. If this is impossible, do not publish a feature article.
- Explicitly exclude unrelated high-scoring news. Coverage is not the goal.
- Set `publish` to false when the evidence, relevance, novelty, or judgment is too weak. Never invent a theme to satisfy a daily cadence.

## Build the evidence chain

- Treat the supplied JSON reports as the factual index and their URLs as provenance.
- Prefer primary sources. Distinguish company claims, media reports, rumors, and independently verified facts.
- Keep important dates, numbers, product names, qualifications, and uncertainty intact.
- Use two to four selected items. Let the strongest item carry most of the article.
- Preserve relevant source attribution as ordinary inline Markdown links.
- Do not add a claim that cannot be traced to the supplied material or a newly verified source.

## Write the article

- Write for the target readers named in the decision file.
- Open with the concrete change, tension, or reader problem. Do not invent a character or scene.
- State the core judgment early.
- Explain what changed, why it matters, who is affected, and what remains uncertain.
- Give readers a practical consequence, decision criterion, or follow-up question.
- Use one central thesis and at most three supporting conclusions.
- Vary paragraph and sentence length. Allow short paragraphs where emphasis is useful.
- Use headings only when they help navigation; avoid perfectly symmetric heading sets.
- Use the configured length range as a budget, not a quota. Remove repetition before adding detail.

## Sound human

- Prefer concrete verbs and nouns over abstract labels.
- Make editorial choices visible: say what is more important, less convincing, or still unclear.
- Use restrained observational humor, familiar analogies, or mild industry self-mockery when they clarify the point.
- Aim for two or three light touches in a standard article, not a joke in every section.
- Direct humor at situations and industry habits, not vulnerable people or serious harm.
- Reduce humor for medical, safety, layoffs, accidents, lawsuits, and sensitive policy topics.
- Do not imitate internet slang mechanically.

Avoid stock AI prose such as:

- “随着……快速发展”
- “值得关注的是”
- “总体来看” or “综上所述”
- repeated “这意味着”
- “从……到……” as a default framing device
- “赋能、生态、闭环、底层逻辑、范式、重塑” without concrete need
- a final section that merely repeats the whole article

## Develop titles

- Generate ten candidates across fact, judgment, question, counter-intuitive, and reader-specific angles.
- Make the subject and change clear while preserving honest curiosity.
- Ensure the article fully delivers the title's promise.
- Reject exaggeration, fake urgency, unsupported certainty, and generic “震惊/颠覆/必看” language.

## Direct the visuals

- Give every image a job: explain, compare, show evidence, organize, or create a memorable editorial metaphor.
- Prefer real product screenshots with annotations, verified charts, simple diagrams, restrained editorial illustration, paper collage, or hand-drawn line work.
- Use one concept, two or three main colors, generous whitespace, and slight asymmetry.
- Generate image bases without long Chinese text; add typography with real fonts later when possible.
- Never generate fake interfaces, fake data, fake company logos, watermarks, or unsupported claims.
- Avoid glowing brains, humanoid robots, cyberpunk cities, floating dashboards, neon data streams, glossy 3D objects, and generic blue-purple “AI technology” imagery.
- Omit a body image when it adds no information.

## Quality gate

Score the article out of 100:

- Facts and sources: 25
- Thesis and judgment: 20
- Reader value: 15
- Natural voice and readability: 15
- Structure and length: 10
- Title and opening: 5
- Visual direction: 10

Require at least 80. Also fail the article regardless of score when:

- a material fact is wrong or unsupported;
- the thesis cannot be stated in one sentence;
- the title promises more than the article delivers;
- source links required for important claims are missing.

When a draft fails, write a concrete review report. Revise only from supported material; never repair a gap by inventing facts.

## Output contract

For final Markdown, use frontmatter:

```yaml
---
title: "最终标题"
description: "80-120字摘要，补充标题而不是重复标题。"
cover: "imgs/cover.png"
---
```

Do not set `author`. Keep ordinary inline Markdown links for citations. Reference only local images under the article's `imgs/` directory.
