#!/usr/bin/env bash
set -e
# Find the location of this script, accounting for symlinks, see https://stackoverflow.com/a/246128
SCRIPTDIR="$( cd -P "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPTDIR"
./cli/sc4pac server --port 51515 --web-app-dir webapp --auto-shutdown=true --launch-browser=true "$@"
