# キーマップ定義方法の改善

## 現在のキーマップ定義

* config.json内でkeyBindings.basicTableとして2Dマップを指定
* 以下のキーに対し、特定のactionを設定(buildTcodeKeymapメソッド内にハードコード)
    * bushuConversion(hu): PostfixBushuAction()
    * inflectionConversion(58): PostfixMazegakiAction(inflection: true)
    * mazegakiConversion(uh): PostfixMazegakiAction(inflection: false)
    * zenkakuMode(90): ZenkakuModeAction()
    * lineMode(88): ToggleLineModeAction()

## 課題

これらの処理は、一部がハードコーディングされており、わかりにくい。以下の問題点がある
* キー入力列の設定値がUserConfig内のフィールドとして定義されている
    * 新しいアクションを導入するとき、キーバインディングの設定項目を追加する必要がある
    * ConfigParams.md, sample-config.jsonも整合するように修正しなければならない
* 2Dマップを読み込んでから、一部を上書きする方法で作られていて、逐次処理的である。宣言的に結果だけを書きたい
* その他にもキーバインディングがハードコードされており、設定値の書き方が難しい
    * symbolSet1, symbolSet2
    * zenkakuOneMode
    * directMode
    * SelfInsertAndDirectMode (キーバインディングもハードコードされていて設定項目がない)

## 解決案

### 案1: 2Dマップの記述を拡張する

* 2Dマップ内の2打鍵に対応する位置にアクションを対応づけるコード文字を書くと、Keymap(_ name, from2d:)の中でアクションを設定する
    * 「コード文字」としてはT-Codeマップに出現しなさそうな文字、英大小文字などを想定
    * b=PostfixBushuAction(), m=PostfixMazegakiAction(inflection: false)などと対応させる
    * コード文字とアクションの対応は別途ハードコードする(解決するメソッドを新規作成)
* メリット
    * 2Dマップの対応する位置に「m」などを書くため、マップの中での位置がわかりやすい
    * bushuConversionなどの設定項目が必要なくなる
* デメリット
    * 2Dマップ外の文字を使うアクション(ZenkakuOneModeActionなど)の記述には適用できない
    * mからアクションにマップする方法が結局ハードコーディングになってしまう
    * KeymapとTcodeKeymapの責任分担の分離がわかりにくくなる

### 案2: キーマップを記述するためのDSLを作る

* 初期Emacsのmock-lispやvimrcのような、何らかのDSLを導入してキーバインディングを設定する
* メリット
    * 設定ファイルを読んだときにわかりやすい
* デメリット
    * 設定が宣言的にならず、プログラム的な逐次処理になってしまう点は変わらない
    * アクションの生成を文字で記述しなければならず、 `PostfixMazegakiAction(inflection: false)` というアクションに対応するラベル `PostfixMazegakiNoInflection` のようなものを導入し、変換する仕組みが必要
    * 設定ファイル全体はJSONになっており、mock-lispやvimrcのようなDSLと親和性が低い。DSLを文字列配列として書くなどで逃げられるか
    * 設定ファイルの書式エラーのハンドリングが必要

## 検討事項

これらの解決案のメリット・デメリットを考慮し、どちらがユーザーにとって使いやすいかを論じてください。また、よりよい別の解決案があるか考えてください。
まだ実装計画や実装には着手せず、解決案の評価だけを提示してください。
