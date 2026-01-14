class CreateAqi < ActiveRecord::Migration[8.1]
  def change
    create_table :aqis do |t|
      t.float :aqi

      t.timestamps
    end
  end
end
