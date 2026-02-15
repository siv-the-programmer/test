#!/usr/bin/env bash



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
  if [ -z "$USERNAME" ]; then
    echo "Username cannot be empty"
    get_username
  fi
}

# repo name func
get_repo() {
  echo -n "Enter repository name: "
  read -r REPO
  if [ -z "$REPO" ]; then
    echo "Repository name cannot be empty"
    get_repo
  fi
}

# commit message func
get_message() {
  echo -n "Enter commit message (or press Enter for default): "
  read -r MSG
  if [ -z "$MSG" ]; then
    MSG="update site"
  fi
}

# deploy site func
deploy_site() {
  echo ""
  echo "Starting deployment..."
  echo ""
  
  get_username
  get_repo
  get_message
  
  REMOTE="https://github.com/$USERNAME/$REPO.git"
  
  echo ""
  echo "Checking if repository exists..."
  
  # Check if repo exists, if not create it
  gh repo view "$USERNAME/$REPO" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Repository not found. Creating new repository..."
    gh repo create "$USERNAME/$REPO" --public --source=. --remote=origin --push=false
    if [ $? -ne 0 ]; then
      echo "Failed to create repository. Please check your credentials."
      return
    fi
  else
    echo "Repository found."
  fi
  
  # git init if needed
  if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
  fi
  
  # Set branch to main
  echo "Setting up main branch..."
  git branch -M main
  
  # Add files
  echo "Adding files..."
  git add .
  
  # Commit changes
  echo "Committing changes..."
  git commit -m "$MSG"
  if [ $? -ne 0 ]; then
    echo "No new changes to commit"
  fi
  
  # Set remote
  echo "Setting remote..."
  git remote add origin "$REMOTE" 2>/dev/null
  if [ $? -ne 0 ]; then
    git remote set-url origin "$REMOTE"
  fi
  
  # Push to GitHub
  echo "Pushing to GitHub..."
  git push -u origin main
  if [ $? -ne 0 ]; then
    echo "Push failed. Please check your credentials."
    return
  fi
  
  # Enable GitHub Pages
  echo "Enabling GitHub Pages..."
  gh repo edit "$USERNAME/$REPO" --enable-pages --pages-branch main --pages-path /
  
  echo ""
  echo "================================"
  echo "DEPLOYMENT COMPLETE"
  echo "================================"
  echo ""
  echo "Your site is live at:"
  echo "https://$USERNAME.github.io/$REPO/"
  echo ""
  echo "Note: It may take a few minutes for the site to be available."
  echo ""
}

# Function to check status
check_status() {
  echo ""
  get_username
  get_repo
  
  echo ""
  echo "Checking deployment status..."
  echo ""
  
  gh repo view "$USERNAME/$REPO" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Repository exists: https://github.com/$USERNAME/$REPO"
    echo "Live site: https://$USERNAME.github.io/$REPO/"
    echo ""
    echo "Checking if GitHub Pages is enabled..."
    gh api repos/$USERNAME/$REPO/pages > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "GitHub Pages is enabled."
    else
      echo "GitHub Pages is not enabled yet."
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
  
  case $CHOICE in
    1)
      deploy_site
      ;;
    2)
      deploy_site
      ;;
    3)
      check_status
      ;;
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
