---
name: commit-to-main
description: Commit finished work directly to main and push. Use when shipping changes, finishing a task, or when the user asks to commit/push. Never create PRs.
---

# Commit to main

## Instructions

1. Make sure you are on `main` (`git checkout main` if needed; pull if behind).
2. Stage only the relevant files with `git add`.
3. Commit with a clear, descriptive message.
4. Push to `origin/main` (`git push origin main`).
5. Do not create feature branches for PRs, open PRs, or run PR-creation tooling (`gh pr create`, ManagePullRequest, etc.).

## Notes

- If work was started on a side branch, cherry-pick or merge it onto `main`, push `main`, and close any accidental PR.
- Keep secrets out of commits; rely on `.gitignore` for `.env` and local deploy hashes.
