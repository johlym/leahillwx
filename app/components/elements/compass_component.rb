# frozen_string_literal: true

# Compass rose used to show wind direction. Renders an SVG dial with
# N/E/S/W markers, tick marks, and a needle that rotates to the given
# heading. Sized in em so callers can drop it into a card at any scale.
#
#   render Elements::CompassComponent.new(direction: 240, size: :md, label: "SW")
module Elements
  class CompassComponent < ViewComponent::Base
    SIZES = { xs: "1.5rem", sm: "2.5rem", md: "4rem", lg: "5.5rem" }.freeze
    CARDINALS = [ "N", "NE", "E", "SE", "S", "SW", "W", "NW" ].freeze

    def initialize(direction:, size: :md, label: nil, show_label: true)
      @direction = direction.to_f
      @size = SIZES.key?(size) ? size : :md
      @label = label
      @show_label = show_label
      @uid = SecureRandom.hex(4)
    end

    def compass_label
      return @label if @label.present?
      idx = ((@direction + 22.5) / 45).floor % 8
      CARDINALS[idx]
    end

    private

    attr_reader :direction, :size, :show_label, :uid
  end
end
