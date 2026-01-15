# frozen_string_literal: true

class Home::GenericTileComponent < ViewComponent::Base
  attr_reader :heading, :subtitle

  def initialize(heading: nil, subtitle: nil)
    @heading = heading
    @subtitle = subtitle
  end
end
