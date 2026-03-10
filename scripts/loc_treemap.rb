#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/loc_treemap.rb
# Usage: ruby loc_treemap.rb [options] <project-root>
#
# Swiftファイルの実装行数をツリーマップとして描画し treemap.png に出力する。
# コメントのみの行（// または /* */ ブロック内）はスキップする。

require 'optparse'
require 'fileutils'
require 'chunky_png'

FONT_PATH_DEFAULT   = '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc'
FONT_MAGICK_DEFAULT = '.Hiragino-Kaku-Gothic-Interface-W3'

options = {
  out_dir:    'out',
  width:      1200,
  height:     800,
  font_path:  FONT_PATH_DEFAULT,
  font_magick: FONT_MAGICK_DEFAULT,
  out_file:   'treemap.png',
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options] <project-root>"
  opts.on('--out-dir DIR',   'Output directory (default: ./out)')  { |d| options[:out_dir]    = d }
  opts.on('--width W',       'Image width  (default: 1200)',  Integer) { |v| options[:width]  = v }
  opts.on('--height H',      'Image height (default: 800)',   Integer) { |v| options[:height] = v }
  opts.on('--font PATH',     'TTF font path') { |p| options[:font_path]   = p }
  opts.on('--font-magick N', 'ImageMagick font name') { |n| options[:font_magick] = n }
end.parse!

project_root = ARGV.first || File.expand_path('..', __dir__)
project_root = File.expand_path(project_root)

# ---------------------------------------------------------------------------
# 1. Swiftファイルの行数集計
# ---------------------------------------------------------------------------

# コメントのみの行をスキップして実装行数を数える
def count_loc(path)
  in_block_comment = false
  loc = 0
  File.foreach(path) do |raw|
    line = raw.rstrip
    stripped = line.lstrip

    if in_block_comment
      if stripped.include?('*/')
        in_block_comment = false
        # */ の後にコードが続く場合はカウント
        after = stripped.sub(%r{.*?\*/}, '').lstrip
        loc += 1 if after != '' && !after.start_with?('//')
      end
      # ブロックコメント内はスキップ
      next
    end

    # ブロックコメント開始
    if stripped.start_with?('/*')
      unless stripped.include?('*/')
        in_block_comment = true
      end
      next
    end

    next if stripped.empty?
    next if stripped.start_with?('//')

    loc += 1
  end
  loc
end

# カテゴリ定義: [カテゴリキー, 表示名, マッチパターン(Regexp or nil), 色]
# ファイルは MacTcode/ または MacTcodeTests/ 以下にある
CATEGORIES = [
  { key: :tcode,     label: 'Tcode',     dir: 'MacTcode/Tcode'     },
  { key: :mazegaki,  label: 'Mazegaki',  dir: 'MacTcode/Mazegaki'  },
  { key: :bushu,     label: 'Bushu',     dir: 'MacTcode/Bushu'     },
  { key: :zenkaku,   label: 'Zenkaku',   dir: 'MacTcode/Zenkaku'   },
  { key: :line,      label: 'Line',      dir: 'MacTcode/Line'      },
  { key: :mode,      label: 'Mode',      dir: 'MacTcode/Mode'      },
  { key: :keymap,    label: 'Keymap',    dir: 'MacTcode/Keymap'    },
  { key: :client,    label: 'Client',    dir: 'MacTcode/Client'    },
  { key: :root,      label: 'Root',      dir: 'MacTcode'           },  # ルート直下（サブディレクトリなし）
  { key: :tests,     label: 'Tests',     dir: 'MacTcodeTests'      },
].freeze

# カテゴリ配色（入力モード系=暖色、制御系=寒色、ルート=グレー、テスト=紫）
CATEGORY_COLORS = {
  tcode:    { base: [220, 60,  40],  text: 'white' },
  mazegaki: { base: [230, 120, 30],  text: 'white' },
  bushu:    { base: [200, 160, 20],  text: 'black' },
  zenkaku:  { base: [160, 200, 30],  text: 'black' },
  line:     { base: [80,  190, 80],  text: 'black' },
  mode:     { base: [40,  100, 200], text: 'white' },
  keymap:   { base: [60,  170, 210], text: 'black' },
  client:   { base: [30,  160, 130], text: 'white' },
  root:     { base: [130, 130, 130], text: 'white' },
  tests:    { base: [150, 80,  200], text: 'white' },
}.freeze

