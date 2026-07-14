class AddObservedAtAndSourceToAqis < ActiveRecord::Migration[8.0]
  def change
    add_column :aqis, :observed_at, :datetime
    add_column :aqis, :epa_aqi, :integer
    add_column :aqis, :source, :string

    add_index :aqis, :observed_at, unique: true
    add_index :aqis, :source
  end
end
