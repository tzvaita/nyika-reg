class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      # Stable public reference, safe to print on a paper form or read aloud.
      t.string  :reference, null: false

      t.string  :name, null: false
      t.string  :principal_contact

      # FIELD MINIMISATION: a description a neighbour could give ("third homestead
      # past the borehole"). Deliberately NOT GPS coordinates, a plot number or a
      # title deed reference — the registry takes no position on land claims.
      t.text    :location_description

      # How the record reached the registry.
      t.integer :capture_source, null: false, default: 0

      # draft -> pending -> verified, with inactive as the soft-delete terminus.
      t.integer :status, null: false, default: 0

      t.date    :last_confirmed_on

      t.references :captured_by, foreign_key: { to_table: :users }
      t.references :verified_by, foreign_key: { to_table: :users }
      t.datetime   :verified_at

      t.timestamps
    end

    add_index :households, :reference, unique: true
    add_index :households, :status
    # Supports the duplicate-detection report (plan step 7).
    add_index :households, [ :name, :location_description ],
              name: "index_households_on_name_and_location"
  end
end
