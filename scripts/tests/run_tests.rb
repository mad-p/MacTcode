#!/usr/bin/env ruby
# frozen_string_literal: true
# scripts/tests/run_tests.rb
# 簡易テスト: Aggregator の動作確認 + scripts/data の JSON を使った統合テスト

$LOAD_PATH.unshift File.join(__dir__, '..', 'lib')
require 'aggregator'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'shellwords'

PASS = "\e[32mPASS\e[0m"
FAIL = "\e[31mFAIL\e[0m"
failures = 0

def assert(desc, result)
  if result
    puts "#{"\e[32mPASS\e[0m"} #{desc}"
  else
    puts "#{"\e[31mFAIL\e[0m"} #{desc}"
    $failures = ($failures || 0) + 1
  end
end

$failures = 0

# ---------------------------------------------------------------------------
# Unit tests: Aggregator
# ---------------------------------------------------------------------------
puts "\n=== Aggregator unit tests ==="

# 正常なJSONを生成してテスト
Dir.mktmpdir do |tmpdir|
  json1 = {
    keyCount: Array.new(40) { |i| i + 1 },
    bigram: Array.new(1600, 1),
    panes: { 'RL' => 10, 'RR' => 20, 'LL' => 5, 'LR' => 15 },
    alternation: { 'alternate' => 100, 'consecutive' => 50, 'first' => 200 },
    lastUpdated: '2026-01-01T00:00:00Z'
  }.transform_keys(&:to_s)

  json2 = {
    keyCount: Array.new(40, 10),
    bigram: Array.new(1600, 2),
    panes: { 'RL' => 5, 'RR' => 5, 'LL' => 5, 'LR' => 5 },
    alternation: { 'alternate' => 10, 'consecutive' => 10, 'first' => 10 },
    lastUpdated: '2026-01-02T00:00:00Z'
  }.transform_keys(&:to_s)

  path1 = File.join(tmpdir, 'a.json')
  path2 = File.join(tmpdir, 'b.json')
  File.write(path1, JSON.generate(json1))
  File.write(path2, JSON.generate(json2))

  agg = Aggregator.new
  assert('add_file returns true for valid JSON', agg.add_file(path1) == true)
  assert('add_file returns true for second valid JSON', agg.add_file(path2) == true)

  s = agg.summary
  # keyCount: 合計 = (1+2+...+40) + 40*10 = 820 + 400 = 1220
  expected_key_sum = (1..40).sum + 40 * 10
  assert("keyCount sum = #{expected_key_sum}", s[:key_count_sum] == expected_key_sum)

  # bigram: 1600*1 + 1600*2 = 4800
  assert('bigram sum = 4800', s[:bigram_sum] == 4800)

  # panes: RL=15, RR=25, LL=10, LR=20
  assert('panes RL=15', s[:panes]['RL'] == 15)
  assert('panes RR=25', s[:panes]['RR'] == 25)

  # alternation
  assert('alternation alternate=110', s[:alternation]['alternate'] == 110)
  assert('alternation first=210', s[:alternation]['first'] == 210)

  # total_counts_zero? は false
  assert('total_counts_zero? is false', !agg.total_counts_zero?)

  # 全0のJSONでテスト
  zero_json = {
    keyCount: Array.new(40, 0),
    bigram: Array.new(1600, 0),
    panes: { 'RL' => 0, 'RR' => 0, 'LL' => 0, 'LR' => 0 },
    alternation: { 'alternate' => 0, 'consecutive' => 0, 'first' => 0 }
  }.transform_keys(&:to_s)
  zero_path = File.join(tmpdir, 'zero.json')
  File.write(zero_path, JSON.generate(zero_json))
  agg_zero = Aggregator.new
  agg_zero.add_file(zero_path)
  assert('total_counts_zero? is true for zero data', agg_zero.total_counts_zero?)

  # 不正JSONのテスト
  bad_path = File.join(tmpdir, 'bad.json')
  File.write(bad_path, 'not json!!!')
  agg_bad = Aggregator.new
  result = agg_bad.add_file(bad_path)
  assert('add_file returns false for invalid JSON', result == false)

  # 存在しないファイル
  result_missing = agg_bad.add_file('/tmp/nonexistent_12345.json')
  assert('add_file returns false for missing file', result_missing == false)

  # 配列長不足（短い）→ゼロ埋め
  short_json = { keyCount: [1, 2, 3], bigram: Array.new(10, 1),
                 panes: { 'RL' => 1, 'RR' => 0, 'LL' => 0, 'LR' => 0 },
                 alternation: { 'alternate' => 1, 'consecutive' => 0, 'first' => 0 } }.transform_keys(&:to_s)
  short_path = File.join(tmpdir, 'short.json')
  File.write(short_path, JSON.generate(short_json))
  agg_short = Aggregator.new
  assert('add_file returns true for short arrays (with warning)', agg_short.add_file(short_path))
  assert('short keyCount[0]=1', agg_short.summary[:keyCount][0] == 1)
  assert('short keyCount[39]=0 (padded)', agg_short.summary[:keyCount][39] == 0)

  # 負の値 → 0 に補正
  neg_json = { keyCount: Array.new(40) { |i| i.odd? ? -5 : 1 },
               bigram: Array.new(1600, 0),
               panes: { 'RL' => -1, 'RR' => 0, 'LL' => 0, 'LR' => 0 },
               alternation: { 'alternate' => 0, 'consecutive' => 0, 'first' => 0 } }.transform_keys(&:to_s)
  neg_path = File.join(tmpdir, 'neg.json')
  File.write(neg_path, JSON.generate(neg_json))
  agg_neg = Aggregator.new
  agg_neg.add_file(neg_path)
  assert('negative keyCount values clamped to 0', agg_neg.summary[:keyCount][1] == 0)
  assert('negative pane value clamped to 0', agg_neg.summary[:panes]['RL'] == 0)
end

# ---------------------------------------------------------------------------
# Integration test: actual data files
# ---------------------------------------------------------------------------
puts "\n=== Integration test (scripts/data) ==="

data_dir = File.join(__dir__, '..', 'data')
json_files = Dir[File.join(data_dir, '*.json')]

if json_files.empty?
  puts "#{"\e[33mSKIP\e[0m"} No JSON files found in scripts/data/"
else
  Dir.mktmpdir do |out_dir|
    cmd = [
      'bundle', 'exec', 'ruby',
      File.join(__dir__, '..', 'plot_strokes.rb'),
      '--out-dir', out_dir,
      '--width', '400',  # 小さいサイズで高速にテスト
      *json_files
    ]
    output = `cd #{File.join(__dir__, '..')} && #{cmd.shelljoin} 2>&1`
    exit_code = $?.exitstatus

    assert('script exits with code 0', exit_code == 0)

    %w[heatmap.png fingers.png rows.png panes.png alternation.png bigram.png basic_chars.png stroke_map.png percentile.png].each do |fname|
      path = File.join(out_dir, fname)
      assert("#{fname} was generated", File.exist?(path) && File.size(path) > 1000)
    end
    top100_path = File.join(out_dir, 'top100.txt')
    assert('top100.txt was generated', File.exist?(top100_path) && File.size(top100_path) > 0)
  end
end

# ---------------------------------------------------------------------------
# Integration test: zero-total cancels PNG generation
# ---------------------------------------------------------------------------
puts "\n=== Zero-total cancellation test ==="

Dir.mktmpdir do |tmpdir|
  zero_json = {
    keyCount: Array.new(40, 0),
    bigram: Array.new(1600, 0),
    panes: { 'RL' => 0, 'RR' => 0, 'LL' => 0, 'LR' => 0 },
    alternation: { 'alternate' => 0, 'consecutive' => 0, 'first' => 0 }
  }.transform_keys(&:to_s)
  zero_path = File.join(tmpdir, 'zero.json')
  File.write(zero_path, JSON.generate(zero_json))

  out_dir = File.join(tmpdir, 'out')
  FileUtils.mkdir_p(out_dir)
  cmd = "cd #{File.join(__dir__, '..')} && bundle exec ruby plot_strokes.rb --out-dir #{out_dir} #{zero_path} 2>&1"
  output = `#{cmd}`
  exit_code = $?.exitstatus

  assert('script exits with code 2 for zero-total input', exit_code == 2)
  pngs = Dir[File.join(out_dir, '*.png')]
  assert('no PNGs generated for zero-total input', pngs.empty?)
end

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
puts "\n=== Results ==="
if $failures == 0
  puts "\e[32mAll tests passed!\e[0m"
else
  puts "\e[31m#{$failures} test(s) failed.\e[0m"
  exit 1
end
