# frozen_string_literal: true

# Renders a single weather record as an information card:
#
#   +-----------------------------+
#   | Highest Temperature         |
#   |   102.4 °F                  |
#   |   on Aug 12, 2023 · 4:15 PM |
#   +-----------------------------+
module Records
  class RecordCardComponent < ViewComponent::Base
    include UnitConversions
    include DateTimeFormatting

    def initialize(row:, record:, icon: nil)
      @row = row
      @record = record
      @icon = icon
    end

    def call
      render Ui::CardComponent.new(padding: :default) do
        safe_join([
          label_block,
          value_block,
          timestamp_block
        ].compact)
      end
    end

    private

    attr_reader :row, :record, :icon

    def label_block
      content_tag(:div, class: "record-card__label") do
        parts = []
        parts << content_tag(:i, "", class: "#{icon} record-card__icon") if icon.present?
        parts << content_tag(:span, row[:label])
        safe_join(parts, " ")
      end
    end

    def value_block
      value_and_unit = formatted_value_parts
      content_tag(:div, class: "record-card__value") do
        parts = []
        parts << content_tag(:span, value_and_unit[:value], class: "record-card__value-number")
        if value_and_unit[:unit].present?
          parts << content_tag(:span, value_and_unit[:unit], class: "record-card__value-unit")
        end
        safe_join(parts)
      end
    end

    def timestamp_block
      timestamp = formatted_timestamp
      return content_tag(:p, "No data yet", class: "record-card__meta record-card__meta--muted") if record.nil?
      return nil if timestamp.blank?

      content_tag(:p, "on #{timestamp}", class: "record-card__meta")
    end

    # ---- Formatting ----

    def formatted_value_parts
      return { value: "—", unit: nil } if record.nil?

      raw = record.public_send(row[:field])
      return { value: "—", unit: nil } if raw.nil?

      case row[:type]
      when :temp
        { value: temp_fahrenheit(raw).round(1).to_s, unit: "°F" }
      when :speed
        { value: wind_speed_mph(raw).round(1).to_s, unit: "mph" }
      when :rain
        { value: rain_in_inches(raw).round(2).to_s, unit: "in" }
      when :pressure
        { value: raw.round(2).to_s, unit: "hPa" }
      when :solar
        { value: raw.round(1).to_s, unit: "W/m²" }
      when :wind_run
        { value: raw.round(1).to_s, unit: "mi" }
      when :hours
        { value: raw.to_s, unit: raw == 1 ? "hour" : "hours" }
      when :days
        { value: raw.to_s, unit: raw == 1 ? "day" : "days" }
      when :humidity
        { value: raw.to_s, unit: "%" }
      when :month
        year_value = record.public_send(row[:year_field])
        { value: [ Date::MONTHNAMES[raw], year_value ].compact.join(" "), unit: nil }
      else
        { value: raw.to_s, unit: nil }
      end
    end

    def formatted_timestamp
      return nil if record.nil? || row[:timestamp_field].blank?
      value = record.public_send(row[:timestamp_field])
      return nil if value.nil?

      case row[:timestamp_type]
      when :datetime
        format_datetime(value)
      when :date
        format_date(value)
      when :rain
        formatted = rain_in_inches(value)
        formatted ? "total: #{formatted.round(2)} in" : nil
      end
    end
  end
end
