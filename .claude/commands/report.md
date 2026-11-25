---
description: Post a concise, honest status update on the current GitHub issue in olowolayemogoodness-crypto/soro (inferred from branch 'fr/<n>-<slug>' or passed as an argument).
argument-hint: "[optional-issue-number-and-note]"
disable-model-invocation: true
---

# `/report` — Post Status to the Current GitHub Issue (`olowolayemogoodness-crypto/soro`)

Post a short, structured engineering status comment on the active GitHub issue in `https://github.com/olowolayemogoodness-crypto/soro` so firstmate and Miracle can track Module B progress without interrupting your terminal. **Never include API keys or `.env` values in the comment (`olowolayemogoodness-crypto/soro` is public).**

## Steps

1. **Determine the issue number `<number>`:**
   - If `$ARGUMENTS` starts with an issue number (e.g., `12` or `#12`), use that number.
   - Otherwise, inspect the current git branch (`git branch --show-current`) or active worktrees (`git worktree list`) for a branch matching `fr/<number>-<slug>` and extract `<number>`.
   - If no issue number can be inferred, list open issues labelled `for:goodness` (`gh issue list --repo olowolayemogoodness-crypto/soro --state open --label "for:goodness"`) and ask Goodness which issue number to report on.

2. **Gather real state (do not fabricate):**
   - Current branch and worktree: `git branch --show-current` and `git status -s`
   - Files modified so far: `git diff --stat` (and `git log main..HEAD --oneline` if commits exist)
   - Verification checks actually run in this session (with real pass/fail output or measured latency, redacting any secret values)
   - Any open blocker or question for firstmate/Miracle

3. **Post the comment to GitHub:**
   ```bash
   gh issue comment <number> --repo olowolayemogoodness-crypto/soro --body "$(cat <<'EOF'
   **Status update (`fr/<number>-<slug>`):** `<In progress | Ready for review | Blocked>`
   - **Progress:** <1–2 bullets on what is implemented>
   - **Files touched:** `<paths>`
   - **Checks run:** `<exact command and output (no secrets)>`
   - **Next / Blockers:** <none, or exact question/blocker>
   EOF
   )"
   ```

4. If the status is `Blocked`, also apply the `status:blocked` label:
   ```bash
   gh issue edit <number> --repo olowolayemogoodness-crypto/soro --add-label "status:blocked"
   ```

5. Print the posted comment URL in the terminal.
