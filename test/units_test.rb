# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'

ENV['XDG_CONFIG_HOME'] ||= Dir.mktmpdir
ENV['GSETTINGS_BACKEND'] = 'memory'

require 'curtail_rb'

# A stand-in for the GSettings-backed Settings, so the pure logic can be
# exercised without a schema or a main loop.
class FakeSettings
  ATTRS = CurtailRb::Settings::KEYS.keys.map { |key| key.tr('-', '_') }

  attr_accessor(*ATTRS)

  DEFAULTS = {
    new_file:            true,
    naming_mode:         0,
    recursive:           true,
    metadata:            true,
    file_attributes:     true,
    lossy:               false,
    suffix_prefix:       '-min',
    png_lossy_level:     90,
    png_lossless_level:  2,
    jpg_lossy_level:     90,
    webp_lossy_level:    70,
    webp_lossless_level: 4,
    jpg_progressive:     false,
    svg_maximum_level:   false,
    compression_timeout: 30,
  }.freeze

  def initialize(**overrides)
    DEFAULTS.merge(overrides).each { |key, value| send("#{key}=", value) }
  end
end

def item(filename:, tmp: '/tmp/.out.tmp', mime: 'image/png')
  CurtailRb::ResultItem.new.tap do |result|
    result.filename = filename
    result.tmp_filename = tmp
    result.mime_type = mime
  end
end

class SettingsKeysTest < Minitest::Test
  def test_every_gschema_key_has_an_accessor
    xml = File.read(CurtailRb::Paths.schema_file)
    keys = xml.scan(/name="([a-z0-9-]+)"/).flatten - ['curtail']

    keys.each do |key|
      assert_includes CurtailRb::Settings::KEYS.keys, key
    end
  end

  def test_accessors_are_generated_for_every_key
    CurtailRb::Settings::KEYS.each_key do |key|
      assert CurtailRb::Settings.method_defined?(key.tr('-', '_'))
      assert CurtailRb::Settings.method_defined?("#{key.tr('-', '_')}=")
    end
  end
end

class NewFilenameTest < Minitest::Test
  def build_for(settings, path)
    CurtailRb::ResultItemManager.new(settings).create_new_filename(path)
  end

  def test_suffix_mode
    assert_equal '/pics/cat-min.png',
      build_for(FakeSettings.new, '/pics/cat.png')
  end

  def test_prefix_mode
    assert_equal '/pics/-mincat.png',
      build_for(FakeSettings.new(naming_mode: 1), '/pics/cat.png')
  end

  def test_overwrite_mode_keeps_the_path
    assert_equal '/pics/cat.png',
      build_for(FakeSettings.new(new_file: false), '/pics/cat.png')
  end

  def test_a_dotted_name_only_splits_the_last_extension
    assert_equal '/pics/my.cat-min.png',
      build_for(FakeSettings.new, '/pics/my.cat.png')
  end

  def test_a_name_with_no_extension
    assert_equal '/pics/cat-min', build_for(FakeSettings.new, '/pics/cat')
  end
end

