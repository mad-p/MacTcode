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

  # linear interpolation: white(0) -> red(1)
  def self.heat_color(t)
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
  def self.render_heatmap(values, out_path:, width: 1000, font_path: nil, font_magick: nil, title: nil)
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
        col = heat_color(t)
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
  # pct_1600: 1600-element array of percentages
  # ---------------------------------------------------------------------------
  def self.render_1600_heatmap(pct_1600, out_path:, width: 1000, font_magick: nil, label_name: 'bigram', title: nil)
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
        col = heat_color(t)
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

    annotate_png(out_path, annotations, font_magick: font_magick)
  end

  # Bigram heatmap (wrapper)
  def self.render_bigram(bigram_pct, out_path:, width: 1000, font_magick: nil, title: nil)
    render_1600_heatmap(bigram_pct, out_path: out_path, width: width,
                        font_magick: font_magick, label_name: 'bigram', title: title)
  end

  # basicCharCount heatmap (same layout as bigram)
  def self.render_basic_chars(basic_char_pct, out_path:, width: 1000, font_magick: nil, title: nil)
    render_1600_heatmap(basic_char_pct, out_path: out_path, width: width,
                        font_magick: font_magick, label_name: 'basicCharCount', title: title)
  end
end
