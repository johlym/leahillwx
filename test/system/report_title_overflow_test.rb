# frozen_string_literal: true

require "application_system_test_case"

class ReportTitleOverflowTest < ApplicationSystemTestCase
  setup do
    @report = Report.create!(
      year: 2024,
      month: 1,
      month_mean_temp: 10.0,
      month_high_temp: 15.0,
      month_high_temp_day: 15,
      month_low_temp: 5.0,
      month_low_temp_day: 1,
      total_heat_degree_days: 100.0,
      total_cool_degree_days: 0.0,
      total_rain: 2.5,
      avg_wind_speed: 5.0,
      month_high_wind_speed: 15.0,
      month_high_wind_day: 10,
      dominant_wind_dir: 180
    )
    @report.entries.create!(day: 15, mean_temp: 50.0, high_temp: 60.0, low_temp: 40.0)
  end

  test "climatological summary heading stays inside a phone viewport" do
    visit report_path(2024, "january")

    [ 320, 390 ].each do |width|
      page.current_window.resize_to(width, 800)

      overflow = page.evaluate_script(<<~JS)
        (() => {
          const title = document.querySelector("h1.ui-section-header-title");
          const subtitle = document.querySelector("p.ui-section-header-subtitle");
          const view = document.documentElement.clientWidth;
          const outside = (el) => {
            const range = document.createRange();
            range.selectNodeContents(el);
            return [...range.getClientRects()].filter((rect) => {
              return rect.width > 0 && (rect.left < -1 || rect.right > view + 1);
            }).length;
          };

          return { view, title: outside(title), subtitle: outside(subtitle), text: title.textContent };
        })()
      JS

      assert_equal 0, overflow["title"], "title overflows at #{width}px: #{overflow.inspect}"
      assert_equal 0, overflow["subtitle"], "subtitle overflows at #{width}px: #{overflow.inspect}"
      assert_match(/Climatological Summary/, overflow["text"])
      assert_match(/January 2024/, page.text)
    end
  end
end
