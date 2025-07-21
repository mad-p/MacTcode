# MacTcode ハードコーディング設定調査結果

## 概要
MacTcodeのソースコード内でハードコーディングされている設定情報をリストアップし、設定ファイル化の優先度を評価します。

## ハードコーディングされた設定一覧

### 数値設定

#### 閾値・上限値
- **maxInflection**: 4 (Mazegaki.swift:15)
  - 説明: 活用部分の最大長
  - 優先度: **高** - 言語や用途により調整が必要

- **maxYomi**: 10 (Mazegaki.swift:122) 
  - 説明: 読みの最大長さ（PostfixMazegakiAction）
  - 優先度: **高** - 辞書や使用場面により変更したい

- **maxLength**: 20 (RecentTextClient.swift:12)
  - 説明: 最近のテキストの最大保存長
  - 優先度: **高** - メモリ使用量とパフォーマンスのバランス調整

- **nKeys**: 40 (Keymap.swift:10)
  - 説明: キーマップの総キー数
  - 優先度: 低 - 基本的にレイアウト固定

#### タイミング・遅延値
- **バックスペース遅延**: 0.05秒 (ContextClient.swift:183)
  - 説明: BackSpace送信の間隔
  - 優先度: **高** - アプリケーションの応答性により調整が必要

- **バックスペース制限**: 10文字 (ContextClient.swift:179)
  - 説明: バックスペースで削除可能な最大文字数
  - 優先度: 中 - 安全性とユーザビリティのバランス

- **読み取得無視テキスト**: 複数のアプリ固有文字列 (ContextClient.swift:141-145)
  - 説明: アプリケーションによって読みが正しく取得できない場合の判定文字列
  - 値: ["\u{200b}", "_", "\n\n", "xt left)\n\n", "──────╯\n\n\n"]
  - 優先度: **高** - 新しいアプリでの動作不良時に追加・修正が必要

#### 文字コード範囲
- **inflectionCharsMin**: 0x3041 (Mazegaki.swift:16)
- **inflectionCharsMax**: 0x30fe (Mazegaki.swift:17)
  - 説明: 活用部分の文字コード範囲（ひらがな・カタカナ）
  - 優先度: 低 - 日本語固有の仕様

### 文字列設定

#### ファイルパス・リソース名
- **辞書ファイル**: "mazegaki.dic" (MazegakiDict.swift:19)
- **部首辞書ファイル**: "bushu.dic" (Bushu.swift:26)
  - 説明: 辞書ファイル名
  - 優先度: 中 - 異なる辞書セットの使用

#### キーマップテーブル
- **TCode基文文字マップ**: 40x40の文字配列 (TcodeKeymap.swift:12-53)
  - 説明: TCode入力における基本的な文字配置マップ（1600文字のテーブル）
  - 優先度: **高** - ユーザーのカスタムキーマップ、他の配列への対応

#### 特殊文字・記号
- **活用マーク**: "—" (MazegakiDict.swift:14)
  - 説明: 辞書内の活用マークを表す文字
  - 優先度: 低 - 辞書フォーマット固有

- **非読み文字**: ["、", "。", "，", "．", "・", "「", "」", "（", "）"] (Mazegaki.swift:19-20)
  - 説明: 読み部分に許されない句読点等
  - 優先度: **中** - 文書の種類により変更したい場合

#### UI文字列・メッセージ
- **全角変換テーブル**: ASCII→全角文字マッピング (ZenkakuMode.swift:13)
  - 説明: 全角変換の文字対応表
  - 優先度: 低 - 標準的な変換規則

- **除外アプリ**: ["com.apple.loginwindow", "com.apple.SecurityAgent"] (TcodeInputController.swift:59)
  - 説明: 処理対象外のアプリケーション
  - 優先度: **中** - セキュリティ要件や使用環境により追加・削除

### キーシーケンス設定

#### 機能呼び出しキー
- **部首変換**: "hu" (TcodeKeymap.swift:54)
- **交ぜ書き変換**: "uh" (TcodeKeymap.swift:55)
- **活用変換**: "58" (TcodeKeymap.swift:56)
- **全角モード**: "90" (TcodeKeymap.swift:61)
- **記号入力1**: "\\" (TcodeKeymap.swift:62)
- **記号入力2**: "\\\\" (TcodeKeymap.swift:64)
  - 説明: 各機能の起動キーシーケンス
  - 優先度: **高** - ユーザーの好みや他のキーバインドとの競合回避

