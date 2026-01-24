class AlmanacController < ApplicationController
  def index
    @date = Date.current
    @almanac_entry = AlmanacEntry.find_by(date: @date)

    if @almanac_entry
      redirect_to almanac_day_path(@almanac_entry.date.year, @almanac_entry.date.strftime("%B").downcase, @almanac_entry.date.day)
    else
      @message = "No almanac data available yet. Please run: rake almanac:generate_all"
    end
  end

  def show
    @start_time = Time.current

    year = params[:year].to_i
    month_name = params[:month_name]
    day = params[:day].to_i
    month_num = Date::MONTHNAMES.index(month_name.capitalize)

    unless month_num
      render_not_found("Invalid month name: #{month_name}")
      return
    end

    unless day.between?(1, 31)
      render_not_found("Invalid day: #{day}")
      return
    end

    begin
      @date = Date.new(year, month_num, day)
    rescue ArgumentError
      render_not_found("Invalid date: #{month_name.capitalize} #{day}, #{year}")
      return
    end

    @almanac_entry = AlmanacEntry.find_by(date: @date)

    unless @almanac_entry
      render_not_found("Almanac data not found for #{@date}")
      return
    end

    # Only calculate dynamic positions for today
    @dynamic_positions = if @date == Date.current
      calculate_dynamic_positions
    else
      nil
    end

    @generation_time = (Time.current - @start_time).round(2)

    respond_to do |format|
      format.html
      format.text do
        render plain: Almanac::TextComponent.new(
          date: @date,
          almanac_entry: @almanac_entry,
          dynamic_positions: @dynamic_positions,
          generation_time: @generation_time
        ).render_in(view_context)
      end
    end
  end

  def available
    # Return available dates grouped by year and month
    entries = AlmanacEntry.all.order(date: :desc).pluck(:date)

    result = entries.group_by(&:year).transform_values do |dates|
      dates.group_by(&:month).transform_values { |month_dates|
        month_dates.map { |d| { day: d.day } }
      }.transform_keys { |m| Date::MONTHNAMES[m].downcase }
    end

    render json: result
  end

  private

  def calculate_dynamic_positions
    lat = ENV.fetch("LOCATION_LAT").to_f
    lon = ENV.fetch("LOCATION_LON").to_f

    service = Almanac::ApproximateCelestialPosition.new(
      datetime: Time.current,
      lat: lat,
      lon: lon
    )

    {
      sun: service.sun_position,
      moon: service.moon_position
    }
  rescue StandardError => e
    Rails.logger.error "Error calculating dynamic positions: #{e.message}"
    nil
  end

  def render_not_found(message)
    respond_to do |format|
      format.html { render plain: message, status: :not_found }
      format.text { render plain: message, status: :not_found }
      format.json { render json: { error: message }, status: :not_found }
    end
  end
end
