#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/plot_strokes.rb
# Usage: ruby plot_strokes.rb [options] <stroke-stats.json>...

require 'optparse'
require 'fileutils'
require 'json'
require_relative 'lib/aggregator'
require_relative 'lib/renderers'
require_relative 'lib/tcode'

FONT_PATH_DEFAULT    = '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc'
FONT_MAGICK_DEFAULT  = '.Hiragino-Kaku-Gothic-Interface-W3'

options = {
  out_dir: 'out',
  width: 1000,
  font_path: FONT_PATH_DEFAULT,
  font_magick: FONT_MAGICK_DEFAULT,
  force: false,
  scale: :linear,
}

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options] <stroke-stats.json> ..."

  opts.on('--out-dir DIR', 'Output directory (default: ./out)') do |d|
    options[:out_dir] = d
  end

  opts.on('--width N', Integer, 'Total output width in pixels (default: 1000)') do |w|
    options[:width] = w
  end

  opts.on('--font PATH_OR_NAME', 'Font file path for gruff (default: Hiragino Kaku Gothic ProN W3 ttc)') do |f|
    options[:font_path] = f
    options[:font_magick] = f
  end

  opts.on('--force', 'Overwrite existing output files') do
    options[:force] = true
  end

  opts.on('--scale SCALE', %w[log linear], 'Color scale for heatmaps: log or linear (default: linear)') do |s|
    options[:scale] = s.to_sym
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end

opt_parser.parse!(ARGV)

input_files = ARGV.empty? ? Dir[File.join(__dir__, 'data', '*.json')] : ARGV

if input_files.empty?
  warn 'No input files specified and no files found in scripts/data/*.json'
  exit 1
end

raw_out = options[:out_dir]
out_dir = raw_out.start_with?('/') ? raw_out : File.join(Dir.pwd, raw_out)
FileUtils.mkdir_p(out_dir)

aggregator = Aggregator.new
input_files.each do |f|
  ok = aggregator.add_file(f)
  warn "Skipped invalid file: #{f}" unless ok
end

if aggregator.total_counts_zero?
  warn 'Aggregated total is zero; aborting PNG generation as requested.'
  exit 2
end

stats = aggregator.summary

# Prepare percentages
key_count_sum = stats[:key_count_sum]
bigram_sum = stats[:bigram_sum]
basic_char_count_sum = stats[:basic_char_count_sum]

key_percent = if key_count_sum > 0
  stats[:keyCount].map { |v| v.to_f * 100.0 / key_count_sum }
else
  Array.new(40, 0.0)
end

bigram_percent = if bigram_sum > 0
  stats[:bigram].map { |v| v.to_f * 100.0 / bigram_sum }
else
  Array.new(1600, 0.0)
end

basic_char_percent = if basic_char_count_sum > 0
  stats[:basicCharCount].map { |v| v.to_f * 100.0 / basic_char_count_sum }
else
  Array.new(1600, 0.0)
end

# Render heatmap (keyCount) - requires non-zero key_count_sum
if key_count_sum > 0
  heatmap_path = File.join(out_dir, 'heatmap.png')
  puts "Rendering heatmap -> #{heatmap_path}"
  Renderers.render_heatmap(key_percent, out_path: heatmap_path, width: options[:width],
                           font_path: options[:font_path], font_magick: options[:font_magick],
                           title: 'キー別ヒートマップ', scale: options[:scale])
else
  warn 'keyCount total is zero; skipping heatmap'
end

# Finger stats
finger_map = [0,1,2,3,4,5,6,7,8,9]
finger_labels = ['L小','L薬','L中','L人','L人(R?)','R人','R人(R?)','R中','R薬','R小']
# We need 8 fingers in order left small -> right small per spec: left small, left ring, left middle, left index, right index (x2 columns combined), right middle, right ring, right small
# Build 8 labels
finger_labels8 = ['左小指','左薬指','左中指','左人指','右人指','右中指','右薬指','右小指']
# Map keys to fingers (8): use last digit mapping described in TODO
finger_values = Array.new(8, 0.0)
if key_count_sum > 0
  stats[:keyCount].each_with_index do |v, idx|
    last = idx % 10
    finger_idx = case last
                 when 0 then 0
                 when 1 then 1
                 when 2 then 2
                 when 3 then 3
                 when 4 then 3
                 when 5 then 4
                 when 6 then 4
                 when 7 then 5
                 when 8 then 6
                 when 9 then 7
                 end
    finger_values[finger_idx] += v
  end
  # convert to percent (of key_count_sum)
  finger_percent = finger_values.map { |v| v.to_f * 100.0 / key_count_sum }
  finger_path = File.join(out_dir, 'fingers.png')
  puts "Rendering finger stats -> #{finger_path}"
  Renderers.render_bar_chart(finger_labels8, finger_percent, out_path: finger_path, width: options[:width],
                             font_path: options[:font_path], title: '指の使用率')
else
  warn 'keyCount total is zero; skipping finger stats'
end

# Row stats (by tens digit: 0..3)
if key_count_sum > 0
  rows = [0,0,0,0]
  stats[:keyCount].each_with_index do |v, idx|
    row = (idx / 10).to_i
    rows[row] += v
  end
  row_percent = rows.map { |v| v.to_f * 100.0 / key_count_sum }
  row_labels = ['最上段','上段','中段','下段']
  row_path = File.join(out_dir, 'rows.png')
  puts "Rendering row stats -> #{row_path}"
  Renderers.render_side_bar_chart(row_labels, row_percent, out_path: row_path, width: options[:width],
                                  font_path: options[:font_path], title: '段の使用率')
