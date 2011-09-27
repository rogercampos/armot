module Armot
  module ActiveRecordExtensions
    module ClassMethods
      def armotize(*attributes)
        make_it_armot! unless included_modules.include?(InstanceMethods)

        attributes.each do |attribute|
          self.class.instance_eval do
            define_method "find_by_#{attribute}" do |value|
              trans = I18n::Backend::ActiveRecord::Translation.find_by_locale_and_value(I18n.locale, value.to_yaml)
              return send("where", {:"#{attribute}" => value}).first if trans.nil?

              find_by_id trans.key.split("_").last
            end

            define_method "find_by_#{attribute}!" do |value|
              trans = I18n::Backend::ActiveRecord::Translation.find_by_locale_and_value(I18n.locale, value.to_yaml)

              if trans.nil?
                original = send("where", {:"#{attribute}" => value}).first
                raise ActiveRecord::RecordNotFound if original.nil?
                original
              else
                find trans.key.split("_").last
              end
            end
          end

          # attribute setter
          define_method "#{attribute}=" do |value|
            armot_attributes[I18n.locale][attribute] = value
            I18n.backend.reload!
          end

          # attribute getter
          define_method attribute do
            return armot_attributes[I18n.locale][attribute] if armot_attributes[I18n.locale][attribute]
            return if new_record?

            trans = I18n.t "#{attribute}_#{id}", :scope => "armot.#{self.class.to_s.underscore.pluralize}.#{attribute}", :default => Armot.token
            return trans if trans != Armot.token

            (I18n.available_locales - [I18n.locale]).each do |lang|
              trans = I18n.t "#{attribute}_#{id}", :scope => "armot.#{self.class.to_s.underscore.pluralize}.#{attribute}", :default => Armot.token, :locale => lang
              break if trans != Armot.token
            end

            trans == Armot.token ? self[attribute] : trans
          end

          define_method "#{attribute}_changed?" do
            armot_attributes[I18n.locale][attribute].present?
          end
        end
      end

    private

      # configure model
      def make_it_armot!
        include InstanceMethods

        after_save :update_translations!
        after_destroy :remove_i18n_entries
      end
    end

    module InstanceMethods

    private
      def armot_attributes
        @armot_attributes ||= Hash.new { |hash, key| hash[key] = {} }
      end

      # called after save
      def update_translations!
        return if armot_attributes.blank?

        armot_attributes.each do |locale, attributes|
          attributes.each do |k, v|
            translation = I18n::Backend::ActiveRecord::Translation.find_or_initialize_by_locale_and_key(locale.to_s, "armot.#{self.class.to_s.underscore.pluralize}.#{k}.#{k}_#{id}")
            translation.update_attribute(:value, v)
          end
        end

        armot_attributes.clear
      end

      def remove_i18n_entries
        t = I18n::Backend::ActiveRecord::Translation.arel_table
        I18n::Backend::ActiveRecord::Translation.delete_all(t[:key].matches("armot.#{self.class.to_s.underscore.pluralize}%_#{id}"))
      end
    end
  end
end

ActiveRecord::Base.extend Armot::ActiveRecordExtensions::ClassMethods
