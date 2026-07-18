# frozen_string_literal: true

class CreateSkyAndHazardSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :wildfire_snapshots do |t|
      t.string :name, null: false
      t.float :lat, null: false
      t.float :lon, null: false
      t.float :distance_mi, null: false
      t.float :acres
      t.float :percent_contained
      t.string :url
      t.string :source, null: false
      t.string :external_id
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :wildfire_snapshots, :fetched_at

    create_table :aurora_snapshots do |t|
      t.float :kp, null: false
      t.float :kp_forecast_max_tonight
      t.float :local_ovation_pct
      t.string :status_label, null: false
      t.string :odds_label
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :aurora_snapshots, :fetched_at

    create_table :planet_nights do |t|
      t.date :date, null: false
      t.string :timezone, null: false, default: "America/Los_Angeles"
      t.jsonb :planets, null: false, default: []
      t.timestamps
    end
    add_index :planet_nights, :date, unique: true

    create_table :iss_passes do |t|
      t.datetime :aos_at, null: false
      t.datetime :los_at, null: false
      t.float :aos_az, null: false
      t.float :los_az, null: false
      t.float :max_el, null: false
      t.float :max_el_az, null: false
      t.integer :duration_s, null: false
      t.boolean :visible, null: false, default: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :iss_passes, :aos_at
    add_index :iss_passes, [ :visible, :aos_at ]
  end
end
