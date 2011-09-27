ActiveRecord::Schema.define(:version => 1) do
  create_table :posts do |t|
    t.string :title
    t.text   :text
    t.string :header
  end

  create_table :comments do |t|
    t.string :msg
    t.string :title
  end

  # I18n ar translations table
  create_table :translations do |t|
    t.string :locale
    t.string :key
    t.text   :value
    t.text   :interpolations
    t.boolean :is_proc, :default => false
  end

  # Puret post translations to test the migration process
  create_table :post_translations do |t|
    t.references :post
    t.string :locale
    t.string :title
    t.text :text
    t.timestamps
  end
end

