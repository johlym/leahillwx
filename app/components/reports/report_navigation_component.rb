# frozen_string_literal: true

class Reports::ReportNavigationComponent < ViewComponent::Base
  def initialize(current_year:, current_month:)
    @current_year = current_year
    @current_month = current_month
  end
end
