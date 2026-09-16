#!/bin/bash
# Pull the latest code of this repository (the VCPToolBox-macOS fork).
#
# Safe to run from any directory: it always operates on the repository that
# contains this script, and it fails loudly instead of printing a false
# "Update complete" when the pull did not actually happen.
set -u

echo "Updating VCPToolBox using Git (no dependencies)..."

# Operate on the repository this script lives in, not the caller's CWD.
cd "$(dirname "$0")" || exit 1

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Update failed: $(pwd) is not a Git working tree." >&2
    exit 1
fi

echo "Pulling latest changes..."
if ! git pull --ff-only; then
    echo "Update failed: the latest code was NOT pulled (see the Git error above)." >&2
    echo "Repair: commit or stash local changes, then retry; if the branch has diverged, reconcile it first (git pull --rebase)." >&2
    exit 1
fi

echo "Update complete. Now at $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD)."
