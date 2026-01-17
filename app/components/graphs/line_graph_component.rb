# frozen_string_literal: true

class Graphs::LineGraphComponent < ViewComponent::Base
  def initialize(data:, title: "Temperature Data")
    @data = data
    @title = title
  end
end
