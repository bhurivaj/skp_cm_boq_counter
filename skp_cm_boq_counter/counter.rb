# frozen_string_literal: true

require 'csv'
require 'date'
require 'uri'

module SkpCm
  module BoQCounter
    module Counter
      # Store selection state for later use
      @selection_only = false
      @cached_definitions = nil

      class << self
        attr_accessor :selection_only, :cached_definitions
      end

      def self.generate_boq
        model = Sketchup.active_model
        @selection_only = UI.messagebox("Count only selected components?", MB_YESNO, "BoQ Counter") == IDYES
        @cached_definitions = Hash.new(0)
        
        entities = @selection_only ? model.selection : model.entities
        count_first_layer_components(entities, @cached_definitions)
        
        filename = get_sketchup_filename(model)
        project_number = extract_project_number(model.path)
        date_modified = Date.today.strftime("%Y-%m-%d")
        revise_no = "R01"
        
        html_content = SkpCm::BoQCounter::HtmlGenerator.generate_html(@cached_definitions, filename, project_number, revise_no, date_modified)
        show_web_dialog(html_content)
      end

      def self.count_first_layer_components(entities, definitions)
        entities.each do |entity|
          if entity.is_a?(Sketchup::ComponentInstance)
            name = entity.definition.name.split('#').first.strip
            definitions[name] += 1
          elsif entity.is_a?(Sketchup::Group)
            group_entities = entity.definition.entities
            count_first_layer_components(group_entities, definitions)
          end
        end
      end

      def self.save_to_csv(filename, project_number, revise_no, date_modified)
        model = Sketchup.active_model
        project_folder = File.dirname(model.path)
        
        if project_folder.empty?
          UI.messagebox("Error: Project file must be saved before exporting CSV.")
          return
        end
        
        definitions = @cached_definitions || Hash.new(0)
        if definitions.empty?
          entities = @selection_only ? model.selection : model.entities
          count_first_layer_components(entities, definitions)
        end
        
        base_filename = filename.gsub('.skp', '')
        csv_filename = "#{revise_no}_#{date_modified}_#{base_filename}.csv"
        csv_file = File.join(project_folder, csv_filename)
        
        begin
          CSV.open(csv_file, "w") do |csv|
            csv << ["Filename", "Project Number", "Revise No", "Date Modified", "Component Name", "Quantity"]
            definitions.each do |name, count|
              csv << [filename, project_number, revise_no, date_modified, name, count]
            end
          end
          UI.messagebox("CSV file saved successfully:\n#{csv_file}")
        rescue Errno::EACCES => e
          UI.messagebox("Error: Permission denied. Cannot write to:\n#{csv_file}")
        rescue IOError, SystemCallError => e
          UI.messagebox("Error saving CSV file:\n#{e.message}")
        end
      end

      def self.show_web_dialog(content)
        dlg = UI::HtmlDialog.new(
          dialog_title: "BoQ Report",
          scrollable: true,
          resizable: true,
          width: 900,
          height: 700
        )
        dlg.set_html(content)
        
        # Callback for saving CSV
        dlg.add_action_callback("save_to_csv") do |_dlg, params|
          begin
            parsed_params = URI.decode_www_form(params).to_h
            filename = parsed_params["filename"] || "Untitled"
            project_number = parsed_params["projectNumber"] || "OPP-00000000000"
            revise_no = parsed_params["reviseNo"] || "R01"
            date_modified = parsed_params["dateUpdated"] || Date.today.strftime("%Y-%m-%d")
            
            save_to_csv(filename, project_number, revise_no, date_modified)
          rescue => e
            UI.messagebox("Error processing save request: #{e.message}")
          end
        end
        
        # Callback for saving settings
        dlg.add_action_callback("save_settings") do |_dlg, params|
          begin
            parsed_params = URI.decode_www_form(params).to_h
            config = {}
            config['api_endpoint'] = parsed_params['apiEndpoint'] if parsed_params['apiEndpoint']
            config['expected_days_offset'] = parsed_params['expectedDays'].to_i if parsed_params['expectedDays']
            
            if SkpCm::BoQCounter::ConfigManager.save_config(config)
              dlg.execute_script("window.settingsSaved && window.settingsSaved(true)")
            else
              dlg.execute_script("window.settingsSaved && window.settingsSaved(false)")
            end
          rescue => e
            UI.messagebox("Error saving settings: #{e.message}")
            dlg.execute_script("window.settingsSaved && window.settingsSaved(false)")
          end
        end
        
        # Callback for loading settings
        dlg.add_action_callback("load_settings") do |_dlg, _params|
          begin
            config = SkpCm::BoQCounter::ConfigManager.load_config
            config_json = config.to_json.gsub("'", "\\'")
            dlg.execute_script("window.loadedSettings && window.loadedSettings(#{config_json})")
          rescue => e
            puts "Error loading settings: #{e.message}"
          end
        end
        
        # Callback for saving credentials
        dlg.add_action_callback("save_credentials") do |_dlg, params|
          begin
            parsed_params = URI.decode_www_form(params).to_h
            username = parsed_params['username']
            password = parsed_params['password']
            
            if username && password && !username.empty? && !password.empty?
              SkpCm::BoQCounter::ConfigManager.save_credentials(username, password)
              dlg.execute_script("window.credentialsSaved && window.credentialsSaved(true)")
            else
              dlg.execute_script("window.credentialsSaved && window.credentialsSaved(false, 'Username and password are required')")
            end
          rescue => e
            puts "Error saving credentials: #{e.message}"
            dlg.execute_script("window.credentialsSaved && window.credentialsSaved(false, '#{e.message}')")
          end
        end
        
        # Callback for loading credentials
        dlg.add_action_callback("load_credentials") do |_dlg, _params|
          begin
            creds = SkpCm::BoQCounter::ConfigManager.get_credentials
            creds_json = creds.to_json.gsub("'", "\\'")
            dlg.execute_script("window.loadedCredentials && window.loadedCredentials(#{creds_json})")
          rescue => e
            puts "Error loading credentials: #{e.message}"
          end
        end
        
        # Callback for clearing credentials
        dlg.add_action_callback("clear_credentials") do |_dlg, _params|
          begin
            SkpCm::BoQCounter::ConfigManager.clear_credentials
            dlg.execute_script("window.credentialsCleared && window.credentialsCleared(true)")
          rescue => e
            puts "Error clearing credentials: #{e.message}"
            dlg.execute_script("window.credentialsCleared && window.credentialsCleared(false)")
          end
        end
        
        dlg.show
      end

      private
      
      def self.get_sketchup_filename(model)
        path = model.path
        path.empty? ? "Untitled.skp" : File.basename(path)
      end

      def self.extract_project_number(path)
        return "OPP-00000000000" if path.empty?
        directories = File.dirname(path).split(File::SEPARATOR)
        project_number = directories.find { |dir| dir.match?(SkpCm::BoQCounter::ConfigManager.project_number_pattern) }
        project_number || "OPP-00000000000"
      end
    end
  end
end
