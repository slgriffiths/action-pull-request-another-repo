#!/bin/sh

set -e
set -x
set -o pipefail

###################
# Helper Functions
reset_color="\\e[0m"
color_red="\\e[31m"
color_green="\\e[32m"
color_yellow="\\e[33m"
color_blue="\\e[36m"
color_gray="\\e[37m"
echo_blue() { printf "%b\n" "${color_blue}$(printf "%s\n" "$*")${reset_color}"; }
echo_green() { printf "%b\n" "${color_green}$(printf "%s\n" "$*")${reset_color}"; }
echo_red() { printf "%b\n" "${color_red}$(printf "%s\n" "$*")${reset_color}"; }
echo_yellow() { printf "%b\n" "${color_yellow}$(printf "%s\n" "$*")${reset_color}"; }
echo_gray() { printf "%b\n" "${color_gray}$(printf "%s\n" "$*")${reset_color}"; }
echo_grey() { printf "%b\n" "${color_gray}$(printf "%s\n" "$*")${reset_color}"; }
echo_info() { printf "%b\n" "${color_blue}ℹ $(printf "%s\n" "$*")${reset_color}"; }
echo_error() { printf "%b\n" "${color_red}✖ $(printf "%s\n" "$*")${reset_color}"; }
echo_warning() { printf "%b\n" "${color_yellow}✔ $(printf "%s\n" "$*")${reset_color}"; }
echo_success() { printf "%b\n" "${color_green}✔ $(printf "%s\n" "$*")${reset_color}"; }
echo_fail() { printf "%b\n" "${color_red}✖ $(printf "%s\n" "$*")${reset_color}"; }

if [ -z "$INPUT_SOURCE_FOLDER" ]
then
  echo "Source folder must be defined"
  return -1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master"]
then
  echo "Destination head branch cannot be 'main' nor 'master'"
  return -1
fi

##############################
echo "::group::Gather Inputs"

if [[ -z "$GITHUB_TOKEN" ]]; then
  if [[ ! -z "$INPUT_GITHUB_TOKEN" ]]; then
    GITHUB_TOKEN="$INPUT_GITHUB_TOKEN"
    echo "::add-mask::$INPUT_GITHUB_TOKEN"
    echo_info "INPUT_GITHUB_TOKEN=$INPUT_GITHUB_TOKEN"
  else
    echo_fail "Set the GITHUB_TOKEN environment variable."
    exit 1
  fi
fi

##############################
echo "::group::Configure git"

# Fix for the unsafe repo error: https://github.com/repo-sync/pull-request/issues/84
git config --global --add safe.directory $(pwd)

# Github actions no longer auto set the username and GITHUB_TOKEN
git remote set-url origin "https://x-access-token:$GITHUB_TOKEN@${GITHUB_SERVER_URL#https://}/$INPUT_DESTINATION_REPO"

echo "Username: $INPUT_USER_NAME"
echo "Email: $INPUT_USER_EMAIL"
echo "PR Title: $INPUT_PR_TITLE"
echo "PR Body: $INPUT_PR_BODY"
echo "PR Reviewer: $INPUT_PR_REVIEWER"
echo "PR Assignee: $INPUT_PR_ASSIGNEE"

git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

CLONE_DIR=$(mktemp -d)

echo "Cloning destination git repository"
git clone "https://x-access-token:$GITHUB_TOKEN@${GITHUB_SERVER_URL#https://}/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
cp -R $INPUT_SOURCE_FOLDER/. "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"
cd "$CLONE_DIR"

# Make a unique branch name each time in case a job fails and is retried.
# Will create branches that require cleanup -- can figure this out later.
now=$(date +"%Y%M%D%H%M%S")
DESTINATION_HEADBRANCH="$INPUT_DESTINATION_HEAD_BRANCH-$now"

git checkout -b "$DESTINATION_HEADBRANCH"

# git pull origin "$DESTINATION_HEADBRANCH"

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  # Workaround for `hub` auth error https://github.com/github/hub/issues/2149#issuecomment-513214342
  export GITHUB_USER="$GITHUB_ACTOR"

  # Committing requires user email and name to be set
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"

  echo "Pushing git commit"

  git push -u origin HEAD:$DESTINATION_HEADBRANCH

  echo "Attaching PR Create arguments"

  # https://cli.github.com/manual/gh_pr_create
  # PR_ARGS=(-B "$INPUT_DESTINATION_BASE_BRANCH" -H "$DESTINATION_HEADBRANCH")

  # if [[ ! -z "$INPUT_PR_TITLE" ]]; then
  #   PR_ARGS+=(-t "$INPUT_PR_TITLE")
  # fi

  # if [[ ! -z "$INPUT_PR_BODY" ]]; then
  #   PR_ARGS+=(-b "$INPUT_PR_BODY")
  # fi

  # if [[ ! -z "$INPUT_PR_REVIEWER" ]]; then
  #   PR_ARGS+=(-r "$INPUT_PR_REVIEWER")
  # fi

  # if [[ ! -z "$INPUT_PR_ASSIGNEE" ]]; then
  #   PR_ARGS+=(-a "$INPUT_PR_ASSIGNEE")
  # fi

  # if [[ ! -z "$INPUT_PR_LABEL" ]]; then
  #   PR_ARGS+=(-l "$INPUT_PR_LABEL")
  # fi

  # if [[ ! -z "$INPUT_PR_MILESTONE" ]]; then
  #   PR_ARGS+=(-m "$INPUT_PR_MILESTONE")
  # fi

  # if [[ "$INPUT_PR_DRAFT" == "true" ]]; then
  #   PR_ARGS+=(-d)
  # fi

  echo "Creating a pull request"
  gh pr create -t "$INPUT_PR_TITLE" \
               -b "$INPUT_PR_BODY" \
               -B "$INPUT_DESTINATION_BASE_BRANCH" \
               -H "$DESTINATION_HEADBRANCH" \
               -r "$INPUT_PR_REVIEWER" \
               -a "$INPUT_PR_ASSIGNEE" \
               -l "$INPUT_PR_LABEL" \
              #  -m $INPUT_PR_MILESTONE
else
  echo "No changes detected"
fi
