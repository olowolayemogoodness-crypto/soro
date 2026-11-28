# Sọ̀rọ̀ (Soro) — Setup & Build-Day Guide for Goodness

Welcome, **Goodness**! This kit sets up **Claude Code CLI** on your laptop for **Module B** of **Sọ̀rọ̀ (Soro)** on our public repository **[`https://github.com/olowolayemogoodness-crypto/soro`](https://github.com/olowolayemogoodness-crypto/soro)**:
- **M3 (`agent/`):** LiveKit Agents Python voice tutor (Silero VAD → Groq Whisper STT → Tutor Brain → `yotext` NFC tone marks → Spitch TTS + pre-recorded glossary audio → step-graph walker + `canvas_cmd` emission).
- **M4 (`content/`):** Quadratics lesson pack (`lesson-pack.json`, tone-marked NFC Yorùbá glossary, pre-recorded `audio/*.mp3`, step graphs, transfer-check variant).
- **M5 (`infra/`):** Nobus Cloud (Lagos) Docker Compose (LiveKit SFU + Postgres), FastAPI server (`/health`, `/packs/{id}`, `/session/token`), and the one-variable LiveKit Cloud failover switch (`LIVEKIT_MODE=nobus|cloud`).

Miracle owns **Module A** (`app/` Flutter shell + canvas bridge on `cap/...` branches, and `contracts/`). You own **Module B** (`agent/`, `content/`, `infra/` on `fr/...` branches). Both laptops push branches to `https://github.com/olowolayemogoodness-crypto/soro` and merge via pull requests into `main` at each checkpoint (`0:00` contracts, `1:00` CP1, `2:30` CP2, `3:15` CP3 freeze).

> **Public Repo Security Notice:** `https://github.com/olowolayemogoodness-crypto/soro` is a **PUBLIC** repository. Never commit `.env` files, and never paste API keys or secrets into code, commit messages, GitHub issues, or pull request comments.

---

## Step 1: Install & Verify Your Required Tools

Run the verification commands below in your terminal. Install anything missing before the build window on **Wednesday 25 Nov 2026**.

| Tool | What It's For | Verify Command | Install Command (macOS / Linux / Windows) |
|---|---|---|---|
| **Git (`>= 2.30`)** | Worktrees (`git worktree`), branches (`fr/...`), emergency bundles | `git --version` | **macOS:** `xcode-select --install`<br>**Ubuntu:** `sudo apt install git`<br>**Windows:** `winget install Git.Git` |
| **Python `3.11` or `3.12`** | `livekit-agents`, `yotext`, FastAPI *(do **not** use 3.9/3.10 or 3.14)* | `python3 --version` | **macOS:** `brew install python@3.12`<br>**Linux:** `uv python install 3.12`<br>**Windows:** `winget install Python.Python.3.12` |
| **`uv`** | Fast Python virtual environments & dependency locking | `uv --version` | **macOS/Linux:** `curl -LsSf https://astral.sh/uv/install.sh \| sh`<br>**Windows:** `powershell -c "irm https://astral.sh/uv/install.ps1 \| iex"` |
| **Docker & Compose** | Local LiveKit SFU + Postgres smoke test before Nobus | `docker --version && docker compose version` | Docker Desktop or OrbStack (macOS) / `sudo apt install docker.io docker-compose-v2` (Ubuntu) |
| **LiveKit CLI (`lk`)** | Room testing & `lk agent console` voice/text loop | `lk --version` | **macOS:** `brew install livekit-cli`<br>**Linux:** `curl -sSL https://get.livekit.io/cli \| bash`<br>**Windows:** `winget install LiveKit.LiveKitCLI` |
| **GitHub CLI (`gh`)** | Reading task queue (`/next-task`), opening/merging PRs, commenting | `gh --version` | **macOS:** `brew install gh`<br>**Ubuntu:** `sudo apt install gh`<br>**Windows:** `winget install GitHub.cli` |
| **`ffmpeg` + `jq` + `curl`** | Trimming glossary `.mp3` clips & testing JSON endpoints | `ffmpeg -version && jq --version && curl --version` | **macOS:** `brew install ffmpeg jq`<br>**Ubuntu:** `sudo apt install ffmpeg jq`<br>**Windows:** `winget install Gyan.FFmpeg jqlang.jq` |
| **Claude Code CLI** | AI coding assistant on your Claude Pro plan | `claude --version` | `npm install -g @anthropic-ai/claude-code` (or official native installer) |
| **OpenSSH (`ssh`)** | Deploying M5 to the Nobus Lagos Ubuntu VM | `ssh -V` | Built in on macOS/Linux/Windows 11 (`ssh-keygen -t ed25519 -f ~/.ssh/nobus_soro`) |

---

## Step 2: Log In to Claude Code with Your Claude Pro Subscription

> **CRITICAL CHECK:** If `ANTHROPIC_API_KEY` is set in your shell environment, Claude Code will ignore your Claude Pro subscription and bill pay-as-you-go Console API credits (or fail with "Credit balance is too low").

1. **Verify `ANTHROPIC_API_KEY` is completely empty in your shell:**
   ```bash
   echo "ANTHROPIC_API_KEY=[$ANTHROPIC_API_KEY]"
   ```
   - It **must** print `ANTHROPIC_API_KEY=[]`.
   - If anything is printed inside the brackets, run `unset ANTHROPIC_API_KEY` and remove any `export ANTHROPIC_API_KEY=...` line from your `~/.zshrc`, `~/.bashrc`, or Windows Environment Variables.
   - *(Note: If we test Claude via API as the Soro tutor brain under decision D5, name that variable `SORO_ANTHROPIC_API_KEY` inside `agent/.env` — never `ANTHROPIC_API_KEY` in your shell!)*

2. **Log in to Claude Code and pin the model to Sonnet:**
   ```bash
   claude
   ```
   Inside the Claude Code prompt, run:
   ```text
   /login
   ```
   Select your **Claude Pro** subscription account in the browser, then verify inside Claude Code:
   ```text
   /status
   /model sonnet
   ```
   Confirm `/status` shows your **Claude Pro** login and **Sonnet** as the active model.

---

## Step 3: Authenticate GitHub CLI (`gh`) & Accept Collaborator Invite

1. Accept the collaborator invitation for **[`https://github.com/olowolayemogoodness-crypto/soro`](https://github.com/olowolayemogoodness-crypto/soro)** on GitHub.
2. Authenticate `gh` in your terminal so `/next-task` and `/report` can read issues, push `fr/...` branches, and open pull requests:
   ```bash
   gh auth login
   ```
   - Choose **GitHub.com** → **HTTPS** (or **SSH** if your SSH key is on GitHub) → **Login with a web browser**.
3. Verify your login and confirm you can see the repository labels (`for:goodness`, `for:miracle`, `status:blocked`, `status:review` are **already created** on `olowolayemogoodness-crypto/soro`):
   ```bash
   gh auth status
   gh label list --repo olowolayemogoodness-crypto/soro
   ```

---

## Step 4: Clone `olowolayemogoodness-crypto/soro` & Copy This Kit In

On build day (`25 Nov 2026`, once `T+0:00` starts):

1. **Clone the repository into `~/work/soro`:**
   ```bash
   mkdir -p ~/work
   git clone https://github.com/olowolayemogoodness-crypto/soro.git ~/work/soro
   ```

2. **Copy all kit files (including hidden `.gitignore`, `.env.example`, `.claude/`, and `.github/`) into `~/work/soro`:**
   ```bash
   cp -R /path/to/soro-friend-kit/.gitignore ~/work/soro/
   cp -R /path/to/soro-friend-kit/.env.example ~/work/soro/
   cp -R /path/to/soro-friend-kit/CLAUDE.md ~/work/soro/
   cp -R /path/to/soro-friend-kit/SETUP-FOR-GOODNESS.md ~/work/soro/
   cp -R /path/to/soro-friend-kit/docs ~/work/soro/
   cp -R /path/to/soro-friend-kit/.claude ~/work/soro/
   cp -R /path/to/soro-friend-kit/.github ~/work/soro/
   ```

3. **Verify the files are in place:**
   ```bash
   ls -la ~/work/soro/.gitignore ~/work/soro/.env.example \
          ~/work/soro/CLAUDE.md ~/work/soro/docs/engineering-notes.md \
          ~/work/soro/.claude/settings.json \
          ~/work/soro/.claude/commands/next-task.md \
          ~/work/soro/.claude/commands/report.md \
          ~/work/soro/.github/ISSUE_TEMPLATE/task-for-claude.md \
          ~/work/soro/.github/workflows/claude.yml
   ```

4. **Create your local uncommitted `.env` from `.env.example`:**
   ```bash
   cp ~/work/soro/.env.example ~/work/soro/.env
   ```
   Open `~/work/soro/.env` (and copy to `agent/.env` / `infra/.env` once those folders exist) and paste in your real `GROQ_API_KEY`, `GEMINI_API_KEY`, `SPITCH_API_KEY`, and `NOBUS_LIVEKIT_*` / `CLOUD_LIVEKIT_*` keys. Confirm `git -C ~/work/soro status` does **not** show `.env` as untracked (it is ignored by `.gitignore`).

---

## Step 5: How to Work Tasks with `/next-task`, `/report`, and Checkpoint Merges

On build day, firstmate (from Miracle's machine) files structured GitHub issues on `https://github.com/olowolayemogoodness-crypto/soro/issues` labelled `for:goodness`.

### 5.1 Picking Up and Finishing Tasks (`/next-task`)

1. **Start Claude Code at the root of `~/work/soro`:**
   ```bash
   ( cd ~/work/soro && claude )
   ```
   *(Choose **Yes, trust this folder** on first launch so `.claude/settings.json` permissions take effect.)*

2. **Run `/next-task`:**
   ```text
   /next-task
   ```
   *(Or pass a specific issue number: `/next-task 2`.)*
   - Claude Code queries `olowolayemogoodness-crypto/soro` for the oldest open `for:goodness` issue that is not `status:blocked` or `status:review`.
   - Comments `"Picked up"` on the issue and creates a worktree at `../soro-wt/fr-<issue-number>-<slug>` on branch `fr/<issue-number>-<slug>`.
   - Builds the feature inside `agent/`, `content/`, or `infra/`, runs the acceptance checks (`curl /health`, `lk agent console`, NFC validation), pushes `fr/<issue-number>-<slug>`, opens a PR with `Closes #<n>` and test results, labels the issue `status:review`, and posts the PR link.
   - If blocked, it labels the issue `status:blocked`, comments the exact error, and stops immediately to save your Pro quota.

3. **Post a mid-task status update anytime with `/report`:**
   ```text
   /report
   ```

4. **Always run `/clear` after finishing a task:**
   ```text
   /clear
   ```

### 5.2 Checkpoint Merge Routine (`0:00`, `1:00` CP1, `2:30` CP2, `3:15` CP3 Freeze)

At each checkpoint (`0:00` frozen contracts, `1:00` CP1 text loop, `2:30` CP2 live voice + canvas commands, `3:15` CP3 co-solve + transfer check freeze), both laptops push their branches (`fr/...` and `cap/...`) and merge through Pull Requests into `main`:

```bash
# 1. Push your branch and open a PR (if /next-task hasn't opened it yet):
git -C ../soro-wt/fr-<n>-<slug> push -u origin "fr/<n>-<slug>"
gh pr create --repo olowolayemogoodness-crypto/soro --base main --head "fr/<n>-<slug>" \
  --title "cp1(module-b): <summary> (#<n>)" \
  --body "Closes #<n> — tested with curl /health and lk agent console."

# 2. Check open PRs and merge when verified:
gh pr list --repo olowolayemogoodness-crypto/soro
gh pr merge <pr-number> --repo olowolayemogoodness-crypto/soro --merge --delete-branch

# 3. Pull the integrated main branch (including Miracle's merged cap/... PRs) into your main checkout:
git -C ~/work/soro checkout main
git -C ~/work/soro pull --ff-only origin main

# 4. If an active worktree continues into the next checkpoint, merge main into it:
git -C ../soro-wt/fr-<next-branch> merge origin/main
```

### 5.3 Emergency Fallback Only: USB Git Bundle Swap (If Venue Network Fails)

Only if venue Wi-Fi AND mobile hotspots fail completely, fall back to exchanging a single git bundle file on the `SORO_USB` stick:
```bash
# Export your committed main/branch to USB:
git -C ~/work/soro bundle create /Volumes/SORO_USB/soro-cp-fr.bundle main
git -C ~/work/soro bundle verify /Volumes/SORO_USB/soro-cp-fr.bundle

# Import Miracle's merged bundle from USB:
git -C ~/work/soro fetch /Volumes/SORO_USB/soro-cp-merged.bundle main:refs/remotes/captain/main
git -C ~/work/soro merge --no-ff refs/remotes/captain/main -m "sync merged checkpoint from captain USB"
```

---

## Step 6: Claude Pro Do's and Don'ts for Build Day (25 Nov 2026)

Claude Pro enforces both a **rolling 5-hour session limit** and a **weekly limit** shared across `claude.ai`, Claude Desktop, mobile, and Claude Code CLI. Follow these rules so you never get rate-limited mid-hackathon:

### DO:
- **Keep `ANTHROPIC_API_KEY` unset** in your terminal (`echo "$ANTHROPIC_API_KEY"` must be blank).
- **Run ONLY ONE Claude Code terminal session at a time.** Running 2–3 parallel sessions multiplies context re-reads and can drain a 5-hour Pro budget in 45 minutes.
- **Use Sonnet (`/model sonnet`) for coding** and switch to **Haiku (`/model haiku`)** for simple JSON schema or Docker tweaks.
- **Run `/clear` between every issue / checkpoint (`CP1`, `CP2`, `CP3`)** so old conversation history is not re-sent on every turn.
- **Run `/compact` if a single debugging thread exceeds ~10 turns**, and check `/usage` at each checkpoint.
- **Optional 5-hour window-split trick:** Send one tiny message (`"hi"`) to Claude ~2 hours before the 4-hour hackathon build starts (`T-2:00`). That starts your 5-hour rolling clock early so it **resets to 100% at `T+3:00`** right before feature freeze and final bugfixes!
- **Optional overflow safety net:** If you have a card attached on claude.ai, enabling a `$5–$10` pay-as-you-go **usage credits** cap in `Settings -> Usage` guarantees you will never be locked out at `CP2`.

### DON'T:
- **Never switch to Opus** during the 4-hour build (Opus burns Pro quota multiple times faster than Sonnet).
- **Never keep `claude.ai` web chat tabs or Claude Desktop running** in the background while coding in Claude Code CLI—they draw from the same 5-hour pool.
- **Never paste 150-item glossary files or huge log dumps into the chat prompt**—let Claude Code read only the specific lines it needs with its file tools.
- **Never put API keys or secrets in code, issues, or PRs** (`https://github.com/olowolayemogoodness-crypto/soro` is public).
