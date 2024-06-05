# MacTcode

## デモ

![](mactcode-demo.gif)

## 動機

macOS用のT-Codeが使えるIMとして[MacUIM](https://github.com/e-kato/macuim)を使っていましたが、永らく更新されていません。
ソースコードは公開されているものの、自分でビルドするのは成功していません。saryとかの用意が難しく…(Ruby 1.9.3をSonomaに入れるとか難しい)。

そこで、単純なT-Codeだけのドライバなら作っちゃえばいいんじゃね? ということで始めました。

## 実装したい機能

おおむね優先度順
- [x] 基本文字の入力
- [x] postfix部首変換
- [x] postfix交ぜ書き変換
    - [ ] 変換候補選択画面
- [x] 全角入力モード (1.4.1)
- [ ] 3ストローク以上の基本文字サポート
- [ ] 1行入力(T-Code変換をしつつバッファにため、一気に入力するモード)
- [ ] configファイルサポート
- [ ] メニュー(config再読み込みとかテンプレ生成とか)
- [ ] インストーラ
- [ ] 仮想鍵盤

## 現状についての警告

- デバッグのため、NSLogに全ストロークが出力されます。プライバシー注意!

## 参考文献

- [azooKey on macOSの開発知見](https://zenn.dev/azookey/articles/d06b4ee8039ba9)
- [日本語入力を作るときに必要だった本](https://mzp.booth.pm/items/809262)
- [Typut](https://github.com/ensan-hcl/Typut)

## ライセンス

MIT
