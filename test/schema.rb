ActiveRecord::Schema.define(:version => 1) do
  create_table :posts do |t|
    t.string :title
    t.text   :text

    t.timestamps
  end

  # I18n ar translations table
  create_table :translations do |t|
    t.string :locale
    t.string :key
    t.text   :value
    t.text   :interpolations
    t.boolean :is_proc, :default => false
  end
end