else
  warn 'keyCount total is zero; skipping row stats'
end

# Panes (RL, RR, LL, LR) - convert to percent of panes sum
panes_sum = stats[:panes].values.sum
if panes_sum > 0
  panes_sorted = stats[:panes].sort_by { |_k,v| -v }
  pane_labels = panes_sorted.map { |k,v| k }
  pane_values = panes_sorted.map { |k,v| v.to_f * 100.0 / panes_sum }
  panes_path = File.join(out_dir, 'panes.png')
  puts "Rendering panes -> #{panes_path}"
  Renderers.render_side_bar_chart(pane_labels, pane_values, out_path: panes_path, width: options[:width],
                                  font_path: options[:font_path], title: 'ペイン使用率')
else
  warn 'panes total is zero; skipping panes chart'
end

# Alternation
alternation_sum = stats[:alternation].values.sum
if alternation_sum > 0
  alt_map = {
    'alternate' => '交互',
    'consecutive' => '連続',
    'first' => '初打'
  }
  alt_sorted = stats[:alternation].sort_by { |_k,v| -v }
  alt_labels = alt_sorted.map { |k,v| alt_map[k] || k }
  alt_values = alt_sorted.map { |k,v| v.to_f * 100.0 / alternation_sum }
  alt_path = File.join(out_dir, 'alternation.png')
  puts "Rendering alternation -> #{alt_path}"
  Renderers.render_side_bar_chart(alt_labels, alt_values, out_path: alt_path, width: options[:width],
                                  font_path: options[:font_path], title: '交互打鍵頻度')
else
  warn 'alternation total is zero; skipping alternation chart'
end

# Bigram
if bigram_sum > 0
  bigram_path = File.join(out_dir, 'bigram.png')
  puts "Rendering bigram -> #{bigram_path}"
  Renderers.render_bigram(bigram_percent, out_path: bigram_path, width: options[:width],
                          font_magick: options[:font_magick], title: 'バイグラムヒートマップ',
                          scale: options[:scale])
else
  warn 'bigram total is zero; skipping bigram chart'
end

# BasicCharCount
if basic_char_count_sum > 0
  basic_chars_path = File.join(out_dir, 'basic_chars.png')
  puts "Rendering basic_chars -> #{basic_chars_path}"
  Renderers.render_basic_chars(basic_char_percent, out_path: basic_chars_path, width: options[:width],
                               font_magick: options[:font_magick], title: '基本文字ヒートマップ',
                               scale: options[:scale])

  # 木を見て森を見るストローク表
  stroke_map_path = File.join(out_dir, 'stroke_map.png')
  puts "Rendering stroke_map -> #{stroke_map_path}"
  Renderers.render_stroke_map(basic_char_percent, out_path: stroke_map_path, width: options[:width],
                              font_magick: options[:font_magick],
                              title: '木を見て森を見るヒートマップ',
                              scale: options[:scale])
else
  warn 'basicCharCount total is zero; skipping basic_chars chart'
end

# top100.txt & percentile.png (basicCharCount + tcode basicTable)
if basic_char_count_sum > 0
  char_table = Tcode.all_chars   # { index => char }

  # 文字ごとにカウントを集計 (■以外・重複キー合算)
  char_count = Hash.new(0)
  stats[:basicCharCount].each_with_index do |cnt, idx|
    next if cnt == 0
    ch = char_table[idx]
    next unless ch
    char_count[ch] += cnt
  end

  # 漢字トップ100
  kanji_sorted = char_count.select { |ch, _| ch =~ /\p{Han}/ }
                            .sort_by { |_, c| -c }
                            .first(100)
  top100_path = File.join(out_dir, 'top100.txt')
  puts "Writing top100 kanji -> #{top100_path}"
  File.write(top100_path, kanji_sorted.map { |ch, _| ch }.join, encoding: 'UTF-8')

  # percentile.png: '■'以外の全文字を頻度降順
  sorted_chars = char_count.sort_by { |_, c| -c }
  percentile_path = File.join(out_dir, 'percentile.png')
  puts "Rendering percentile -> #{percentile_path}"
  Renderers.render_percentile(sorted_chars, out_path: percentile_path, width: options[:width],
                              font_magick: options[:font_magick])
else
  warn 'basicCharCount total is zero; skipping top100/percentile'
end

puts "All done. Output in #{out_dir}"

# Stream histograms
stream_count = stats[:streamCount]
if stream_count.empty?
  warn 'streamCount not found in input files; skipping stream histograms'
else
  stream_count.each do |threshold, histogram|
    next if histogram.sum == 0

    histo_path = File.join(out_dir, "stream-histo-#{threshold}.png")
    puts "Rendering stream histogram (#{threshold}s) -> #{histo_path}"
    Renderers.render_stream_histogram(histogram, out_path: histo_path, threshold: threshold,
                                      width: options[:width], font_path: options[:font_path])

    charcount_path = File.join(out_dir, "stream-charcount-#{threshold}.png")
    puts "Rendering stream charcount (#{threshold}s) -> #{charcount_path}"
    Renderers.render_stream_charcount(histogram, out_path: charcount_path, threshold: threshold,
                                      width: options[:width], font_path: options[:font_path])
  end
end
 
