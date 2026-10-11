# frozen_string_literal: true

module SkpCm
  module BoQCounter
    # Warning shown while Classmat Suite (old combined plugin) is still installed.
    # Never tell the user to delete classmat_config.json while it is the only copy of their settings.
    # config_status:
    #   :copied — new config exists, classmat_config.json can be deleted
    #   :failed — classmat_config.json exists but could not be copied; it is still the only copy
    #   :none   — there is no classmat_config.json
    def self.legacy_message(plugins_dir, config_status)
      config_note =
        case config_status
        when :copied then "Your BoQ settings and login have been copied to SKP CM BoQ Counter.\n"
        when :failed then "Keep classmat_config.json for now — your BoQ settings could not be copied (see Ruby Console).\n"
        else ''
        end
      config_item = config_status == :copied ? "- classmat_config.json\n" : ''

      <<~MSG
        Classmat Suite (old version) is still installed.
        BoQ Counter and Grid Dimension are now separate plugins.
        #{config_note}
        Please close SketchUp and delete these items from:
        #{plugins_dir}

        - classmat_suite.rb
        #{config_item}- lib/boq/ (folder)
        - lib/grid/ (folder)
        - lib/core/config_manager.rb
        - icons/boq_icon.png
        - icons/grid_icon.png

        Then restart SketchUp.
      MSG
    end
  end
end
