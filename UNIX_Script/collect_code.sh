#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
OUTPUT_FOLDER="$SCRIPT_DIR/collected_outputs"
mkdir -p "$OUTPUT_FOLDER"

# --- Input, output config ---
SOURCE_DIR="${1:-.}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Could not find '$SOURCE_DIR'"
  exit 1
fi

SOURCE_BASENAME=$(basename "$(realpath "$SOURCE_DIR")")
CURRENT_TIME=$(date '+%Y%m%d_%H%M%S')

if [ -n "$2" ]; then
  OUTPUT_FILE="$OUTPUT_FOLDER/$2"
else
  OUTPUT_FILE="$OUTPUT_FOLDER/${SOURCE_BASENAME}_${CURRENT_TIME}.txt"
fi

# ── Source code files ──────────────────────────────────────
CODE_EXTENSIONS=(
  "py" "js" "ts" "jsx" "tsx"
  "java" "c" "cpp" "h" "hpp"
  "cs" "go" "rs" "rb" "php"
  "swift" "kt" "scala" "sh" "bash"
  "html" "css" "scss" "sass" "less"
  "sql" "r" "lua" "dart" "vue" "svelte"
  "asm" "pl" "ex" "exs" "erl" "clj"
)

# ── Building/Project config files ─────────────────────────
CONFIG_EXACT=(
  "build.gradle" "build.gradle.kts" "settings.gradle" "settings.gradle.kts" "gradle.properties" "gradlew" "pom.xml" "build.xml" "ivy.xml"
  "package.json" "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "webpack.config.js" "vite.config.js" "vite.config.ts" "rollup.config.js" "babel.config.js" ".babelrc" "jest.config.js" "jest.config.ts" "vitest.config.ts" "tsconfig.json" "jsconfig.json" ".eslintrc.json" ".eslintrc.js" "tailwind.config.js" "tailwind.config.ts" "postcss.config.js"
  "pyproject.toml" "setup.py" "setup.cfg" "requirements.txt" "Pipfile" "Pipfile.lock" "tox.ini" "pytest.ini" "mypy.ini" ".flake8"
  "Gemfile" "Gemfile.lock" "Rakefile"
  "go.mod" "go.sum"
  "Cargo.toml" "Cargo.lock"
  "*.csproj" "*.sln" "*.fsproj" "nuget.config" "Directory.Build.props"
  "Dockerfile" "docker-compose.yml" "docker-compose.yaml" ".dockerignore" "Makefile" "Justfile" ".gitlab-ci.yml" "Jenkinsfile" "azure-pipelines.yml" ".travis.yml" "circle.yml" "nginx.conf" "apache.conf" "Procfile"
  "*.tf" "*.tfvars" "*.k8s.yaml" "*.k8s.yml"
)

DATA_EXTENSIONS=(
  "json" "yaml" "yml" "toml" "ini" "cfg" "conf" "xml" "plist" "properties"
  "txt" "md" "rst" "csv" "tsv" "log"
  "sql" "ddl" "dml"
  "graphql" "gql" "proto"
)

MAX_DATA_FILE_KB="${MAX_DATA_FILE_KB:-500}"   # Maximum is 500 KB
INCLUDE_DATA="${INCLUDE_DATA:-true}"

EXCLUDE_DIRS=(
  "node_modules" ".git" "__pycache__"
  ".venv" "venv" "env" "dist" "build"
  ".next" ".nuxt" "target" "vendor"
  ".idea" ".vscode"
  "$(basename "$OUTPUT_FOLDER")"
)

# --- Exception dir ---
EXCLUDE_ARGS=( \( )
for dir in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDE_ARGS+=(-name "$dir" -o)
done
unset 'EXCLUDE_ARGS[-1]'
EXCLUDE_ARGS+=( \) -prune -o )

declare -A SEEN_FILES

already_seen() {
  local rp
  rp="$(realpath "$1" 2>/dev/null)" || return 1
  [[ -n "${SEEN_FILES[$rp]:-}" ]]
}

mark_seen() {
  local rp
  rp="$(realpath "$1" 2>/dev/null)" || return
  SEEN_FILES["$rp"]=1
}