#### 選択キー配列
- **候補選択キー**: 右手ホーム位置4キー + 数字1-0 (TcodeInputController.swift:32-43)
  - 説明: 候補選択のキー配列
  - 優先度: **中** - キーボードレイアウトやユーザー習慣により変更

### その他設定

#### 候補表示設定
- **候補パネルタイプ**: kIMKSingleRowSteppingCandidatePanel (AppDelegate.swift:19)
- **候補スタイル**: kIMKMain (AppDelegate.swift:19)
  - 説明: 候補ウィンドウの表示形式
  - 優先度: 中 - UI preferences

#### デバッグ・ログ設定
- **ログ有効化**: ENABLE_NSLOG フラグ (Log.swift:13)
  - 説明: NSLogの出力制御
  - 優先度: 中 - デバッグ用途

## 設定ファイル化の推奨優先度

### 🔴 最高優先度（必須）
1. **Mazegaki.maxInflection** (4) - 活用部分の最大長
2. **PostfixMazegakiAction.maxYomi** (10) - 読みの最大長
3. **キーシーケンス設定** - 各機能の起動キー
4. **バックスペース遅延時間** (0.05秒) - 応答性調整
5. **読み取得無視テキスト** - アプリ固有の判定文字列（新しいアプリ対応時に必須）

### 🟡 高優先度（推奨）
1. **TCode基文文字マップ** - ユーザーカスタムキーマップ対応
2. **RecentTextClient.maxLength** (20) - 最近のテキスト保存長
3. **候補選択キー配列** - 候補選択キーのカスタマイズ
4. **除外アプリケーション一覧** - セキュリティ設定

### 🟢 中優先度（オプション）
1. **非読み文字配列** - 句読点の扱い
2. **辞書ファイル名** - 異なる辞書セットの使用
3. **バックスペース制限** (10文字) - 安全性設定

## 提案する設定ファイル構造

```json
{
  "mazegaki": {
    "maxInflection": 4,
    "maxYomi": 10,
    "nonYomiCharacters": ["、", "。", "，", "．", "・", "「", "」", "（", "）"],
    "dictionaryFile": "mazegaki.dic"
  },
  "bushu": {
    "dictionaryFile": "bushu.dic"
  },
  "keyBindings": {
    "bushuConversion": "hu",
    "mazegakiConversion": "uh", 
    "inflectionConversion": "58",
    "zenkakuMode": "90",
    "symbolSet1": "\\",
    "symbolSet2": "\\\\",
    "basicTable": [
      "■■■■■■■■■■ヮヰヱヵヶ請境系探象ゎゐゑ■■盛革突温捕■■■■■依繊借須訳",
      "■■■■■■■■■■丑臼宴縁曳尚賀岸責漁於汚乙穏■益援周域荒■■■■■織父枚乱香",
      "■■■■■■■…■■鬼虚狭脅驚舎喜幹丘糖奇既菊却享康徒景処ぜ■■■■■譲ヘ模降走",
      "■■■■■■■←■■孤誇黄后耕布苦圧恵固巧克懇困昏邦舞雑漢緊■■■■■激干彦均又",
      "[...残り36行の40文字文字列配列...]"
    ]
  },
  "ui": {
    "candidateSelectionKeys": ["j", "k", "l", ";", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
    "backspaceDelay": 0.05,
    "backspaceLimit": 10,
    "yomiIgnoreTexts": ["\u{200b}", "_", "\n\n", "xt left)\n\n", "──────╯\n\n\n"]
  },
  "system": {
    "recentTextMaxLength": 20,
    "excludedApplications": ["com.apple.loginwindow", "com.apple.SecurityAgent"],
    "logEnabled": true
  }
}
```

### 設定ファイル構造の特徴

- **basicTable**: 40行×40文字の配列として定義
  - 各行は40文字の文字列
  - 配列のインデックスが行位置、文字列の位置が列位置に対応
  - ユーザーは特定の行や文字のみを変更可能

この設定ファイル構造により、ユーザーは再コンパイルなしで主要な動作をカスタマイズできるようになります。特にbasicTableの配列形式により、部分的な配列変更や他の配列との組み合わせが容易になります。