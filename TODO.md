# 自動部首変換の禁止設定

`中心→患` のように、部首変換したいが自動では使いたくない語を、「自動変換しない組み合わせ」として学習できるようにしたい

- bushu_auto.dicのエントリとして `中心N` のように書くと、その組合せは自動変換禁止の意味とする
    - 合成後のフィールドが `N` の場合に禁止設定とする

- 自動変換禁止エントリはPendingKakuteiの受容では上書きせず、禁止のままを保存する

- 自動変換禁止の組合せであることをbushu_auto.dicに追加するキーストロークを実装する
    - PendingKakuteiモードのときに `-` キーを入力すると、その組合せを禁止する
        - すでにautoDictにエントリがある場合
            - 禁止設定でなければ禁止設定にする
            - 禁止設定であれば何もしない
        - ない場合
            - 禁止設定を追加する
        - このキー `-` は設定項目のbushu.disableAutoKeysで指定する(複数指定可)
    - PendingKakuteiモードのときに `+` キーを入力すると、禁止設定を解除し、自動設定を追加する
        - すでにautoDictにエントリがある場合
            - 禁止設定を解除する
        - その後、通常の受容処理を行う
        - このキー `+` は設定項目のbushu.addAutoKeysで指定する(複数指定可)

## 実装方針

- tryAutoBushuで、resultが `"N"` の場合は変換しない
- PendingKakuteiModeでの禁止設定編集コマンドはinputEventTypeが.printableである場合にtextの内容で判定する(PendingKakuteiModeはキーマップを持たないため)
    - PendingKakuteiModeに渡すonAcceptに引数を追加して、InputEventを受けとれるようにする
    - PendingKakuteiMode.handleからaccept経由でイベントをonAcceptに渡す
- 部首変換のonAcceptではこのイベントを見て、上記の禁止設定/自動設定の処理を行う
- 交ぜ書き変換のonAcceptでは引数のイベントを無視する
