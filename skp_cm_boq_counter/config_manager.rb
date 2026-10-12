# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'base64'

module SkpCm
  module BoQCounter
    module ConfigManager
      # Default configuration values (the login lives in SKP CM Extensions Hub since 2.0.0)
      DEFAULTS = {
        # Legacy settings (for backward compatibility)
        'api_endpoint' => 'https://odoo.catice.co/api/equipment_request',
        'expected_days_offset' => 4,
        'project_number_pattern' => 'OPP-\\d{11}',

        # Request defaults
        'default_request_type' => 'issue',
        'default_status' => 'draft'
      }.freeze

      # Simple XOR encryption key (basic obfuscation - not cryptographically secure)
      ENCRYPTION_KEY = "ClassmatSuite2025"

      # Per-user data folder — survives plugin reinstall/update
      def self.user_data_dir
        base =
          if Sketchup.platform == :platform_win
            appdata = ENV['APPDATA']
            appdata.nil? || appdata.empty? ? File.join(Dir.home, 'AppData', 'Roaming') : appdata
          else
            File.join(Dir.home, 'Library', 'Application Support')
          end
        File.join(base, 'SkpCm', 'boq_counter')
      end

      # Get the path to the configuration file
      def self.config_file_path
        File.join(user_data_dir, 'config.json')
      end

      # Classmat Suite kept its config in the Plugins folder
      def self.legacy_config_path
        plugins_dir = Sketchup.find_support_file('Plugins')
        plugins_dir.nil? ? nil : File.join(plugins_dir, 'classmat_config.json')
      end

      # Copy the Classmat Suite config once (only when there is no new config yet).
      # Never deletes the old file. Returns true when copied.
      def self.migrate_legacy_config
        legacy = legacy_config_path
        return false if legacy.nil? || !File.exist?(legacy)
        return false if File.exist?(config_file_path)

        FileUtils.mkdir_p(user_data_dir)
        FileUtils.cp(legacy, config_file_path)
        true
      rescue StandardError => e
        puts "SKP CM BoQ Counter: could not migrate Classmat Suite config (#{e.message})"
        false
      end

      # Simple encryption (XOR with key)
      def self.encrypt(text)
        return '' if text.nil? || text.empty?
        encrypted = text.bytes.each_with_index.map do |byte, i|
          byte ^ ENCRYPTION_KEY[i % ENCRYPTION_KEY.length].ord
        end
        Base64.strict_encode64(encrypted.pack('C*'))
      end

      # Simple decryption
      def self.decrypt(encrypted_text)
        return '' if encrypted_text.nil? || encrypted_text.empty?
        begin
          decoded = Base64.strict_decode64(encrypted_text)
          decoded.bytes.each_with_index.map do |byte, i|
            (byte ^ ENCRYPTION_KEY[i % ENCRYPTION_KEY.length].ord).chr
          end.join
        rescue
          '' # Return empty string if decryption fails
        end
      end

      # Load configuration from file or return defaults
      def self.load_config
        config_path = config_file_path
        
        if File.exist?(config_path)
          begin
            file_content = File.read(config_path)
            saved_config = JSON.parse(file_content)
            # Merge with defaults to ensure all keys exist
            DEFAULTS.merge(saved_config)
          rescue JSON::ParserError, Errno::EACCES => e
            puts "Warning: Failed to load config (#{e.message}), using defaults"
            DEFAULTS.dup
          end
        else
          DEFAULTS.dup
        end
      end

      # Save configuration to file
      def self.save_config(config)
        config_path = config_file_path
        
        begin
          # Ensure directory exists
          FileUtils.mkdir_p(File.dirname(config_path))
          
          # Merge with current config to preserve other settings
          current_config = load_config
          updated_config = current_config.merge(config)
          
          # Write to file
          File.write(config_path, JSON.pretty_generate(updated_config))
          true
        rescue Errno::EACCES, IOError => e
          UI.messagebox("Failed to save configuration: #{e.message}")
          false
        end
      end

      # Get a specific configuration value
      def self.get(key)
        config = load_config
        config[key.to_s]
      end

      # Set a specific configuration value
      def self.set(key, value)
        config = load_config
        config[key.to_s] = value
        save_config(config)
      end

      # Get expected days offset
      def self.expected_days_offset
        get('expected_days_offset')
      end

      # Get project number pattern as regex
      def self.project_number_pattern
        Regexp.new(get('project_number_pattern'))
      end

      # Get default request type
      def self.default_request_type
        get('default_request_type')
      end

      # Get default status
      def self.default_status
        get('default_status')
      end

      # Account saved by BoQ 1.x — only read to move it to the Extensions Hub (HubLink.migrate_credentials)
      def self.legacy_credentials
        config = load_config
        username = config['username'].to_s
        password = decrypt(config['password'].to_s).dup.force_encoding('UTF-8')
        return nil if username.empty? || password.empty?

        { 'username' => username, 'password' => password }
      end

      # save_config merges, so it cannot remove keys — rewrite the file without them
      def self.clear_legacy_credentials
        return true unless File.exist?(config_file_path)

        config = load_config.reject { |key, _| %w[username password].include?(key) }
        File.write(config_file_path, JSON.pretty_generate(config))
        true
      rescue SystemCallError, IOError => e
        puts "SKP CM BoQ Counter: could not clear old credentials (#{e.message})"
        false
      end

      # Settings form → config (Expected Return Days is the only editable setting)
      def self.settings_from_params(params)
        days = params['expected_days_offset'].to_i
        days.between?(1, 365) ? { 'expected_days_offset' => days } : {}
      end
    end
  end
end
