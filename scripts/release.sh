#!/bin/bash
echo "🚀 Creating release..."
VERSION=$(date +%Y.%m.%d)
TAG="v$VERSION"
git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"
gh release create "$TAG" --title "Release $TAG" --notes "Automated release $TAG"
echo "✅ Release $TAG created!"
