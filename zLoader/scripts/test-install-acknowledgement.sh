#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/prepare-patched-idevice.sh test
