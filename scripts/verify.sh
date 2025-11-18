#!/bin/bash
echo "🔍 Verifying template setup..."
ESSENTIAL_FILES=(
    "README.md"
    ".github/workflows/ci.yml"
    ".github/CODEOWNERS"
    "scripts/setup.sh"
    "scripts/test.sh"
    "docs/CONTRIBUTING.md"
    "docs/DEVELOPMENT.md"
)
for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
    fi
done
SCRIPTS=("setup.sh" "test.sh" "lint.sh" "dev.sh" "release.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -x "scripts/$script" ]; then
        echo "✅ scripts/$script (executable)"
    else
        echo "❌ scripts/$script - NOT EXECUTABLE"
    fi
done
echo "🎉 Template verification complete!"
