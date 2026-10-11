# frozen_string_literal: true

require 'sketchup.rb'
require_relative 'config_manager'
require_relative 'html_generator'
require_relative 'counter'

module SkpCm
  module BoQCounter
    # Classmat Suite (old combined plugin) — BoQ now lives in this plugin
    def self.legacy_installed?
      plugins_dir = Sketchup.find_support_file('Plugins')
      !plugins_dir.nil? && File.exist?(File.join(plugins_dir, 'classmat_suite.rb'))
    end

    def self.legacy_message
      plugins_dir = Sketchup.find_support_file('Plugins')
      <<~MSG
        Classmat Suite (old version) is still installed.
        BoQ Counter and Grid Dimension are now separate plugins.
        Your BoQ settings and login have been copied to SKP CM BoQ Counter.

        Please close SketchUp and delete these items from:
        #{plugins_dir}

        - classmat_suite.rb
        - classmat_config.json
        - lib/boq/ (folder)
        - lib/grid/ (folder)
        - lib/core/config_manager.rb
        - icons/boq_icon.png
        - icons/grid_icon.png

        Then restart SketchUp.
      MSG
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
        UI.start_timer(1, false) { UI.messagebox(legacy_message) }
      end

      file_loaded(__FILE__)
    end
  end
end
