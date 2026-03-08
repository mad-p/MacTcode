# stroke-stats 図示スクリプト

`stroke-stats.json` を読み込み、キーストローク統計情報を PNG として出力する Ruby スクリプトです。

## 必要環境

- Ruby 3.3.0（rbenv 推奨）
- Bundler
- ImageMagick（`magick` コマンド）— ヒートマップへのテキスト描画に使用

### macOS セットアップ

```bash
brew install imagemagick
cd scripts
bundle install
```

## 使い方

```bash
cd scripts
bundle exec ruby plot_strokes.rb [options] [stroke-stats.json ...]
```

引数を省略すると `scripts/data/*.json` を自動的に使用します。

### オプション

| オプション | デフォルト | 説明 |
|---|---|---|
| `--out-dir DIR` | `./out` | 出力ディレクトリ |
| `--width N` | `1000` | 出力画像の横幅（px）。この値をもとにセルサイズを自動計算 |
| `--font PATH` | ヒラギノ角ゴ ProN W3 ttc | gruff 用フォントファイルパス（gruff は `--font` にファイルパスを要求） |
| `--force` | false | 既存ファイルを上書きする |

### 実行例

```bash
# scripts/data の全JSONを合算して out/ に出力
bundle exec ruby plot_strokes.rb

# 特定ファイルを指定
bundle exec ruby plot_strokes.rb data/stroke-stats-home-202602.json data/stroke-stats-work-202602.json

# 出力先・横幅を指定
bundle exec ruby plot_strokes.rb --out-dir /tmp/myout --width 1200

# 別のフォントを使う
bundle exec ruby plot_strokes.rb --font /System/Library/Fonts/ヒラギノ角ゴシック\ W6.ttc
```

## 出力ファイル

| ファイル名 | 内容 |
|---|---|
| `heatmap.png` | keyCount のキーごと使用率ヒートマップ（4行×10列、各セルに%値を表示） |
| `finger_stats.png` | 指別使用率の棒グラフ（左小指〜右小指の8本） |
| `row_stats.png` | 段別使用率の横棒グラフ（最上段〜下段） |
| `panes.png` | ペイン（RL/RR/LL/LR）別の使用率横棒グラフ（頻度降順） |
| `alternation.png` | 交互打鍵／連続打鍵／初打の割合横棒グラフ（頻度降順） |
| `bigram.png` | バイグラムのヒートマップ（40×40、左手→右手のグループ順） |

## 入力ファイル形式

`StrokeStats.md` に定義されている `stroke-stats.json` 形式。
複数ファイルを指定した場合は要素ごとに合算して統計を作成します。

**注意:** 合算後に全要素が 0 の場合は PNG 生成をキャンセルして終了コード 2 で終了します。

## フォントと日本語表示

- `gruff`（棒グラフ）にはフォント**ファイルパス**を `--font` で渡します。デフォルトは `/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc` です。
- `heatmap.png` と `bigram.png` のテキスト描画には `magick` コマンド（ImageMagick）を使用しており、内部でフォント名 `.Hiragino-Kaku-Gothic-Interface-W3` を使っています（`magick -list font` で確認できます）。
- ImageMagick がインストールされていない場合はテキスト描画をスキップして PNG は生成されますが、数値ラベルや軸ラベルが表示されません。

## テスト

```bash
cd scripts
bundle exec ruby tests/run_tests.rb
```

Aggregator のユニットテスト（正常系・異常系・境界値）と統合テスト（実際のJSONでの全PNG生成）を実行します。

## ファイル構成

```
scripts/
  plot_strokes.rb        # メインスクリプト
  Gemfile                # 依存 gems（gruff, chunky_png, mini_magick）
  lib/
    aggregator.rb        # 複数JSONの読み込み・合算
    renderers.rb         # 各PNG描画ロジック
  data/                  # サンプル stroke-stats.json を置く場所
  tests/
    run_tests.rb         # テストスクリプト
```