# ファイルを収集してカテゴリに分類
all_swift = Dir.glob(File.join(project_root, '**', '*.swift')).sort

groups = CATEGORIES.map { |c| c.merge(files: []) }

all_swift.each do |path|
  rel = path.sub("#{project_root}/", '')
  # 最も深くマッチするカテゴリを選ぶ（dirの長さが長い順に評価）
  matched = groups
    .select { |g| rel.start_with?("#{g[:dir]}/") || (g[:key] == :root && File.dirname(rel) == 'MacTcode') }
    .max_by { |g| g[:dir].length }
  matched[:files] << path if matched
end

# 各ファイルのLOCを集計
FileData = Struct.new(:path, :name, :loc, :category)

all_files = []
groups.each do |grp|
  grp[:files].each do |path|
    loc = count_loc(path)
    next if loc == 0
    all_files << FileData.new(path, File.basename(path, '.swift'), loc, grp[:key])
  end
end

total_loc = all_files.sum(&:loc)
puts "Total LOC: #{total_loc}"
all_files.sort_by { |f| [-f.loc, f.name] }.each do |f|
  puts "  #{f.category.to_s.ljust(10)} #{f.name.ljust(30)} #{f.loc}"
end

# ---------------------------------------------------------------------------
# 2. Squarified Treemap レイアウト
# ---------------------------------------------------------------------------

Rect = Struct.new(:x, :y, :w, :h)

# Squarified treemap アルゴリズム
# items: [{value:, ...}, ...]  (value > 0)
# rect: Rect — 割り当て領域
# 返り値: 各アイテムに :rect を付与した配列
def squarify(items, rect)
  return [] if items.empty? || rect.w <= 0 || rect.h <= 0

  total = items.sum { |i| i[:value].to_f }
  result = []
  remaining = items.dup

  until remaining.empty?
    w = [rect.w, rect.h].min   # 短辺
    area = rect.w * rect.h
    scale = area / total

    # 現在の行に追加するアイテムを決定
    row = []
    best_ratio = Float::INFINITY
    remaining.each do |item|
      row << item
      ratio = worst_aspect(row, w, scale)
      if ratio <= best_ratio
        best_ratio = ratio
      else
        row.pop
        break
      end
    end

    # 行を確定してレイアウト
    row_value = row.sum { |i| i[:value].to_f }
    row_area  = row_value * scale
    if rect.w >= rect.h
      # 横長 → 縦方向に行を積む
      col_w = (row_area / rect.h).round(4)
      y_cursor = rect.y
      row.each do |item|
        item_h = (item[:value].to_f / row_value * rect.h).round(4)
        result << item.merge(rect: Rect.new(rect.x, y_cursor, col_w, item_h))
        y_cursor += item_h
      end
      rect = Rect.new(rect.x + col_w, rect.y, rect.w - col_w, rect.h)
    else
      # 縦長 → 横方向に行を積む
      row_h = (row_area / rect.w).round(4)
      x_cursor = rect.x
      row.each do |item|
        item_w = (item[:value].to_f / row_value * rect.w).round(4)
        result << item.merge(rect: Rect.new(x_cursor, rect.y, item_w, row_h))
        x_cursor += item_w
      end
      rect = Rect.new(rect.x, rect.y + row_h, rect.w, rect.h - row_h)
    end

    remaining -= row
    total -= row_value
  end
  result
end

def worst_aspect(row, w, scale)
  s = row.sum { |i| i[:value].to_f } * scale
  row.map do |i|
    a = i[:value].to_f * scale
    r = a / s * w    # 矩形の一辺
    other = a / r    # もう一辺
    [r / other, other / r].max
  end.max
end

# ---------------------------------------------------------------------------
# 3. 描画
# ---------------------------------------------------------------------------

PAD_TOP    = 72  # タイトル1行 + 凡例1行
PAD        = 4   # セル間のマージン
TITLE_H    = 32  # タイトル行の高さ
LEGEND_H   = 22  # 凡例行の高さ（タイトル直下）
BORDER     = 1

