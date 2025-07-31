#!/bin/bash

# Read current version from pubspec.yaml
current_version=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

# Split version into parts
IFS='.' read -r major minor patch <<< "$current_version"

# Increment minor version, reset patch to 0
new_minor=$((minor + 1))
new_version="$major.$new_minor.0"

# Update pubspec.yaml with new version (keeping build number as +1)
sed -i '' "s/version: $current_version+.*/version: $new_version+1/" pubspec.yaml

echo "Minor version bumped from $current_version to $new_version"
echo "Updated pubspec.yaml: version: $new_version+1" 