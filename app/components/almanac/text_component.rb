# frozen_string_literal: true

class Almanac::TextComponent < ViewComponent::Base
  include DateTimeFormatting

  def initialize(date:, almanac_entry:, dynamic_positions: nil, generation_time: nil)
    @date = date
    @almanac_entry = almanac_entry
    @dynamic_positions = dynamic_positions
    @generation_time = generation_time
  end

  private

  attr_reader :date, :almanac_entry, :dynamic_positions, :generation_time
end
