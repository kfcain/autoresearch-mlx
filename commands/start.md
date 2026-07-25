---
name: start
description: Start a new autonomous MLX autoresearch run — set up a fresh run branch, establish a baseline, then loop on train.py to minimize val_bpb.
argument-hint: "[run-tag]"
allowed-tools: Read Edit Write Bash(git:*) Bash(uv:*) Bash(grep:*) Bash(tail:*) Bash(kill:*) Bash(ls:*)
---

Start a new autoresearch run using the **autoresearch** skill's protocol.

Requested run tag: `$ARGUMENTS` (if empty, propose one based on today's date).

Do the setup phase with me first:

1. Locate the project (`train.py`, `prepare.py`, `program.md` — at the repo root
   or in an `autoresearch-mlx/` subdirectory) and confirm `pyproject.toml`'s
   directory for `uv run`.
2. Confirm the run tag and create branch `autoresearch/<tag>` from the default
   branch (it must not already exist).
3. Read `README.md`, `prepare.py` (fixed), and `train.py` (the file you edit).
4. Verify `~/.cache/autoresearch/` has data + tokenizer; if not, tell me to run
   `uv run prepare.py`.
5. Initialize `results.tsv` and run `uv run train.py` once, unmodified, to record
   the baseline `val_bpb` **on this hardware**.

Once I confirm setup, begin the experiment loop and run autonomously — edit
`train.py`, commit only that file (never `git add -A`), run
`uv run train.py > run.log 2>&1`, read `val_bpb`, keep-or-revert via git, log to
`results.tsv`, and **do not stop to ask whether to continue**.

To keep the loop's git/training churn out of this session, you may run it in an
isolated context by delegating to the `research-loop` subagent once setup is
confirmed and the baseline is recorded.

Follow the full protocol in the `autoresearch` skill (setup, judgment criteria,
loop mechanics, timeout/crash handling, tsv format, and the optional `rigor.py`
significance gate).
