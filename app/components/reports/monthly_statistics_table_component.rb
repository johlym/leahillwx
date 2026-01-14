module Reports
  class MonthlyStatisticsTableComponent < ViewComponent::Base
    def initialize(report:)
      @report = report
    end

    private

    attr_reader :report
  end
end
