---
name: autoresearch
description: Run the autonomous MLX autoresearch loop — a fixed-budget, keep-or-revert training research loop for the autoresearch-mlx repo. Use when the user asks to start/run autoresearch, kick off the research loop, autonomously improve train.py, minimize val_bpb, or "run experiments while I sleep" on an Apple Silicon (MLX) GPT training project.
when_to_use: The working directory (or a subdirectory) contains autoresearch-mlx's train.py, prepare.py, and program.md, and the user wants to autonomously search for train.py changes that lower val_bpb under a fixed 5-minute training budget.
user-invocable: true
allowed-tools: Read Edit Write Bash(git:*) Bash(uv:*) Bash(grep:*) Bash(tail:*) Bash(kill:*) Bash(ls:*)
---

# Autoresearch (MLX)

Run the autonomous research loop from `program.md`: an LLM-driven experiment
loop that edits **one** file (`train.py`), runs a fixed 5-minute MLX training
budget, reads a single metric (`val_bpb`), and keeps or reverts the change via
git. This is the Apple Silicon (MLX) port of Karpathy's `autoresearch` — no
PyTorch or CUDA.

**You are an autonomous researcher.** Once the loop starts, do not stop to ask
whether to keep going.

## Locate the project

The autoresearch files may sit at the repo root or inside an `autoresearch-mlx/`
subdirectory of a larger repo. First find them:

```bash
ls train.py prepare.py program.md 2>/dev/null || ls autoresearch-mlx/train.py
```

Run all `uv run` commands from the directory that contains `pyproject.toml`.
`$PROJ` below is that directory. **Monorepo rule:** always stage only the
autoresearch files (`$PROJ/train.py`, `$PROJ/results.tsv`). **Never `git add -A`**
— this project may live inside a larger repo.

## Setup (once per run, do this with the user)

1. **Agree on a run tag** based on today's date (e.g. `mar5`). The branch
   `autoresearch/<tag>` must not already exist — this is a fresh run.
2. **Create the branch**: `git checkout -b autoresearch/<tag>` from the current
   default branch.
3. **Read the in-scope files** for full context (the repo is small):
   - `README.md` — repository context.
   - `prepare.py` — fixed constants, data prep, tokenizer, dataloader,
     evaluation. **Do not modify.**
   - `train.py` — the only file you edit: model architecture, optimizer,
     training loop.
4. **Verify data exists**: check that `~/.cache/autoresearch/` contains data
   shards and a tokenizer. If not, tell the user to run `uv run prepare.py`
   (it needs to happen once on this machine; you should not run heavy prep
   silently).
5. **Establish YOUR baseline**: create `results.tsv` with the header row and run
   `uv run train.py` once, unmodified, to get the baseline `val_bpb` **on this
   hardware**. Never reuse baseline numbers from other machines.
6. **Confirm and go**, then begin the loop below.

## What you can and cannot do

**CAN:** modify `train.py` freely — architecture, optimizer, hyperparameters,
training loop, batch size, model size. Anything is fair game as long as it runs
without crashing and finishes within the time budget.

**CANNOT:**
- Modify `prepare.py`. It is read-only (fixed evaluation, data loading,
  tokenizer, and constants like the time budget and sequence length).
- Modify the evaluation harness. `evaluate_bpb` in `prepare.py` is the ground
  truth metric.
- Install new packages or add dependencies. Use only what is already in
  `pyproject.toml`.

## Judgment criteria

- **Goal:** the lowest `val_bpb`. The time budget is fixed at 5 minutes of
  training, so you never optimize for speed directly — faster training just buys
  more steps inside the budget.
- **Memory** is a soft constraint (MLX unified memory). Some increase is fine
  for a real gain; do not let it blow up.
- **Simplicity criterion:** all else equal, simpler is better. A 0.001 gain that
  adds 20 lines of hacky code is probably not worth it; a gain (or a wash) from
  *deleting* code is a great outcome — keep it.
- **First run is always the unmodified baseline.**

## The loop

The loop runs on the dedicated `autoresearch/<tag>` branch. **LOOP FOREVER:**

1. Check git state (current branch/commit).
2. Tune `train.py` with one experimental idea by editing the code directly.
3. Commit only that file:
   `git add "$PROJ/train.py" && git commit -m "experiment: <description>"`
   (never `git add -A`).
4. Run it, redirecting all output to a log — do **not** tee or let output flood
   context: `uv run train.py > run.log 2>&1`
5. Read the result: `grep "^val_bpb:\|^peak_vram_mb:" run.log`
6. If the grep is empty the run crashed — `tail -n 50 run.log` for the trace and
   attempt a fix. Give up on an idea after a few failed attempts.
7. Record the result in `results.tsv` (see format below).
8. **If `val_bpb` improved (lower):** stage the tsv and fold it into the
   experiment commit to advance the branch:
   `git add "$PROJ/results.tsv" && git commit --amend --no-edit`
9. **If equal or worse:** log the discard row (with the discarded commit hash),
   then discard the change cleanly: `git reset --hard <previous kept commit>`.

**Timeout:** an experiment should take ~7 minutes (5 min train + ~1 min
compile/eval). If a run exceeds **15 minutes**, kill it and treat it as a
failure (discard and revert).

**Crashes:** if it's something dumb (typo, missing import), fix and re-run. If
the idea is fundamentally broken, log `crash` in the tsv and move on.

## results.tsv format

Tab-separated (NOT commas — commas break descriptions). Header plus 5 columns:

```
commit	val_bpb	memory_gb	status	description
```

1. short git commit hash (7 chars)
2. `val_bpb` (e.g. `1.234567`) — use `0.000000` for crashes
3. peak memory in GB, `.1f` (peak_vram_mb / 1024) — use `0.0` for crashes
4. status: `keep`, `discard`, or `crash`
5. short description of what the experiment tried

Example:

```
commit	val_bpb	memory_gb	status	description
383abb4	2.667000	26.9	keep	baseline
909dd59	2.588904	26.9	keep	halve total batch size to 2^16
```

## Optional: rigorous keep/discard

A single 5-minute run is noisy (~0.03 `val_bpb` between reruns of the *same*
`train.py`). Deciding on one sub-threshold delta chases noise. When the user
wants stronger decisions, gate keep/discard with `rigor.py` instead of eyeballing
one delta — it runs several seeds and keeps only on a high-confidence bootstrap
win, fails a clear loser after one run, and never re-scores an identical
`train.py`:

```bash
uv run rigor.py run "halve the batch size"      # score train.py vs best (3 seeds)
uv run rigor.py run "..." --seeds 5 --confidence 0.9
uv run rigor.py best                            # current best
uv run rigor.py log                             # every scored config
```

`rigor.py` only decides — it never edits `train.py`, touches git, or changes
`evaluate_bpb`, and writes samples to `rigor_ledger.jsonl`.

## NEVER STOP

Once the loop has begun (after setup), do **not** pause to ask the human whether
to continue — no "should I keep going?", no "is this a good stopping point?". The
human may be asleep and expects you to run indefinitely until manually stopped.
If you run out of ideas, think harder: re-read the in-scope files for new angles,
combine previous near-misses, try more radical architectural changes. The loop
runs until the human interrupts you, period. At ~7 min/experiment you can run
roughly 8–9 per hour — about 70 over a night's sleep.
