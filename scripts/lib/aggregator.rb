# frozen_string_literal: true

require 'json'

class Aggregator
  EXPECTED_KEYCOUNT_LEN = 40
  EXPECTED_BIGRAM_LEN = 1600
  PANE_KEYS = %w[RL RR LL LR]
  ALTERNATION_KEYS = %w[alternate consecutive first]

  attr_reader :key_count, :bigram, :basic_char_count, :panes, :alternation

  def initialize
    @key_count        = Array.new(EXPECTED_KEYCOUNT_LEN, 0)
    @bigram           = Array.new(EXPECTED_BIGRAM_LEN, 0)
    @basic_char_count = Array.new(EXPECTED_BIGRAM_LEN, 0)
    @panes            = Hash[PANE_KEYS.map { |k| [k, 0] }]
    @alternation      = Hash[ALTERNATION_KEYS.map { |k| [k, 0] }]
    @valid_files = 0
  end

  def add_file(path)
    begin
      data = JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      warn "JSON parse error in #{path}: #{e.message}"
      return false
    rescue Errno::ENOENT => e
      warn "File not found: #{path}"
      return false
    end

    # keyCount
    if data['keyCount'].is_a?(Array)
      arr = data['keyCount'].map { |v| to_non_neg_int(v) }
      if arr.length < EXPECTED_KEYCOUNT_LEN
        warn "keyCount length #{arr.length} < #{EXPECTED_KEYCOUNT_LEN}, padding with zeros"
        arr += Array.new(EXPECTED_KEYCOUNT_LEN - arr.length, 0)
      elsif arr.length > EXPECTED_KEYCOUNT_LEN
        warn "keyCount length #{arr.length} > #{EXPECTED_KEYCOUNT_LEN}, truncating"
        arr = arr[0, EXPECTED_KEYCOUNT_LEN]
      end
      @key_count = @key_count.each_with_index.map { |orig, i| orig + arr[i] }
    else
      warn "keyCount missing or invalid in #{path}, treating as zeros"
    end

    # bigram
    if data['bigram'].is_a?(Array)
      b = data['bigram'].map { |v| to_non_neg_int(v) }
      if b.length < EXPECTED_BIGRAM_LEN
        warn "bigram length #{b.length} < #{EXPECTED_BIGRAM_LEN}, padding with zeros"
        b += Array.new(EXPECTED_BIGRAM_LEN - b.length, 0)
      elsif b.length > EXPECTED_BIGRAM_LEN
        warn "bigram length #{b.length} > #{EXPECTED_BIGRAM_LEN}, truncating"
        b = b[0, EXPECTED_BIGRAM_LEN]
      end
      @bigram = @bigram.each_with_index.map { |orig, i| orig + b[i] }
    else
      warn "bigram missing or invalid in #{path}, treating as zeros"
    end

    # basicCharCount
    if data['basicCharCount'].is_a?(Array)
      bc = data['basicCharCount'].map { |v| to_non_neg_int(v) }
      if bc.length < EXPECTED_BIGRAM_LEN
        warn "basicCharCount length #{bc.length} < #{EXPECTED_BIGRAM_LEN}, padding with zeros"
        bc += Array.new(EXPECTED_BIGRAM_LEN - bc.length, 0)
      elsif bc.length > EXPECTED_BIGRAM_LEN
        warn "basicCharCount length #{bc.length} > #{EXPECTED_BIGRAM_LEN}, truncating"
        bc = bc[0, EXPECTED_BIGRAM_LEN]
      end
      @basic_char_count = @basic_char_count.each_with_index.map { |orig, i| orig + bc[i] }
    else
      warn "basicCharCount missing or invalid in #{path}, treating as zeros"
    end

    # panes
    if data['panes'].is_a?(Hash)
      PANE_KEYS.each do |k|
        val = to_non_neg_int(data['panes'][k])
        @panes[k] += val
      end
    else
      warn "panes missing or invalid in #{path}, treating as zeros"
    end

    # alternation
    if data['alternation'].is_a?(Hash)
      ALTERNATION_KEYS.each do |k|
        val = to_non_neg_int(data['alternation'][k])
        @alternation[k] += val
      end
    else
      warn "alternation missing or invalid in #{path}, treating as zeros"
    end

    @valid_files += 1
    true
  end

  def total_counts_zero?
    total = @key_count.sum + @bigram.sum + @basic_char_count.sum +
            @panes.values.sum + @alternation.values.sum
    total == 0
  end

  def summary
    {
      keyCount: @key_count,
      bigram: @bigram,
      basicCharCount: @basic_char_count,
      panes: @panes,
      alternation: @alternation,
      key_count_sum: @key_count.sum,
      bigram_sum: @bigram.sum,
      basic_char_count_sum: @basic_char_count.sum,
      files_used: @valid_files
    }
  end

  private

  def to_non_neg_int(v)
    i = v.to_i
    i < 0 ? 0 : i
  rescue
    0
  end
end
