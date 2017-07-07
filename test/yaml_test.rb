require 'minitest/autorun'
load 'yaml_validator.rb'

$RESULT_OK = 'File is valid'

class YamlTest < MiniTest::Unit::TestCase

  def setup
    @yaml_validator = YamlValidator.new([])
  end

  def test_mapping_value
    assert_equal $RESULT_OK, YamlValidator.new(['sample: file']).validate
  end

  def test_mapping_sequence
    assert_equal $RESULT_OK, YamlValidator.new(['sample:\n-']).validate
  end

  def test_mapping_nok
    assert $RESULT_OK != YamlValidator.new(['sample: file:']).validate
  end

  def test_group_lines_by_indent
    assert_equal 4, @yaml_validator.send("group_lines_by_indent", ['---', 'sample: file', 'list:', '    item 1', '    item 2', 'items:']).size
  end

end

