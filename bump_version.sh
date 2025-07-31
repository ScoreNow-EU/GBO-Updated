#!/bin/bash

# Read current version from pubspec.yaml
current_version=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

# Split version into parts
IFS='.' read -r major minor patch <<< "$current_version"

# Increment patch version
new_patch=$((patch + 1))
new_version="$major.$minor.$new_patch"

# Update pubspec.yaml with new version (keeping build number as +1)
sed -i '' "s/version: $current_version+.*/version: $new_version+1/" pubspec.yaml

echo "Version bumped from $current_version to $new_version"
echo "Updated pubspec.yaml: version: $new_version+1" 