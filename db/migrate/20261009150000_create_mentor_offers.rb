class CreateMentorOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :mentor_offers, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string  :subject,         null: false
      t.text    :experience,      null: false
      t.text    :who_its_for,     null: false
      t.integer :sessions_count,  null: false
      t.integer :session_minutes, null: false

      t.timestamps null: false
    end
  end
end
