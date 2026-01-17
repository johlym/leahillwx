# frozen_string_literal: true

class Graphs::LineGraphComponent < ViewComponent::Base
  def initialize(data:, year:, month:, day: nil)
    @data = data
    @year = year
    @month = month
    @day = day
  end

  def title
    month_name = Date::MONTHNAMES[@month]

    if @day
      "Hourly Temperature Data - #{month_name} #{@day}, #{@year}"
    else
      "Daily Temperature Data - #{month_name} #{@year}"
    end
  end
end