append_file() {
  local file="$1"
  local label="${2:-}"
  local rel="${file#$SOURCE_DIR/}"
  rel="${rel#/}" 
  
  local lines
  lines=$(awk 'END{print NR}' "$file" 2>/dev/null || echo 0)

  {
    echo "################################################################"
    [ -n "$label" ] && echo "# [$label]"
    echo "# FILE : $rel"
    echo "# LINES: $lines"
    cat "$file" 2>/dev/null
    echo ""
  } >> "$OUTPUT_FILE"

  echo "  ✔ $rel ($lines lines)${label:+  [$label]}" >&2
  echo "$lines"
}

{
  echo "================================================================"
  echo "  SOURCE   : $(realpath "$SOURCE_DIR")"
  echo "  GENERATED: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "================================================================"
  echo ""
} > "$OUTPUT_FILE"

FILE_COUNT=0
TOTAL_LINES=0

add_lines() { 
  # Remove redundant space
  local l=$(echo "$1" | tr -d ' ') 
  TOTAL_LINES=$((TOTAL_LINES + l))
  FILE_COUNT=$((FILE_COUNT + 1))
}

# SOURCE CODE
echo ""
echo "[1/3] Collecting from $(realpath "$SOURCE_DIR")..."

CODE_EXT_ARGS=()
for ext in "${CODE_EXTENSIONS[@]}"; do
  CODE_EXT_ARGS+=(-iname "*.${ext}" -o)
done
unset 'CODE_EXT_ARGS[-1]'

echo -e "SOURCE CODE\n" >> "$OUTPUT_FILE"

while IFS= read -r -d '' file; do
  [[ "$(realpath "$file")" == "$(realpath "$OUTPUT_FILE")" ]] && continue
  already_seen "$file" && continue
  mark_seen "$file"
  add_lines "$(append_file "$file" "code")"
done < <(find "$SOURCE_DIR" "${EXCLUDE_ARGS[@]}" -type f \( "${CODE_EXT_ARGS[@]}" \) -print0 2>/dev/null | sort -z)

# BUILDING/PROJECT CONFIG FILES
echo "[2/3] Collecting build/project files..."

CONFIG_ARGS=()
for pattern in "${CONFIG_EXACT[@]}"; do
  CONFIG_ARGS+=(-iname "$pattern" -o)
done
unset 'CONFIG_ARGS[-1]'

echo -e "BUILDING/PROJECT FILES\n" >> "$OUTPUT_FILE"

while IFS= read -r -d '' file; do
  [[ "$(realpath "$file")" == "$(realpath "$OUTPUT_FILE")" ]] && continue
  already_seen "$file" && continue
  mark_seen "$file"
  add_lines "$(append_file "$file" "config")"
done < <(find "$SOURCE_DIR" "${EXCLUDE_ARGS[@]}" -type f \( "${CONFIG_ARGS[@]}" \) -print0 2>/dev/null | sort -z)

# DATA / DATABASE FILES
# ══════════════════════════════════════════════════════════════
if [ "$INCLUDE_DATA" = "true" ]; then
  echo ""
  echo "[3/3] Collecting database files..."

  DATA_EXT_ARGS=()
  for ext in "${DATA_EXTENSIONS[@]}"; do
    DATA_EXT_ARGS+=(-iname "*.${ext}" -o)
  done
  unset 'DATA_EXT_ARGS[-1]'

  echo -e "DATABASE FILES\n" >> "$OUTPUT_FILE"

  while IFS= read -r -d '' file; do
    [[ "$(realpath "$file")" == "$(realpath "$OUTPUT_FILE")" ]] && continue
    already_seen "$file" && continue

    file_kb=$(du -k "$file" 2>/dev/null | cut -f1)
    if [ "${file_kb:-0}" -gt "$MAX_DATA_FILE_KB" ]; then
      echo "  ⚠ SKIPPED (${file_kb} KB > ${MAX_DATA_FILE_KB} KB limit): ${file#$SOURCE_DIR/}" >&2
      continue
    fi

    mark_seen "$file"
    add_lines "$(append_file "$file" "data")"
  done < <(find "$SOURCE_DIR" "${EXCLUDE_ARGS[@]}" -type f \( "${DATA_EXT_ARGS[@]}" \) -print0 2>/dev/null | sort -z)
fi

# --- Summary ---
{
  echo "################################################################"
  echo "# File count: $FILE_COUNT"
  echo "# Total lines: $TOTAL_LINES"
  echo "# Time  : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "################################################################"
} >> "$OUTPUT_FILE"