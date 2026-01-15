# frozen_string_literal: true

module Records
  class SectionComponent < ViewComponent::Base
    def initialize(title:, rows:, year_record:, current_year_record:, all_time_record:, year_label:, current_year_label:, show_three_columns:)
      @title = title
      @rows = rows
      @year_record = year_record
      @current_year_record = current_year_record
      @all_time_record = all_time_record
      @year_label = year_label
      @current_year_label = current_year_label
      @show_three_columns = show_three_columns
    end

    private

    attr_reader :title, :rows, :year_record, :current_year_record, :all_time_record,
                :year_label, :current_year_label, :show_three_columns

    def enriched_rows
      @enriched_rows ||= rows.map do |row|
        row.merge(
          year_record: year_record,
          current_year_record: current_year_record,
          all_time_record: all_time_record
        )
      end
    end
  end
end
