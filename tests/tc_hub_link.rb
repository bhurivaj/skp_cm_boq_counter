# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_hub_link.rb
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'

module Sketchup
  class << self
    attr_accessor :platform

    def find_support_file(_name)
      nil
    end
  end
end

module SkpCm
  module ExtensionsHub
  end
end

# Same public methods as SkpCm::ExtensionsHub::Auth (skp_cm_extensions_hub/auth.rb, spec §3.4)
module FakeAuth
  class << self
    attr_accessor :logged_in, :username, :token, :api_base_url, :imports, :listeners, :shown,
                  :import_reply, :relogin_reply, :relogins, :broken

    def reset
      self.logged_in = false
      self.username = nil
      self.token = nil
      self.api_base_url = 'https://odoo.test'
      self.imports = []
      self.listeners = []
      self.shown = false
      self.import_reply = [true, nil, 'old@b.c'] # [ok, error, username the Hub holds afterwards]
      self.relogin_reply = [true, nil]
      self.relogins = 0
      self.broken = false
    end

    def logged_in?
      logged_in
    end

    def on_change(&listener)
      raise 'hub broke' if broken
      listeners << listener
      listener
    end

    def off_change(listener)
      listeners.delete(listener)
    end

    def show_login
      self.shown = true
    end

    def relogin
      self.relogins += 1
      yield(*relogin_reply)
    end

    def import_credentials(user, pass)
      imports << [user, pass]
      ok, error, held = import_reply
      self.username = held
      yield ok, error
    end
  end
end

require_relative '../skp_cm_boq_counter/hub_link'

class TestHubLink < Minitest::Test
  HL = SkpCm::BoQCounter::HubLink
  CM = SkpCm::BoQCounter::ConfigManager

  def setup
    @tmp = Dir.mktmpdir
    @old_home = ENV['HOME']
    ENV['HOME'] = @tmp
    Sketchup.platform = :platform_osx
    FakeAuth.reset
    SkpCm::ExtensionsHub.const_set(:Auth, FakeAuth) unless SkpCm::ExtensionsHub.const_defined?(:Auth, false)
  end

  def teardown
    ENV['HOME'] = @old_home
    FileUtils.rm_rf(@tmp)
  end

  # Hub missing, disabled, or 0.3.0 (module exists without Auth)
  def no_hub
    SkpCm::ExtensionsHub.send(:remove_const, :Auth) if SkpCm::ExtensionsHub.const_defined?(:Auth, false)
  end

  def save_old_account
    CM.save_config('username' => 'old@b.c', 'password' => CM.encrypt('pw'))
  end

  def migrate
    result = nil
    HL.migrate_credentials { |r| result = r }
    result
  end

  def test_status_when_old_hub_without_auth
    no_hub
    expected = { 'hub' => false, 'logged_in' => false, 'username' => nil, 'token' => nil, 'api_base_url' => nil }
    assert_equal expected, HL.status
    assert_nil HL.watch { |_| }
    HL.unwatch(nil)
    assert_equal false, HL.show_login
    assert_match(/0\.4\.0/, HL::MISSING_MESSAGE)
  end

  def test_status_from_hub
    FakeAuth.logged_in = true
    FakeAuth.username = 'a@b.c'
    FakeAuth.token = 't'
    expected = { 'hub' => true, 'logged_in' => true, 'username' => 'a@b.c', 'token' => 't',
                 'api_base_url' => 'https://odoo.test' }
    assert_equal expected, HL.status
  end

  def test_watch_and_unwatch
    listener = HL.watch { |_| }
    assert_equal [listener], FakeAuth.listeners
    HL.unwatch(listener)
    assert_empty FakeAuth.listeners
  end

  def test_show_login_and_relogin
    assert_equal true, HL.show_login
    assert FakeAuth.shown
    result = nil
    HL.relogin { |ok| result = ok }
    assert_equal true, result
    no_hub
    HL.relogin { |ok| result = ok }
    assert_equal false, result
  end

  def test_migrate_without_old_account
    assert_equal :none, migrate
    assert_empty FakeAuth.imports
  end

  def test_migrate_without_hub_keeps_account
    save_old_account
    no_hub
    assert_equal :no_hub, migrate
    refute_nil CM.legacy_credentials
  end

  def test_migrate_when_hub_has_account
    save_old_account
    FakeAuth.username = 'hub@b.c'
    assert_equal :hub_has_account, migrate
    assert_empty FakeAuth.imports
    assert_nil CM.legacy_credentials
  end

  def test_migrate_imports
    save_old_account
    assert_equal :imported, migrate
    assert_equal [['old@b.c', 'pw']], FakeAuth.imports
    assert_nil CM.legacy_credentials
  end

  def test_migrate_rejected_password_clears
    save_old_account
    FakeAuth.import_reply = [false, 'username หรือ password ไม่ถูกต้อง', 'old@b.c']
    assert_equal :rejected, migrate
    assert_nil CM.legacy_credentials
  end

  def test_migrate_network_error_keeps_for_next_time
    save_old_account
    FakeAuth.import_reply = [false, 'เชื่อมต่อ server ไม่ได้', nil]
    assert_equal :retry_later, migrate
    refute_nil CM.legacy_credentials
  end

  # SketchUp started offline: the report asks again when it opens
  def test_refresh_reconnects_only_when_logged_in_without_token
    result = nil
    HL.refresh { |ok| result = ok }
    assert_equal 0, FakeAuth.relogins, 'not logged in: nothing to do'
    FakeAuth.logged_in = true
    FakeAuth.token = 't'
    HL.refresh { |ok| result = ok }
    assert_equal 0, FakeAuth.relogins, 'online: nothing to do'
    FakeAuth.token = nil
    HL.refresh { |ok| result = ok }
    assert_equal 1, FakeAuth.relogins
    assert_equal true, result
    no_hub
    HL.refresh { |ok| result = ok }
    assert_equal false, result
  end

  # the production report must still open when the Hub or the config misbehaves
  def test_errors_from_hub_or_config_do_not_escape
    FakeAuth.broken = true
    assert_nil HL.watch { |_| }
    original = CM.method(:legacy_credentials)
    CM.define_singleton_method(:legacy_credentials) { raise Errno::EISDIR }
    result = nil
    HL.migrate_credentials { |r| result = r }
    assert_equal :error, result
  ensure
    CM.define_singleton_method(:legacy_credentials, original) if original
  end
end
