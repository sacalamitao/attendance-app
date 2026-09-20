class CreateAttendees < ActiveRecord::Migration[8.1]
  def change
    create_table :attendees do |t|
      t.string :full_name, null: false
      t.string :gender, null: false
      t.date :birthdate, null: false
      t.string :qr_token, null: false
      t.datetime :deactivated_at

      t.timestamps
    end

    add_index :attendees, :qr_token, unique: true
    add_index :attendees, :birthdate
    add_index :attendees, :deactivated_at
    add_index :attendees, :full_name
    add_check_constraint :attendees, "gender IN ('male', 'female')", name: "attendees_gender_check"
  end
end
