# frozen_string_literal: true

require_relative 'config_manager'

module SkpCm
  module BoQCounter
    # The only place that knows SKP CM Extensions Hub. The Hub is looked up at call time:
    # SketchUp loads plugins in file-name order, so the Hub may load after BoQ.
    module HubLink
      MISSING_MESSAGE = "ต้องติดตั้งหรืออัปเดต SKP CM Extensions Hub (0.4.0 ขึ้นไป) แล้ว restart SketchUp\n" \
                        'https://github.com/bhurivaj/skp_cm_extensions_hub/releases/latest'

      class << self
        # SkpCm::ExtensionsHub::Auth, or nil when the Hub is missing, disabled or older than 0.4.0
        def auth
          defined?(SkpCm::ExtensionsHub::Auth) ? SkpCm::ExtensionsHub::Auth : nil
        end

        def status
          hub = auth
          unless hub
            return { 'hub' => false, 'logged_in' => false, 'username' => nil, 'online' => false }
          end

          { 'hub' => true, 'logged_in' => hub.logged_in?, 'username' => hub.username,
            'online' => !hub.uid.nil? }
        end

        # Returns the listener to pass to unwatch, or nil when there is no Hub
        def watch(&listener)
          hub = auth
          hub ? hub.on_change(&listener) : nil
        rescue StandardError => e
          puts "SKP CM BoQ Counter: #{e.class}: #{e.message}"
          nil
        end

        def unwatch(listener)
          hub = auth
          hub.off_change(listener) if hub && listener
        end

        def relogin(&done)
          hub = auth
          return finish(done, false) unless hub

          hub.relogin { |ok, _error| finish(done, ok) }
        end

        # Logged in but not connected (e.g. SketchUp started offline): ask the server again
        def refresh(&done)
          hub = auth
          return finish(done, false) unless hub
          return finish(done, true) unless hub.logged_in? && hub.uid.nil?

          relogin(&done)
        end

        def show_login
          hub = auth
          return false unless hub

          hub.show_login
          true
        end

        # Moves the BoQ 1.x account to the Hub (spec §4.4). Yields :none, :no_hub,
        # :hub_has_account, :imported, :rejected, :retry_later or :error
        def migrate_credentials(&done)
          creds = ConfigManager.legacy_credentials
          return finish(done, :none) unless creds

          hub = auth
          return finish(done, :no_hub) unless hub

          if hub.username
            ConfigManager.clear_legacy_credentials
            return finish(done, :hub_has_account)
          end

          hub.import_credentials(creds['username'], creds['password']) do |ok, _error|
            # a rejected password leaves the username in the Hub; a network error saves nothing
            if ok || hub.username
              ConfigManager.clear_legacy_credentials
              finish(done, ok ? :imported : :rejected)
            else
              finish(done, :retry_later)
            end
          end
        rescue StandardError => e
          puts "SKP CM BoQ Counter: could not move the old account (#{e.class}: #{e.message})"
          finish(done, :error)
        end

        private

        def finish(done, result)
          done.call(result) if done
          result
        rescue StandardError => e
          puts "SKP CM BoQ Counter: #{e.class}: #{e.message}"
          result
        end
      end
    end
  end
end
