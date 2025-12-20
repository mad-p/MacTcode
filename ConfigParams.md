# MacTcode 設定ファイルガイド

## 概要
MacTcodeは`config.json`形式の設定ファイルを使用してカスタマイズできます。このガイドでは、設定可能な項目と設定方法について説明します。

## 設定ファイルの場所
設定ファイルは以下の順序で検索されます：

1. `~/Library/Containers/jp.mad-p.inputmethod.MacTcode/Data/Library/Application Support/MacTcode/config.json` (ユーザー設定)
2. アプリケーション内の`config.json` (デフォルト設定)

## 設定ファイルの構造

設定ファイルは以下の5つのカテゴリに分かれています：

```json
{
  "mazegaki": { /* 交ぜ書き変換設定 */ },
  "bushu": { /* 部首変換設定 */ },
  "keyBindings": { /* キーバインド設定 */ },
  "ui": { /* ユーザーインターフェース設定 */ },
  "system": { /* システム動作設定 */ }
}
```

## 設定項目詳細

### 1. 交ぜ書き変換設定 (`mazegaki`)

```json
"mazegaki": {
  "maxInflection": 4,
  "maxYomi": 10,
  "mazegakiYomiCharacters": "々ー\\p{Hiragana}\\p{Katakana}\\p{Han}",
  "dictionaryFile": "mazegaki.dic",
  "mruEnabled": false,
  "mruFile": "mazegaki_user.dic"
}
```

- **`maxInflection`**: 活用部分の最大文字数（1-10）
- **`maxYomi`**: 読みの最大文字数（1-50）
- **`mazegakiYomiCharacters`**: 交ぜ書き変換で読み部分に含める文字の正規表現文字クラス記法
- **`dictionaryFile`**: 交ぜ書き変換辞書のファイル名
- **`mruEnabled`**: MRU（Most Recently Used）学習機能の有効/無効
  - `true`の場合、選択した候補が次回から優先的に表示されます
  - 学習データは`mruFile`で指定したファイルに保存されます
- **`mruFile`**: MRU学習データのファイル名
  - Application Support/MacTcode ディレクトリに自動保存されます

### 2. 部首変換設定 (`bushu`)

```json
"bushu": {
  "bushuYomiCharacters": "0-9()、。「」・\\p{Hiragana}\\p{Katakana}\\p{Han}",
  "dictionaryFile": "bushu.dic",
  "autoEnabled": false,
  "autoFile": "bushu_auto.dic",
  "disableAutoKeys": ["-"],
  "addAutoKeys": ["+"]
}
```

- **`bushuYomiCharacters`**: 部首変換で部品取得に含める文字の正規表現文字クラス記法
- **`dictionaryFile`**: 部首変換辞書のファイル名
- **`autoEnabled`**: 部首変換自動学習機能の有効/無効
- **`autoFile`**: 部首変換自動学習データのファイル名
- **`disableAutoKeys`**: 自動部首変換を禁止設定にするキーのリスト
  - 手動部首変換後のキャンセル期間内にこのキーを入力すると、その組み合わせが自動変換禁止リストに追加されます
  - 例: "中心→患"を手動変換後に`-`キーを入力すると、次回から"中心"は自動変換されなくなります
  - 複数のキーを指定可能です
- **`addAutoKeys`**: 禁止設定を解除して自動設定を追加するキーのリスト
  - 手動部首変換後のキャンセル期間内にこのキーを入力すると、禁止設定が解除され自動変換が有効になります
  - 例: 禁止設定済みの"中心"を手動変換後に`+`キーを入力すると、次回から自動変換されるようになります
  - 複数のキーを指定可能です

### 3. キーバインド設定 (`keyBindings`)

```json
"keyBindings": {
  "bushuConversion": "hu",
  "mazegakiConversion": "uh",
  "inflectionConversion": "58",
  "zenkakuMode": "90",
  "lineMode": "88",
  "symbolSet1": "\\",
  "symbolSet2": "\\\\",
  "basicTable": [
    "■■■■■■■■■■ヮヰヱヵヶ請境系探象ゎゐゑ■■盛革突温捕■■■■■依繊借須訳",
    "（40行の文字列配列...）"
  ]
}
```

