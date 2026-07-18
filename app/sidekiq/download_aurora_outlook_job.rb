# frozen_string_literal: true

class DownloadAuroraOutlookJob
  include Sidekiq::Job

  def perform(*_args)
    outlook = NoaaAuroraClient.new.outlook

    AuroraSnapshot.create!(
      kp: outlook[:kp],
      kp_forecast_max_tonight: outlook[:kp_forecast_max_tonight],
      local_ovation_pct: outlook[:local_ovation_pct],
      status_label: outlook[:status_label],
      odds_label: outlook[:odds_label],
      fetched_at: Time.current
    )
  rescue HttpClient::RequestError => e
    Rails.logger.warn("Aurora outlook download failed: #{e.message}")
  end
end
