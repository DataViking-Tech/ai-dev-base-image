#!/usr/bin/env bash
set -euo pipefail

create_directories_from_file() {
  local workspace_root=$1
  local directory_file=$2

  while read -r dir; do
    [[ -n "$dir" ]] || continue
    [[ -d "$dir" ]] || mkdir -p "$dir"
  done < "$directory_file"

  echo "  ✔ Project directories created"
}
