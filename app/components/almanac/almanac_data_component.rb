# frozen_string_literal: true

class Almanac::AlmanacDataComponent < ViewComponent::Base
  include DateTimeFormatting

  def initialize(almanac_entry:, dynamic_positions: nil)
    @almanac_entry = almanac_entry
    @dynamic_positions = dynamic_positions
  end

  private

  attr_reader :almanac_entry, :dynamic_positions
end
