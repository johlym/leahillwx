# frozen_string_literal: true

class Elements::WindVaneComponent < ViewComponent::Base
  def initialize(direction:)
    @direction = direction
  end

  def direction
    @direction
  end
end
