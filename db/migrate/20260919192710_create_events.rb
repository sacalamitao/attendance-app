class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.date :event_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :location, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :opened_at
      t.datetime :closed_at

      t.timestamps
    end

    add_index :events, :event_date
    add_index :events, :status
    add_check_constraint :events, "status IN ('draft', 'open', 'closed')", name: "events_status_check"
    add_check_constraint :events, "end_time >= start_time", name: "events_time_range_check"
  end
end
