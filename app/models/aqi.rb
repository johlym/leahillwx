# == Schema Information
#
# Table name: aqis
#
#  id         :bigint           not null, primary key
#  co         :float
#  nh3        :float
#  no         :float
#  no2        :float
#  o3         :float
#  pm10       :float
#  pm2_5      :float
#  so2        :float
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Aqi < ApplicationRecord
  validates :co, :nh3, :no, :no2, :o3, :pm10, :pm2_5, :so2, presence: true
  validates :co, :nh3, :no, :no2, :o3, :pm10, :pm2_5, :so2, numericality: { greater_than_or_equal_to: 0 }
end
