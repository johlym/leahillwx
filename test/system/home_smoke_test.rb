require "application_system_test_case"

class HomeSmokeTest < ApplicationSystemTestCase
  test "home page loads" do
    visit root_url
    assert_selector "body"
    assert_text(/lhwx|weather|temperature/i)
  end

  test "about page loads" do
    visit about_url
    assert_selector "body"
  end

  test "graphs index loads or redirects" do
    visit graphs_url
    assert_selector "body"
  end
end
