#!/bin/bash
set -e

# Script to generate terraform-docs for all stacks
# Usage: ./scripts/generate-docs.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ROOT_DIR/.terraform-docs.yml"

echo "🔍 Finding all stack directories with Terraform files..."

# Find all directories containing .tf files under stacks/
find "$ROOT_DIR/stacks" -type f -name "*.tf" | while read -r tf_file; do
    stack_dir=$(dirname "$tf_file")

    # Skip .terraform directories
    if [[ "$stack_dir" == *".terraform"* ]]; then
        continue
    fi

    # Check if README.md already exists or needs update
    if [ -f "$stack_dir/README.md" ]; then
        echo "📝 Updating docs in: $stack_dir"
    else
        echo "📄 Creating docs in: $stack_dir"
    fi

    # Generate docs
    cd "$stack_dir" && terraform-docs -c "$CONFIG_FILE" .
done

echo "✅ All documentation generated successfully!"
