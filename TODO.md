- [x] Translator.swiftで定義しているlayoutはDvorak配列になっている。これを例えばQWERTYにも変更できるように、設定項目に追加する
    - [x] SystemConfigにkeyboardLayoutとkeyboardLayoutMappingを追加
    - [x] Translator.swiftをUserConfigs参照に変更
    - [x] sample-config.jsonにキーボードレイアウト設定を追加
    - [x] ConfigParams.mdにQWERTY配列の例とレイアウト説明を追加

## キーボードレイアウト対応完了
- Dvorak配列（デフォルト）とQWERTY配列の切り替え対応
- 設定ファイルでキーマッピングを完全にカスタマイズ可能
- ユーザーガイドでの詳細な設定方法説明
- 全47テストが正常実行される状態を維持
