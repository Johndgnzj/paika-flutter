#!/bin/bash
# Paika 自動部署腳本

set -e

echo "🀄 開始部署 Paika..."

# 1. 清理舊檔案
echo "🧹 清理舊檔案..."
flutter clean

# 2. 安裝依賴
echo "📦 安裝依賴..."
flutter pub get

# 3. 編譯 Web 版本
echo "🔨 編譯 Web 版本..."
flutter build web --release

# 4. 部署到 Firebase
echo "🚀 部署到 Firebase..."
firebase deploy --only hosting

echo "✅ 部署完成！"
echo "🌐 網址：https://paika.web.app"
