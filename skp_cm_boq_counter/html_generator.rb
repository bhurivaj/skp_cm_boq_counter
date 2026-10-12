# frozen_string_literal: true

require 'json'

module SkpCm
  module BoQCounter
    # Builds the report page: report.html with report.css, the BoQ data and report.js inlined.
    # Everything is inlined because the dialog uses set_html (relative src paths do not resolve there).
    module HtmlGenerator
      def self.generate_html(data, filename, project_number, revise_no, date_modified)
        boq = {
          'rows' => data.map { |name, count| { 'name' => name, 'count' => count } },
          'filename' => filename, 'projectNumber' => project_number,
          'reviseNo' => revise_no, 'dateUpdated' => date_modified
        }
        # block form of sub: the inserted text is used as-is (no \1 or \\ handling)
        read('report.html')
          .sub('__REPORT_CSS__') { read('report.css') }
          .sub('__REPORT_JS__') { read('report.js') }
          .sub('__BOQ_DATA__') { "window.BOQ_DATA = #{json_for_script(boq)};" }
      end

      # "</script>" inside a component name must not close the script tag
      def self.json_for_script(value)
        JSON.generate(value).gsub('</', '<\/')
      end

      def self.read(name)
        File.read(File.join(PLUGIN_DIR, name), encoding: 'UTF-8')
      end
    end
  end
end
