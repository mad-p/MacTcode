# frozen_string_literal: true

require 'json'

# T-Code 設定ファイルを読み込み、basicTable を元に
# インデックス (0..1599) から対応する文字を返すユーティリティ。
module Tcode
  CONFIG_PATHS = [
    File.expand_path(
      '~/Library/Containers/jp.mad-p.inputmethod.MacTcode/Data/' \
      'Library/Application Support/MacTcode/config.json'
    ),
    File.expand_path(
      File.join(__dir__, '..', '..', 'sample-config.json')
    )
  ].freeze

  # basicTable を読み込んで返す。
  # 戻り値: 40 要素の配列。各要素は 40 文字の文字列。
  # 見つからない場合は nil を返す。
  def self.load_basic_table
    CONFIG_PATHS.each do |path|
      next unless File.exist?(path)

      begin
        data = JSON.parse(File.read(path))
        table = data.dig('keyBindings', 'basicTable')
        next unless table.is_a?(Array) && !table.empty?

        return table
      rescue JSON::ParserError => e
        warn "Tcode: JSON parse error in #{path}: #{e.message}"
      end
    end
    nil
  end

  # basicTable のキャッシュ付きアクセサ
  def self.basic_table
    @basic_table ||= load_basic_table
  end

  # インデックス i (0..1599) に対応する文字を返す。
  # i = k1 * 40 + k2 のとき basicTable[k2][k1] が対応文字。
  # basic_table が nil か範囲外の場合は nil を返す。
  def self.index_to_char(i)
    table = basic_table
    return nil unless table

    k1 = i / 40
    k2 = i % 40
    row = table[k2]
    return nil unless row.is_a?(String)

    ch = row[k1]
    ch == '■' ? nil : ch
  end

  # 0..1599 の全インデックスを { index => char } のハッシュで返す。
  # '■' および basicTable に存在しないエントリは除外する。
  def self.all_chars
    (0...1600).each_with_object({}) do |i, h|
      ch = index_to_char(i)
      h[i] = ch if ch
    end
  end
end
