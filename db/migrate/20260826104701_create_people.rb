class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :household, null: false, foreign_key: true

      t.string  :name, null: false
      t.integer :relationship, null: false, default: 0

      # FIELD MINIMISATION: age_band is the preferred form. year_of_birth is
      # allowed where a household knows it, but a full date of birth is NOT
      # collected — it is identifying and the registry has no use for it.
      t.integer :age_band
      t.integer :year_of_birth

      t.integer :residency_status, null: false, default: 0

      # Optional, and only how to reach them — never a national ID number.
      t.string  :contact_method

      # Soft-delete: people leave households without their history being erased.
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :people, [ :household_id, :active ]
  end
end
