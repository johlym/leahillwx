module Shared
  class DateNavigationComponent < ViewComponent::Base
    def initialize(current_year:, current_month: nil, current_day: nil, base_path:, day_required: false, jump_button: false)
      @current_year = current_year
      @current_month = current_month
      @current_day = current_day
      @base_path = base_path
      @day_required = day_required
      @jump_button = jump_button
    end

    def day_label
      @day_required ? "Day:" : "Day (optional):"
    end
  end
end
