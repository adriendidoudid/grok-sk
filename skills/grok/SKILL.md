---
name: grok
description: Call xAI's Grok API (authenticated with GROK_API_KEY) for chat/reasoning, image generation and editing, video generation, real-time web search, and X (Twitter) search. Use when the user asks to generate images or videos with Grok (e.g. website/app assets, illustrations, hero images), to edit an image, to ask Grok a question, or to search the web or X in real time through Grok. Also use when a task needs AI-generated visual assets and Grok is the available image provider.
---

# Grok (xAI API)

Call the xAI API directly with `curl` — no SDK, no dependencies. Base URL: `https://api.x.ai/v1`.

## Conventions (read first)

1. **Assume shell state does not persist between commands** (true in most agent harnesses): variables like `$KEY` or a captured request id are gone in the next invocation. Every command block below is self-contained: it re-resolves the key on its first line — keep that line when running them.

   Check availability up front (never print the key itself):

   ```bash
   KEY="${GROK_API_KEY:-$XAI_API_KEY}"; [ -n "$KEY" ] && echo "key: OK" || echo "key: MISSING"
   ```

   If MISSING, stop and ask the user to `export GROK_API_KEY` (key from https://console.x.ai). Never guess, hardcode, echo, or commit a key.

2. **Payloads go through a single-quoted heredoc to stdin** (`-d @-`), so apostrophes and newlines in prompts are always safe. **Raw responses are saved to `/tmp/grok-*.json`** so errors and citations can be inspected afterward.

3. **If a `jq` extraction prints nothing, the call failed.** Run `jq . /tmp/grok-<step>.json` and read the `error` field before retrying — do not retry blindly.

4. Media rules:
   - Always `"response_format": "url"`, never `b64_json` — never paste base64 into the conversation.
   - Returned media URLs are **temporary**: download with `curl -sL -o` immediately.
   - After downloading, verify with `file <path>` (must report image/video data, not HTML or empty) and, if your environment can display images, view them before using them.

5. The legacy Live Search `search_parameters` field is retired (returns HTTP 410). Real-time search goes through the `web_search` / `x_search` tools on `/v1/responses` (see below).

6. `jq` is assumed. If unavailable, parse with `python3 -c 'import json,sys; d=json.load(sys.stdin); ...'`.

## Models (as of mid-2026)

| Task | Default | Alternative |
|---|---|---|
| Chat / reasoning / search | `grok-4.3` | — |
| Image generation & editing | `grok-imagine-image-quality` ($0.05/img) | `grok-imagine-image` ($0.02/img, drafts) |
| Video generation | `grok-imagine-video` ($0.05/s) | `grok-imagine-video-1.5` ($0.08/s, 1080p image-to-video) |
| Code | `grok-build-0.1` | — |

If a model ID returns 404, the lineup has changed — fetch https://docs.x.ai/developers/models and use the current recommended model for the task.

## Chat

OpenAI-compatible endpoint:

```bash
KEY="${GROK_API_KEY:-$XAI_API_KEY}"
curl -s https://api.x.ai/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d @- > /tmp/grok-chat.json <<'EOF'
{
  "model": "grok-4.3",
  "messages": [
    {"role": "system", "content": "optional system prompt"},
    {"role": "user", "content": "the question — apostrophes are safe in this quoted heredoc"}
  ]
}
EOF
jq -r '.choices[0].message.content' /tmp/grok-chat.json
```

## Generate images

**Workflow for project assets (e.g. a website):**

1. **Find the right output folder.** Look for the project's existing image location: `public/images/`, `public/`, `src/assets/`, `assets/`, `static/img/`… Match the existing convention; only create a folder if none exists.
2. **Craft the prompt from the project, not from thin air.** Read the site's copy, existing design, CSS colors, and tone first. A good prompt states: subject, artistic style, color palette (match the brand — name the actual hex/color families you found), composition, lighting/mood, and ends with "no text, no watermark, no logo" unless text is wanted.
3. **Pick the aspect ratio by placement:** hero/banner `16:9` or `2:1`, card/thumbnail `3:2` or `4:3`, portrait/story `9:16`, avatar/icon `1:1`. Supported: `1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3, 2:1, 1:2, auto` (plus tall phone ratios like `19.5:9`, `9:20`).
4. **Call the API** (`resolution`: `1k` or `2k`; `n`: number of variants, default 1):

```bash
KEY="${GROK_API_KEY:-$XAI_API_KEY}"
curl -s https://api.x.ai/v1/images/generations \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d @- > /tmp/grok-img.json <<'EOF'
{
  "model": "grok-imagine-image-quality",
  "prompt": "Minimalist hero illustration of ..., flat vector style, palette of deep navy #1a2b4c and warm coral accents, soft ambient light, generous negative space on the left for headline text, no text, no watermark",
  "n": 1,
  "aspect_ratio": "16:9",
  "resolution": "2k",
  "response_format": "url"
}
EOF
jq -r '.data[]?.url' /tmp/grok-img.json
```

5. **Download immediately** with a descriptive kebab-case filename (`.jpg` unless `file` says otherwise):

```bash
curl -sL "<url printed above>" -o public/images/hero-team-collaboration.jpg
file public/images/hero-team-collaboration.jpg
```

For several variants (`n` > 1), loop:

```bash
i=1; jq -r '.data[]?.url' /tmp/grok-img.json | while read -r u; do
  curl -sL "$u" -o "public/images/hero-v$i.jpg"; i=$((i+1)); done
```

6. **Verify** each file — view the image if your environment supports it, otherwise at least check the `file` output and byte size — to confirm it matches the brief before wiring it into the project. If it misses, refine the prompt and regenerate — don't ship a bad image.

For drafts or many variants, use `grok-imagine-image` and `1k`, then regenerate keepers with the quality model.

## Edit an image

`POST /v1/images/edits` — synchronous, natural-language edits; also composes up to 3 reference images. Source: public URL, `data:` base64 URI, or Files API id (JPG/PNG, ≤20 MiB). Built with `jq -n` here because embedding a base64 data URI needs safe interpolation:

```bash
KEY="${GROK_API_KEY:-$XAI_API_KEY}"
jq -n --arg prompt "Replace the background with a soft studio gradient, keep the subject unchanged" \
      --arg url "https://example.com/source.jpg" \
  '{model:"grok-imagine-image-quality", prompt:$prompt, image:{type:"image_url", url:$url}}' \
| curl -s https://api.x.ai/v1/images/edits \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d @- \
  > /tmp/grok-edit.json
jq -r '.data[]?.url // .url // empty' /tmp/grok-edit.json
```

For a local file, use `--arg url "data:image/jpeg;base64,$(base64 -w0 path/to/local.jpg)"`. Then download and verify as in step 5–6 above.

## Generate videos

Async: submit → poll → download. Params: `duration` 1–15 s, `resolution` `480p|720p|1080p`, `aspect_ratio` as for images, optional `"image": "<url>"` for image-to-video.

**Step 1 — submit** (prints the request id; if it prints nothing, inspect `/tmp/grok-vid.json`):

```bash
KEY="${GROK_API_KEY:-$XAI_API_KEY}"
curl -s https://api.x.ai/v1/videos/generations \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d @- > /tmp/grok-vid.json <<'EOF'
{
  "model": "grok-imagine-video",
  "prompt": "Slow dolly-in on ..., cinematic, golden hour",
  "duration": 6,
  "aspect_ratio": "16:9",
  "resolution": "720p"
}
EOF
jq -r '.request_id // empty' /tmp/grok-vid.json
```

**Step 2 — poll.** Paste the id printed above (it does not persist between commands). This block runs ≤ ~90 s, so it fits typical per-command timeouts — **re-run it until status is `done`** (generation typically takes 1–5 min):

```bash
KEY="${GROK_API_KEY:-$XAI_API_KEY}"
REQUEST_ID="<paste request_id here>"
for _ in $(seq 1 9); do
  curl -s https://api.x.ai/v1/videos/$REQUEST_ID -H "Authorization: Bearer $KEY" > /tmp/grok-vid-status.json
  STATUS=$(jq -r '.status' /tmp/grok-vid-status.json)
  [ "$STATUS" = "pending" ] || break
  sleep 10
done
echo "status: $STATUS"
[ "$STATUS" = "done" ] && curl -sL "$(jq -r '.video.url' /tmp/grok-vid-status.json)" -o public/videos/clip-name.mp4
```

Statuses: `pending` → re-run; `done` → downloaded; `failed`/`expired` → `jq . /tmp/grok-vid-status.json` for the error. Still pending after ~10 min total: stop and report the `request_id` to the user instead of looping forever.

Related, same async pattern: `POST /v1/videos/edits` (edit an existing video, ≤8.7 s) and `POST /v1/videos/extensions` (continue from the last frame).

## Web search (via Grok)

Server-side tool on the **Responses API** — Grok searches, browses pages, and answers with citations in one call. Billed as tokens + per tool invocation.

```bash
KEY="${GROK_API_KEY:-$XAI_API_KEY}"
curl -s https://api.x.ai/v1/responses \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d @- > /tmp/grok-search.json <<'EOF'
{
  "model": "grok-4.3",
  "input": [{"role": "user", "content": "the question needing fresh web data"}],
  "tools": [{"type": "web_search"}]
}
EOF
jq -r '.output[] | select(.type=="message") | .content[] | select(.type=="output_text") | .text' /tmp/grok-search.json
echo "--- sources ---"
jq -r '.citations[]?' /tmp/grok-search.json
```

Web search filters are **nested under `filters`**: `{"type": "web_search", "filters": {"allowed_domains": ["example.com"]}}` (or `excluded_domains`; max 5; mutually exclusive). Optional: `"enable_image_understanding": true`. Always pass citations on to the user.

## X (Twitter) search

Same call with `x_search` — searches posts, users, and threads on X. **Unlike web_search, its filters sit directly in the tool object** (not under `filters`):

```json
"tools": [{
  "type": "x_search",
  "allowed_x_handles": ["elonmusk"],
  "from_date": "2026-06-01",
  "to_date": "2026-07-05"
}]
```

Filters (all optional — bare `{"type": "x_search"}` searches all of X): `allowed_x_handles` / `excluded_x_handles` (max 20, mutually exclusive), `from_date` / `to_date` (`YYYY-MM-DD`), `enable_image_understanding`, `enable_video_understanding`. Extract text and citations exactly as in web search.

`web_search` and `x_search` can be combined in one `tools` array; the model decides which to call. xAI also offers code-interpreter and collections-search server tools — see https://docs.x.ai/developers/tools/overview.

## Troubleshooting

- **Empty `jq` output**: the call failed — `jq . /tmp/grok-<step>.json` and read `error` before retrying.
- **401**: key missing/invalid — re-check `GROK_API_KEY`; don't retry blindly.
- **404 on a model**: model renamed — fetch https://docs.x.ai/developers/models for current IDs.
- **410 mentioning `search_parameters`**: legacy API — use `/v1/responses` + tools as above.
- **429**: rate limit — wait ~30 s and retry once; if persistent, tell the user (quota/billing at console.x.ai).
- **Moderation rejection** (image/video): rephrase the prompt — avoid real people, brands, violent/explicit content — and tell the user what was adjusted.
- **Downloaded file is HTML or 0 bytes**: the temporary URL expired — regenerate and download immediately.
