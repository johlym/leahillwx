# frozen_string_literal: true

require "test_helper"

class Reports::ReportNavigationComponentTest < ViewComponent::TestCase
  include Rails.application.routes.url_helpers

  test "renders navigation form with stimulus controller" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 1))

    assert_selector "div.report-navigation[data-controller='report-navigation']"
    assert_selector "form[action='#{reports_path}'][method='get']"
  end

  test "renders year select with correct attributes" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 1))

    assert_selector "select#year-select[name='year']"
    assert_selector "select[data-report-navigation-target='yearSelect']"
    assert_selector "select[data-action='change->report-navigation#updateMonths']"
    assert_selector "select[data-current-year='2024']"
    assert_selector "select[data-current-month='1']"
    assert_selector "option[value='']", text: "Select a Year"
  end

  test "renders month select with correct attributes" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 1))

    assert_selector "select#month-select[name='month'][disabled]"
    assert_selector "select[data-report-navigation-target='monthSelect']"
    assert_selector "select[data-action='change->report-navigation#enableGoButton']"
    assert_selector "option[value='']", text: "Select a Month"
  end

  test "renders GO button with correct attributes" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 1))

    assert_selector "button[type='button'][disabled]", text: "GO"
    assert_selector "button[data-action='click->report-navigation#navigateToReport']"
    assert_selector "button[data-report-navigation-target='goButton']"
  end

  test "renders download link when current_year and current_month are provided" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 1))

    assert_selector "a.secondary-button", text: "Download Text Version"
    assert_selector "a[href='#{report_path(2024, "january")}.txt']"
  end

  test "does not render download link when current_year is nil" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: nil, current_month: 1))

    assert_no_selector "a.secondary-button", text: "Download Text Version"
  end

  test "does not render download link when current_month is nil" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: nil))

    assert_no_selector "a.secondary-button", text: "Download Text Version"
  end

  test "renders navigation message container" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 1))

    assert_selector "div.navigation-message[data-report-navigation-target='message']"
  end

  test "renders screen reader labels for accessibility" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 1))

    assert_selector "label.sr-only[for='year-select']", text: "Year:"
    assert_selector "label.sr-only[for='month-select']", text: "Month:"
  end

  test "renders correct download link for different months" do
    render_inline(Reports::ReportNavigationComponent.new(current_year: 2024, current_month: 12))

    assert_selector "a[href='#{report_path(2024, "december")}.txt']"
  end
end
