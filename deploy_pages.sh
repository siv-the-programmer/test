#!/usr/bin/env bash
set -euo pipefail

clear
echo "GitHub Pages Deployment Tool"
echo "                  by Sivario"

show_menu() {
  echo ""
  echo "What would you like to do?"
  echo ""
  echo "1) Deploy a new site"
  echo "2) Update an existing site"
  echo "3) Check deployment status"
  echo "4) Exit"
  echo ""
  echo -n "Choose an option (1-4): "
}

# username func
get_username() {
  USERNAME="siv-the-programmer"
  if [ -z "${USERNAME:-}" ]; then
    echo "Username cannot be empty"
    get_username
  fi
}

# repo name func
get_repo() {
  echo -n "Enter repository name: "
  read -r REPO
  if [ -z "${REPO:-}" ]; then
    echo "Repository name cannot be empty"
    get_repo
  fi
}

# commit message func
get_message() {
  echo -n "Enter commit message (or press Enter for default): "
  read -r MSG
  if [ -z "${MSG:-}" ]; then
    MSG="update site"
  fi
}

ensure_gh_auth() {
  if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
  fi
}

ensure_git_repo() {
  if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
  fi
}

ensure_remote() {
  REMOTE="https://github.com/$USERNAME/$REPO.git"
  echo "Setting remote..."
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE"
  else
    git remote add origin "$REMOTE"
  fi
}

ensure_repo_exists() {
  echo "Checking if repository exists..."
  if ! gh repo view "$USERNAME/$REPO" >/dev/null 2>&1; then
    echo "Repository not found. Creating new repository..."
    gh repo create "$USERNAME/$REPO" --public --source=. --remote=origin --push=false
  else
    echo "Repository found."
  fi
}

sync_remote_branches() {
  # Fetch remote branches if remote exists and is reachable
  if git ls-remote --exit-code origin >/dev/null 2>&1; then
    git fetch origin --prune >/dev/null 2>&1 || true
  fi
}

ensure_main_branch() {
  echo "Ensuring main branch exists..."
  if git show-ref --verify --quiet refs/heads/main; then
    git checkout main >/dev/null
  else
    # If origin/main exists, base off it; otherwise create main locally
    if git show-ref --verify --quiet refs/remotes/origin/main; then
      git checkout -B main origin/main >/dev/null
    else
      git checkout -B main >/dev/null
    fi
  fi

  # If main has no commits yet, create an initial commit so branches can exist
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "Creating initial commit on main..."
    git add . || true
    git commit -m "initial commit" || true
  fi
}

ensure_patch1_branch() {
  echo "Ensuring patch1 branch exists (create if missing)..."
  if git show-ref --verify --quiet refs/heads/patch1; then
    git checkout patch1 >/dev/null
  else
    if git show-ref --verify --quiet refs/remotes/origin/patch1; then
      git checkout -B patch1 origin/patch1 >/dev/null
    else
      git checkout -B patch1 main >/dev/null
    fi
  fi
}

commit_on_patch1() {
  echo "Adding files..."
  git add .

  echo "Committing changes on patch1..."
  if git diff --cached --quiet; then
    echo "No staged changes to commit."
  else
    git commit -m "$MSG"
  fi
}

push_patch1() {
  echo "Pushing patch1 to GitHub..."
  git push -u origin patch1
}

fast_forward_main_to_patch1() {
  echo "Fast-forwarding main to patch1 (so Pages builds from main)..."
  git checkout main >/dev/null
  git merge --ff-only patch1
  git push -u origin main
}

enable_pages_main_root() {
  echo "Enforcing GitHub Pages: branch=main, path=/ (root)..."
  # This command is supported in recent gh versions; if it errors, auth/permissions are usually the issue.
  gh repo edit "$USERNAME/$REPO" --enable-pages --pages-branch main --pages-path /
}

# deploy site func
deploy_site() {
  echo ""
  echo "Starting deployment..."
  echo ""

  ensure_gh_auth
  get_username
  get_repo
  get_message

  ensure_git_repo
  ensure_repo_exists
  ensure_remote
  sync_remote_branches

  ensure_main_branch
  ensure_patch1_branch

  commit_on_patch1
  push_patch1

  # Keep main in sync for GitHub Pages publishing
  fast_forward_main_to_patch1
  enable_pages_main_root

  echo ""
  echo "================================"
  echo "DEPLOYMENT COMPLETE"
  echo "================================"
  echo ""
  echo "Your site is live at:"
  echo "https://$USERNAME.github.io/$REPO/"
  echo ""
  echo "Branch workflow:"
  echo "- You commit/push to: patch1"
  echo "- GitHub Pages publishes from: main (root)"
  echo ""
}

# Function to check status
check_status() {
  echo ""
  ensure_gh_auth
  get_username
  get_repo

  echo ""
  echo "Checking deployment status..."
  echo ""

  if gh repo view "$USERNAME/$REPO" >/dev/null 2>&1; then
    echo "Repository exists: https://github.com/$USERNAME/$REPO"
    echo "Live site: https://$USERNAME.github.io/$REPO/"
    echo ""
    echo "Checking if GitHub Pages is enabled..."
    if gh api "repos/$USERNAME/$REPO/pages" >/dev/null 2>&1; then
      echo "GitHub Pages is enabled."
    else
      echo "GitHub Pages is not enabled yet (or not accessible)."
    fi
  else
    echo "Repository not found."
  fi
  echo ""
}

# Main program loop
while true; do
  show_menu
  read -r CHOICE

  case "$CHOICE" in
    1) deploy_site ;;
    2) deploy_site ;;
    3) check_status ;;
    4)
      echo ""
      echo "Goodbye"
      exit 0
      ;;
    *)
      echo ""
      echo "Invalid option. Please choose 1-4."
      ;;
  esac
done
