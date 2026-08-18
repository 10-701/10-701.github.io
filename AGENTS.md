## Pull request publishing

For implementation tasks, after making and validating the requested changes:

1. Confirm that the diff contains only changes required by the task.
2. Run the repository's relevant tests and checks.
3. Commit the intended changes with a concise commit message.
4. Run `gh auth setup-git`.
5. Push the current branch with `git push --set-upstream origin HEAD`.
6. Check whether a pull request already exists for the current branch.
7. If none exists, run `gh pr create --base main --fill`.
8. Report the pull request URL in the final response.
9. Never merge the pull request.
10. Never push directly to `main`.

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin https://github.com/mld-instructors/10701-f26-website.git
else
  git remote add origin https://github.com/mld-instructors/10701-f26-website.git
fi

gh auth setup-git
git push --set-upstream origin HEAD