module Reports
  class OverviewStatisticsTableComponent < ViewComponent::Base
    def initialize(report:, type: :monthly, day: nil)
      @report = report
      @type = type
      @day = day
    end

    private

    attr_reader :report, :type, :day
  end
end
