# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_legacy_message.rb
require 'minitest/autorun'
require_relative '../skp_cm_boq_counter/legacy'

class TestLegacyMessage < Minitest::Test
  def msg(config_status)
    SkpCm::BoQCounter.legacy_message('/Plugins', config_status)
  end

  def test_copied_config_is_listed_for_deletion
    text = msg(:copied)
    assert_includes text, 'Your BoQ settings and login have been copied'
    assert_includes text, '- classmat_config.json'
  end

  def test_failed_copy_tells_user_to_keep_config
    text = msg(:failed)
    refute_includes text, 'have been copied'
    refute_includes text, '- classmat_config.json'
    assert_includes text, 'Keep classmat_config.json'
  end

  def test_no_legacy_config_mentions_nothing_about_it
    text = msg(:none)
    refute_includes text, 'classmat_config.json'
    refute_includes text, 'have been copied'
  end

  def test_message_names_plugins_folder_and_old_files
    text = msg(:copied)
    assert_includes text, '/Plugins'
    assert_includes text, '- classmat_suite.rb'
    assert_includes text, '- lib/grid/ (folder)'
  end
end
