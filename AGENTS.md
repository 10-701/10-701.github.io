# Repository instructions

These instructions apply to the entire repository.

## General rules

- Follow the user's requested scope exactly.
- Do not modify unrelated files.
- Do not introduce harmless or placeholder changes unless explicitly requested.
- Never print, expose, commit, or include authentication tokens in URLs.
- Never push directly to `main`.
- Never bypass repository rules or use administrative merge privileges.
- Never approve a pull request authored by this account.

## Task types

For implementation tasks:

1. Make the requested changes.
2. Validate the diff.
3. Run relevant checks.
4. Commit the intended changes.
5. Push the task branch.
6. Create or locate the pull request.
7. Enable auto-merge.
8. Report the pull request URL.

For reviews, explanations, investigations, or planning requests:

- Do not modify files.
- Do not create commits or pull requests.
- Report findings only.

## Branch preparation

Before editing files for an implementation task, inspect the current branch:

```bash
current_branch="$(git branch --show-current)"

if [ -z "$current_branch" ] || [ "$current_branch" = "main" ] || [ "$current_branch" = "work" ]; then
  current_branch="codex/$(date -u +%Y%m%d-%H%M%S)"
  git switch -c "$current_branch"
fi
```

Use the existing branch when it is already a task-specific branch.

Never make implementation commits directly on `main`.

## Validation

Before committing:

1. Review the complete diff.
2. Confirm that only intended files changed.
3. Run the repository's relevant tests, linters, formatters, or validation commands.
4. Always run:

```bash
git diff --check
git status --short
git diff --stat
git diff
```

If validation fails, fix the problem when it is within the requested scope. Otherwise, report the blocker.

Do not commit when there are no changes.

## Commit

Stage only the intended files. Do not blindly stage unrelated changes.

Create a concise commit message that describes the implementation:

```bash
git add -- <intended-files>
git commit -m "<concise description>"
```

After committing, confirm that the working tree is clean:

```bash
git status --short --branch
```

## GitHub authentication and remote

The GitHub token is provided through `GH_TOKEN`. Never display its value.

Confirm that it exists:

```bash
test -n "${GH_TOKEN:-}" || {
  echo "GH_TOKEN is not configured"
  exit 1
}
```

Configure the repository remote:

```bash
repository_url="https://github.com/10-701/10-701.github.io.git"

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$repository_url"
else
  git remote add origin "$repository_url"
fi
```

Configure Git to use GitHub CLI authentication:

```bash
gh auth setup-git
```

Do not add the token to the Git remote URL.

## Push

Confirm that the current branch is not `main`, then push it:

```bash
current_branch="$(git branch --show-current)"

if [ -z "$current_branch" ] || [ "$current_branch" = "main" ]; then
  echo "Refusing to push an invalid or protected branch"
  exit 1
fi

git push --set-upstream origin "$current_branch"
```

Never force-push unless the user explicitly requests it.

## Pull request

Look for an existing open pull request from the current branch into `main`:

```bash
current_branch="$(git branch --show-current)"

pr_url="$(
  gh pr list \
    --repo 10-701/10-701.github.io \
    --state open \
    --head "$current_branch" \
    --base main \
    --json url \
    --jq '.[0].url // empty'
)"
```

If no open pull request exists, create one:

```bash
if [ -z "$pr_url" ]; then
  pr_url="$(
    gh pr create \
      --repo 10-701/10-701.github.io \
      --base main \
      --head "$current_branch" \
      --fill
  )"
fi
```

The pull request title and description must clearly summarize:

- What changed.
- Why it changed.
- Which checks were run.

Update the PR description if `--fill` does not produce an adequate description.

## Auto-merge

After creating or locating the pull request, enable auto-merge using squash merging:

```bash
gh pr merge --repo 10-701/10-701.github.io --auto --squash "$pr_url"
```

This command may schedule the merge, but required human reviews and checks must remain enforced.

Never:

- Use `--admin`.
- Bypass branch protection.
- Merge without the required human approval.
- Remove or weaken review requirements.
- Push directly to `main`.

## Completion report

At the end of an implementation task, report:

- A concise summary of the changes.
- The commit hash and commit message.
- The checks performed and their results.
- The pull request URL.
- Whether auto-merge was enabled.
- Any remaining blockers.

If pushing, creating the pull request, or enabling auto-merge fails, report the exact failure. Do not weaken repository protections to work around it.
