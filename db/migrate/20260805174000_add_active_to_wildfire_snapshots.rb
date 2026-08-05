# frozen_string_literal: true

class AddActiveToWildfireSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :wildfire_snapshots, :active, :boolean, null: false, default: true
    change_column_null :wildfire_snapshots, :name, true
  end
end
