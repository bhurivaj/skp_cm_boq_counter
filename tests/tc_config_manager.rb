# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_config_manager.rb
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'

# Minimal stub of the SketchUp API used by ConfigManager
module Sketchup
  class << self
    attr_accessor :platform, :plugins_dir

    def find_support_file(name)
      name == 'Plugins' ? plugins_dir : nil
    end
  end
end

require_relative '../skp_cm_boq_counter/config_manager'

class TestConfigManager < Minitest::Test
  CM = SkpCm::BoQCounter::ConfigManager

  def setup
    @tmp = Dir.mktmpdir
    @old_home = ENV['HOME']
    @old_appdata = ENV['APPDATA']
    ENV['HOME'] = File.join(@tmp, 'home')
    FileUtils.mkdir_p(ENV['HOME'])
    ENV.delete('APPDATA')
    Sketchup.platform = :platform_osx
    Sketchup.plugins_dir = File.join(@tmp, 'Plugins')
    FileUtils.mkdir_p(Sketchup.plugins_dir)
  end

  def teardown
    ENV['HOME'] = @old_home
    if @old_appdata
      ENV['APPDATA'] = @old_appdata
    else
      ENV.delete('APPDATA')
    end
    FileUtils.rm_rf(@tmp)
  end

  def legacy_path
    File.join(Sketchup.plugins_dir, 'classmat_config.json')
  end

  def write_legacy(hash)
    File.write(legacy_path, JSON.generate(hash))
  end

  # --- paths ---

  def test_mac_config_path
    expected = File.join(ENV['HOME'], 'Library', 'Application Support', 'SkpCm', 'boq_counter', 'config.json')
    assert_equal expected, CM.config_file_path
  end

  def test_windows_config_path_uses_appdata
    Sketchup.platform = :platform_win
    ENV['APPDATA'] = File.join(@tmp, 'Roaming')
    assert_equal File.join(@tmp, 'Roaming', 'SkpCm', 'boq_counter', 'config.json'), CM.config_file_path
  end

  def test_windows_without_appdata_falls_back_to_home
    Sketchup.platform = :platform_win
    ENV['APPDATA'] = ''
    expected = File.join(ENV['HOME'], 'AppData', 'Roaming', 'SkpCm', 'boq_counter', 'config.json')
    assert_equal expected, CM.config_file_path
  end

  def test_legacy_config_path_is_in_plugins_folder
    assert_equal legacy_path, CM.legacy_config_path
  end

  def test_legacy_config_path_nil_when_plugins_folder_unknown
    Sketchup.plugins_dir = nil
    assert_nil CM.legacy_config_path
  end

  # --- migration ---

  def test_migrate_copies_legacy_config_and_password_still_decrypts
    write_legacy('username' => 'alice', 'password' => CM.encrypt('s3cret'), 'expected_days_offset' => 7)

    assert_equal true, CM.migrate_legacy_config
    assert File.exist?(CM.config_file_path)
    assert File.exist?(legacy_path), 'legacy file must not be deleted'
    assert_equal({ 'username' => 'alice', 'password' => 's3cret' }, CM.get_credentials)
    assert_equal 7, CM.get('expected_days_offset')
  end

  def test_migrate_does_not_overwrite_existing_config
    CM.save_credentials('new_user', 'new_pass')
    write_legacy('username' => 'old_user', 'password' => CM.encrypt('old_pass'))

    assert_equal false, CM.migrate_legacy_config
    assert_equal 'new_user', CM.get_credentials['username']
  end

  def test_migrate_without_legacy_config_does_nothing
    assert_equal false, CM.migrate_legacy_config
    refute File.exist?(CM.config_file_path)
  end

  def test_migrate_when_plugins_folder_unknown_does_nothing
    Sketchup.plugins_dir = nil
    assert_equal false, CM.migrate_legacy_config
  end

  def test_migrate_failure_returns_false_without_raising
    write_legacy('username' => 'alice')
    # HOME is a regular file → mkdir_p of the data dir must fail
    blocker = File.join(@tmp, 'not_a_dir')
    File.write(blocker, 'x')
    ENV['HOME'] = blocker

    assert_equal false, CM.migrate_legacy_config
  end

  def test_corrupted_legacy_config_falls_back_to_defaults
    File.write(legacy_path, '{"username": "ali')

    assert_equal true, CM.migrate_legacy_config
    assert_equal CM::DEFAULTS['api_base_url'], CM.load_config['api_base_url']
  end

  # --- unchanged behaviour ---

  def test_encrypt_decrypt_round_trip_with_original_key
    assert_equal 'ClassmatSuite2025', CM::ENCRYPTION_KEY
    assert_equal 'pässwörd', CM.decrypt(CM.encrypt('pässwörd')).force_encoding('UTF-8')
  end
end
