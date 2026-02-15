#!/usr/bin/env bash

USERNAME="siv-the-programmer"
WORK_BRANCH="patch1"
PROD_BRANCH="main"
PAGES_PATH="/"

echo "GitHub Pages Deploy"
echo "patch1 -> main (Pages publishes from main)"
echo ""

command -v git >/dev/null 2>&1 || { echo "git not installed"; exit 1; }
command -v gh  >/dev/null 2>&1 || { echo "gh not installed"; exit 1; }

if ! gh auth status >/dev/null 2>&1; then
  echo "Run: gh auth login"
  exit 1
fi

echo -n "repo name: "
read -r REPO
[ -z "$REPO" ] && { echo "repo required"; exit 1; }

echo -n "commit message (Enter = update site): "
read -r MSG
[ -z "$MSG" ] && MSG="update site"

if [ ! -d ".git" ]; then
  git init || exit 1
fi

REMOTE="https://github.com/$USERNAME/$REPO.git"

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE" || exit 1
else
  git remote add origin "$REMOTE" || exit 1
fi

if ! gh repo view "$USERNAME/$REPO" >/dev/null 2>&1; then
  gh repo create "$USERNAME/$REPO" --public --source=. --remote=origin --push=false || exit 1
fi

git fetch origin >/dev/null 2>&1

if git show-ref --verify --quiet "refs/heads/$WORK_BRANCH"; then
  git checkout "$WORK_BRANCH" || exit 1
else
  git checkout -b "$WORK_BRANCH" || exit 1
fi

mkdir -p .github/workflows

if [ ! -f ".github/workflows/ci.yml" ]; then
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  pull_request:
    branches: [ main ]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: test -f index.html
EOF
fi

git add .

if git diff --cached --quiet; then
  echo "no changes"
else
  git commit -m "$MSG" || exit 1
fi

git push -u origin "$WORK_BRANCH" || exit 1

if gh api "repos/$USERNAME/$REPO/pages" >/dev/null 2>&1; then
  gh api -X PUT "repos/$USERNAME/$REPO/pages" \
    -f "build_type=legacy" \
    -f "source[branch]=$PROD_BRANCH" \
    -f "source[path]=$PAGES_PATH" >/dev/null 2>&1
else
  gh api -X POST "repos/$USERNAME/$REPO/pages" \
    -f "build_type=legacy" \
    -f "source[branch]=$PROD_BRANCH" \
    -f "source[path]=$PAGES_PATH" >/dev/null 2>&1
fi

PR=$(gh pr list --head "$WORK_BRANCH" --base "$PROD_BRANCH" --json number -q '.[0].number')

if [ -z "$PR" ]; then
  gh pr create --head "$WORK_BRANCH" --base "$PROD_BRANCH" --title "$MSG" --body "auto merge" || exit 1
  PR=$(gh pr list --head "$WORK_BRANCH" --base "$PROD_BRANCH" --json number -q '.[0].number')
fi

gh pr merge "$PR" --merge || {
  echo "merge blocked (likely branch protection or checks failing)"
  exit 1
}

echo ""
echo "done"
echo "repo: https://github.com/$USERNAME/$REPO"
echo "site: https://$USERNAME.github.io/$REPO/"
echo ""
