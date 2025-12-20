# 特定のアプリではダミーのinsertTextを実行

第1打鍵が入力を発生しないときに、そのストロークが表示されてしまうアプリがある(KeePassX、JetBrainsのIDE等)。
第1打鍵がpendingになり、かつIMKInputController.handle内でIMKInputText.insertTextが一度も呼ばれなかった場合、ダミーのinputTextを行う。

## 追加仕様

- config.jsonに対象となるアプリのbundle_idを設定できるようにする
- ダミーinsertText方式としてNUL文字1文字を送る方法と空文字列を送る方法を用意し、configではbundle_idに対して選べるようにする
    - 例: `com.google.android.studio` に対し `nul` を設定、 `org.keepassx.keepassx` に対し `empty` を設定

## 実装方針

- ClientWrapper内でinsertTextが呼ばれたかどうかのフラグを管理する。コンストラクタでfalseを設定
- ClientWrapperにsendDummyInsertMaybe()を用意し、insertTextが呼ばれていない場合にダミーのinsertTextを呼ぶ
- ContextClientではsendDummyInsertMaybe()をclientにforwardする
- TcodeMode.handle()で、.pendingの処理時に、sendDummyInsertMaybe()を呼ぶ
