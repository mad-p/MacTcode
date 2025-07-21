## 完了済みタスク

1. [x] **クラス再配置**
    - [x] swiftファイルひとつにクラスひとつが対応するように修正
        - Mazegaki.swift（14個の型）→ 6ファイルに分割
        - MacTcodeApp.swift（2個の型）→ 2ファイルに分割  
        - Bushu.swift（2個の型）→ 2ファイルに分割
        - TcodeKeymap.swift（2個の型）→ 2ファイルに分割
    - [x] `make test`でテスト実行可能にMakefile更新
    - [x] 全テスト通過確認（45テスト成功）

2. [x] **コンフィグファイル機能を追加**
    - [x] ソースコード内にハードコーディングされている設定情報をリストアップ
        - [x] ConfigParams.md に記入
        - [x] 40+項目の設定値を特定・分類
        - [x] 設定ファイル化の優先度評価
        - [x] TCode基文文字マップ(40x40配列)を追加
        - [x] 読み取得無視テキスト(アプリ固有判定文字列)を追加
    - [x] config.jsonのサーチパスを決定
        - [x] `~/Library/Application Support/MacTcode/config.json`
    - [x] 設定ファイル構造の設計
        - [x] JSON形式で5カテゴリ構成(mazegaki, bushu, keyBindings, ui, system)
        - [x] basicTableを40個の文字列配列として定義
    - [x] コンフィグ情報を保存するクラス UserConfigs を作成
        - [x] 5つの設定カテゴリ構造体定義(MazegakiConfig, BushuConfig, KeyBindingsConfig, UIConfig, SystemConfig)
        - [x] シングルトンパターンでアクセス管理
        - [x] Codableプロトコル対応でJSON形式の保存・読み込み
        - [x] デフォルト値の完全定義
    - [x] コンフィグ情報の読み込み機能を実装
        - [x] 設定妥当性検証機能(ConfigValidationError)
        - [x] 外部ファイルからの読み込み機能
        - [x] 設定変更通知システム(UserConfigsDelegate)
        - [x] エラーハンドリングとフォールバック機能
        - [x] 設定状態管理機能
    - [x] ソースコード内各所からコンフィグ情報を参照するように修正
        - [x] Mazegaki.swift の設定参照修正
        - [x] TcodeKeymap.swift の基文文字マップ参照修正
        - [x] ContextClient.swift の設定参照修正
        - [x] RecentTextClient.swift の設定参照修正
        - [x] TcodeInputController.swift の設定参照修正（候補選択キー・除外アプリ）
        - [x] Bushu.swift の設定参照修正
        - [x] Log.swift の設定参照修正

## 残りタスク

3. **設定ファイル完成**
    - [ ] サンプル config.json ファイルの生成
    - [ ] ビルド・テスト確認
    - [ ] 動作確認
