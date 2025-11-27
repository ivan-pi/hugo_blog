#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub Pages...\033[0m"

# Build the project
hugo

# Go to public folder
cd public

# Add changes
git add .
msg="rebuilding site $(date)"
if [ $# -eq 1 ]; then msg="$1"; fi
git commit -m "$msg"

# Push to GitHub Pages repo
git push origin master --force  # force because gh-pages is often rewritten

cd ..
