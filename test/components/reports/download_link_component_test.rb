# frozen_string_literal: true

require "test_helper"

class Reports::DownloadLinkComponentTest < ViewComponent::TestCase
  test "renders download link with correct text" do
    render_inline(Reports::DownloadLinkComponent.new(path: "/reports/2024/january"))

    assert_selector "a", text: "Download text version"
  end

  test "renders download link with correct CSS class" do
    render_inline(Reports::DownloadLinkComponent.new(path: "/reports/2024/january"))

    assert_selector "a.btn-secondary"
  end

  test "renders download icon" do
    render_inline(Reports::DownloadLinkComponent.new(path: "/reports/2024/january"))

    assert_selector "a i.fa-regular.fa-download[aria-hidden='true']"
  end

  test "appends .txt extension to path" do
    render_inline(Reports::DownloadLinkComponent.new(path: "/reports/2024/january"))

    assert_selector "a[href='/reports/2024/january.txt']"
  end

  test "works with different paths" do
    render_inline(Reports::DownloadLinkComponent.new(path: "/reports/2023/december"))

    assert_selector "a[href='/reports/2023/december.txt']"
  end

  test "handles paths without leading slash" do
    render_inline(Reports::DownloadLinkComponent.new(path: "reports/2024/march"))

    assert_selector "a[href='reports/2024/march.txt']"
  end
end
