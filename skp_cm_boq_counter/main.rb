# frozen_string_literal: true

require 'sketchup.rb'
require_relative 'config_manager'
require_relative 'html_generator'
require_relative 'counter'
require_relative 'legacy'

module SkpCm
  module BoQCounter
    # Classmat Suite (old combined plugin) — BoQ now lives in this plugin
    def self.legacy_installed?
      plugins_dir = Sketchup.find_support_file('Plugins')
      !plugins_dir.nil? && File.exist?(File.join(plugins_dir, 'classmat_suite.rb'))
    end

    # Status for legacy_message, based on what is on disk after migration
    def self.legacy_config_status
      legacy = ConfigManager.legacy_config_path
      return :none if legacy.nil? || !File.exist?(legacy)

      File.exist?(ConfigManager.config_file_path) ? :copied : :failed
    end

    unless file_loaded?(__FILE__)
      # Must run before the legacy warning: the user may delete classmat_config.json right after reading it
      ConfigManager.migrate_legacy_config

      toolbar = UI::Toolbar.new('SKP CM BoQ')

      cmd = UI::Command.new('BoQ Counter') { Counter.generate_boq }
      cmd.tooltip = 'Generate Bill of Quantities'
      icon = File.join(PLUGIN_DIR, 'icons', 'boq_icon.png')
      cmd.large_icon = cmd.small_icon = icon if File.exist?(icon)
      toolbar.add_item(cmd)
      toolbar.show

      if legacy_installed?
        message = legacy_message(Sketchup.find_support_file('Plugins'), legacy_config_status)
        # Stop the timer first: a modal dialog inside a non-repeating timer makes it repeat (SketchUp API bug)
        timer_id = UI.start_timer(1, false) do
          UI.stop_timer(timer_id)
          UI.messagebox(message)
        end
      end

      file_loaded(__FILE__)
    end
  end
end
