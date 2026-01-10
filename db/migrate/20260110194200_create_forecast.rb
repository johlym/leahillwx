class CreateForecast < ActiveRecord::Migration[8.1]
  def change
    create_table :forecasts do |t|
      t.jsonb :forecast

      t.timestamps
    end
  end
end
