#!/usr/bin/env ruby
# frozen_string_literal: true

# JSONL 打鍵ログを、オーソリニア配列キーボード付きアニメーション GIF に変換する。
# 描画（SVG）とエンコード（ImageMagick）を分離し、将来の WebP / MP4 出力に備える。

require 'json'
require 'optparse'
require 'tmpdir'
require 'fileutils'
require 'cgi'

class KeystrokeVisualizer
  KEY_ROWS = [
    %w[1 2 3 4 5 6 7 8 9 0],
    %w[q w e r t y u i o p],
    %w[a s d f g h j k l ;],
    %w[z x c v b n m , . /]
  ].freeze
  # KEY_ROWS を物理的に押下したときの macOS virtual key code。Dvorak などの入力配列とは独立している。
  KEYCODES = [
    18, 19, 20, 21, 23, 22, 26, 28, 25, 29,
    12, 13, 14, 15, 17, 16, 32, 34, 31, 35,
     0,  1,  2,  3,  5,  4, 38, 40, 37, 41,
     6,  7,  8,  9, 11, 45, 46, 43, 47, 44
  ].freeze
  FUNCTION_KEYS = %w[escape space delete enter cancel].freeze

  def initialize(events, fps:, highlight_frames:, width:)
    @events = events.sort_by { |event| [event.fetch('elapsedMilliseconds', 0), event.fetch('sequence', 0)] }
    @fps = fps
    @highlight_frames = highlight_frames
    @width = width
  end

  def duration_milliseconds
    last = @events.map { |event| event.fetch('elapsedMilliseconds', 0) }.max || 0
    [last + (1000.0 * @highlight_frames / @fps).ceil, 1000].max
  end

  def frame_count
    (duration_milliseconds * @fps / 1000.0).ceil + 1
  end

  def summary
    {
      'eventCount' => @events.length,
      'frameCount' => frame_count,
      'durationMilliseconds' => duration_milliseconds,
      'fps' => @fps,
      'keyHighlightFrames' => @highlight_frames
    }
  end

  def write_frames(directory)
    state = { text: '', mode: 'tcode', pending: '', highlighted_until: {}, last_key_input: nil }
    event_index = 0
    total_frames = frame_count
    total_frames.times do |frame_index|
      at = (frame_index * 1000.0 / @fps).round
      while event_index < @events.length && @events[event_index].fetch('elapsedMilliseconds', 0) <= at
        apply(@events[event_index], state, frame_index)
        event_index += 1
      end
      path = File.join(directory, format('frame-%06d.svg', frame_index))
      File.write(path, svg(state, at, frame_index))
    end
  end

  private

  def apply(event, state, frame_index)
    case event['type']
    when 'keyInput'
      state[:last_key_input] = event
      key = key_name(event)
      state[:highlighted_until][key] = frame_index + @highlight_frames if key
    when 'passthrough'
      apply_passthrough(state[:last_key_input], state)
    when 'modeChanged'
      state[:mode] = event['mode'] || state[:mode]
    when 'pendingChanged'
      state[:pending] = event['keys'] || ''
    when 'textCommitted'
      state[:text] += event['text'].to_s
    when 'textDeleted'
      delete = event['text'].to_s
      state[:text] = if !delete.empty? && state[:text].end_with?(delete)
                       state[:text][0...-delete.length]
                     else
                       state[:text][0...-1].to_s
                     end
    when 'textReplaced'
      old = event['replacedText'].to_s
      state[:text] = state[:text][0...-old.length].to_s if !old.empty? && state[:text].end_with?(old)
      state[:text] += event['text'].to_s
    when 'pendingKakuteiCancel'
      state[:highlighted_until]['cancel'] = frame_index + @highlight_frames
    end
    state[:text] = state[:text].each_char.to_a.last(40).join
  end

  def key_name(event)
    case event['keyType']
    when 'space', 'delete', 'escape', 'enter'
      event['keyType']
    else
      keycode = event['keyCode']
      return unless keycode

      index = KEYCODES.index(keycode.to_i)
      index && "key-#{index}"
    end
  end

  def apply_passthrough(event, state)
    return unless event

    case event['keyType']
    when 'printable'
      state[:text] += event['text'].to_s
    when 'delete'
      state[:text] = state[:text].each_char.to_a[0...-1].join
    end
  end

  def svg(state, elapsed, frame_index)
    height = 560
    cell = ((@width - 80) / 12.0).floor
    key_height = 54
    keyboard = KEY_ROWS.each_with_index.map do |row, row_index|
      row.map.with_index do |_key, column|
        key = "key-#{row_index * 10 + column}"
        key_svg(key, 40 + column * cell, 160 + row_index * (key_height + 12), cell - 8, key_height, state, frame_index)
      end.join
    end.join
    functions = [
      ['escape', 'Esc', 40], ['space', 'Space', 160], ['delete', 'Delete', 400], ['enter', 'Enter', 540], ['cancel', 'Cancel', 680]
    ].map { |key, label, x| key_svg(key, x, 435, key == 'space' ? 220 : 100, key_height, state, frame_index, label) }.join

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{height}" viewBox="0 0 #{@width} #{height}">
        <rect width="100%" height="100%" fill="#1d1f21"/>
        <text x="40" y="48" fill="#ffffff" font-family="Hiragino Sans, sans-serif" font-size="26">MacTcode 打鍵ログ</text>
        <text x="40" y="82" fill="#cccccc" font-family="Menlo, monospace" font-size="19">#{format_time(elapsed)}   mode: #{escape(state[:mode])}   pending: #{escape(state[:pending])}</text>
        <rect x="40" y="96" width="#{@width - 80}" height="42" rx="6" fill="#303236"/>
        <text x="54" y="124" fill="#ffffff" font-family="Hiragino Sans, sans-serif" font-size="22">#{escape(state[:text])}</text>
        #{keyboard}
        #{functions}
      </svg>
    SVG
  end

  def key_svg(key, x, y, width, height, state, frame_index, label = nil)
    active = state[:highlighted_until][key].to_i > frame_index
    fill = active ? '#d9534f' : '#e6e6e6'
    label_svg = if label
                  foreground = active ? '#ffffff' : '#222222'
                  <<~SVG
                    <text x="#{x + width / 2}" y="#{y + height / 2 + 7}" text-anchor="middle" fill="#{foreground}" font-family="Menlo, monospace" font-size="20">#{escape(label)}</text>
                  SVG
                else
                  ''
                end
    <<~SVG
      <rect x="#{x}" y="#{y}" width="#{width}" height="#{height}" rx="7" fill="#{fill}"/>
      #{label_svg}
    SVG
  end

  def format_time(milliseconds)
    seconds = milliseconds / 1000
    format('%02d:%02d:%02d', seconds / 3600, (seconds / 60) % 60, seconds % 60)
  end

  def escape(text)
    CGI.escapeHTML(text.to_s)
  end