def rgba(r, g, b, a = 255)
  ChunkyPNG::Color.rgba(r, g, b, a)
end

def lighten(base, amount = 40)
  r, g, b = base
  rgba([r + amount, 255].min, [g + amount, 255].min, [b + amount, 255].min)
end

def darken(base, amount = 40)
  r, g, b = base
  rgba([r - amount, 0].max, [g - amount, 0].max, [b - amount, 0].max)
end

img_w = options[:width]
img_h = options[:height]

canvas = ChunkyPNG::Image.new(img_w, img_h, rgba(30, 30, 30))

# タイトルバー（1行目: タイトル文字列用）
(0...TITLE_H).each { |y| (0...img_w).each { |x| canvas[x, y] = rgba(50, 50, 50) } }
# 凡例バー（2行目: やや濃い背景）
(TITLE_H...PAD_TOP).each { |y| (0...img_w).each { |x| canvas[x, y] = rgba(40, 40, 40) } }

# ツリーマップ領域
tm_rect = Rect.new(PAD, PAD_TOP + PAD, img_w - PAD * 2, img_h - PAD_TOP - PAD * 2)

GROUP_PAD = 3  # グループ間の内側余白

# ---------------------------------------------------------------------------
# 2段階レイアウト
#   第1段階: カテゴリグループをSquarify（グループ合計LOCが面積に比例）
#   第2段階: 各グループ領域の内側でファイルをSquarify
# ---------------------------------------------------------------------------

# グループ合計LOCを計算し、CATEGORIESの順序を維持（存在するものだけ）
group_items = CATEGORIES.filter_map do |c|
  files = all_files.select { |f| f.category == c[:key] }
  next if files.empty?
  total = files.sum(&:loc)
  { key: c[:key], label: c[:label], value: total, files: files }
end

# グループをLOC降順でSquarify（面積比例）
group_laid_out = squarify(group_items.sort_by { |g| -g[:value] }, tm_rect)

# 各ファイルのレイアウト結果
all_laid_out = []  # { item_hash, group_key }

group_laid_out.each do |grp|
  r = grp[:rect]
  # グループ内余白を確保してファイルをSquarify
  inner = Rect.new(r.x + GROUP_PAD, r.y + GROUP_PAD,
                   r.w - GROUP_PAD * 2, r.h - GROUP_PAD * 2)
  file_items = grp[:files].sort_by { |f| -f.loc }.map do |f|
    { value: f.loc, name: f.name, category: f.category, loc: f.loc }
  end
  file_laid = squarify(file_items, inner)
  file_laid.each { |fi| all_laid_out << fi.merge(group_rect: r, group_key: grp[:key]) }
end

# 各セルを描画
annotations = []

# まずグループの背景（薄暗い枠）を描画
group_laid_out.each do |grp|
  r = grp[:rect]
  base = CATEGORY_COLORS[grp[:key]][:base]
  bg_color = darken(base, 70)
  x0 = r.x.round; y0 = r.y.round
  x1 = (r.x + r.w).round - 1; y1 = (r.y + r.h).round - 1
  next if x1 <= x0 || y1 <= y0
  (y0..y1).each { |y| (x0..x1).each { |x| canvas[x, y] = bg_color } }
end

all_laid_out.each do |item|
  r = item[:rect]
  cat = item[:category]
  base = CATEGORY_COLORS[cat][:base]
  text_color = CATEGORY_COLORS[cat][:text]

  x0 = r.x.round
  y0 = r.y.round
  x1 = (r.x + r.w).round - 1
  y1 = (r.y + r.h).round - 1

  next if x1 <= x0 || y1 <= y0

  # セル塗りつぶし
  fill = rgba(*base)
  border_color = darken(base, 50)

  (y0..y1).each do |y|
    (x0..x1).each do |x|
      canvas[x, y] = fill
    end
  end

  # ボーダー
  (x0..x1).each do |x|
    canvas[x, y0] = border_color
    canvas[x, y1] = border_color
  end
  (y0..y1).each do |y|
    canvas[x0, y] = border_color
    canvas[x1, y] = border_color
  end

  # テキストアノテーション（セルが十分大きい場合のみ）
  cell_w = x1 - x0
  cell_h = y1 - y0
  next unless cell_w >= 30 && cell_h >= 16

  label = item[:name]
  sub   = "#{item[:loc]}"
  cx = x0 + cell_w / 2
  cy = y0 + cell_h / 2

  if cell_h >= 32
    annotations << { x: cx, y: cy - 10, text: label, color: text_color, pointsize: 13, anchor: :center }
    annotations << { x: cx, y: cy + 4,  text: sub,   color: text_color, pointsize: 10, anchor: :center }
  else
    short = cell_w >= 60 ? "#{label} #{sub}" : label
    annotations << { x: cx, y: cy - 6, text: short, color: text_color, pointsize: 11, anchor: :center }
  end
