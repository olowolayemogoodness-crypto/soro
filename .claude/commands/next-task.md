---
description: Pick up the oldest open unblocked 'for:goodness' GitHub issue from olowolayemogoodness-crypto/soro, work it in an isolated 'fr/<n>-<slug>' worktree, verify acceptance checks, and open a PR.
argument-hint: "[optional-issue-number]"
disable-model-invocation: true
---

# `/next-task` — Sọ̀rọ̀ Module B Task Runner (`olowolayemogoodness-crypto/soro`)

Follow these steps in order. Do not skip verification checks, never edit `app/` or `contracts/` unless the issue explicitly lists them under **Owned paths**, and **never paste API keys or `.env` values into issue comments or PR bodies** (`https://github.com/olowolayemogoodness-crypto/soro` is a **PUBLIC** repository).

## Step 1: Select the Target Issue from the GitHub Queue

1. If an explicit issue number was passed in `$ARGUMENTS`, inspect that issue directly:
   ```bash
   gh issue view "$ARGUMENTS" --repo olowolayemogoodness-crypto/soro --json number,title,state,labels,body,url,createdAt
   ```
2. Otherwise, query open issues labelled `for:goodness` on `olowolayemogoodness-crypto/soro`, sorted oldest first, excluding `status:blocked` and `status:review`:
   ```bash
   gh issue list --repo olowolayemogoodness-crypto/soro --state open --label "for:goodness" --limit 30 \
     --json number,title,labels,createdAt,url,body \
     | jq '
       map(select(
         ([.labels[].name] | index("status:blocked") | not) and
         ([.labels[].name] | index("status:review") | not)
       ))
       | sort_by(.createdAt)
       | .[0]
     '
   ```
3. If the result is `null`, tell Goodness: *"No open unblocked `for:goodness` issues in `https://github.com/olowolayemogoodness-crypto/soro/issues` right now."* and stop.
4. Display a concise summary of the chosen issue before touching any code:
   - **Issue:** `#<number> — <title>` (`<url>`)
   - **Owned paths:** (from the issue body)
   - **Contracts touched:** (from the issue body)
   - **Acceptance checks:** (from the issue body)

## Step 2: Claim the Issue & Prepare the Worktree (`fr/<issue-number>-<slug>`)

1. Derive a short kebab-case `<slug>` (2–4 words, lowercase alphanumeric and hyphens) from the issue title, forming branch name `fr/<number>-<slug>`.
2. Post a short pickup comment on the issue:
   ```bash
   gh issue comment <number> --repo olowolayemogoodness-crypto/soro --body "Picked up — working in worktree on branch \`fr/<number>-<slug>\`."
   ```
3. Fetch the latest `main` branch from `origin` (`https://github.com/olowolayemogoodness-crypto/soro.git`):
   ```bash
   git fetch origin main || true
   ```
4. Create (or reuse) an isolated git worktree at `../soro-wt/fr-<number>-<slug>` on branch `fr/<number>-<slug>` based on `origin/main` (or `main` if offline):
   ```bash
   mkdir -p ../soro-wt
   git worktree add -b "fr/<number>-<slug>" "../soro-wt/fr-<number>-<slug>" origin/main \
     || git worktree add -b "fr/<number>-<slug>" "../soro-wt/fr-<number>-<slug>" main \
     || git worktree add "../soro-wt/fr-<number>-<slug>" "fr/<number>-<slug>"
   ```
5. If local `.env` files exist in the main checkout (`.env`, `agent/.env`, `infra/.env`), copy or symlink them into the worktree (never stage or commit them).

## Step 3: Implement & Verify Inside the Worktree

1. Read `CLAUDE.md` and the relevant section of `docs/engineering-notes.md` if you have not already loaded them in this session.
2. Perform all edits strictly inside `../soro-wt/fr-<number>-<slug>` within the **Owned paths** named by the issue (`agent/`, `content/`, `infra/`, `docs/`).
   - Enforce Sọ̀rọ̀'s pedagogy rules: **one question per turn**, **never give the final answer**, **correct the specific misconception**, and **write only student-stated math or a next-step template with `?` blanks on the notebook canvas**.
   - Normalize all Yorùbá strings to **Unicode NFC** (`unicodedata.normalize("NFC", text)`).
   - Never introduce `CC-BY-NC` or `N-ATLaS` model weights.
   - Never hardcode or log API keys, tokens, or secrets.
3. Run every command listed under **Acceptance checks** in the issue body (plus standard checks such as `uv run ...`, `curl -sS http://localhost:8000/health | jq .`, or `lk agent console` as applicable).

## Step 4A: When Checks Pass — Open PR & Report Result

1. Check `git -C ../soro-wt/fr-<number>-<slug> status` to ensure no `.env` or secret files are staged.
2. Commit and push the branch to `https://github.com/olowolayemogoodness-crypto/soro`:
   ```bash
   git -C "../soro-wt/fr-<number>-<slug>" add <owned-paths>
   git -C "../soro-wt/fr-<number>-<slug>" commit -m "feat(module-b): <concise summary> (#<number>)"
   git -C "../soro-wt/fr-<number>-<slug>" push -u origin "fr/<number>-<slug>"
   ```
3. Open a pull request against `main` whose body includes `Closes #<number>` and the exact verification output (with any tokens/keys redacted):
   ```bash
   gh pr create --repo olowolayemogoodness-crypto/soro --base main --head "fr/<number>-<slug>" \
     --title "<title> (#<number>)" \
     --body "$(cat <<'EOF'
   Closes #<number>

   ## Summary
   - <bullet summary of changes within owned paths>

   ## Contracts Touched
   - <list of contracts/*.json verified>

   ## What Was Tested
   - `<exact command 1>` -> `<actual result / latency / output>`
   - `<exact command 2>` -> `<actual result / latency / output>`
   EOF
   )"
   ```
4. Label the issue `status:review` and post a short result comment containing the full `https://github.com/olowolayemogoodness-crypto/soro/pull/<pr>` URL:
   ```bash
   gh issue edit <number> --repo olowolayemogoodness-crypto/soro --add-label "status:review" || true
   gh issue comment <number> --repo olowolayemogoodness-crypto/soro --body "Done in <full-https-pr-url>. Tested: <1-line summary of checks run>."
   ```
5. Remind Goodness to run `/clear` before starting the next task so Claude Pro context usage stays low.

## Step 4B: If Blocked — Comment Exact Blocker & Label `status:blocked`

If you hit a missing dependency, failing external API key, contract mismatch requiring `contracts/` or `app/` changes, or the same error twice:
1. Do **not** loop and burn Claude Pro quota.
2. Label the issue `status:blocked` and post the exact blocker on the issue (redacting any secret values):
   ```bash
   gh issue edit <number> --repo olowolayemogoodness-crypto/soro --add-label "status:blocked"
   gh issue comment <number> --repo olowolayemogoodness-crypto/soro --body "$(cat <<'EOF'
   Blocked on `#<number>` (`fr/<number>-<slug>`):
   - **Obstacle:** <what failed>
   - **Command & output:** `<exact command>` -> `<exact error (no secrets)>`
   - **What is needed to unblock:** <decision, contract change, or key needed from firstmate/Miracle>
   EOF
   )"
   ```
3. Stop and report the blocker to Goodness in the terminal.
