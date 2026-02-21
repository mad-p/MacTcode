# stroke-stats.json 仕様

目的

- T‑Code の基本キーに関する詳細な頻度統計を累積保存するためのファイル仕様。
- ファイル名: `stroke-stats.json`
- 保存場所: `UserConfigs.i.configFileURL("stroke-stats.json")`（`tc-record.txt` と同じディレクトリ）

書式概要

- ファイル形式: UTF-8 の JSON オブジェクト
- 累積形式（既存のカウントに追記するのではなく、累積値を上書きで保存）

主要フィールド

- `keyCount`: 整数配列（長さ 40）
  - インデックス 0..39 が各 T‑Code 基本キーに対応
  - 値はそのキー単体の使用回数（累積）

- `basicCharCount`: 整数配列（長さ 1600 = 40 * 40）
  - インデックスは `first * 40 + second`（first, second は 0..39）
  - 値は「基本文字」単位（1打目と2打目の組合せ）の出現頻度

- `bigram`: 整数配列（長さ 1600 = 40 * 40）
  - インデックスは `first * 40 + second`
  - 値はキーのバイグラム（連続した2キー）の出現頻度
  - 注意: 実装では `basicCharCount` と `bigram` は用途に応じて使い分け可能（両方保存されます）

- `panes`: オブジェクト
  - キー: `"RL"`, `"RR"`, `"LL"`, `"LR"`
  - 値: 各左右ペイン組合せの出現回数
  - 左右判定: キー番号の10進下1桁を用いる。下1桁が 0..4 → `L`、5..9 → `R`。
    例: key 7 の下1桁は 7 → `R`。

- `alternation`: オブジェクト
  - フィールド:
    - `"alternate"`: 直前キーと左右が異なる（交互打鍵）回数
    - `"consecutive"`: 直前キーと左右が同じ（連続打鍵）回数
    - `"first"`: 連続性がない状態での第1打目としての回数（シーケンス開始）

- `lastUpdated`: 文字列（ISO8601 形式）
  - ファイルを最終更新した日時。

インデックス計算例

- 2 打の組合せで first=2, second=7 の場合の配列インデックス:

  ```text
  idx = 2 * 40 + 7 = 87
  ```

連続性（バイグラム計算）についてのルール

- バイグラム／交互打鍵の "連続" と見なすのは、同じ入力シーケンス内で連続する T‑Code 基本キー（0..39）だけです。
- 以下のイベントは "連続性を断つ" とみなし、次の基本キーは `first` としてカウントされます:
  - 部首変換の適用（`InputStats.i.incrementBushuCount()` が呼ばれた場合）
  - 交ぜ書き変換の適用（`incrementMazegakiCount()`）
  - 機能実行（モード切替やアクション、`incrementFunctionCount()`）
  - モードの push/pop
  - 候補の確定（`candidateSelected`）や PendingKakutei の受容
  - printable でも `Translator.strToKey` が 0..39 を返さないキー（T‑Code 基本外の入力）

書き出しタイミング

- 既存の `tc-record.txt` と同じタイミングで保存されます。具体的には:
  - `InputStats.writeStatsToFile()` の実行時（`writeStatsToFileMaybe()` により `syncStatsInterval` 間隔で実行される）
  - `deactivateServer(_:)` などの終了／切替時
- 設定 `system.syncStatsInterval` が 0 の場合は自動出力は抑止されます（手動で `writeStrokeStatsToFile()` を呼べば書き出せます）。

設定による制御

- `system.strokeStatsEnabled` (boolean, デフォルト: `true`)
  - `false` にすると、ストロークに関する集計（`recordStroke`, `recordNonStrokeEvent` の効果）および `stroke-stats.json` の読み書きが行われません。

ファイルの例（抜粋）

```json
{
  "keyCount": [0, 1, 3, 0, 0, 2, ...],
  "basicCharCount": [0, 0, ..., 0],
  "bigram": [0, 0, 1, 0, ...],
  "panes": {"RL": 12, "RR": 34, "LL": 21, "LR": 15},
  "alternation": {"alternate": 120, "consecutive": 80, "first": 200},
  "lastUpdated": "2026-02-21T15:00:00Z"
}
```

注意事項 / 実装メモ

- 配列の長さは固定（`keyCount`=40、`basicCharCount`/`bigram`=1600）なので、パーサーは長さチェックを行ってください。
- JSON にコメントは入れられないため、実データは純粋な配列とオブジェクトで構成されます。上の例は可読性のため省略記法を使っています。
- `basicCharCount` と `bigram` は用途により重複する情報を持つことがあり得ます（実装や将来の解析目的に応じて片方のみを参照しても構いません）。
- 大量にカウントが増える可能性があるため、解析ツール側で型（Int の範囲）や桁数の取り扱いに注意してください（必要に応じて 64-bit 整数で扱うこと）。

解析のヒント（簡易）

- Python で読み込む場合のサンプル（簡易）:

```python
import json
with open('stroke-stats.json', 'r', encoding='utf-8') as f:
    s = json.load(f)
key_count = s['keyCount']
bigram = s['bigram']
# first=2, second=7 の頻度
idx = 2 * 40 + 7
print('bigram[2,7] =', bigram[idx])
```

更新履歴

- 2026-02-21: 初版（STROKE_STATS.md）

