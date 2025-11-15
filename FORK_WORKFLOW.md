# Fork Workflow Guide

## Branch Structure

- **master**: Tracks `upstream/master` (jlesage/docker-handbrake) - kept clean
- **jc/customizations**: Your custom changes and modifications

## Remotes

- **origin**: Your fork (jasperchan/docker-pdb-base)
- **upstream**: Original repo (jlesage/docker-handbrake)

## Regular Workflow

### Pulling Upstream Changes

When you want to sync with the latest upstream changes:

```bash
# Fetch latest changes from upstream
git fetch upstream

# Update your master branch
git checkout master
git merge upstream/master --ff-only

# Optional: Push updated master to your fork
git push origin master

# Update your customizations branch
git checkout jc/customizations
git merge master
# or use: git rebase master (for cleaner history)

# Resolve any conflicts if they occur

# Push your updated customizations
git push origin jc/customizations
```

### Working on Customizations

All your changes should be made on `jc/customizations`:

```bash
# Make sure you're on your customizations branch
git checkout jc/customizations

# Make your changes
# ... edit files ...

# Commit changes
git add .
git commit -m "Your change description"

# Push to your fork
git push origin jc/customizations
```

### Quick Reference

```bash
# See current branch and status
git status

# View all branches
git branch -a

# See difference between your customizations and upstream
git diff upstream/master..jc/customizations

# See your custom commits
git log upstream/master..jc/customizations --oneline
```

## Current State

- **master**: Now at upstream commit `85d705e` (25.10.1 changelog)
- **jc/customizations**: Contains your changes (commits `5cb65b0`, `6627f4e`, and earlier custom work)

## Notes

- Never commit directly to `master` - it should always match upstream
- All your custom work goes on `jc/customizations`
- Periodically sync with upstream to stay up-to-date
- Use `git merge` for safer updates, or `git rebase` for cleaner history (but only if you understand rebasing)
