class CreateCaseDocuments < ActiveRecord::Migration[8.1]
  # The brief's "Document record": document ID, type, related entity, uploader,
  # verification status, file link and date.
  #
  # This stores METADATA AND A LINK ONLY. The brief calls for "secure object
  # storage linked to cases, not uncontrolled document dumping", and separately
  # warns against holding identity document images. So the registry records that
  # a document was sighted, of what type, by whom, and where it lives — it does
  # not hold the file, and it never transcribes what the document says.
  def change
    create_table :case_documents do |t|
      # Polymorphic because the brief says "related entity", not "case". Today
      # only programme cases have documents; contributions and receipts will.
      t.references :documentable, polymorphic: true, null: false

      t.integer    :document_type, null: false
      t.integer    :verification_status, null: false, default: 0

      t.string     :file_link
      t.date       :sighted_on
      t.text       :note

      t.references :uploaded_by, foreign_key: { to_table: :users }
      t.references :verified_by, foreign_key: { to_table: :users }
      t.datetime   :verified_at

      t.timestamps
    end

    add_index :case_documents, [ :documentable_type, :documentable_id, :document_type ],
              name: "index_case_documents_on_documentable_and_type"
  end
end
