class AddIntervalToForecast < ActiveRecord::Migration[8.1]
  def change
    add_column :forecasts, :interval, :string, default: 'daily', null: false
  end
end
