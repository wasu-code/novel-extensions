#!/bin/bash

REMOTE=universe
BRANCH=dev
FOLDER=lib

git config core.sparseCheckout true
echo "$FOLDER/*" > .git/info/sparse-checkout

git fetch $REMOTE $BRANCH
REMOTE_SHA=$(git rev-parse $REMOTE/$BRANCH)

# Checkout only the folder into current branch
git checkout $REMOTE/$BRANCH -- $FOLDER

git add $FOLDER
git commit -m "chore: sync /$FOLDER with latest changes from $REMOTE/$BRANCH @$REMOTE_SHA"

git config core.sparseCheckout false

echo "Done: /$FOLDER synced from $REMOTE/$BRANCH ($REMOTE_SHA)"