- **`bushuConversion`**: 部首変換を開始するキーシーケンス
- **`mazegakiConversion`**: 交ぜ書き変換を開始するキーシーケンス
- **`inflectionConversion`**: 活用変換を開始するキーシーケンス
- **`zenkakuMode`**: 全角入力モードを開始するキーシーケンス
- **`lineMode`**: 行入力モードを開始するキーシーケンス
- **`symbolSet1`**, **`symbolSet2`**: 記号入力セットのキーシーケンス
- **`basicTable`**: T-Code基本文字配列（40行×40文字）
- キーシーケンスの設定置には、入力される文字を指定してください。上記の `hu`、`uh` はDvorak配列の場合の例となります
- バックスラッシュやダブルクォートはエスケープしてください

### 4. ユーザーインターフェース設定 (`ui`)

```json
"ui": {
  "candidateSelectionKeys": ["j", "k", "l", ";", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
  "backspaceDelay": 0.05,
  "backspaceLimit": 10,
  "symbolSet1Chars": "√∂『』　“《》【】┏┳┓┃◎◆■●▲▼┣╋┫━　◇□○△▽┗┻┛／＼※§¶†‡",
  "symbolSet2Chars": "♠♡♢♣㌧㊤㊥㊦㊧㊨㉖㉗㉘㉙㉚⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳①②③④⑤㉑㉒㉓㉔㉕⑥⑦⑧⑨⑩"
}
```

- **`candidateSelectionKeys`**: 変換候補を選択するキーのリスト（使用可能な文字は下記参照）
- **`backspaceDelay`**: バックスペース送信の遅延時間（秒、0.01-1.0）
- **`backspaceLimit`**: バックスペースで削除可能な最大文字数（1-100）
- **`symbolSet1Chars`**: 記号入力セット1の文字列
- **`symbolSet2Chars`**: 記号入力セット2の文字列

### 5. システム動作設定 (`system`)

```json
"system": {
  "recentTextMaxLength": 20,
  "excludedApplications": ["com.apple.loginwindow", "com.apple.SecurityAgent"],
  "disableOneYomiApplications": ["com.google.Chrome"],
  "dummyInsertTextApps": {
    "com.google.android.studio": "nul"
  },
  "syncStatsInterval": 1200,
  "cancelPeriod": 1.5,
  "keyboardLayout": "dvorak",
  "keyboardLayoutMapping": [
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    "'", ",", ".", "p", "y", "f", "g", "c", "r", "l",
    "a", "o", "e", "u", "i", "d", "h", "t", "n", "s",
    ";", "q", "j", "k", "x", "b", "m", "w", "v", "z"
  ],
  "logEnabled": false
}
```

- **`recentTextMaxLength`**: 最近入力したテキストの保存最大文字数（1-100）
- **`excludedApplications`**: T-Code処理を無効化するアプリケーションのBundle IDリスト
- **`disableOneYomiApplications`**: 1文字の読みを無効化するアプリケーションのBundle IDリスト
  - Google Chrome上のGoogle Docsなど、一部のアプリケーションでは読みが1文字しか取れず、変換が正しく動作しない場合があります
  - このリストに含まれるアプリケーションでは、最低2文字の読みが必要になる代わりに、この問題を回避できます
- **`dummyInsertTextApps`**: 第1打鍵でダミーのinsertTextを送信するアプリケーションの設定（オブジェクト）
  - 一部のアプリケーション（KeePassX、JetBrains IDE、Android Studio等）では、第1打鍵がpending状態になった際にinsertTextが呼ばれず、ストロークが画面に表示されてしまう問題があります
  - このオブジェクトに含まれるアプリケーションでは、pending状態時にダミーのinsertTextを送信して問題を回避します
  - キー: アプリケーションのBundle ID（例: "com.google.android.studio"）
  - 値: ダミー文字の種類
    - `"nul"`: NUL文字（\0）を送信
    - `"empty"`: 空文字列（""）を送信
  - 例: `{"com.google.android.studio": "nul", "com.jetbrains.intellij": "nul"}`