class CommandTest < Minitest::Test
  def command(settings, **kwargs)
    CurtailRb::Compressor.build_command(item(**kwargs), settings)
  end

  def test_png_lossless_is_oxipng_alone
    command(FakeSettings.new, filename: '/a/b.png').then do |cmd|
      assert_match(/\Aoxipng -o 2 -i 1 /, cmd)
      refute_includes cmd, 'pngquant'
    end
  end

  def test_png_lossy_chains_pngquant_into_oxipng
    command(FakeSettings.new(lossy: true), filename: '/a/b.png').then do |cmd|
      assert_match(/\Apngquant --quality=0-90 /, cmd)
      assert_includes cmd, ' && oxipng'
    end
  end

  def test_png_strips_metadata_when_asked
    command(FakeSettings.new(metadata: false), filename: '/a/b.png')
      .then { |cmd| assert_includes cmd, '--strip safe' }
  end

  def test_png_preserves_attributes_when_asked
    command(FakeSettings.new, filename: '/a/b.png')
      .then { |cmd| assert_includes cmd, '--preserve' }
  end

  def test_jpeg_lossless_omits_the_quality_flag
    command(FakeSettings.new, filename: '/a/b.jpg', mime: 'image/jpeg')
      .then do |cmd|
        assert_match(/\Ajpegoptim -o --stdout /, cmd)
        refute_includes cmd, '--max='
      end
  end

  def test_jpeg_lossy_sets_the_quality
    command(
      FakeSettings.new(lossy: true),
      filename: '/a/b.jpg',
      mime:     'image/jpeg',
    )
      .then { |cmd| assert_includes cmd, '--max=90' }
  end

  def test_jpeg_progressive
    command(
      FakeSettings.new(jpg_progressive: true),
      filename: '/a/b.jpg',
      mime:     'image/jpeg',
    )
      .then { |cmd| assert_includes cmd, '--all-progressive' }
  end

  def test_webp_lossless_pins_quality_to_100
    command(FakeSettings.new, filename: '/a/b.webp', mime: 'image/webp')
      .then do |cmd|
        assert_includes cmd, '-lossless'
        assert_includes cmd, '-q 100'
        assert_includes cmd, '-m 4'
      end
  end

  def test_webp_lossy_uses_its_own_level
    command(
      FakeSettings.new(lossy: true),
      filename: '/a/b.webp',
      mime:     'image/webp',
    )
      .then do |cmd|
        refute_includes cmd, '-lossless'
        assert_includes cmd, '-q 70'
      end
  end

  def test_webp_metadata_is_opt_in
    command(FakeSettings.new, filename: '/a/b.webp', mime: 'image/webp')
      .then { |cmd| assert_includes cmd, '-metadata all' }
    command(
      FakeSettings.new(metadata: false),
      filename: '/a/b.webp',
      mime:     'image/webp',
    )
      .then { |cmd| refute_includes cmd, '-metadata' }
  end

  def test_svg_maximum_level_adds_the_aggressive_flags
    command(FakeSettings.new, filename: '/a/b.svg', mime: 'image/svg+xml')
      .then { |cmd| refute_includes cmd, '--shorten-ids' }
    command(
      FakeSettings.new(svg_maximum_level: true),
      filename: '/a/b.svg',
      mime:     'image/svg+xml',
    )
      .then { |cmd| assert_includes cmd, '--shorten-ids' }
  end

  # The whole reason the command is a shell string: a filename with a space or
  # a quote in it must not become two arguments.
  def test_filenames_are_quoted
    command(FakeSettings.new, filename: "/a/my pic'; rm -rf x.png")
      .then do |cmd|
        refute_includes cmd, '; rm -rf x.png '
        assert_includes cmd, Shellwords.escape("/a/my pic'; rm -rf x.png")
      end
  end
end

class ExecuteTest < Minitest::Test
  def test_success_reports_nothing
    assert_nil CurtailRb::Compressor.execute('true', FakeSettings.new)
  end

  def test_failure_reports_the_output
    CurtailRb::Compressor.execute('echo boom >&2; false', FakeSettings.new)
      .then do |message, details|
        assert_equal 'An unknown error has occurred.', message
        assert_includes details, 'boom'
      end
  end

  # The point of not using Timeout.timeout: the child has to actually die.
  def test_a_hung_command_times_out_and_is_killed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    CurtailRb::Compressor
      .execute('sleep 30', FakeSettings.new(compression_timeout: 1))
      .then do |message, details|
        assert_includes message, 'timeout of 1 seconds'
        assert_nil details
      end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :<, 10
  end

  def test_details_are_escaped_for_the_markup_popover
    CurtailRb::Compressor.execute(
      'echo "<b>&</b>" >&2; false',
      FakeSettings.new,
    )
      .then do |_message, details|
        assert_includes details, '&lt;b&gt;'
        assert_includes details, '&amp;'
      end
  end
end

class ToolsTest < Minitest::Test
  def test_extract_version_finds_a_three_part_version
    assert_equal '1.5.6',
      CurtailRb::Tools.extract_version('jpegoptim v1.5.6 x86_64')
  end

  def test_extract_version_falls_back
    assert_equal CurtailRb::Tools::NOT_FOUND,
      CurtailRb::Tools.extract_version('no version here')
  end

  def test_scaled_size_preserves_aspect_landscape
    assert_equal [48, 24],
      CurtailRb::Tools.scaled_size(
        200,
        100,
        48,
        48,
      )
  end

  def test_scaled_size_preserves_aspect_portrait
    assert_equal [24, 48],
      CurtailRb::Tools.scaled_size(
        100,
        200,
        48,
        48,
      )
  end

  def test_scaled_size_square
    assert_equal [48, 48],
      CurtailRb::Tools.scaled_size(
        100,
        100,
        48,
        48,
      )
  end

  def test_five_filters_in_upstream_order
    assert_equal ['All images', 'PNG images', 'JPEG images', 'WebP images',
                  'SVG images'
],
      CurtailRb::Tools::FILTERS.map(&:first)
  end
end

class ResultItemTest < Minitest::Test
  def test_set_error_marks_and_messages
    CurtailRb::ResultItem.new.tap do |result|
      result.set_error('nope')
      assert result.error
      assert_equal 'nope', result.error_message
    end
  end

  def test_starts_running
    assert CurtailRb::ResultItem.new.running
  end
end
