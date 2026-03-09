# 統計情報の改善

## lib/tcode.rbを作成

* 設定ファイルを読み、keyBindings.basicTableを取得する
* 設定ファイルは以下の2つある。この順でkeyBindings.basicTableが見つかるまで読む
    * `~/Library/Containers/jp.mad-p.inputmethod.MacTcode/Data/Library/Application Support/MacTcode/config.json`
    * プロジェクトルートの `sample-config.json`
* bigramやbasicCharCountのインデックスである0～1599をこのbasicTableを使って文字に変換するメソッドを提供する
    * インデックス値 `i = k1 * 40 + k2` のとき、k1は第1打鍵のキーコード、k2は第2打鍵のキーコードである
    * このとき、 `basicTable[k2][k1]` でその打鍵に対応する文字が得られる。k1とk2の順序に気をつけること

## ヒートマップのログスケールを実装

* コマンドラインオプション `--scale` のlog/linearで制御

## basic_chars.png の改善

* セルに対応するT-Code基本文字をセル中央に描画する

## 文字の出現頻度

* basicCharCount内の値をインデックスおよび対応する文字に関連づけ、出現頻度の順位を求める
* 漢字トップ100
    * 出現した文字のうち、正規表現 `/\p{Han}/` に一致するものを頻度の高い順に100個取り出す
    * 結果は頻度順に連結した文字列とする
    * top100.txtに出力する
* 出現頻度順基本文字一覧
    * 出現した文字のうち、 `■` 以外のものを出現頻度順に連結する
    * これを一行40文字で改行しpngに描画する
    * 出現頻度の累積を計算し
        * パーセンタイル0～50の文字は文字背景をピンクとする
        * パーセンタイル値50～75、75～90、90～95の段階を設け、順に薄くなるピンクを文字背景とする
        * パーセンタイル値95～100の文字は背景色を白とする
    * percentile.pngとして出力する
        * 図の標題を「入力したことのある字(出現頻度順)」とする

