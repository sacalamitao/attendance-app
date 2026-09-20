class CreateAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :attendances do |t|
      t.references :event, null: false, foreign_key: true
      t.references :attendee, null: false, foreign_key: true
      t.references :operator, null: false, foreign_key: { to_table: :users }
      t.datetime :scanned_at, null: false
      t.string :ministry_classification, null: false

      t.timestamps
    end

    # The invariant: one attendee can be present at most once per event.
    add_index :attendances, [ :event_id, :attendee_id ], unique: true
    add_index :attendances, [ :event_id, :ministry_classification ]
    add_index :attendances, [ :event_id, :scanned_at ]
    add_check_constraint :attendances,
      "ministry_classification IN ('kkb', 'yan', 'mens', 'womens')",
      name: "attendances_ministry_classification_check"
  end
end
