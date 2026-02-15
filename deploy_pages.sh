#!/usr/bin/env bash
set -euo pipefail

# GitHub Pages deploy helper
# - Work branch: patch1
# - Publish branch: main (fast-forwarded to patch1)
# - Pages source: main + / (root)
#
# Requirements: git, gh (authenticated), curl (only for gh install, not used here)

BANNER() {
  printf "\nGitHub Pages Deployment Tool  (Sivario)\n\n"
}

die() { printf "error: %s\n" "$*" >&2; exit 1; }
note() { printf "%s\n" "$*"; }

USERNAME_DEFAULT="siv-the-programmer"
WORK_BRANCH="patch1"
PUBLISH_BRANCH="main"
PAGES_PATH="/"

get_username() {
  USERNAME="${USERNAME_DEFAULT}"
  [ -n "${USERNAME}" ] || die "username empty"
}

get_repo() {
  read -r -p "repo: " REPO
  [ -n "${REPO:-}" ] || die "repo empty"
}

get_message() {
  read -r -p "msg  : " MSG || true
  MSG="${MSG:-update site}"
}

require_gh_auth() {
  gh auth status >/dev/null 2>&1 || die "gh not authenticated (run: gh auth login)"
}

ensure_repo_exists() {
  if ! gh repo view "$USERNAME/$REPO" >/dev/null 2>&1; then
    note "repo not found -> creating $USERNAME/$REPO"
    gh repo create "$USERNAME/$REPO" --public --source=. --remote=origin --push=false >/dev/null
  else
    note "repo ok: $USERNAME/$REPO"
  fi
}

ensure_git_repo() {
  if [ ! -d .git ]; then
    note "git init"
    git init >/dev/null
  fi
}

ensure_remote() {
  local remote="https://github.com/$USERNAME/$REPO.git"
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$remote"
  else
    git remote add origin "$remote"
  fi
}

fetch_origin() {
  git fetch origin --prune >/dev/null 2>&1 || true
}

ensure_branch_exists_locally() {
  local branch="$1"
  local base="$2"

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    return 0
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git checkout -B "$branch" "origin/$branch" >/dev/null
    return 0
  fi

  git checkout -B "$branch" "$base" >/dev/null
}

ensure_initial_commit() {
  # If repo has no commits, make one so branches exist cleanly.
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    note "initial commit"
    git add . >/dev/null 2>&1 || true
    git commit -m "initial commit" >/dev/null 2>&1 || true
  fi
}

commit_on_work_branch() {
  git checkout "$WORK_BRANCH" >/dev/null

  git add .
  if git diff --cached --quiet; then
    note "no changes"
    return 0
  fi

  git commit -m "$MSG" >/dev/null
  note "commit: $WORK_BRANCH -> $MSG"
}

push_work_branch() {
  git push -u origin "$WORK_BRANCH"
}

fast_forward_publish_branch() {
  git checkout "$PUBLISH_BRANCH" >/dev/null
  git merge --ff-only "$WORK_BRANCH" >/dev/null
  git push -u origin "$PUBLISH_BRANCH"
}

enable_pages_main_root() {
  # Uses GitHub REST API via gh; works regardless of gh repo-edit flags.
  local endpoint="repos/$USERNAME/$REPO/pages"
  note "pages: source=$PUBLISH_BRANCH path=$PAGES_PATH"

  if gh api "$endpoint" >/dev/null 2>&1; then
    gh api -X PUT "$endpoint" \
      -f "source[branch]=$PUBLISH_BRANCH" \
      -f "source[path]=$PAGES_PATH" \
      >/dev/null
    return 0
  fi

  gh api -X POST "$endpoint" \
    -f "source[branch]=$PUBLISH_BRANCH" \
    -f "source[path]=$PAGES_PATH" \
    >/dev/null
}

deploy() {
  require_gh_auth
  get_username
  get_repo
  get_message

  ensure_git_repo
  ensure_repo_exists
  ensure_remote
  fetch_origin

  # Ensure publish branch exists (local or remote), and has at least one commit
  if git show-ref --verify --quiet "refs/remotes/origin/$PUBLISH_BRANCH"; then
    git checkout -B "$PUBLISH_BRANCH" "origin/$PUBLISH_BRANCH" >/dev/null
  else
    git checkout -B "$PUBLISH_BRANCH" >/dev/null
  fi
  ensure_initial_commit

  # Ensure work branch exists
  ensure_branch_exists_locally "$WORK_BRANCH" "$PUBLISH_BRANCH"

  commit_on_work_branch
  push_work_branch
  fast_forward_publish_branch
  enable_pages_main_root

  printf "\nurl  : https://%s.github.io/%s/\n" "$USERNAME" "$REPO"
  printf "work : %s\npub  : %s (pages: %s)\n\n" "$WORK_BRANCH" "$PUBLISH_BRANCH" "$PAGES_PATH"
}

status() {
  require_gh_auth
  get_username
  get_repo

  if ! gh repo view "$USERNAME/$REPO" >/dev/null 2>&1; then
    die "repo not found: $USERNAME/$REPO"
  fi

  note "repo : https://github.com/$USERNAME/$REPO"
  note "site : https://$USERNAME.github.io/$REPO/"

  if gh api "repos/$USERNAME/$REPO/pages" >/dev/null 2>&1; then
    note "pages: enabled"
    gh api "repos/$USERNAME/$REPO/pages" -q '.source | "src : \(.branch) \(.path)"' 2>/dev/null || true
  else
    note "pages: not enabled"
  fi
  printf "\n"
}

menu() {
  BANNER
  printf "1) deploy\n2) update\n3) status\n4) quit\n\n"
  read -r -p "> " choice
  case "${choice:-}" in
    1|2) deploy ;;
    3) status ;;
    4) exit 0 ;;
    *) note "bad option" ;;
  esac
}

while true; do
  menu
done
