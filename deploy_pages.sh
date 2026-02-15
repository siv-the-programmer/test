#!/usr/bin/env bash

WORK_BRANCH="patch1"
PAGES_BRANCH="main"
PAGES_PATH="/"
USERNAME="siv-the-programmer"

clear
echo "GitHub Pages Deployment Tool"
echo "by Sivario"
echo ""

fail() {
  echo "error: $1"
  exit 1
}

get_repo() {
  echo -n "repo name: "
  read -r REPO
  if [ -z "$REPO" ]; then
    echo "repo name cannot be empty"
    get_repo
  fi
}

get_message() {
  echo -n "commit message (Enter = update site): "
  read -r MSG
  if [ -z "$MSG" ]; then
    MSG="update site"
  fi
}

check_gh_login() {
  if ! gh auth status > /dev/null 2>&1; then
    fail "gh not logged in. Run: gh auth login"
  fi
}

ensure_git() {
  if [ ! -d ".git" ]; then
    echo "git init"
    if ! git init > /dev/null 2>&1; then
      fail "git init failed"
    fi
  fi
}

ensure_repo_exists() {
  if ! gh repo view "$USERNAME/$REPO" > /dev/null 2>&1; then
    echo "repo not found -> creating $USERNAME/$REPO"
    if ! gh repo create "$USERNAME/$REPO" --public --source=. --remote=origin --push=false > /dev/null 2>&1; then
      fail "failed to create repo"
    fi
  else
    echo "repo exists"
  fi
}

ensure_remote() {
  REMOTE="https://github.com/$USERNAME/$REPO.git"

  if ! git remote add origin "$REMOTE" > /dev/null 2>&1; then
    if ! git remote set-url origin "$REMOTE" > /dev/null 2>&1; then
      fail "failed to set git remote"
    fi
  fi

  # Fetch if possible (new repos may not have anything yet; that's ok)
  git fetch origin --prune > /dev/null 2>&1
}

ensure_first_commit() {
  if ! git rev-parse --verify HEAD > /dev/null 2>&1; then
    echo "first commit (repo was empty)"
    git add . > /dev/null 2>&1
    git commit -m "initial commit" > /dev/null 2>&1
  fi
}

ensure_branch() {
  # ensure_branch BRANCH BASE_BRANCH
  BR="$1"
  BASE="$2"

  # local branch exists
  if git show-ref --verify --quiet "refs/heads/$BR"; then
    return
  fi

  # remote branch exists
  if git show-ref --verify --quiet "refs/remotes/origin/$BR"; then
    git checkout -B "$BR" "origin/$BR" > /dev/null 2>&1 || fail "failed to checkout $BR from origin"
    return
  fi

  # create from base
  git checkout -B "$BR" "$BASE" > /dev/null 2>&1 || fail "failed to create $BR from $BASE"
}

enable_pages_main_root() {
  echo "setting GitHub Pages -> branch: $PAGES_BRANCH  path: $PAGES_PATH"

  if gh api "repos/$USERNAME/$REPO/pages" > /dev/null 2>&1; then
    # update existing
    gh api -X PUT "repos/$USERNAME/$REPO/pages" \
      -f "source[branch]=$PAGES_BRANCH" \
      -f "source[path]=$PAGES_PATH" > /dev/null 2>&1 || fail "failed to update pages"
  else
    # create new
    gh api -X POST "repos/$USERNAME/$REPO/pages" \
      -f "source[branch]=$PAGES_BRANCH" \
      -f "source[path]=$PAGES_PATH" > /dev/null 2>&1 || fail "failed to create pages"
  fi
}

deploy() {
  echo ""
  echo "deploying..."
  echo ""

  check_gh_login
  get_repo
  get_message

  ensure_git
  ensure_repo_exists
  ensure_remote

  # make sure main exists + has at least one commit
  if git show-ref --verify --quiet "refs/remotes/origin/$PAGES_BRANCH"; then
    git checkout -B "$PAGES_BRANCH" "origin/$PAGES_BRANCH" > /dev/null 2>&1 || fail "failed to checkout main"
  else
    git checkout -B "$PAGES_BRANCH" > /dev/null 2>&1 || fail "failed to create main"
  fi
  ensure_first_commit

  # make sure patch1 exists
  ensure_branch "$WORK_BRANCH" "$PAGES_BRANCH"
  git checkout "$WORK_BRANCH" > /dev/null 2>&1 || fail "failed to checkout patch1"

  # commit on patch1 (only if something changed)
  git add . > /dev/null 2>&1 || fail "git add failed"
  if git diff --cached --quiet; then
    echo "no changes to commit"
  else
    git commit -m "$MSG" || fail "git commit failed"
  fi

  echo "push -> $WORK_BRANCH"
  git push -u origin "$WORK_BRANCH" || fail "push patch1 failed"

  echo "sync $PAGES_BRANCH <- $WORK_BRANCH"
  git checkout "$PAGES_BRANCH" > /dev/null 2>&1 || fail "checkout main failed"
  git merge --ff-only "$WORK_BRANCH" > /dev/null 2>&1 || fail "fast-forward merge failed (main has diverged)"
  git push -u origin "$PAGES_BRANCH" > /dev/null 2>&1 || fail "push main failed"

  enable_pages_main_root

  echo ""
  echo "done"
  echo "site: https://$USERNAME.github.io/$REPO/"
  echo "work branch : $WORK_BRANCH"
  echo "pages branch: $PAGES_BRANCH (root)"
  echo ""
}

status() {
  check_gh_login
  get_repo

  echo ""
  echo "repo: https://github.com/$USERNAME/$REPO"
  echo "site: https://$USERNAME.github.io/$REPO/"
  echo ""

  if gh api "repos/$USERNAME/$REPO/pages" > /dev/null 2>&1; then
    echo "pages: enabled"
    gh api "repos/$USERNAME/$REPO/pages" -q '.source | "source: \(.branch) \(.path)"' 2>/dev/null
  else
    echo "pages: not enabled"
  fi
  echo ""
}

while true; do
  echo "1) deploy"
  echo "2) update"
  echo "3) status"
  echo "4) quit"
  echo -n "> "
  read -r CHOICE

  case "$CHOICE" in
    1) deploy ;;
    2) deploy ;;
    3) status ;;
    4) echo "bye"; exit 0 ;;
    *) echo "invalid option" ;;
  esac
done
