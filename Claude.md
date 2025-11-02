# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

- ユーザーへは日本語で応答してください

## プロジェクト概要

MacTcodeは、macOS用のT-Code日本語入力メソッド（IME）です。T-Codeは2ストロークで日本語文字を入力する効率的な入力方式で、部首変換や交ぜ書き変換などの機能を提供します。

## ビルドとテスト

### 開発サイクル
```bash
make reload          # デバッグビルド→インストール→入力メソッド再起動
make releaseBuild    # リリースビルド
make test            # テスト実行
```

### ログの確認
設定ファイルで`"logEnabled": true`を設定後、以下で確認:
```bash
log stream --predicate 'process == "MacTcode"'
```

### 設定ファイルの場所
```
~/Library/Containers/jp.mad-p.inputmethod.MacTcode/Data/Library/Application Support/MacTcode/config.json
```

## コアアーキテクチャ

### 三角関係: Mode - Controller - Client

**Mode** (入力状態):
- `handle()`: 入力イベントを処理
- 例: `TcodeMode`, `ZenkakuMode`, `MazegakiSelectionMode`

**Controller** (モード管理):
- `TcodeInputController`が`IMKInputController`を継承
- モードスタックで状態遷移を管理
- `pushMode()`/`popMode()`で一時的なモード切替

**Client** (テキスト入出力):
- `ContextClient`: カーソル周辺のテキスト取得（複雑なロジック）
- `RecentTextClient`: クライアントが文脈を提供できない場合のフォールバック
- 読み取得の順序: 選択範囲 → クライアント → ミラー

### キーマップシステム

入力フロー: `キーイベント → KeymapResolver → Command → Action`

- **KeymapResolver**: キーシーケンスを解決し、Commandに変換
- **Command**: `.passthrough`, `.processed`, `.pending`, `.text(String)`, `.action(Action)`, `.keymap(Keymap)`
- **Action**: 実際の処理（部首変換、交ぜ書き変換など）

### 変換エンジン

**部首変換 (Bushu)**:
- `Bushu.swift`: tc-bushu.elアルゴリズムの再実装
- 2文字の組み合わせから1文字を合成
- 部品単位の合成、引き算（部品の削除）をサポート

**交ぜ書き変換 (Mazegaki)**:
- `MazegakiDict.swift`: 辞書ファイル読み込み、LRU学習データ管理
- `Mazegaki.swift`: 読み取得と変換候補の検索
- `MazegakiSelectionMode.swift`: 候補選択UI
- `MazegakiHit.swift`: 変換候補、LRU学習優先の候補取得

### 学習機能とキャンセル期間

**PendingKakutei** (変換キャンセル機構):
- 変換確定後、`cancelPeriod`秒間（デフォルト1.5秒）キャンセル可能
- Delete、Control-g、Escapeキーでキャンセルして読みに戻せる
- キャンセルされなかった変換は「受容」され、学習データに反映
- `Controller`プロトコルの`pendingKakutei`プロパティで管理

**交ぜ書き候補LRU学習**:
- 選択された候補を先頭に移動（LRU: Least Recently Used）
- `MazegakiDict.lruDict`で学習データを管理（元辞書は不変）
- `MazegakiHit.candidates()`はLRU辞書を優先的に参照
- `mazegaki_user.dic`に自動保存（統計データと同じタイミング）
- 設定: `mazegaki.lruEnabled`, `mazegaki.lruFile`

**自動部首変換**（未実装、将来用）:
- 設定: `bushu.autoEnabled`, `bushu.autoFile`

### 設定管理

`UserConfigs.shared`（シングルトン）が5つの設定カテゴリを管理:
1. **MazegakiConfig**: 交ぜ書き変換設定、LRU学習設定
2. **BushuConfig**: 部首変換設定、自動学習設定（将来用）
3. **KeyBindingsConfig**: キーバインド、基本文字配列（40x40）
4. **UIConfig**: 候補選択キー、記号セット
5. **SystemConfig**: 除外アプリ、ログ、統計同期間隔、キャンセル期間

設定変更は`UserConfigsDelegate`プロトコルで通知。

### 統計管理

`InputStats.shared`（シングルトン）:
- スレッドセーフ（DispatchQueueで排他制御）
- 基本文字、部首変換、交ぜ書き変換、機能実行をカウント
- 定期的に`tc-record.txt`に出力（デフォルト1200秒間隔）

## 重要なパターン

1. **プロトコル指向**: `Mode`, `Controller`, `Client`などで責務を明確化
2. **シングルトン**: `UserConfigs.shared`, `InputStats.shared`, `MazegakiDict.i`, `Bushu.i`
3. **モードスタック**: 候補選択などのサブモードを一時的にプッシュ
4. **フォールバック**: クライアント → ミラーの順で読み取得、設定不正時はデフォルトで動作

## 主要ファイル

| ファイル | 役割 |
|---------|------|
| `AppDelegate.swift` | IMKServer初期化、シグナルハンドラ、統計保存 |
| `TcodeInputController.swift` | 入力制御の中核、モードスタック管理 |
| `TcodeMode.swift` | 基本T-Code入力モード |
| `KeymapResolver.swift` | キーシーケンス解決エンジン |
| `ContextClient.swift` | テキスト読み取りの複雑なロジック |
| `UserConfigs.swift` | 設定管理システム |
| `Bushu.swift` | 部首変換アルゴリズム |
| `MazegakiDict.swift` | 交ぜ書き辞書、LRU学習データ |
| `PendingKakutei.swift` | 変換キャンセル機構 |
| `InputStats.swift` | 統計管理 |

## テスト

テストは`MacTcodeTests/`に配置。最大規模のテストは`ContextClientTests.swift`（19253行）。

```bash
make test    # すべてのテストを実行
```

## 開発状況

完了した機能:
- ✅ キャンセル期間機能（PendingKakutei）
- ✅ 交ぜ書き候補LRU学習

未実装の機能（`TODO.md`参照）:
- ⏳ 自動部首変換機能
