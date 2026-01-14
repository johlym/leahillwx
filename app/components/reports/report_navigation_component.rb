# frozen_string_literal: true

class Reports::ReportNavigationComponent < ViewComponent::Base
  def initialize(current_year:, current_month:, current_day: nil)
    @current_year = current_year
    @current_month = current_month
    @current_day = current_day
  end
end
