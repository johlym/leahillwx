class RenamePm25inAqi < ActiveRecord::Migration[8.1]
  def change
    rename_column :aqis, :aqi, :pm2_5
  end
end
