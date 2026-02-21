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

# 特定のテストのみ実行する場合
xcodebuild -project MacTcode.xcodeproj -scheme MacTcode -destination 'platform=macOS' test -only-testing:MacTcodeTests/BushuTests
xcodebuild -project MacTcode.xcodeproj -scheme MacTcode -destination 'platform=macOS' test -only-testing:MacTcodeTests/ContextClientTests/testDeleteMarked
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
- 例: `TcodeMode`, `ZenkakuMode`, `MazegakiSelectionMode`, `LineMode`

**Controller** (モード管理):
- `TcodeInputController`が`IMKInputController`を継承
- モードスタックで状態遷移を管理
- `pushMode()`/`popMode()`で一時的なモード切替

**Client** (テキスト入出力):
- `ContextClient`: カーソル周辺のテキスト取得（複雑なロジック）
- `RecentTextClient`: クライアントが文脈を提供できない場合のフォールバック
- `LineClient`: 1行モード用のクライアント、バッファにテキストを蓄積して一気に送信
- 読み取得の順序: 選択範囲 → クライアント → ミラー

### キーマップシステム

入力フロー: `キーイベント → KeymapResolver → Command → Action`

- **KeymapResolver**: キーシーケンスを解決し、Commandに変換
- **Command**: `.passthrough`, `.processed`, `.pending`, `.text(String)`, `.action(Action)`, `.keymap(Keymap)`
- **Action**: 実際の処理（部首変換、交ぜ書き変換など）

### 変換エンジン

**部首変換 (Bushu)**:
- `Bushu.swift`: tc-bushu.elアルゴリズムの再実装、自動学習データ管理
- 2文字の組み合わせから1文字を合成
- 部品単位の合成、引き算（部品の削除）をサポート
- `autoDict`: 自動部首変換学習データ（受容された変換結果を記録）
- `tryAutoBushu()`: 文字入力後に自動変換を試行

**交ぜ書き変換 (Mazegaki)**:
- `MazegakiDict.swift`: 辞書ファイル読み込み、MRU学習データ管理
- `Mazegaki.swift`: 読み取得と変換候補の検索
- `MazegakiSelectionMode.swift`: 候補選択UI
- `MazegakiHit.swift`: 変換候補、MRU学習優先の候補取得

### 学習機能とキャンセル期間

**PendingKakutei** (変換キャンセル機構):
- 変換確定後、`cancelPeriod`秒間（デフォルト1.5秒）キャンセル可能
- Delete、Control-g、Escapeキーでキャンセルして読みに戻せる
- キャンセルされなかった変換は「受容」され、学習データに反映
- `Controller`プロトコルの`pendingKakutei`プロパティで管理
- `onAccepted`コールバック: `(_ parameter: Any?, _ inputEvent: InputEvent?) -> HandleResult`
  - 部首変換: `-`/`+`キー処理時は`.processed`を返してイベント消費、それ以外は`.forward`
  - 交ぜ書き変換: 常に`.forward`を返してイベント転送

**交ぜ書き候補MRU学習**:
- 選択された候補を先頭に移動（MRU: Most Recently Used）
- `MazegakiDict.mruDict`で学習データを管理（元辞書は不変）
- `MazegakiHit.candidates()`はMRU辞書を優先的に参照
- `mazegaki_user.dic`に自動保存（統計データと同じタイミング）
- 設定: `mazegaki.mruEnabled`, `mazegaki.mruFile`

**自動部首変換**:
- 手動部首変換で受容された結果を学習し、次回から自動的に変換
- `Bushu.autoDict`で学習データを管理（キー: 合成元2文字、値: 合成結果1文字 or "N"）
- `TcodeMode.handle()`で文字入力後に`tryAutoBushu()`を実行
- 順序厳密: "木林"で学習したものは"林木"では自動変換されない
- 自動変換もキャンセル可能（受容時は学習データ更新なし）
- `bushu_auto.dic`に自動保存（統計データと同じタイミング）
- 設定: `bushu.autoEnabled`, `bushu.autoFile`, `bushu.disableAutoKeys`, `bushu.addAutoKeys`
- **禁止設定**: キャンセル期間内に`-`キーで自動変換を禁止、`+`キーで禁止解除（値が"N"のエントリは自動変換されない）

### 設定管理

`UserConfigs.i`（シングルトン）が5つの設定カテゴリを管理:
1. **MazegakiConfig**: 交ぜ書き変換設定、MRU学習設定
2. **BushuConfig**: 部首変換設定、自動部首変換学習設定
3. **KeyBindingsConfig**: キーバインド、基本文字配列（40x40）
4. **UIConfig**: 候補選択キー、記号セット
5. **SystemConfig**: 除外アプリ、ログ、統計同期間隔、キャンセル期間

