#!/usr/bin/ruby

class TextFile
  FILE_NAME_EXT = ['yaml', 'yml']

  def initialize(file_name)
    @file_name = file_name
    @lines = Array.new

    pre_file_check(@file_name)

    file = File.open(@file_name)
    file.each_line do |line|
      @lines << line
    end
  end

  def pre_file_check(file_name)
    extension = File.extname(file_name)
    if extension.empty?
      raise "#{file_name} with no extension"
    end

    ext = extension.downcase[1..extension.length]
    unless FILE_NAME_EXT.include? ext
      raise "#{file_name} with wrong extension"
    end

    unless File.exist? file_name
      raise "#{file_name} not exists"
    end
  end

  def validate_as_yaml
    YamlValidator.new(@lines).validate
  end
end

class YamlValidator
  STATE_TRANSITION = {:mapping => [:mapping, :sequence, :value], :sequence => [:mapping, :value]}

  REG_EXP = {
      :invalid_char => /\t/,
      :mapping => /(^\s*\w+:\s)(.*)/,
      :value => /^[^-]*(\s|\w)$/,
      :comment => /---/,
      :sequence => /^( *-\s)(.*)/
  }
  INDENT = /(\s*)(\w|- )+/

  def initialize(lines)
    @lines = lines
  end

  def validate
    @result = 'File is valid'
    begin
      @grouped_lines_by_indent = group_lines_by_indent(@lines)

      @grouped_lines_by_indent.each_with_index do |grouped_lines, index|

        @last_scalar_pos = -1
        @last_sequence_pos = -1
        @strict_pos = -1          # Position to compare following values with

        valid_keys = REG_EXP.keys

        grouped_lines.each do |line|
          line_is_valid = false

          REG_EXP.each { |key, reg_exp|

            next unless valid_keys.include? key

            unless line_is_valid
              case key
                when :invalid_char
                  line.scan(reg_exp) { |match| raise "Not allowed #{match} character in line #{index + 1}" }

                when :comment
                  line_is_valid = true

                when :mapping
                  line.scan(reg_exp) do |match|

                    @strict_pos = get_current_indent(line)
                    @last_squalar_pos = @strict_pos if @last_scalar_pos == -1

                    valid_keys = STATE_TRANSITION[:mapping]
                    unless rest_of_line_valid?(valid_keys, match[1])
                      raise "Mapping error: #{match[1]} in line #{line.to_s}"
                    end

                    if @last_scalar_pos > -1 && @strict_pos > -1
                      raise "Indentation error in line #{line.to_s}" if @strict_pos != @last_scalar_pos
                    end
                    line_is_valid = true
                  end

                when :sequence
                  line.scan(reg_exp) do |match|

                    @strict_pos = match[0].size
                    @last_sequence_pos = @strict_pos if @last_sequence_pos == -1
                    @last_scalar_pos = -1

                    valid_keys = STATE_TRANSITION[:sequence]
                    unless rest_of_line_valid?(valid_keys, match[1])
                      raise "Sequence error: #{match[1]} in line #{line.to_s}"
                    end

                    if @last_sequence_pos > -1 && @strict_pos > -1
                      raise "Indentation error in line #{line.to_s}" if @strict_pos != @last_sequence_pos
                    end
                    line_is_valid = true
                  end

                when :value
                  line.scan(reg_exp) do |match|
                    line_is_valid = true
                  end

                else
                  raise "Unhandled key #{key} in line #{line}"
              end
            end
          }
          raise "Parsing error in line #{line}" unless line_is_valid
        end
      end
    rescue => ex
      @result = "#{ex.message}"
    end
    @result
  end

  def rest_of_line_valid?(valid_keys, value)
    valid = false
    valid_keys.each do |new_key|
      new_exp = REG_EXP[new_key]
      if new_exp =~ value || value.to_s.empty?
        # puts "value_valid? key: #{new_key} value: #{value}"
        if new_key == :mapping
          @strict_pos += get_current_indent(value)
          @last_scalar_pos = @strict_pos if @last_scalar_pos == -1
        end
        valid = true
        break
      end
    end
    valid
  end

  def group_lines_by_indent(lines)
    grouped_lines_by_indent = Array.new

    first_indent = get_first_indent(lines)
    group = []
    lines.each do |line|
      current_indent = -1
      if (match = line.match(INDENT))
        current_indent = match.captures[0].size
      end
      if current_indent > first_indent || current_indent == -1
        group.push(line)
      else
        grouped_lines_by_indent.push(group)
        group = [line]
      end
    end
    grouped_lines_by_indent.push(group)
  end

  def get_current_indent(line)
    indent = -1
    if (match = line.match(INDENT))
      indent = match.captures[0].size
    end
    indent
  end

  def get_first_indent(lines)
    indent = -1
    lines.each { |line|
        if (indent = get_current_indent(line)) >= 0
        break
      end
    }
    indent
  end
end

ARGV[0] = 'sample.yaml'
puts (TextFile.new (ARGV[0])).validate_as_yaml if $0 == __FILE__

