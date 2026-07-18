# frozen_string_literal: true

class DownloadIssPassesJob
  include Sidekiq::Job

  def perform(*_args)
    tle = Iss::CelestrakClient.new.fetch_tle
    passes = Iss::PassPredictor.new(tle: tle).predict
    fetched_at = Time.current

    IssPass.transaction do
      IssPass.where("los_at < ?", 1.day.ago).delete_all

      passes.each do |pass|
        record = IssPass.find_or_initialize_by(aos_at: pass[:aos_at])
        record.assign_attributes(
          los_at: pass[:los_at],
          aos_az: pass[:aos_az],
          los_az: pass[:los_az],
          max_el: pass[:max_el],
          max_el_az: pass[:max_el_az],
          duration_s: pass[:duration_s],
          visible: pass[:visible],
          fetched_at: fetched_at
        )
        record.save!
      end
    end
  rescue HttpClient::RequestError, Iss::Tle::ParseError, Iss::Sgp4::PropagationError => e
    Rails.logger.warn("ISS pass download failed: #{e.message}")
  end
end