end

# グループラベルをグループ領域の左上に表示
group_laid_out.each do |grp|
  r = grp[:rect]
  base = CATEGORY_COLORS[grp[:key]][:base]
  text_color = CATEGORY_COLORS[grp[:key]][:text]
  gx = r.x.round + GROUP_PAD + 2
  gy = r.y.round + GROUP_PAD + 1
  gw = r.w.round
  gh = r.h.round
  next unless gw >= 40 && gh >= 14
  annotations << {
    x: gx, y: gy,
    text: grp[:label],
    color: text_color,
    pointsize: 10,
    anchor: :northwest
  }
end

# ---------------------------------------------------------------------------
# 4. 凡例
# ---------------------------------------------------------------------------

legend_items = CATEGORIES.map do |c|
  total = all_files.select { |f| f.category == c[:key] }.sum(&:loc)
  next if total == 0
  { label: c[:label], key: c[:key], loc: total }
end.compact

box_size    = 14
leg_x       = PAD + 4
leg_y       = TITLE_H + (LEGEND_H - box_size) / 2  # 凡例行の垂直中央
leg_spacing = 110

legend_items.each_with_index do |li, i|
  bx = leg_x + i * leg_spacing
  base = CATEGORY_COLORS[li[:key]][:base]
  (leg_y...(leg_y + box_size)).each do |y|
    (bx...(bx + box_size)).each do |x|
      canvas[x, y] = rgba(*base) if x < img_w && y < img_h
    end
  end
  annotations << {
    x: bx + box_size + 3,
    y: leg_y,
    text: "#{li[:label]}(#{li[:loc]})",
    color: 'white',
    pointsize: 11,
    anchor: :northwest
  }
end

# ---------------------------------------------------------------------------
# 5. 出力
# ---------------------------------------------------------------------------

FileUtils.mkdir_p(options[:out_dir])
out_path = File.join(options[:out_dir], options[:out_file])
canvas.save(out_path)
puts "Saved: #{out_path}"

# ImageMagick でテキストアノテーション
begin
  require 'mini_magick'
  tool = MiniMagick::Tool.new('magick')
  tool << out_path
  annotations.each do |a|
    tool.font(options[:font_magick])
    tool.pointsize(a[:pointsize] || 12)
    tool.fill(a[:color] || 'black')
    if a[:anchor] == :center
      tool.gravity('NorthWest')
      # テキスト幅を概算してセンタリング（1文字 ≈ pointsize * 0.6）
      approx_w = a[:text].length * (a[:pointsize] || 12) * 0.6
      ax = (a[:x] - approx_w / 2).round
      ay = a[:y]
      tool.annotate("+#{ax}+#{ay}", a[:text])
    else
      tool.gravity('NorthWest')
      tool.annotate("+#{a[:x]}+#{a[:y]}", a[:text])
    end
  end
  # タイトル
  tool.font(options[:font_magick])
  tool.pointsize(18)
  tool.fill('white')
  tool.gravity('NorthWest')
  tool.annotate("+#{img_w / 2 - 120}+7", "MacTcode  LOC Treemap  (total: #{total_loc})")
  tool << out_path
  tool.call
  puts "Annotated: #{out_path}"
rescue LoadError
  warn 'mini_magick not available; skipping text annotations.'
rescue StandardError => e
  warn "Annotation failed: #{e.message}"
end
