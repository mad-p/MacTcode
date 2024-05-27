#!/bin/bash
set -e
# ビルド
xcodebuild -workspace MacTcode.xcodeproj/project.xcworkspace -scheme MacTcode clean archive -archivePath build/archive.xcarchive
# 上書き
sudo rm -rf /Library/Input\ Methods/MacTcode.app
sudo cp -r build/archive.xcarchive/Products/Applications/MacTcode.app /Library/Input\ Methods/
# 再起動
pkill "MacTcode"
