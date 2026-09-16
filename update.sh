#!/bin/bash
# Pull the latest code of this repository (the VCPToolBox-macOS fork) and
# refresh its dependencies.
#
# Safe to run from any directory: it always operates on the repository that
# contains this script, and it fails loudly instead of printing a false
# "Update complete" when the pull did not actually happen.
set -u

echo "Updating VCPToolBox using Git..."

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

status=0

# Install/update Python dependencies. Each install runs in a subshell so a
# failing step can never move this script's working directory: on macOS a
# system-Python pip3 often refuses to install, and the old
# "cd plugin && pip3 install ... && cd ../.." chain then stranded the shell
# inside the plugin directory for the remaining steps.
for plugin in SciCalculator VideoGenerator; do
    requirements="Plugin/$plugin/requirements.txt"
    if [ -f "$requirements" ]; then
        echo "Installing/updating Python dependencies for $plugin..."
        ( cd "Plugin/$plugin" && pip3 install -r requirements.txt ) || {
            echo "Warning: failed to install Python dependencies for $plugin." >&2
            status=1
        }
    fi
done

echo "Installing/updating Node.js dependencies..."
npm install || {
    echo "Warning: failed to install Node.js dependencies." >&2
    status=1
}

if [ "$status" -ne 0 ]; then
    echo "Code pulled successfully, but some dependency steps failed (see the warnings above)." >&2
    exit 1
fi

echo "Update complete. Now at $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD)."
