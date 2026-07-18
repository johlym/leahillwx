# frozen_string_literal: true

# == Schema Information
#
# Table name: iss_passes
#
#  id         :bigint           not null, primary key
#  aos_at     :datetime         not null
#  aos_az     :float            not null
#  duration_s :integer          not null
#  fetched_at :datetime         not null
#  los_at     :datetime         not null
#  los_az     :float            not null
#  max_el     :float            not null
#  max_el_az  :float            not null
#  visible    :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class IssPass < ApplicationRecord
  validates :aos_at, :los_at, :aos_az, :los_az, :max_el, :max_el_az, :duration_s, :fetched_at, presence: true

  scope :upcoming, -> { where("los_at > ?", Time.current).order(:aos_at) }
  scope :visible_upcoming, -> { upcoming.where(visible: true) }

  def self.next_visible
    visible_upcoming.first
  end

  def self.next_any
    upcoming.first
  end
end
