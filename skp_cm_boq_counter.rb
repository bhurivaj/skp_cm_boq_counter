# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module SkpCm
  module BoQCounter
    PLUGIN_NAME = 'SKP CM BoQ Counter'
    VERSION = '2.0.1'

    file = __FILE__.dup
    file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)
    PLUGIN_DIR = File.join(File.dirname(file), 'skp_cm_boq_counter').freeze

    unless file_loaded?(__FILE__)
      ext = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_DIR, 'main'))
      ext.description = 'Count components and generate Bill of Quantities reports.'
      ext.version = VERSION
      ext.creator = 'Bhurivaj Padcharaditthakul'
      ext.copyright = '© 2026 Bhurivaj Padcharaditthakul'
      Sketchup.register_extension(ext, true)
      file_loaded(__FILE__)
    end
  end
end
