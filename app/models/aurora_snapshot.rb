# frozen_string_literal: true

# == Schema Information
#
# Table name: aurora_snapshots
#
#  id                      :bigint           not null, primary key
#  fetched_at              :datetime         not null
#  kp                      :float            not null
#  kp_forecast_max_tonight :float
#  local_ovation_pct       :float
#  odds_label              :string
#  status_label            :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_aurora_snapshots_on_fetched_at  (fetched_at)
#
class AuroraSnapshot < ApplicationRecord
  validates :kp, :status_label, :fetched_at, presence: true

  def self.latest
    order(fetched_at: :desc).first
  end
end
