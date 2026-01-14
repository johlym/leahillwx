class AddColumnsToAqi < ActiveRecord::Migration[8.1]
  def change
    add_column :aqis, :co, :float
    add_column :aqis, :no, :float
    add_column :aqis, :no2, :float
    add_column :aqis, :o3, :float
    add_column :aqis, :so2, :float
    add_column :aqis, :pm10, :float
    add_column :aqis, :nh3, :float
  end
end
