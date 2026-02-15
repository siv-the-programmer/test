#!/usr/bin/env bash

# Simple GitHub Pages deploy script
# - You work on:  patch1
# - Pages uses:   main (root /)
# - Script keeps main synced to patch1

WORK_BRANCH="patch1"
PAGES_BRANCH="main"
PAGES_PATH="/"
USERNAME="siv-the-programmer"

clear
echo "GitHub Pages Deployment Tool"
echo "by Sivario"
echo ""

pause() { echo ""; }

# ---------- input ----------
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

# ---------- checks ----------
check_gh_login() {
  gh auth status > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "gh not logged in. Run: gh auth login"
    exit 1
  fi
}

ensure_git() {
  if [ ! -d ".git" ]; then
    echo "git init"
    git init
  fi
}

ensure_repo_exists() {
  gh repo view "$USERNAME/$REPO" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "repo not found -> creating $USERNAME/$REPO"
    gh repo create "$USERNAME/$REPO" --public --source=. --remote=origin --push=false
    if [ $? -ne 0 ]; then
      echo "failed to create repo"
      exit 1
    fi
  else
    echo "repo exists"
  fi
}

ensure_remote() {
  REMOTE="https://github.com/$USERNAME/$REPO.git"

  git remote add origin "$REMOTE" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    git remote set-url origin "$REMOTE"
  fi

  # try fetch (ok if it fails on brand new repo)
  git fetch origin > /dev/null 2>&1
}

# ---------- branch helpers ----------
ensure_branch() {
  # usage: ensure_branch branch_name base_branch
  BR="$1"
  BASE="$2"

  # local exists?
  git show-ref --verify --quiet "refs/heads/$BR"
  if [ $? -eq 0 ]; then
    return
  fi

  # remote exists?
  git show-ref --verify --quiet "refs/remotes/origin/$BR"
  if [ $? -eq 0 ]; then
    git checkout -B "$BR" "origin/$BR" > /dev/null 2>&1
    return
  fi

  # create from base
  git checkout -B "$BR" "$BASE" > /dev/null 2>&1
}

ensure_first_commit() {
  git rev-parse --verify HEAD > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "first commit (repo was empty)"
    git add .
    git commit -m "initial commit" > /dev/null 2>&1
  fi
}

# ---------- pages ----------
enable_pages_main_root() {
  echo "setting GitHub Pages -> branch: $PAGES_BRANCH  path: $PAGES_PATH"

  # If pages already exists -> update
  gh api "repos/$USERNAME/$REPO/pages" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    gh api -X PUT "repos/$USERNAME/$REPO/pages" \
      -f "source[branch]=$PAGES_BRANCH" \
      -f "source[path]=$PAGES_PATH" > /dev/null 2>&1
    return
  fi

  # Else -> create
  gh api -X POST "repos/$USERNAME/$REPO/pages" \
    -f "source[branch]=$PAGES_BRANCH" \
    -f "source[path]=$PAGES_PATH" > /dev/null 2>&1
}

# ---------- actions ----------
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

  # make sure main exists (and has at least 1 commit)
  ensure_branch "$PAGES_BRANCH" "$PAGES_BRANCH"
  git checkout "$PAGES_BRANCH" > /dev/null 2>&1
  ensure_first_commit

  # make sure patch1 exists
  ensure_branch "$WORK_BRANCH" "$PAGES_BRANCH"
  git checkout "$WORK_BRANCH" > /dev/null 2>&1

  # commit on patch1
  git add .
  git diff --cached --quiet
  if [ $? -eq 0 ]; then
    echo "no changes to commit"
  else
    git commit -m "$MSG"
  fi

  # push patch1
  echo "push -> $WORK_BRANCH"
  git push -u origin "$WORK_BRANCH"
  if [ $? -ne 0 ]; then
    echo "push failed"
    exit 1
  fi

  # fast-forward main to patch1
  echo "sync $PAGES_BRANCH <- $WORK_BRANCH"
  git checkout "$PAGES_BRANCH" > /dev/null 2>&1
  git merge --ff-only "$WORK_BRANCH" > /dev/null 2>&1
  git push -u origin "$PAGES_BRANCH" > /dev/null 2>&1

  # enable pages
  enable_pages_main_root

  echo ""
  echo "done"
  echo "site: https://$USERNAME.github.io/$REPO/"
  echo "work branch: $WORK_BRANCH"
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

  gh api "repos/$USERNAME/$REPO/pages" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "pages: enabled"
    gh api "repos/$USERNAME/$REPO/pages" -q '.source | "source: \(.branch) \(.path)"' 2>/dev/null
  else
    echo "pages: not enabled"
  fi
  echo ""
}

# ---------- menu ----------
while true; do
  echo "1) deploy"
  echo "2) update"
  echo "3) status"
  echo "4) quit"
  echo -n "> "
  read -r CHOICE

  if [ "$CHOICE" = "1" ]; then
    deploy
  elif [ "$CHOICE" = "2" ]; then
    deploy
  elif [ "$CHOICE" = "3" ]; then
    status
  elif [ "$CHOICE" = "4" ]; then
    echo "bye"
    exit 0
  else
    echo "invalid option"
    pause
  fi
done
