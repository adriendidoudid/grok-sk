#!/usr/bin/env bash
# Tests every jq extraction expression used in skills/grok/SKILL.md against
# mock responses matching the documented xAI API shapes, including error cases.
set -euo pipefail
cd "$(mktemp -d)"
fail() { echo "FAIL: $1"; exit 1; }

# chat: .choices[0].message.content
echo '{"choices":[{"message":{"role":"assistant","content":"Bonjour!"}}]}' > chat.json
[ "$(jq -r '.choices[0].message.content' chat.json)" = "Bonjour!" ] || fail chat

# image generation: .data[]?.url — success, multi, error->empty
echo '{"data":[{"url":"https://img.x.ai/a.jpg"}]}' > img1.json
[ "$(jq -r '.data[]?.url' img1.json)" = "https://img.x.ai/a.jpg" ] || fail img1
echo '{"data":[{"url":"https://i/1.jpg"},{"url":"https://i/2.jpg"},{"url":"https://i/3.jpg"}]}' > img3.json
[ "$(jq -r '.data[]?.url' img3.json | wc -l)" = "3" ] || fail img3
echo '{"error":{"code":"invalid_model","message":"..."}}' > imgerr.json
[ -z "$(jq -r '.data[]?.url' imgerr.json)" ] || fail imgerr

# multi-download loop: URL iteration + counter
out=$(i=1; jq -r '.data[]?.url' img3.json | while read -r u; do echo "hero-v$i <- $u"; i=$((i+1)); done)
echo "$out" | grep -q "hero-v3 <- https://i/3.jpg" || fail loop

# image edits: both plausible response shapes + jq -n payload builder
echo '{"data":[{"url":"https://img.x.ai/e.jpg"}]}' > edit_a.json
echo '{"url":"https://img.x.ai/e.jpg"}' > edit_b.json
[ "$(jq -r '.data[]?.url // .url // empty' edit_a.json)" = "https://img.x.ai/e.jpg" ] || fail edit_a
[ "$(jq -r '.data[]?.url // .url // empty' edit_b.json)" = "https://img.x.ai/e.jpg" ] || fail edit_b
jq -n --arg prompt "keep the subject's pose, don't change it" --arg url "data:image/jpeg;base64,AAA=" \
  '{model:"grok-imagine-image-quality", prompt:$prompt, image:{type:"image_url", url:$url}}' \
  | jq -e '.image.type=="image_url"' >/dev/null || fail builder

# video: submit id (success + error->empty), status, url
echo '{"request_id":"req_abc123"}' > vid.json
[ "$(jq -r '.request_id // empty' vid.json)" = "req_abc123" ] || fail vid
echo '{"error":{"message":"bad request"}}' > viderr.json
[ -z "$(jq -r '.request_id // empty' viderr.json)" ] || fail viderr
echo '{"status":"done","video":{"url":"https://vidgen.x.ai/v.mp4","duration":6}}' > vidst.json
[ "$(jq -r '.status' vidst.json)" = "done" ] || fail vidst
[ "$(jq -r '.video.url' vidst.json)" = "https://vidgen.x.ai/v.mp4" ] || fail vidurl

# poll loop logic: pending -> done exits the loop
n=0
mockfetch() { n=$((n+1)); if [ "$n" -lt 3 ]; then echo '{"status":"pending"}'; else cat vidst.json; fi; }
STATUS=""
for _ in $(seq 1 9); do
  mockfetch > st.json
  STATUS=$(jq -r '.status' st.json)
  [ "$STATUS" = "pending" ] || break
done
[ "$STATUS" = "done" ] || fail pollloop

# responses API: message text + citations, tolerant of non-message items and null citations
cat > resp.json <<'EOF'
{"output":[{"type":"web_search_call","id":"ws_1"},{"type":"message","content":[{"type":"output_text","text":"Answer.","annotations":[{"type":"url_citation","url":"https://x.ai","start_index":0,"end_index":6,"title":"1"}]}]}],"citations":["https://x.ai","https://docs.x.ai"]}
EOF
jq -r '.output[] | select(.type=="message") | .content[] | select(.type=="output_text") | .text' resp.json \
  | grep -q "Answer." || fail resptext
[ "$(jq -r '.citations[]?' resp.json | wc -l)" = "2" ] || fail cites
echo '{"output":[],"citations":null}' > resp2.json
jq -r '.citations[]?' resp2.json >/dev/null || fail citesnull

echo "ALL JQ / LOGIC TESTS PASSED"
