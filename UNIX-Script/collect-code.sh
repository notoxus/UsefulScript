#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
OUTPUT_FOLDER="$SCRIPT_DIR/collected_outputs"
mkdir -p "$OUTPUT_FOLDER"

# ── Input / output config ────────────────────────────────────
SOURCE_DIR="${1:-.}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Could not find '$SOURCE_DIR'"
  exit 1
fi

SOURCE_DIR="$(realpath "$SOURCE_DIR")"
SOURCE_BASENAME="$(basename "$SOURCE_DIR")"
CURRENT_TIME="$(date '+%Y%m%d_%H%M%S')"

if [ -n "$2" ]; then
  OUTPUT_FILE="$OUTPUT_FOLDER/$2"

  if [ -f "$OUTPUT_FILE" ]; then
    filename="${2%.*}"
    extension="${2##*.}"

    if [[ "$filename" == "$extension" ]]; then
      OUTPUT_FILE="$OUTPUT_FOLDER/${filename}_${CURRENT_TIME}"
    else
      OUTPUT_FILE="$OUTPUT_FOLDER/${filename}_${CURRENT_TIME}.${extension}"
    fi

    echo "Caution: file already exists. New name: $(basename "$OUTPUT_FILE")" >&2
  fi
else
  OUTPUT_FILE="$OUTPUT_FOLDER/${SOURCE_BASENAME}_${CURRENT_TIME}.md"
fi

# ── Source code / configuration files ────────────────────────
CODE_EXTENSIONS=(
  # Programming languages
  "py" "js" "ts" "jsx" "tsx"
  "java" "c" "cpp" "h" "hpp"
  "cs" "go" "rs" "rb" "php"
  "swift" "kt" "scala" "sh" "bash"
  "html" "css" "scss" "sass" "less"
  "sql" "r" "lua" "dart" "vue" "svelte"
  "asm" "pl" "ex" "exs" "erl" "clj"
  "luau"

  # Declarative / configuration languages
  "nix"
  "json"
  "yaml"
  "yml"
  "toml"
)

# ── Building / project configuration ─────────────────────────
CONFIG_EXACT=(
  # Gradle / Java
  "build.gradle"
  "build.gradle.kts"
  "settings.gradle"
  "settings.gradle.kts"
  "gradle.properties"
  "gradlew"
  "pom.xml"
  "build.xml"
  "ivy.xml"

  # JavaScript / TypeScript
  "package.json"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "webpack.config.js"
  "vite.config.js"
  "vite.config.ts"
  "rollup.config.js"
  "babel.config.js"
  ".babelrc"
  "jest.config.js"
  "jest.config.ts"
  "vitest.config.ts"
  "tsconfig.json"
  "jsconfig.json"
  ".eslintrc.json"
  ".eslintrc.js"
  "tailwind.config.js"
  "tailwind.config.ts"
  "postcss.config.js"

  # Python
  "pyproject.toml"
  "setup.py"
  "setup.cfg"
  "requirements.txt"
  "Pipfile"
  "Pipfile.lock"
  "tox.ini"
  "pytest.ini"
  "mypy.ini"
  ".flake8"

  # Ruby
  "Gemfile"
  "Gemfile.lock"
  "Rakefile"

  # Go
  "go.mod"
  "go.sum"

  # Rust
  "Cargo.toml"
  "Cargo.lock"

  # C# / .NET
  "*.csproj"
  "*.sln"
  "*.fsproj"
  "nuget.config"
  "Directory.Build.props"

  # Docker / containers
  "Dockerfile"
  "Containerfile"
  "docker-compose.yml"
  "docker-compose.yaml"
  "compose.yml"
  "compose.yaml"
  ".dockerignore"

  # Build / task runners
  "Makefile"
  "Justfile"

  # CI/CD
  ".gitlab-ci.yml"
  "Jenkinsfile"
  "azure-pipelines.yml"
  ".travis.yml"
  "circle.yml"

  # Server / deployment
  "nginx.conf"
  "apache.conf"
  "Procfile"

  # Infrastructure
  "*.tf"
  "*.tfvars"
  "*.k8s.yaml"
  "*.k8s.yml"

  # Nix
  "flake.lock"
)

# ── Data / documentation files ───────────────────────────────
# JSON/YAML/YML/TOML are intentionally handled as source/config above.
DATA_EXTENSIONS=(
  "txt"
  "md"
  "mdx"
  "rst"
  "csv"
  "tsv"
  "log"
  "ddl"
  "dml"
  "graphql"
  "gql"
  "proto"
)

MAX_DATA_FILE_KB="${MAX_DATA_FILE_KB:-500}"
INCLUDE_DATA="${INCLUDE_DATA:-true}"

# ── Directories to exclude ───────────────────────────────────
EXCLUDE_DIRS=(
  # Dependencies
  "node_modules"
  "vendor"

  # Version control
  ".git"

  # Python environments / caches
  "__pycache__"
  ".venv"
  "venv"
  "env"
  ".pytest_cache"
  ".mypy_cache"
  ".ruff_cache"
  ".tox"

  # Build / generated output
  "dist"
  "build"
  "target"
  "coverage"
  "htmlcov"
  ".next"
  ".nuxt"
  ".output"
  ".svelte-kit"
  ".astro"

  # Tool caches
  ".cache"
  ".gradle"
  ".terraform"
  ".terraform.d"
  ".parcel-cache"
  ".turbo"
  ".vite"

  # IDE / editor
  ".idea"
  ".vscode"
  ".fleet"
  ".zed"

  # Script output
  "$(basename "$OUTPUT_FOLDER")"
)

