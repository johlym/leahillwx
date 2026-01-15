class RecordsController < ApplicationController
  def index
    @selected_year = params[:year]&.to_i || Time.current.year
    @current_year = Time.current.year

    @selected_year_record = Record.for_year(@selected_year).first
    @current_year_record = Record.for_year(@current_year).first
    @all_time_record = Record.all_time_record

    @available_years = Record.where(scope: "yearly").order(year: :desc).pluck(:year)
  end
end
