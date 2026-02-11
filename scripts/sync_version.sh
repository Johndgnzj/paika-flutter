#!/bin/bash
# 從 pubspec.yaml 讀取版本號並同步到 web/index.html

# 讀取版本號
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')

# 更新 index.html
sed -i '' "s/<meta name=\"version\" content=\".*\">/<meta name=\"version\" content=\"$VERSION\">/" web/index.html

echo "Version synced: $VERSION"