- **`syncStatsInterval`**: 統計情報をファイルに出力する間隔（秒単位）
  - デフォルト値: 1200（20分）
  - 0に設定すると統計ファイルの出力が無効になります
  - 統計情報は入力メソッド切り替え時やアプリケーション終了時に自動的に保存されます
  - 詳細はREADME.mdの「統計情報の記録」セクションを参照してください
- **`cancelPeriod`**: 変換確定後のキャンセル可能期間（秒、0.1-10.0）
  - 変換確定後、この期間内であればDeleteキーやControl-g、Escapeキーで変換をキャンセルして読みに戻すことができます
  - デフォルト値: 1.5秒
  - 部首変換自動学習機能、MRU学習機能が有効な場合、この期間経過時に学習データが更新されます
- **`keyboardLayout`**: キーボードレイアウトの名前（"dvorak", "qwerty"等）
- **`keyboardLayoutMapping`**: 40個のキー配列マッピング（文字列配列）
- **`logEnabled`**: デバッグログの出力有効/無効

## 設定ファイルのセットアップ

### 1. サンプル設定ファイルをコピー

```bash
# ディレクトリを作成
# MacTcodeを一度起動するとディレクトリが作られます

# サンプル設定ファイルをコピー
cp sample-config.json ~/Library/Containers/jp.mad-p.inputmethod.MacTcode/Data/Library/Application\ Support/MacTcode/config.json
```

### 2. 設定を編集

テキストエディタで`config.json`を開いて必要な項目を変更してください。

### 3. T-Code基本文字配列のカスタマイズ

`basicTable`は40行×40文字の配列です。各行は40文字の文字列として定義されています：

```json
"basicTable": [
  "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほ",
  "（39行続く...）"
]
```

特定の文字のみを変更したい場合は、対応する行と位置の文字を変更してください。

## よくある設定例

### キーバインドの変更
```json
"keyBindings": {
  "bushuConversion": "fg",
  "mazegakiConversion": "gf"
}
```

### 候補選択キーの変更
```json
"ui": {
  "candidateSelectionKeys": ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"]
}
```

#### 候補選択キーで使用可能な文字

候補選択キー（`candidateSelectionKeys`）には以下の文字を使用できます：

**アルファベット**（小文字）
```
a b c d e f g h i j k l m n o p q r s t u v w x y z
```

**数字**
```
0 1 2 3 4 5 6 7 8 9
```

**記号**
```
-  =  [  ]  '  ;  ,  .  /
```

**注意事項**
- 大文字のアルファベット（A-Z）は使用できません
- バックスラッシュ（\）やその他の記号は現在サポートされていません
- 文字は、キーの物理的な位置を表わすため、keyboardLayoutの設定に関わりなく、QWERTY配列で書いてください
- 同じキーを重複して指定しないでください
- キーの順序が候補の番号に対応します（最初のキーが1番目の候補）

### キーボードレイアウトの変更

デフォルトはDvorak配列ですが、QWERTY配列に変更することも可能です：

```json
"system": {
  "keyboardLayout": "qwerty",
  "keyboardLayoutMapping": [
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
    "a", "s", "d", "f", "g", "h", "j", "k", "l", ";",
    "z", "x", "c", "v", "b", "n", "m", ",", ".", "/"
  ]
}
```

#### キーボードレイアウトについて

- **`keyboardLayout`**: レイアウト名（識別用）
- **`keyboardLayoutMapping`**: 40個のキー配列
  - 配列の順序は行ごとに左から右へ（4行×10列）
  - 1行目: 数字行（1-9, 0）
  - 2-4行目: 文字行（キーボードの上から下へ）

### バックスペース動作の調整
```json
"ui": {
  "backspaceDelay": 0.1,
  "backspaceLimit": 5
}
```

## 設定反映について

設定ファイルを変更した場合は、MacTcodeを再起動してください。将来のバージョンでは設定の動的リロード機能が追加予定です。

```bash
pkill MacTcode
# MacTcodeを起動
```

## トラブルシューティング

- 設定ファイルの書式が正しくない場合、デフォルト設定で動作します
- ログを有効にして問題を特定できます（`"logEnabled": true`）
    - ログを読むには以下のコマンドが便利です
    - ```bash
      log stream --predicate 'process == "MacTcode"'
      ```
- 設定に問題がある場合は、サンプル設定ファイルから再度コピーしてください
