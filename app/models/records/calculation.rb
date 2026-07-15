module Records
  class Calculation
    CALCULATORS = [
      Records::TemperatureExtremes,
      Records::WindExtremes,
      Records::RainExtremes,
      Records::HumidityExtremes,
      Records::BarometerExtremes,
      Records::SolarExtremes
    ].freeze

    def initialize(scope:, year: nil)
      @scope = scope
      @year = year
      @record = Record.find_or_initialize_by(scope: scope, year: year)
    end

    def calculate_and_save!
      measurements = Records::MeasurementScope.new(scope: @scope, year: @year).resolve

      Rails.logger.info "Starting record calculation for #{@scope} #{@year || 'all-time'}"

      CALCULATORS.each do |calculator_class|
        calculator_class.new(record: @record, measurements: measurements, scope: @scope, year: @year).calculate
        Rails.logger.info "✓ #{calculator_class.name.demodulize.titleize} calculated"
      end

      @record.save!
      Rails.logger.info "✓ Record saved successfully"
      @record
    end
  end
end
