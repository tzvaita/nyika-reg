class CreateProgrammeCases < ActiveRecord::Migration[8.1]
  # The brief's "Programme case" entity: case ID, programme type, household,
  # beneficiary, status, evidence required, verification stage and outcome.
  #
  # NOTE ON SENSITIVE DATA: the brief allows health, disability, children and
  # financial data to be captured inside a defined programme case with restricted
  # access. This table deliberately captures NONE of it. What a case records is
  # which evidence is required and whether it has been seen — the evidence itself
  # stays as document metadata. A case says "a birth certificate was sighted and
  # verified", never what it contained.
  def change
    create_table :programme_cases do |t|
      t.string     :reference, null: false

      t.references :household, null: false, foreign_key: true
      # Who the case is for. Optional: drought relief is for the household as a
      # whole, while BEAM is for a named child.
      t.references :beneficiary, foreign_key: { to_table: :people }

      t.integer    :programme_type, null: false
      t.integer    :status, null: false, default: 0
      t.integer    :outcome

      t.date       :opened_on, null: false
      t.datetime   :submitted_at
      t.datetime   :outcome_recorded_at
      t.text       :outcome_note

      t.references :opened_by, foreign_key: { to_table: :users }
      t.references :submitted_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :programme_cases, :reference, unique: true
    add_index :programme_cases, :status
    add_index :programme_cases, [ :household_id, :programme_type ]
  end
end
