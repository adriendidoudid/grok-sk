![grok-sk banner](banner.png)

# grok-sk

[![validate](https://github.com/adriendidoudid/grok-sk/actions/workflows/validate.yml/badge.svg)](https://github.com/adriendidoudid/grok-sk/actions/workflows/validate.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Agent skill for **xAI's Grok API**, written against the open [Agent Skills](https://agentskills.io) standard (`SKILL.md`) — it works with **any coding agent that reads skills**: Claude Code, Cursor, Codex, Gemini CLI, opencode, Amp, and others. The instructions are agent-agnostic (plain `curl` + `jq`, no harness-specific tools assumed). Once installed, your agent can autonomously:

| Capability | Endpoint | Model |
|---|---|---|
| 💬 Chat / reasoning | `/v1/chat/completions` | `grok-4.3` |
| 🖼️ Image generation | `/v1/images/generations` | `grok-imagine-image-quality` |
| ✏️ Image editing | `/v1/images/edits` | `grok-imagine-image-quality` |
| 🎬 Video generation | `/v1/videos/generations` | `grok-imagine-video` |
| 🌐 Real-time web search | `/v1/responses` + `web_search` | `grok-4.3` |
| 𝕏 X (Twitter) search | `/v1/responses` + `x_search` | `grok-4.3` |

Pure `curl` — no SDK, no dependencies to install in your projects. The skill lives in [`skills/grok/SKILL.md`](skills/grok/SKILL.md).

## Requirements

- A Grok API key from [console.x.ai](https://console.x.ai)
- `curl` and `jq` available in the shell

Export the key (add it to `~/.bashrc` / `~/.zshrc` to make it permanent):

```bash
export GROK_API_KEY="xai-..."
```

(`XAI_API_KEY` works as a fallback.)

## Install

```bash
npx skills add adriendidoudid/grok-sk
```

The installer asks **which agent(s)** to install into (Claude Code, Cursor, Codex, Gemini CLI, opencode, Amp…) and handles each one's skills directory for you. Choose the **global** install so the skill is available in every project. To update later, re-run the same command.

Manual fallback — copy the skill into your agent's skills folder (Claude Code shown; other agents each have their own equivalent directory):

```bash
git clone https://github.com/adriendidoudid/grok-sk
mkdir -p ~/.claude/skills/grok
cp grok-sk/skills/grok/SKILL.md ~/.claude/skills/grok/SKILL.md
```

## Usage

Once installed, just ask naturally in any project — the agent picks up the skill on its own. Real-world prompts:

**Website assets** (the flagship use case):

> Build the landing page. If you need images, generate them with Grok and put them in the appropriate folder, with prompts that match this site's branding and style.

The skill makes the agent find the existing assets folder (`public/images/`, `src/assets/`…), craft a prompt from the site's actual colors and tone, pick the aspect ratio matching the placement (hero 16:9, avatar 1:1…), download the files with clean names, and visually verify them before wiring them in.

**Single image:**

> Generate a 16:9 hero image with Grok for this page — dark, minimal, matching our navy palette — and reference it in `index.html`.

**Edit an existing image:**

> Take `public/images/hero.jpg` and use Grok to replace the background with a soft studio gradient, keeping the subject unchanged.

**Video:**

> Generate a 6-second product teaser video with Grok (16:9, 720p) and save it in `public/videos/`.

**Real-time web search:**

> Use Grok web search to find what changed in Next.js 16 and check whether our config is affected. Cite sources.

**X search:**

> Search X via Grok for reactions to the latest xAI release this week, only from AI researcher accounts.

**Chat:**

> Ask Grok for 10 tagline ideas for this product, in French and English.

Prompts work in any language — the skill's triggers are semantic.

## Publishing & CI

`npx skills add` installs straight from this repo's default branch — **every push to `main` is immediately live** for new installs; there is no separate publish step. To protect that, CI runs on every push and PR:

- `scripts/validate.py` — frontmatter, bash syntax of every snippet, JSON validity of every payload
- `scripts/test-jq.sh` — every `jq` extraction tested against mock xAI API responses (including error shapes)

An optional `live-smoke` job (manual trigger, needs a `GROK_API_KEY` repo secret) pings the real chat endpoint.

Run the same checks locally before pushing:

```bash
python3 scripts/validate.py && bash scripts/test-jq.sh
```

## Repository layout

```
skills/grok/SKILL.md        the skill (the only thing npx skills add installs)
scripts/validate.py         static validation (frontmatter, bash, JSON)
scripts/test-jq.sh          jq expressions vs mock API responses
.github/workflows/          CI: validate on push/PR + optional live smoke test
```

## Cost notes

Images ~$0.02–0.05 each, video ~$0.05/s, search billed as tokens + per tool invocation — see [xAI pricing](https://docs.x.ai/developers/models). The skill defaults to quality models and tells the agent to use the cheaper `grok-imagine-image` for drafts.

## License

[MIT](LICENSE)
