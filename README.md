# grok-sk

Agent skill for calling **xAI's Grok API** from Claude Code (or any agent supporting `SKILL.md`): chat, image generation & editing, video generation, real-time web search, and X (Twitter) search.

The skill lives in [`skills/grok/SKILL.md`](skills/grok/SKILL.md).

## Requirements

- A Grok API key from [console.x.ai](https://console.x.ai), exported as `GROK_API_KEY`:

```bash
export GROK_API_KEY="xai-..."
```

(`XAI_API_KEY` works as a fallback.)

- `curl` and `jq` available in the shell.

## Install

```bash
npx skills add <your-github-user>/grok-sk
```

Choose the **global** install when prompted so the skill is available in every project.

Manual fallback — copy the skill into your global skills folder:

```bash
mkdir -p ~/.claude/skills/grok
cp skills/grok/SKILL.md ~/.claude/skills/grok/SKILL.md
```

## Usage

Once installed, just ask in any project, e.g.:

> "Build the landing page. If you need images, generate them with Grok and put them in the appropriate folder, with prompts that match this site's style."

The skill guides the agent to find the right assets folder, craft a brand-appropriate prompt, pick the right aspect ratio, generate via the xAI API, and download the files locally.

## Publishing & CI

`npx skills add` installs straight from this repo's default branch — **every push to `main` is immediately live** for new installs; there is no separate publish step. To protect that, CI runs on every push and PR:

- `scripts/validate.py` — frontmatter, bash syntax of every snippet, JSON validity of every payload
- `scripts/test-jq.sh` — every `jq` extraction tested against mock xAI API responses (including error shapes)

An optional `live-smoke` job (manual trigger, needs a `GROK_API_KEY` repo secret) pings the real chat endpoint.

Run the same checks locally before pushing:

```bash
python3 scripts/validate.py && bash scripts/test-jq.sh
```

Users update an installed skill by re-running `npx skills add <your-github-user>/grok-sk`.
