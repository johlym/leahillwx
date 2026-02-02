class AlmanacController < ApplicationController
  def index
    # Default to current month
    redirect_to almanac_month_path(Date.current.year, Date.current.strftime("%B").downcase)
  end

  def show
    @start_time = Time.current

    year = params[:year].to_i
    month_name = params[:month_name]
    month_num = Date::MONTHNAMES.index(month_name.capitalize)

    unless month_num
      render_not_found("Invalid month name: #{month_name}")
      return
    end

    begin
      @month_date = Date.new(year, month_num, 1)
    rescue ArgumentError
      render_not_found("Invalid date: #{month_name.capitalize} #{year}")
      return
    end

    # Get all entries for the month
    start_date = @month_date.beginning_of_month
    end_date = @month_date.end_of_month
    @entries = AlmanacEntry.where(date: start_date..end_date).order(:date).index_by(&:date)

    # Get today's entry for the current card (if viewing current month)
    @today = Date.current
    @current_entry = if @month_date.year == @today.year && @month_date.month == @today.month
      AlmanacEntry.find_by(date: @today)
    else
      nil
    end

    # Calculate dynamic positions for today only
    @dynamic_positions = if @current_entry
      calculate_dynamic_positions
    else
      nil
    end

    # Get location info
    @location = {
      lat: ENV.fetch("LOCATION_LAT").to_f,
      lon: ENV.fetch("LOCATION_LON").to_f
    }

    @generation_time = (Time.current - @start_time).round(2)
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

    sun_pos = service.sun_position
    moon_pos = service.moon_position

    {
      sun: {
        azimuth: sun_pos[:azimuth_deg],
        altitude: sun_pos[:altitude_deg],
        right_ascension: sun_pos[:ra_deg],
        declination: sun_pos[:dec_deg]
      },
      moon: {
        azimuth: moon_pos[:azimuth_deg],
        altitude: moon_pos[:altitude_deg],
        right_ascension: moon_pos[:ra_deg],
        declination: moon_pos[:dec_deg]
      }
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
