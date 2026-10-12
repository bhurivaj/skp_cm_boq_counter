# frozen_string_literal: true

# Run (no SketchUp needed): ruby tests/tc_html_generator.rb
require 'minitest/autorun'
require 'json'

module SkpCm
  module BoQCounter
    PLUGIN_DIR = File.expand_path('../skp_cm_boq_counter', __dir__) unless const_defined?(:PLUGIN_DIR)
  end
end

require_relative '../skp_cm_boq_counter/html_generator'

class TestHtmlGenerator < Minitest::Test
  G = SkpCm::BoQCounter::HtmlGenerator
  DIR = SkpCm::BoQCounter::PLUGIN_DIR

  def html(data = { 'Chair' => 2 })
    G.generate_html(data, 'a.skp', 'OPP-12345678901', 'R01', '2026-10-12')
  end

  def boq_data(page)
    JSON.parse(page[/window\.BOQ_DATA = (.*);$/, 1])
  end

  def test_all_parts_are_inlined
    page = html
    %w[__REPORT_CSS__ __REPORT_JS__ __BOQ_DATA__].each { |p| refute_includes page, p }
    assert_includes page, '.modal-overlay'   # from report.css
    assert_includes page, 'createApp'        # from report.js
    refute_match(/<script src="report/, page)
  end

  def test_boq_data
    expected = { 'rows' => [{ 'name' => 'Chair', 'count' => 2 }], 'filename' => 'a.skp',
                 'projectNumber' => 'OPP-12345678901', 'reviseNo' => 'R01', 'dateUpdated' => '2026-10-12' }
    assert_equal expected, boq_data(html)
  end

  def test_script_tag_in_name_is_escaped
    name = %q(x</script><script>alert("1")</script>'"\\ ไทย)
    page = html(name => 1)
    refute_includes page, 'x</script>'
    assert_equal name, boq_data(page)['rows'][0]['name']
  end

  def test_every_template_file_fits_the_300_line_rule
    %w[report.html report.css report.js html_generator.rb].each do |f|
      assert File.readlines(File.join(DIR, f)).size <= 300, "#{f} is longer than 300 lines"
    end
  end

  def test_login_form_is_gone_and_hub_status_is_used
    page = html
    %w[saveAndLogin testLogin credentials authToken isLoggingIn apiBaseUrl load_credentials].each do |old|
      refute_includes page, old
    end
    %w[window.authStatus openHubLogin auth_status].each do |used|
      assert_includes page, used
    end
  end

  # Stock Request is paused while the document workflow changes (spec §7)
  def test_stock_request_is_paused
    page = html
    %w[apiFetch /stock-requests/ /locations/ showStockRequestModal sendStockRequest .token relogin].each do |old|
      refute_includes page, old
    end
    assert_includes page, 'ยังไม่พร้อมใช้งาน'
    assert_match(/<button[^>]*disabled[^>]*>\s*Send Stock Request/m, page)
  end

  # every name the template uses must be returned from setup() (sort arrows used sortKey/sortOrder)
  def test_template_names_are_returned_from_setup
    returned = File.read(File.join(DIR, 'report.js'))[/return \{(.*?)\};/m, 1].split(/[\s,]+/).reject(&:empty?)
    %w[sortKey sortOrder sortTable filteredData totalQuantity auth authHint openHubLogin].each do |name|
      assert_includes returned, name
    end
  end
end
