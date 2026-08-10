---
name: commit-to-main
description: Commit finished work directly to main. Push only if the repo is public. Use when shipping changes, finishing a task, or when the user asks to commit. Never create PRs; never push private repos.
---

# Commit to main

## Instructions

1. Make sure you are on `main` (`git checkout main` if needed; pull if behind and a remote pull is appropriate).
2. Stage only the relevant files with `git add`.
3. Commit with a clear, descriptive message.
4. Check repository visibility (`gh repo view --json isPrivate,visibility` or equivalent).
5. If the repository is **public**, push to `origin/main` (`git push origin main`).
6. If the repository is **non-public** (private/internal), do **not** push — leave the commit local on `main`.
7. Do not create feature branches for PRs, open PRs, or run PR-creation tooling (`gh pr create`, ManagePullRequest, etc.).

## Notes

- If work was started on a side branch, cherry-pick or merge it onto `main`, then follow the push rules above. Close any accidental PR.
- Keep secrets out of commits; rely on `.gitignore` for `.env` and local deploy hashes.
