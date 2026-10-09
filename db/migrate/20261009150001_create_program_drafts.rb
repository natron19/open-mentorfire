class CreateProgramDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :program_drafts, id: :uuid do |t|
      t.references :mentor_offer, type: :uuid, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.text     :gemini_raw
      t.string   :failure_reason
      t.datetime :generated_at

      # The offer's session count and length when the draft ran, so the page and the .md stay true after an edit.
      t.integer :sessions_count
      t.integer :session_minutes

      t.string :name
      t.text   :purpose
      t.text   :outcome_statement
      t.jsonb  :sessions,              null: false, default: []
      t.jsonb  :tasks,                 null: false, default: []
      t.jsonb  :first_intro_questions, null: false, default: []

      t.timestamps null: false
    end
    add_index :program_drafts, :status
  end
end