# ── Files to exclude ──────────────────────────────────────────
EXCLUDE_FILES=(
  # Environment / secrets
  ".env"
  ".env.local"
  ".env.development"
  ".env.production"
  ".env.test"

  # Credentials
  "credentials.json"
  "service-account.json"

  # Private keys / certificates
  "*.pem"
  "*.key"
  "*.crt"
  "*.p12"
  "*.pfx"

  # Archives
  "*.zip"
  "*.tar"
  "*.gz"
  "*.bz2"
  "*.xz"
  "*.7z"

  # Binary / media
  "*.png"
  "*.jpg"
  "*.jpeg"
  "*.gif"
  "*.ico"
  "*.mp3"
  "*.wav"
  "*.ogg"
  "*.mp4"
  "*.mkv"
  "*.webm"
)

# ── Build find exclusion arguments ────────────────────────────
EXCLUDE_ARGS=( \( )

for dir in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDE_ARGS+=(-name "$dir" -o)
done

unset 'EXCLUDE_ARGS[-1]'
EXCLUDE_ARGS+=( \) -prune -o )

# ── Build file exclusion arguments ────────────────────────────
EXCLUDE_FILE_ARGS=()

for pattern in "${EXCLUDE_FILES[@]}"; do
  EXCLUDE_FILE_ARGS+=(! -iname "$pattern")
done

# ── Track already collected files ────────────────────────────
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

# ── Append a file to output ──────────────────────────────────
append_file() {
  local file="$1"
  local label="${2:-}"
  local rel="${file#$SOURCE_DIR/}"
  rel="${rel#/}"

  local lines
  lines=$(awk 'END{print NR}' "$file" 2>/dev/null || echo 0)

  {
    echo "### File: $rel"
    echo '```'
    sed 's/\r$//' "$file" 2>/dev/null
    echo '```'
    echo ""
  } >> "$OUTPUT_FILE"

  echo "  ✔ $rel ($lines lines)${label:+  [$label]}" >&2
  echo "$lines"
}

# ── Initialize output ────────────────────────────────────────
{
  echo "# PROJECT SOURCE CODE"
  echo "- **Source**: $SOURCE_DIR"
  echo "- **Generated**: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "---"
  echo ""
} > "$OUTPUT_FILE"

FILE_COUNT=0
TOTAL_LINES=0

add_lines() {
  local l
  l=$(echo "$1" | tr -d ' ')
  TOTAL_LINES=$((TOTAL_LINES + l))
  FILE_COUNT=$((FILE_COUNT + 1))
}

# ── SOURCE CODE ──────────────────────────────────────────────
echo ""
echo "[1/3] Collecting source code from $SOURCE_DIR..."

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
done < <(
  find "$SOURCE_DIR" \
    "${EXCLUDE_ARGS[@]}" \
    -type f \
    "${EXCLUDE_FILE_ARGS[@]}" \
    \( "${CODE_EXT_ARGS[@]}" \) \
    -print0 2>/dev/null |
    sort -z
)

# ── BUILD / PROJECT CONFIG ───────────────────────────────────
echo "[2/3] Collecting build/project files..."

CONFIG_ARGS=()

for pattern in "${CONFIG_EXACT[@]}"; do
  CONFIG_ARGS+=(-iname "$pattern" -o)
done

unset 'CONFIG_ARGS[-1]'

echo -e "BUILDING / PROJECT FILES\n" >> "$OUTPUT_FILE"

while IFS= read -r -d '' file; do
  [[ "$(realpath "$file")" == "$(realpath "$OUTPUT_FILE")" ]] && continue
  already_seen "$file" && continue

  mark_seen "$file"
  add_lines "$(append_file "$file" "config")"
done < <(
  find "$SOURCE_DIR" \
    "${EXCLUDE_ARGS[@]}" \
    -type f \
    "${EXCLUDE_FILE_ARGS[@]}" \
    \( "${CONFIG_ARGS[@]}" \) \
    -print0 2>/dev/null |
    sort -z
)

# ── DATA / DOCUMENTATION ─────────────────────────────────────
if [ "$INCLUDE_DATA" = "true" ]; then
  echo ""
  echo "[3/3] Collecting data/documentation files..."

  DATA_EXT_ARGS=()

  for ext in "${DATA_EXTENSIONS[@]}"; do
    DATA_EXT_ARGS+=(-iname "*.${ext}" -o)
  done

  unset 'DATA_EXT_ARGS[-1]'

  echo -e "DATA / DOCUMENTATION FILES\n" >> "$OUTPUT_FILE"

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
  done < <(
    find "$SOURCE_DIR" \
      "${EXCLUDE_ARGS[@]}" \
      -type f \
      "${EXCLUDE_FILE_ARGS[@]}" \
      \( "${DATA_EXT_ARGS[@]}" \) \
      -print0 2>/dev/null |
      sort -z
  )
fi

# ── Summary ──────────────────────────────────────────────────
{
  echo "---"
  echo "### SUMMARY"
  echo "- **Total Files**: $FILE_COUNT"
  echo "- **Total Lines**: $TOTAL_LINES"
} >> "$OUTPUT_FILE"

echo ""
echo "Done!"
echo "Output: $OUTPUT_FILE"
echo "Files:  $FILE_COUNT"
echo "Lines:  $TOTAL_LINES"