end

def read_events(path)
  events = []
  File.readlines(path, chomp: true).each_with_index do |line, index|
    next if line.empty?
    begin
      event = JSON.parse(line)
      raise "line #{index + 1}: JSON object is required" unless event.is_a?(Hash)
      events << event
    rescue JSON::ParserError => error
      raise "line #{index + 1}: invalid JSON: #{error.message}"
    end
  end
  events
end

def output_path(input, output, type)
  path = output || input.sub(/\.jsonl\z/i, '')
  unless /\.#{type}$/ =~ path
    path += ".#{type}"
  end
  puts "output_path: input=#{input}  output=#{output}  type=#{type}  path=#{path}"
  path
end

def command_available?(name)
  system('which', name, out: File::NULL, err: File::NULL)
end

options = { fps: 30, highlight_frames: 9, width: 1000, type: 'mp4' }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: visualize_keystrokes.rb INPUT.jsonl [options]'
  opts.on('-o', '--output FILE', '出力ファイル（拡張子省略時は --type を使用）') { |value| options[:output] = value }
  opts.on('-t', '--type TYPE', %w[gif mp4], '出力形式: gif または mp4（既定: mp4）') { |value| options[:type] = value }
  opts.on('--fps N', Integer, 'FPS（既定: 30）') { |value| options[:fps] = value }
  opts.on('-h', '--key-highlight-frames N', Integer, '打鍵キーの強調フレーム数（既定: 9）') { |value| options[:highlight_frames] = value }
  opts.on('--width N', Integer, '出力幅 px（既定: 1000）') { |value| options[:width] = value }
  opts.on('--dry-run', 'GIF を生成せず再生概要を JSON で出力') { options[:dry_run] = true }
end
parser.parse!
input = ARGV.shift or abort(parser.to_s)
abort('入力ファイルは1つだけ指定してください') unless ARGV.empty?
abort('--fps は1以上で指定してください') unless options[:fps].positive?
abort('--key-highlight-frames は1以上で指定してください') unless options[:highlight_frames].positive?
abort('--width は400以上で指定してください') if options[:width] < 400
unless command_available?('magick')
  abort('ImageMagick の magick コマンドが必要です。例: brew install imagemagick')
end
if options[:type] == 'mp4' && !command_available?('ffmpeg')
  abort('MP4 出力には ffmpeg コマンドが必要です。例: brew install ffmpeg')
end

visualizer = KeystrokeVisualizer.new(read_events(input), fps: options[:fps], highlight_frames: options[:highlight_frames], width: options[:width])
if options[:dry_run]
  puts JSON.generate(visualizer.summary)
  exit 0
end

output = output_path(input, options[:output], options[:type])
Dir.mktmpdir('mactcode-visualizer') do |directory|
  puts "Generating #{visualizer.frame_count} frames at #{options[:fps]} FPS..."
  visualizer.write_frames(directory)
  frames = File.join(directory, 'frame-*.svg')
  gif_output = options[:type] == 'gif' ? output : File.join(directory, 'animation.gif')
  delay = [(100.0 / options[:fps]).round, 1].max
  success = system('magick', '-delay', delay.to_s, '-loop', '0', frames, gif_output)
  abort('GIF のエンコードに失敗しました') unless success
  if options[:type] == 'mp4'
    puts "Encoding to #{output} ..."
    abort('MP4 のエンコードに失敗しました') unless system('ffmpeg', '-y', '-i', gif_output, output)
  end
end
puts "Generated #{output} (#{visualizer.frame_count} frames at #{options[:fps]} FPS)"
