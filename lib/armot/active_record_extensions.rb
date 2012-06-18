module Armot
  module ActiveRecordExtensions
    module ClassMethods
      def armotize(*attributes)
        make_it_armot! unless included_modules.include?(InstanceMethods)

        instance_mixin = Module.new
        class_mixin = Module.new

        attributes.each do |attribute|
          class_mixin.module_eval do
            define_method :"find_by_#{attribute}" do |value|
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

            define_method :"find_by_#{attribute}!" do |value|
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

            # To implement by armotized classes
            define_method :"reload_armot!" do
            end
          end

          instance_mixin.module_eval do
            define_method :"#{attribute}=" do |value|
              armot_attributes[I18n.locale]["#{attribute}"] = value
            end

            define_method :"#{attribute}_changed?" do
              armot_attributes[I18n.locale]["#{attribute}"].present?
            end

            define_method :"#{attribute}" do
              return armot_attributes[I18n.locale]["#{attribute}"] if armot_attributes[I18n.locale]["#{attribute}"]

              if armot_attributes.any?
                I18n.fallbacks[I18n.locale].each do |fallback|
                  return armot_attributes[fallback]["#{attribute}"] if armot_attributes[fallback]["#{attribute}"]
                end
              end

              if persisted?
                trans = I18n.t "#{attribute}_#{id}", :scope => "armot.#{self.class.to_s.underscore.pluralize}.#{attribute}", :default => Armot.token
                return trans if trans != Armot.token
              end

              ( new_record? || trans == Armot.token) ? self[:"#{attribute}"] : trans
            end
          end
        end

        self.const_set("ArmotInstanceMethods", instance_mixin)
        self.const_set("ArmotClassMethods", class_mixin)
        include self.const_get("ArmotInstanceMethods") unless self.included_modules.map(&:to_s).include?("#{self}::ArmotInstanceMethods")
        extend self.const_get("ArmotClassMethods") unless self.singleton_class.included_modules.map(&:to_s).include?("#{self}::ArmotClassMethods")
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

      def update_translations!
        return if armot_attributes.empty?

        armot_attributes.each do |locale, attributes|
          attributes.each do |k, v|
            translation = I18n::Backend::ActiveRecord::Translation.find_or_initialize_by_locale_and_key(locale.to_s, "armot.#{self.class.to_s.underscore.pluralize}.#{k}.#{k}_#{id}")
            translation.update_attribute(:value, v)
          end
        end

        self.class.reload_armot!
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
