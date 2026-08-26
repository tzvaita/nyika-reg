class CreateSolidCacheTables < ActiveRecord::Migration[8.1]
  # Solid Cache's table, in the PRIMARY database for the same single-database
  # reason as the queue tables.
  #
  # This matters beyond caching: the rate limiting on /register and /h/:token
  # uses Rails.cache, which was per-process memory. Backed by the database, those
  # limits hold across processes and survive a restart.
  def change
  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", limit: 1024, null: false
    t.binary "value", limit: 536870912, null: false
    t.datetime "created_at", null: false
    t.integer "key_hash", limit: 8, null: false
    t.integer "byte_size", limit: 4, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end
  end
end
