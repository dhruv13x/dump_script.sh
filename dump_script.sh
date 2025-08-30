#!/bin/bash

# ===========================
# Project Code Dump Utility (Final Production-Ready v9.1 RED)
# ===========================
# Notes:
#  - Default: create dump + .sha256 + append to checksums_index.txt
#  - --bundle / --archive: create ONE zip that contains all older dumps (and their .sha256)
#    exactly as separate files (no per-dump nested archives). After success, those source
#    dumps are removed so the next archive is incremental ("last zip stays separate").
#  - All previous features preserved.
# ===========================

set -euo pipefail

# Flags
FORCE=false
QUIET=false
COMPRESS=false
NO_TOC=false
OUTFILE=""
EXCLUDES=()
BUNDLE=false   # explicit bundling flag (off by default)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
  cat <<-USAGE
Usage: $0 [--force|-y] [--quiet|-q] [--no-toc] [--compress] [--bundle|--archive] [--output FILE] [--exclude PATTERNS] [--help|-h]

Options:
  --force, -y        Skip confirmation prompt (non-interactive)
  --quiet, -q        Skip preview & confirmation (CI mode)
  --no-toc           Skip TOC generation (faster CI runs)
  --compress         Gzip final dump (.md.gz)
  --bundle           Bundle older dumps into ONE zip (incremental)
  --archive          Alias for --bundle (compatibility)
  --output FILE      Specify custom output filename
  --exclude PATTERNS Comma-separated list of exclude patterns (globs)
  --help,  -h        Show this help message
USAGE
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-y) FORCE=true ;;
    --quiet|-q) QUIET=true; FORCE=true ;;
    --compress) COMPRESS=true ;;
    --no-toc) NO_TOC=true ;;
    --bundle|--archive) BUNDLE=true ;;
    --output) OUTFILE="${2:-}"; shift ;;
    --exclude) IFS=',' read -r -a EXCLUDES <<< "${2:-}"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo -e "${RED}❌ Unknown option: $1${NC}"; usage; exit 1 ;;
  esac
  shift
done

# Basic context
foldername=$(basename "$(pwd)")
timestamp=$(date '+%d.%m.%Y_%H.%M.%S')

# Output filename (default or custom)
if [[ -z "${OUTFILE}" ]]; then
  outfile="${foldername}_all_code_dump_${timestamp}.md"
else
  outfile="${OUTFILE}"
fi

# Prevent accidental overwrite
if [[ -e "$outfile" ]]; then
  echo -e "${YELLOW}⚠️ File $outfile already exists. Appending random suffix...${NC}"
  outfile="${outfile%.*}_$RANDOM.${outfile##*.}"
fi

# Slugify helper
slugify() {
  echo "$1" \
    | sed 's|^\./||' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g;s/^-+|-+$//g'
}

# Build find command (base)
find_cmd=(find . \
  \( -name "*.py" -o -name "*.sh" -o -name "*.ini" -o -name "*.txt" -o -name "*.md" \
     -o -name ".flake8" -o -name "*.yml" -o -name "*.yaml" -o -name "*.toml" \
     -o -name "*.cfg" -o -name "*.json" -o -name "Dockerfile" \) \
  ! -name "__init__.py" \
  ! -name "dump_script.sh" \
  ! -name "*.log" \
  ! -name "*.pem" \
  ! -name "*.db" \
  ! -name "*.sqlite" \
  ! -path "*/__pycache__/*" \
  ! -path "*/.git/*" \
  ! -path "*/.venv/*" \
  ! -path "*/myenv/*" \
  ! -path "*/.mypy_cache/*" \
  ! -path "*/.pytest_cache/*" \
  ! -path "*/.idea/*" \
  ! -name "*.pyc" \
  ! -name ".env" \
  ! -name "${foldername}_all_code_dump_*.md" \
  ! -name "${foldername}_all_code_dump_*.md.sha256" \
  ! -name "${foldername}_all_code_dump_*.md.gz" \
  ! -name "${foldername}_all_code_dump_*.md.gz.sha256" \
)

# Apply user excludes (if any)
for pattern in "${EXCLUDES[@]:-}"; do
  find_cmd+=( ! -path "$pattern" ! -name "$pattern" )
done
find_cmd+=( -print0 )

# Collect files to include in dump
mapfile -d '' files < <("${find_cmd[@]}" | LC_ALL=C sort -z)

