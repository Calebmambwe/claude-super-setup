#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Error: No directory path provided." >&2
  echo "Usage: $0 <directory>" >&2
  exit 1
fi

dir="$1"

if [[ ! -d "$dir" ]]; then
  echo "Error: '$dir' does not exist or is not a directory." >&2
  exit 1
fi

archive="logs-$(date +%Y%m%d).tar.gz"

mapfile -t files < <(find "$dir" -maxdepth 1 -name '*.log' -type f -mtime -7)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .log files modified in the last 7 days found in '$dir'."
  exit 0
fi

tar -czf "$archive" "${files[@]}"

echo "Archived ${#files[@]} file(s) into $archive"
