class TrendsController < ApplicationController
  def index
    @years_available = Report.distinct.order(year: :desc).pluck(:year)
    @message = "Trends coming online — new charts and anomaly cards land shortly."
    render :index
  end

  def show
    @years_available = Report.distinct.order(year: :desc).pluck(:year)
    @selected_year = params[:year].to_i
    @message = "Trends coming online — new charts and anomaly cards land shortly."
    render :index
  end
end
