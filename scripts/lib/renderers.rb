# frozen_string_literal: true

require 'chunky_png'
require 'gruff'

begin
  require 'mini_magick'
rescue LoadError
  warn 'mini_magick gem not available; text annotations will not be rendered.'
end

module Renderers
  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  # t (0.0..1.0) を white -> red の色にマップする。
  # scale: :linear (デフォルト) または :log
  def self.heat_color(t, scale: :linear)
    t = [[t, 0.0].max, 1.0].min
    t = if scale == :log && t > 0
      Math.log(t * (Math::E - 1) + 1)   # log(1)=0, log(e)=1 に正規化
    else
      t
    end
    t = [[t, 0.0].max, 1.0].min
    r = 255
    g = (255 * (1.0 - t)).round
    b = (255 * (1.0 - t)).round
    ChunkyPNG::Color.rgba(r, g, b, 255)
  end

  # Annotate text onto an existing PNG file using ImageMagick via MiniMagick
  # annotations: array of { x:, y:, text:, color:, pointsize: }
  # font_magick: ImageMagick font name (e.g. '.Hiragino-Kaku-Gothic-Interface-W3')
  def self.annotate_png(path, annotations, font_magick: nil)
    return unless defined?(MiniMagick)

    tool = MiniMagick::Tool.new('magick')
    tool << path
    annotations.each do |a|
      tool.font(font_magick) if font_magick
      tool.pointsize(a[:pointsize] || 12)
      tool.fill(a[:color] || 'black')
      tool.gravity('NorthWest')
      tool.annotate("+#{a[:x]}+#{a[:y]}", a[:text])
    end
    tool << path
    tool.call
  rescue StandardError => e
    warn "MiniMagick annotate failed: #{e.message}"
  end

  # ---------------------------------------------------------------------------
  # Heatmap (keyCount): 4 rows x 10 cols
  # values: 40-element array of percentages (0.0..100.0)
  # font_path:   path to font file (for gruff, unused here)
  # font_magick: ImageMagick font name (for text annotation)
  # ---------------------------------------------------------------------------
  def self.render_heatmap(values, out_path:, width: 1000, font_path: nil, font_magick: nil, title: nil, scale: :linear)
    raise ArgumentError, "values must be 40 elements (got #{values.length})" unless values.length == 40

    pad_left   = 50
    pad_right  = 20
    pad_top    = title ? 70 : 50
    pad_bottom = 50

    grid_w  = width - pad_left - pad_right
    cell_w  = (grid_w / 10).floor
    cell_h  = cell_w
    height  = pad_top + cell_h * 4 + pad_bottom

    img    = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
    border = ChunkyPNG::Color.rgba(180, 180, 180, 255)
    max_v  = values.max.nonzero? || 1.0

    annotations = []

    # Title
    if title
      title_ps = [[( width * 0.025).to_i, 14].max, 28].min
      tx = (width / 2) - (title_ps * title.length * 0.3).to_i
      annotations << { x: [tx, 4].max, y: 8, text: title, color: 'black', pointsize: title_ps }
    end

    4.times do |r|
      10.times do |c|
        idx = r * 10 + c
        v   = values[idx]
        t   = v / max_v.to_f
        col = heat_color(t, scale: scale)
        x0  = pad_left + c * cell_w
        y0  = pad_top  + r * cell_h

        (0...cell_w).each do |px|
          (0...cell_h).each { |py| img[x0 + px, y0 + py] = col }
        end

        (x0...x0 + cell_w).each { |x| img[x, y0] = border; img[x, y0 + cell_h - 1] = border }
        (y0...y0 + cell_h).each { |y| img[x0, y] = border; img[x0 + cell_w - 1, y] = border }

        label      = format('%3.1f', v)
        text_color = t > 0.6 ? 'white' : 'black'
        ps         = [[( cell_w * 0.35).to_i, 8].max, 20].min
        tx         = x0 + (cell_w / 2) - (ps * label.length * 0.3).to_i
        ty         = y0 + (cell_h / 2) - (ps * 0.5).to_i
        annotations << { x: tx, y: ty, text: label, color: text_color, pointsize: ps }
      end
    end

    img.save(out_path)
    annotate_png(out_path, annotations, font_magick: font_magick)
  end

  # ---------------------------------------------------------------------------
  # Vertical bar chart via gruff
  # font_path: path to font file for gruff
  # ---------------------------------------------------------------------------
  def self.render_bar_chart(labels, values, out_path:, width: 1000, font_path: nil, title: '')
    g = Gruff::Bar.new(width)
    g.title = title
    g.font  = font_path if font_path && File.exist?(font_path)
    g.theme_pastel
    g.hide_legend = true
    g.y_axis_label = '%'
    g.labels = labels.each_with_index.map { |l, i| [i, l] }.to_h
    g.data :usage, values.map { |v| v.round(2) }
    g.write(out_path)
  end

  # ---------------------------------------------------------------------------
  # Horizontal bar chart via gruff (SideBar)
  # font_path: path to font file for gruff
  # ---------------------------------------------------------------------------
  def self.render_side_bar_chart(labels, values, out_path:, width: 1000, font_path: nil, title: '')
    g = Gruff::SideBar.new(width)
    g.title = title
    g.font  = font_path if font_path && File.exist?(font_path)
    g.theme_pastel
    g.hide_legend = true
    g.x_axis_label = '%'
    g.labels = labels.each_with_index.map { |l, i| [i, l] }.to_h
    g.data :usage, values.map { |v| v.round(2) }
    g.write(out_path)
  end

  # ---------------------------------------------------------------------------
  # Bigram heatmap: 40x40
  # font_magick: ImageMagick font name for axis labels
  # ---------------------------------------------------------------------------
  BIGRAM_ORDER = [
    *(0..4), *(10..14), *(20..24), *(30..34),
    *(5..9), *(15..19), *(25..29), *(35..39)
  ].freeze

  BIGRAM_GROUP_LABELS = [
    'L最上段', 'L上段', 'L中段', 'L下段',
    'R最上段', 'R上段', 'R中段', 'R下段'
  ].freeze

  # ---------------------------------------------------------------------------
  # Internal: shared 40x40 heatmap renderer for bigram and basicCharCount
  # pct_1600:   1600-element array of percentages
  # char_table: optional Hash { index(0..1599) => char } for cell labels
  # ---------------------------------------------------------------------------
  def self.render_1600_heatmap(pct_1600, out_path:, width: 1000, font_magick: nil, label_name: 'bigram', title: nil, scale: :linear, char_table: nil)
    raise ArgumentError, "#{label_name} must be 1600 elements (got #{pct_1600.length})" unless pct_1600.length == 1600

    pad_left   = 100
    pad_right  = 20
    pad_top    = title ? 120 : 100
    pad_bottom = 20

    grid_w  = width - pad_left - pad_right
    cell_w  = (grid_w / 40).floor
    cell_h  = cell_w
    height  = pad_top + cell_h * 40 + pad_bottom

    img   = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
    max_v = pct_1600.max.nonzero? || 1.0

    BIGRAM_ORDER.each_with_index do |first_key, ri|
      BIGRAM_ORDER.each_with_index do |second_key, ci|
        v   = pct_1600[first_key * 40 + second_key]
        t   = v / max_v.to_f
        col = heat_color(t, scale: scale)
        x0  = pad_left + ci * cell_w
        y0  = pad_top  + ri * cell_h
        (0...cell_w).each do |px|
          (0...cell_h).each { |py| img[x0 + px, y0 + py] = col }
        end
      end
    end

    # Group separator lines
    group_sep = ChunkyPNG::Color.rgba(0, 0, 0, 200)
    [0, 5, 10, 15, 20, 25, 30, 35, 40].each do |g|
      x = pad_left + g * cell_w
      y = pad_top  + g * cell_h
      (pad_top...(pad_top + 40 * cell_h)).each { |yy| img[x, yy] = group_sep if x < width }
      (pad_left...(pad_left + 40 * cell_w)).each { |xx| img[xx, y] = group_sep if y < height }
    end

    img.save(out_path)

    annotations = []
    title_ps = [[( width * 0.025).to_i, 14].max, 28].min

    # Title
    if title
      tx = (width / 2) - (title_ps * title.length * 0.3).to_i
      annotations << { x: [tx, 4].max, y: 8, text: title, color: 'black', pointsize: title_ps }
    end

    ps = [[cell_w * 5 / 8, 8].max, 14].min
    BIGRAM_GROUP_LABELS.each_with_index do |label, gi|
      cx = pad_left + gi * 5 * cell_w + (5 * cell_w / 2) - (ps * label.length * 0.3).to_i
      cy = [pad_top - ps - 4, 2].max
      annotations << { x: cx, y: cy, text: label, color: 'black', pointsize: ps }

      rx = 2
      ry = [pad_top + gi * 5 * cell_h + (5 * cell_h / 2) - ps, 2].max
      annotations << { x: rx, y: ry, text: label, color: 'black', pointsize: ps }
    end

    # セル内文字ラベル (basicCharCount用)
    if char_table
      char_ps = [[cell_w * 3 / 4, 6].max, 12].min
      BIGRAM_ORDER.each_with_index do |first_key, ri|
        BIGRAM_ORDER.each_with_index do |second_key, ci|
          idx = first_key * 40 + second_key
          ch  = char_table[idx]
          next unless ch

          v   = pct_1600[idx]
          t   = (v / max_v.to_f)
          t   = (scale == :log && t > 0) ? Math.log(t * (Math::E - 1) + 1) : t
          text_color = t > 0.6 ? 'white' : 'black'
          x0  = pad_left + ci * cell_w
          y0  = pad_top  + ri * cell_h
          tx  = x0 + (cell_w / 2) - (char_ps * 0.5).to_i
          ty  = y0 + (cell_h / 2) - (char_ps * 0.5).to_i
          annotations << { x: [tx, pad_left].max, y: [ty, pad_top].max, text: ch, color: text_color, pointsize: char_ps }
        end
      end
    end

    annotate_png(out_path, annotations, font_magick: font_magick)
  end

  # ---------------------------------------------------------------------------
  # 木を見て森を見るストローク表ヒートマップ: 50cols x 32rows
  # pct_1600:   1600要素の割合配列 (basicCharCount を正規化したもの)
  # char_table: Hash { index(0..1599) => char }  セル内文字ラベル用
  #
  # 座標変換:
  #   k1 = index / 40, k2 = index % 40
  #   p1 = k1%10 < 5 ? 0 : 1  (0=左手, 1=右手)
  #   p2 = k2%10 < 5 ? 0 : 1
  #   x1=k1%5, y1=k1/10,  x2=k2%5, y2=k2/10
  #   x = x2*5 + x1 + p2*25   (0..49)
  #   y = y2*4 + y1 + p1*16   (0..31)
  # ---------------------------------------------------------------------------
  def self.render_1600_stroke_heatmap(pct_1600, out_path:, width: 1200, font_magick: nil,
                                      title: '木を見て森を見るヒートマップ', scale: :linear,
                                      char_table: nil)
    raise ArgumentError, "pct_1600 must be 1600 elements (got #{pct_1600.length})" unless pct_1600.length == 1600

    n_cols = 50
    n_rows = 32

    # 象限ラベル行（上・下それぞれ）と標題行を確保
    title_ps   = 18
    title_h    = title ? title_ps + 10 : 0
    qlabel_h   = 20   # 象限ラベルの高さ
    pad_left   = 10
    pad_right  = 10
    pad_top    = title_h + qlabel_h + 4
    pad_bottom = qlabel_h + 4

    grid_w  = width - pad_left - pad_right
    cell_w  = (grid_w.to_f / n_cols).floor
    cell_h  = cell_w
    height  = pad_top + cell_h * n_rows + pad_bottom

    img   = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)
    max_v = pct_1600.max.nonzero? || 1.0

    # --- セルの塗りつぶし ---
    grid = Array.new(n_cols * n_rows, 0.0)   # (x, y) -> pct
    1600.times do |idx|
      k1 = idx / 40
      k2 = idx % 40
      p1 = k1 % 10 < 5 ? 0 : 1
      p2 = k2 % 10 < 5 ? 0 : 1
      x1 = k1 % 5;  y1 = k1 / 10
      x2 = k2 % 5;  y2 = k2 / 10
      x  = x2 * 5 + x1 + p2 * 25
      y  = y2 * 4 + y1 + p1 * 16
      grid[y * n_cols + x] = pct_1600[idx]
    end

    n_rows.times do |gy|
      n_cols.times do |gx|
        v   = grid[gy * n_cols + gx]
        t   = v / max_v.to_f
        col = heat_color(t, scale: scale)
        x0  = pad_left + gx * cell_w
        y0  = pad_top  + gy * cell_h
        (0...cell_w).each do |px|
          (0...cell_h).each { |py| img[x0 + px, y0 + py] = col }
        end
      end
    end

    # --- 罫線（森の境界） ---
    thin_sep  = ChunkyPNG::Color.rgba(120, 120, 120, 200)
    thick_sep = ChunkyPNG::Color.rgba(0,   0,   0,   255)

    # 縦線: x = 5, 10, 15, 20 | 25(太) | 30, 35, 40, 45
    (0...n_cols).step(5) do |gx|
      next if gx == 0
      color = (gx == 25) ? thick_sep : thin_sep
      x = pad_left + gx * cell_w
      (pad_top...(pad_top + n_rows * cell_h)).each { |yy| img[x, yy] = color if x < width }
    end

    # 横線: y = 4, 8, 12 | 16(太) | 20, 24, 28
    (0...n_rows).step(4) do |gy|
      next if gy == 0
      color = (gy == 16) ? thick_sep : thin_sep
      y = pad_top + gy * cell_h
      (pad_left...(pad_left + n_cols * cell_w)).each { |xx| img[xx, y] = color if y < height }
    end

    img.save(out_path)

    annotations = []

    # --- 標題 ---
    if title
      tx = (width / 2) - (title_ps * title.length * 0.3).to_i
      annotations << { x: [tx, 4].max, y: 4, text: title, color: 'black', pointsize: title_ps }
    end

    # --- 象限ラベル ---
    # p1=0(左手)=上半分(y<16), p1=1(右手)=下半分(y>=16)
    # p2=0(左手)=左半分(x<25), p2=1(右手)=右半分(x>=25)
    # ラベル位置: 上(y<pad_top)と下(y>pad_top+n_rows*cell_h)
    ql_ps   = 13
    left_cx  = pad_left + 12 * cell_w + cell_w / 2   # 左半分中央
    right_cx = pad_left + 37 * cell_w + cell_w / 2   # 右半分中央
    top_y    = title_h + 4
    bot_y    = pad_top + n_rows * cell_h + 4

    [
      { text: 'LL', x: left_cx,  y: top_y },
      { text: 'LR', x: right_cx, y: top_y },
      { text: 'RL', x: left_cx,  y: bot_y },
      { text: 'RR', x: right_cx, y: bot_y },
    ].each do |q|
      tx = q[:x] - (ql_ps * q[:text].length * 0.35).to_i
      annotations << { x: [tx, 0].max, y: q[:y], text: q[:text], color: 'black', pointsize: ql_ps }
    end

    # --- セル内文字ラベル ---
    if char_table
      char_ps = [[cell_w * 3 / 4, 6].max, 12].min
      1600.times do |idx|
        ch = char_table[idx]
        next unless ch

        k1 = idx / 40
        k2 = idx % 40
        p1 = k1 % 10 < 5 ? 0 : 1
        p2 = k2 % 10 < 5 ? 0 : 1
        x1 = k1 % 5;  y1 = k1 / 10
        x2 = k2 % 5;  y2 = k2 / 10
        gx = x2 * 5 + x1 + p2 * 25
        gy = y2 * 4 + y1 + p1 * 16

        v  = grid[gy * n_cols + gx]
        t  = v / max_v.to_f
        t  = (scale == :log && t > 0) ? Math.log(t * (Math::E - 1) + 1) : t
        text_color = t > 0.6 ? 'white' : 'black'

        x0 = pad_left + gx * cell_w
        y0 = pad_top  + gy * cell_h
        tx = x0 + (cell_w / 2) - (char_ps * 0.5).to_i
        ty = y0 + (cell_h / 2) - (char_ps * 0.5).to_i
        annotations << { x: [tx, pad_left].max, y: [ty, pad_top].max,
                         text: ch, color: text_color, pointsize: char_ps }
      end
    end

    annotate_png(out_path, annotations, font_magick: font_magick)
  end

  # stroke_map wrapper
  def self.render_stroke_map(pct_1600, out_path:, width: 1200, font_magick: nil,
                             title: '木を見て森を見るヒートマップ', scale: :linear)
    require_relative 'tcode'
    char_table = Tcode.all_chars
    render_1600_stroke_heatmap(pct_1600, out_path: out_path, width: width,
                               font_magick: font_magick, title: title,
                               scale: scale, char_table: char_table)
  end

  # Bigram heatmap (wrapper)
  def self.render_bigram(bigram_pct, out_path:, width: 1000, font_magick: nil, title: nil, scale: :linear)
    render_1600_heatmap(bigram_pct, out_path: out_path, width: width,
                        font_magick: font_magick, label_name: 'bigram', title: title, scale: scale)
  end

  # basicCharCount heatmap: セルにT-Code基本文字を描画
  def self.render_basic_chars(basic_char_pct, out_path:, width: 1000, font_magick: nil, title: nil, scale: :linear)
    require_relative 'tcode'
    char_table = Tcode.all_chars
    render_1600_heatmap(basic_char_pct, out_path: out_path, width: width,
                        font_magick: font_magick, label_name: 'basicCharCount', title: title,
                        scale: scale, char_table: char_table)
  end

  # ---------------------------------------------------------------------------
  # Percentile chart: 出現頻度順基本文字一覧
  # sorted_chars: [ [char, count], ... ] 頻度降順
  # cols:         1行あたりの文字数 (デフォルト40)
  # ---------------------------------------------------------------------------
  PERCENTILE_BANDS = [
    { upto: 50,  color: [255, 160, 160] },   # 濃いピンク
    { upto: 75,  color: [255, 192, 192] },
    { upto: 90,  color: [255, 210, 210] },
    { upto: 95,  color: [255, 228, 228] },
    { upto: 100, color: [255, 255, 255] },   # 白
  ].freeze

  def self.render_percentile(sorted_chars, out_path:, width: 1000, font_magick: nil,
                             title: '入力したことのある字(出現頻度順)', cols: 40)
    return if sorted_chars.empty?

    total = sorted_chars.sum { |_, c| c }.to_f

    # 各文字のパーセンタイル (累積頻度の割合)
    cumulative = 0.0
    char_pct = sorted_chars.map do |ch, cnt|
      cumulative += cnt / total * 100.0
      [ch, cumulative]
    end

    rows = (char_pct.length.to_f / cols).ceil

    # レイアウト定数
    pad_left   = 10
    pad_right  = 10
    title_ps   = title ? [[(width * 0.025).to_i, 14].max, 28].min : 0
    title_h    = title ? title_ps + 10 : 0

    # 凡例: バンドごとに色ボックス＋ラベル
    legend_ps    = [[(width * 0.018).to_i, 10].max, 18].min
    legend_box_h = legend_ps + 6
    legend_h     = legend_box_h + 8   # ボックス＋下余白

    pad_top    = pad_left + title_h + legend_h
    pad_bottom = 10

    cell_w = ((width - pad_left - pad_right).to_f / cols).floor
    cell_h = (cell_w * 1.4).to_i
    height = pad_top + cell_h * rows + pad_bottom

    img = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color::WHITE)

    annotations = []

    # タイトル
    if title
      tx = (width / 2) - (title_ps * title.length * 0.3).to_i
      annotations << { x: [tx, 4].max, y: pad_left, text: title, color: 'black', pointsize: title_ps }
    end

    # 凡例描画
    legend_labels = [
      '0-50%',
      '50-75%',
      '75-90%',
      '90-95%',
      '95-100%',
    ]
    n_bands   = PERCENTILE_BANDS.length
    band_w    = (width - pad_left - pad_right) / n_bands
    legend_y0 = pad_left + title_h + 4

    PERCENTILE_BANDS.each_with_index do |band, i|
      r, g, b = band[:color]
      bg = ChunkyPNG::Color.rgba(r, g, b, 255)
      x0 = pad_left + i * band_w
      # 色ボックスを塗る
      (0...band_w).each do |px|
        (0...legend_box_h).each { |py| img[x0 + px, legend_y0 + py] = bg }
      end
      # ボックス枠線
      border = ChunkyPNG::Color.rgba(180, 180, 180, 255)
      (0...band_w).each { |px| img[x0 + px, legend_y0] = border; img[x0 + px, legend_y0 + legend_box_h - 1] = border }
      (0...legend_box_h).each { |py| img[x0, legend_y0 + py] = border; img[x0 + band_w - 1, legend_y0 + py] = border }
      # ラベルテキスト
      label = legend_labels[i]
      tx = x0 + (band_w / 2) - (legend_ps * label.length * 0.3).to_i
      ty = legend_y0 + (legend_box_h / 2) - (legend_ps * 0.5).to_i
      annotations << { x: [tx, x0].max, y: [ty, legend_y0].max, text: label, color: 'black', pointsize: legend_ps }
    end

    char_pct.each_with_index do |(ch, cum_pct), idx|
      row = idx / cols
      col = idx % cols
      x0  = pad_left + col * cell_w
      y0  = pad_top  + row * cell_h

      # 背景色
      band  = PERCENTILE_BANDS.find { |b| cum_pct <= b[:upto] } || PERCENTILE_BANDS.last
      r, g, b = band[:color]
      bg_color = ChunkyPNG::Color.rgba(r, g, b, 255)
      (0...cell_w).each do |px|
        (0...cell_h).each { |py| img[x0 + px, y0 + py] = bg_color }
      end

      # 文字アノテーション
      char_ps = [[cell_w * 3 / 4, 8].max, 18].min
      tx = x0 + (cell_w / 2) - (char_ps * 0.5).to_i
      ty = y0 + (cell_h / 2) - (char_ps * 0.5).to_i
      annotations << { x: [tx, 0].max, y: [ty, 0].max, text: ch, color: 'black', pointsize: char_ps }
    end

    img.save(out_path)
    annotate_png(out_path, annotations, font_magick: font_magick)
  end

  # ---------------------------------------------------------------------------
  # Stream histogram (horizontal bar chart)
  # histogram: 51-element array of counts (index = stream length, index 0 unused)
  # threshold: string e.g. "0.5"
  # font_path: path to font file for gruff
  # ---------------------------------------------------------------------------
  def self.render_stream_histogram(histogram, out_path:, threshold:, width: 1000, font_path: nil)
    # インデックス1〜50 (長さ1〜50のストリーム)
    counts = histogram[1, 50] || []
    counts = counts + Array.new([50 - counts.length, 0].max, 0)

    total = counts.sum

    # 最小値〜最大値の範囲で表示（度数0も含む）、最低5要素は確保
    first_nonzero = counts.index { |v| v > 0 } || 0
    last_nonzero  = counts.rindex { |v| v > 0 } || 0
    range_start   = first_nonzero          # 0-based index into counts (= stream length - 1)
    range_end     = [last_nonzero, 4].max  # 最低5要素
    display_counts = counts[range_start..range_end]

    # ストリーム長は range_start+1 〜 range_end+1
    # ラベルは5刻みのみ表示、それ以外は空文字
    display_labels = (range_start..range_end).each_with_index.map do |stream_idx, i|
      len = stream_idx + 1  # ストリーム長
      (len % 5 == 0 || len == 1) ? len.to_s : ''
    end

    title = "漢直ストリーム (しきい値#{threshold}秒)"

    g = Gruff::SideBar.new(width)
    g.title = title
    g.font  = font_path if font_path && File.exist?(font_path)
    g.theme_pastel
    g.hide_legend = true
    g.x_axis_label = 'count'
    g.labels = display_labels.each_with_index.map { |l, i| [i, l] }.to_h
    g.data :count, display_counts
    g.write(out_path)

    # 右下に "n = {合計}" を注釈
    # gruff出力後にMiniMagickで追記
    if defined?(MiniMagick)
      img_info = MiniMagick::Image.open(out_path)
      img_w = img_info.width
      img_h = img_info.height
      n_text = "n = #{total}"
      ps = 16
      tx = img_w - ps * n_text.length - 10
      ty = img_h - ps - 10
      annotate_png(out_path,
                   [{ x: tx, y: ty, text: n_text, color: 'black', pointsize: ps }],
                   font_magick: font_path)
    end
  end
end
