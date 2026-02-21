# ストローク統計を記録したい

入力したキーストロークの統計情報を取る

* 記録対象
    * T-Codeの基本キーのみ (Translate.strToKeyが0～39を返すキー)
* 記録する統計情報
    * キー別使用頻度(0-39)
    * 基本文字頻度(1打目 * 40 + 2打目で0～1599)
    * 基本文字の左右ペイン別頻度 ("RL", "RR", "LL", "LR")
        * キーコード(strToKeyの値)の10進下1桁でLかRかを判定する。0～4 → L、5～9 → R
    * bigram(1打目 * 40 + 2打目で0～1599)
        * 基本キー以外の入力、機能実行(部首・交ぜ書き変換やモード切りかえ)はbigram計算に対して連続性を切断したと考える
    * 交互打鍵頻度(交互打鍵"alternate"、連続打鍵"consecutive"、第1打目"first")
* 記録を保存形式
    * ファイル名stroke-stats.json
    * 頻度情報は、キー別、基本文字、bigramは1次元配列で、左右ペインと交互打鍵はオブジェクトでシリアライズ
    * ファイル形式についてSTROKE_STATS.mdというファイルに記述
    * tc-record.txtと同じ場所に作成
    * tc-record.txtと同じタイミングで読み込み、書き出し
* 記録するかどうかの設定項目
    * config.jsonのsystem.strokeStatsEnabledを新設、デフォルト値はtrue
    * ConfigParams.mdも合わせて更新
