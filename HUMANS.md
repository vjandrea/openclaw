# Rebase dev onto the latest stable tag

Tags are local refs. Use a tag such as `v2026.10.7`, not
`upstream/tags/latest`.

Fetch remote refs and tags:

```bash
git fetch --all --prune --tags
```

Select the highest stable version tag, excluding prereleases:

```bash
latest_stable=$(git tag --list 'v[0-9]*' --sort=-version:refname |
  awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }')

echo "$latest_stable"
```

Confirm the selected tag is the intended release and the working tree is clean:

```bash
git status -sb
```

Create a backup branch, then rebase:

```bash
git switch dev
git branch "backup/dev-before-rebase-$(date +%Y%m%d-%H%M%S)"
git rebase "$latest_stable"
```

If conflicts occur, resolve them, stage the resolved files, and continue:

```bash
git add <resolved-files>
git rebase --continue
```

To cancel the rebase:

```bash
git rebase --abort
```

After verifying the result, update the remote branch:

```bash
git push --force-with-lease origin dev
```

Rebasing rewrites the branch's commit history. Coordinate with anyone else using
`dev` before force-pushing.
