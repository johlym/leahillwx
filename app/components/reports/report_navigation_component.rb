# frozen_string_literal: true

class Reports::ReportNavigationComponent < ViewComponent::Base
  def initialize(current_year:, current_month:, current_day: nil)
    @current_year = current_year
    @current_month = current_month
    @current_day = current_day
  end

  def show_download_link?
    @current_year.present? && @current_month.present?
  end

  def month_name
    return nil unless @current_month

    Date::MONTHNAMES[@current_month].downcase
  end
end