# Nothing to dump?
if [[ ${#files[@]} -eq 0 ]]; then
  echo -e "${YELLOW}⚠️ No matching files found. Exiting.${NC}"
  exit 0
fi

# Preview (unless quiet)
if [[ "$QUIET" == false ]]; then
  echo "📄 The following files will be included in the dump:"
  printf '%s\n' "${files[@]#./}"
  echo
fi

# Confirm unless forced
if [[ "$FORCE" == false ]]; then
  read -p "❓ Proceed with combining these files into $outfile? (y/n): " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    echo -e "${RED}❌ Operation cancelled.${NC}"
    exit 1
  fi
fi

# Write header / TOC
{
  echo "# 🗃️ Combined Project Source & Config Dump"
  echo "**Generated on:** $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
  echo "---"
  echo
  if [[ "$NO_TOC" == false ]]; then
    echo "## 📚 Table of Contents"
  fi
} > "$outfile"

# TOC lines (if enabled)
if [[ "$NO_TOC" == false ]]; then
  index=1
  for file in "${files[@]}"; do
    clean_file="${file#./}"
    anchor=$(slugify "$clean_file")
    echo "$index. [$clean_file](#${anchor})" >> "$outfile"
    index=$((index + 1))
  done
  printf "\n---\n\n" >> "$outfile"
fi

# Append file contents
for file in "${files[@]}"; do
  clean_file="${file#./}"
  anchor=$(slugify "$clean_file")

  # Detect language for code fences
  lang=""
  if [[ "$(basename "$file")" == "Dockerfile" ]]; then
    lang="dockerfile"
  else
    ext="${file##*.}"
    case "$ext" in
      py) lang="python" ;;
      sh) lang="bash" ;;
      yml|yaml) lang="yaml" ;;
      ini) lang="ini" ;;
      txt) lang="text" ;;
      md) lang="markdown" ;;
      json) lang="json" ;;
      toml) lang="toml" ;;
      cfg) lang="ini" ;;
    esac
  fi

  {
    echo "## 📄 $clean_file"
    echo "<a id=\"$anchor\"></a>"
    echo
    echo '```'"$lang"
    cat "$file"
    echo '```'
    echo
    echo "---"
    echo
  } >> "$outfile"
done

# Optionally compress the dump (if requested)
if [[ "$COMPRESS" == true ]]; then
  gzip -9 -f "$outfile"
  outfile="${outfile}.gz"
  echo -e "${GREEN}✅ All files saved and compressed to: $outfile${NC}"
else
  echo -e "${GREEN}✅ All files saved to: $outfile${NC}"
fi

# --- Checksums (sha256) ---
checksum=""
if command -v sha256sum >/dev/null 2>&1; then
  checksum=$(sha256sum "$outfile")
elif command -v shasum >/dev/null 2>&1; then
  checksum=$(shasum -a 256 "$outfile")
else
  echo -e "${YELLOW}⚠️ No sha256 tool found; skipping checksum.${NC}"
fi

if [[ -n "$checksum" ]]; then
  echo "$checksum"
  # write sidecar beside the dump (works for .md or .md.gz)
  echo "$checksum" > "${outfile}.sha256"
  # append to global ledger
  echo "$checksum" >> checksums_index.txt
fi

# --- Explicit bundling: ONE ZIP containing individual dumps (incremental) ---
if [[ "$BUNDLE" == true ]]; then
  if ! command -v zip >/dev/null 2>&1; then
    echo -e "${RED}❌ 'zip' not found. Please install zip (e.g., apt-get install zip) to use --archive.${NC}"
    exit 1
  fi

  mkdir -p archives
  bundle_name="archives/dumps_bundle_${timestamp}.zip"

  shopt -s nullglob
  prefix="${foldername}_all_code_dump_"
  to_bundle=()

  # collect dumps (.md and .md.gz) and their .sha256, excluding the current dump (+ sidecar)
  for f in ${prefix}*.md ${prefix}*.md.gz; do
    [[ "$(basename "$f")" == "$(basename "$outfile")" ]] && continue
    [[ "$(basename "$f")" == "$(basename "$outfile").sha256" ]] && continue

    to_bundle+=("$f")
    [[ -e "$f.sha256" ]] && to_bundle+=("$f.sha256")
  done
  shopt -u nullglob

  if [[ ${#to_bundle[@]} -gt 0 ]]; then
    # -n: store already-compressed files without re-compressing (.gz, .zip, .tgz, .xz, .bz2)
    if zip -q -n .gz:.zip:.tgz:.xz:.bz2 "$bundle_name" -- "${to_bundle[@]}"; then
      # Remove the originals so the next archive run is incremental
      rm -f -- "${to_bundle[@]}"
      echo -e "${GREEN}📦 Created archive: $bundle_name${NC}"
      echo -e "${GREEN}🧹 Removed ${#to_bundle[@]} bundled file(s) from workspace (incremental archiving).${NC}"
    else
      echo -e "${RED}❌ Bundling failed. Files were NOT deleted.${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}ℹ️ No older dumps found to archive.${NC}"
  fi
fi

# Done
exit 0