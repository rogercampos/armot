module Armot
  module ActiveRecordExtensions
    module ClassMethods
      def armotize(*attributes)
        make_it_armot! unless included_modules.include?(InstanceMethods)

        mixin = Module.new

        attributes.each do |attribute|
          self.instance_eval <<-RUBY
            def find_by_#{attribute}(value)
              t = I18n::Backend::ActiveRecord::Translation.arel_table
              trans = I18n::Backend::ActiveRecord::Translation.where(
                :locale => I18n.locale,
                :value => value.to_yaml
              ).where(
                t[:key].matches("armot.#{self.to_s.underscore.pluralize}%")
              ).all

              return send("where", {:"#{attribute}" => value}).first if trans.empty?

              res = nil
              trans.each do |x|
                res = find_by_id x.key.split("_").last
                break if res
              end

              res
            end

            def find_by_#{attribute}!(value)
              t = I18n::Backend::ActiveRecord::Translation.arel_table
              trans = I18n::Backend::ActiveRecord::Translation.where(
                :locale => I18n.locale,
                :value => value.to_yaml
              ).where(
                t[:key].matches("armot.#{self.to_s.underscore.pluralize}%")
              ).all

              if trans.empty?
                original = send("where", {:"#{attribute}" => value}).first
                raise ActiveRecord::RecordNotFound if original.nil?
                original
              else
                res = nil
                trans.each do |x|
                  res = find_by_id x.key.split("_").last
                  break if res
                end

                res ? res : raise(ActiveRecord::RecordNotFound)
              end
            end
          RUBY

          mixin.module_eval <<-STR
            def #{attribute}=(value)
              armot_attributes[I18n.locale]['#{attribute}'] = value
              I18n.backend.reload!
            end

            def #{attribute}
              return armot_attributes[I18n.locale]['#{attribute}'] if armot_attributes[I18n.locale]['#{attribute}']
              return if new_record?

              trans = I18n.t "#{attribute}_\#{id}", :scope => "armot.\#{self.class.to_s.underscore.pluralize}.#{attribute}", :default => Armot.token
              return trans if trans != Armot.token

              (I18n.available_locales - [I18n.locale]).each do |lang|
                trans = I18n.t "#{attribute}_\#{id}", :scope => "armot.\#{self.class.to_s.underscore.pluralize}.#{attribute}", :default => Armot.token, :locale => lang
                break if trans != Armot.token
              end

              trans == Armot.token ? self[:#{attribute}] : trans
            end

            def #{attribute}_changed?
              armot_attributes[I18n.locale]['#{attribute}'].present?
            end
          STR
        end

        self.const_set("ArmotInstanceMethods", mixin)
        include self.const_get("ArmotInstanceMethods") unless self.included_modules.include?("ArmotInstanceMethods")
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
