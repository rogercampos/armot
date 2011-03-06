module Armot
  module PuretIntegration

    # It assumes all of your tables ending with _translations are puret
    # translation tables.
    def self.migrate

      black_list = ["created_at", "updated_at", "locale", "id"]

      new_i18n_translations = []
      ActiveRecord::Base.connection.tables.each do |t|
        if t =~ /(\w+)_translations$/
          model = $1
          attributes = ActiveRecord::Base.connection.columns(t).select{|x| !(black_list + ["#{model}_id"]).include?(x.name)}.map{|x| x.name}

          t.classify.constantize.all.each do |instance|

            attributes.each do |attr|
              if value = instance.send(attr)
                new_i18n_translations << I18n::Backend::ActiveRecord::Translation.new(
                          :locale => instance.locale,
                          :value => value,
                          :key => "armot.#{model.pluralize}.#{attr}.#{attr}_#{  instance.send("#{model}_id")  }")
              end
            end
          end
        end
      end

      I18n::Backend::ActiveRecord::Translation.transaction do
        new_i18n_translations.each {|x| x.save}
      end
    end
  end
end
