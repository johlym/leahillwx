# frozen_string_literal: true

class Reports::DownloadLinkComponent < ViewComponent::Base
  def initialize(path:)
    @path = path
  end

  def download_path
    "#{@path}.txt"
  end
end