設定変更は`UserConfigsDelegate`プロトコルで通知。

### 統計管理

`InputStats.i`（シングルトン）:
- スレッドセーフ（DispatchQueueで排他制御）
- 基本文字、部首変換、交ぜ書き変換、機能実行をカウント
- 定期的に`tc-record.txt`に出力（デフォルト1200秒間隔）

### このセッションで行った変更（要約・2026-02-21）

以下はこの作業セッションで実装／追加した内容の短いサマリです。将来の解析やデバッグ時に参照してください。

- InputStats の拡張
  - ストローク（T‑Code基本キー）単位の頻度統計を追加しました。
  - 追加メソッド: `recordStroke(key:)`, `recordNonStrokeEvent()`, `resetStrokeStats()`, `writeStrokeStatsToFile()`, `loadStrokeStatsMaybe()`。
  - 内部データ構造: `keyCount[40]`, `basicCharCount[1600]`, `bigram[1600]`, `panes`, `alternation`。
  - 書き出しは既存の統計同期タイミング（`tc-record.txt` と同時）で行います。累積保存です（リセットしない）。

- 設定変更
  - 新しい設定フラグを追加: `system.strokeStatsEnabled`（デフォルト: `true`）。
  - このフラグが `false` の場合、ストローク統計の収集および `stroke-stats.json` の読み書きは行われません。

- 記録フックと連続性ルール
  - 記録は Option A（実際に basic と判定された箇所）を採用し、`TcodeMode` の `.text` 分岐で `Translator.strToKey` が 0..39 を返す文字を `recordStroke` で記録します。
  - 連続性を断つ（バイグラムを切る）イベント: 部首/交ぜ書き受容、機能実行、モード切替、候補確定、PendingKakutei の受容、非基本キー入力など。

- コードの主な変更箇所
  - `MacTcode/InputStats.swift` — ストローク統計実装
  - `MacTcode/UserConfigs.swift` — `strokeStatsEnabled` を追加（デフォルト true）
  - `MacTcode/Tcode/TcodeMode.swift` — `.text` 分岐で `recordStroke` 呼び出し
  - `MacTcode/Tcode/TcodeInputController.swift` — push/pop/deactivate/candidateSelected で `recordNonStrokeEvent` 呼び出し
  - `MacTcode/Mode/PendingKakuteiMode.swift` — accept() で連続性断ち

- テストとドキュメント
  - 単体テスト追加: `MacTcodeTests/StrokeStatsTests.swift`（ストローク記録、連続性切断、無効化挙動の検証）
  - ドキュメント追加／更新:
    - `STROKE_STATS.md`：`stroke-stats.json` のフォーマット仕様
    - `README.md`：統計セクションにストローク統計の説明追記
    - `ConfigParams.md`：`system.strokeStatsEnabled` の説明追記

重要: これら変更は既存のビルドとテストスイートで検証済み（Debug ビルド成功、ユニットテスト実行成功）。

必要に応じて、`STROKE_STATS.md` に記載した JSON を読み取る解析スクリプト（Python など）を追加できます。希望があれば実装します。

## 重要なパターン

1. **プロトコル指向**: `Mode`, `Controller`, `Client`などで責務を明確化
2. **シングルトン**: `UserConfigs.i`, `InputStats.i`, `MazegakiDict.i`, `Bushu.i`
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
| `MazegakiDict.swift` | 交ぜ書き辞書、MRU学習データ |
| `PendingKakutei.swift` | 変換キャンセル機構 |
| `InputStats.swift` | 統計管理 |
| `LineMode.swift` | 1行入力モード（バッファに蓄積して一気に送信） |

## テスト

テストは`MacTcodeTests/`に配置。最大規模のテストは`ContextClientTests.swift`（19253行）。

```bash
make test    # すべてのテストを実行
```

## 開発状況

完了した機能:
- ✅ 基本文字入力、部首変換、交ぜ書き変換
- ✅ キャンセル期間機能（PendingKakutei）
- ✅ 交ぜ書き候補MRU学習
- ✅ 自動部首変換機能（禁止設定含む）
- ✅ 全角入力モード
- ✅ 1行入力モード（LineMode）
- ✅ 統計記録機能
- ✅ SIGINTハンドリング（統計・学習データの同期）

詳細は`TODO.md`および`README.md`を参照。

## 重要な実装詳細

### HandleResult型
- `.processed`: イベントを消費（次のモードに渡さない）
- `.forward`: イベントを次のモードに転送
- `.passthrough`: すべてのモードをスルーしてアプリケーションに渡す

### イベントフロー
Mode.handle()の返り値として`HandleResult`を返すことで、入力イベントの制御を行う。
PendingKakuteiMode経由での学習データ操作（`-`/`+`キー）では`.processed`を返してイベントを消費し、意図しない文字入力を防ぐ。
