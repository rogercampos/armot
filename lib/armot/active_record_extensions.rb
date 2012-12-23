module Armot
  module ActiveRecordExtensions
    module ClassMethods
      def armotize(*attributes)
        if included_modules.include?(InstanceMethods)
          raise DoubleDeclarationError, "armotize can only be called once in #{self}"
        end

        make_it_armot!

        instance_mixin = Module.new
        class_mixin = Module.new

        class_mixin.module_eval do
          define_method :armotized_attributes do
            attributes.map(&:to_sym)
          end

          define_method :define_localized_accessors_for do |*localizable_attributes|
            reload_localized_accessors_for *localizable_attributes
          end

          define_method :reload_localized_accessors_for do |*localizable_attributes|
            localizable_attributes = armotized_attributes if localizable_attributes.first == :all

            locales_to_define = if localizable_attributes.last.is_a?(Hash) && localizable_attributes.last[:locales]
              localizable_attributes.last[:locales]
            else
              I18n.available_locales
            end

            localizable_attributes.each do |attr|
              locales_to_define.each do |locale|
                next if respond_to?(:"#{attr}_#{locale}")
                define_method "#{attr}_#{locale}" do
                  armot_wrap_in_locale(locale) do
                    send attr
                  end
                end

                next if respond_to?(:"#{attr}_#{locale}=")
                define_method "#{attr}_#{locale}=" do |value|
                  armot_wrap_in_locale(locale) do
                    send "#{attr}=", value
                  end
                end
              end
            end
          end
        end

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
          end

          instance_mixin.module_eval do
            define_method :"#{attribute}=" do |value|
              armot_attributes[I18n.locale]["#{attribute}"] = value
            end

            define_method :"#{attribute}_changed?" do
              armot_attributes[I18n.locale]["#{attribute}"].present?
            end

            define_method :"#{attribute}_raw" do
              return armot_attributes[I18n.locale]["#{attribute}"]
            end

            define_method :"#{attribute}" do
              return send("#{attribute}_raw") if armot_attributes[I18n.locale]["#{attribute}"]

              if armot_attributes.any? && I18n.respond_to?(:fallbacks)
                I18n.fallbacks[I18n.locale].each do |fallback|
                  return armot_attributes[fallback]["#{attribute}"] if armot_attributes[fallback]["#{attribute}"]
                end
              end

              if persisted? && I18n.respond_to?(:fallbacks)
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

      def validates_armotized_presence_of(attr_name, locales)
        validates_with Armot::ActiveRecordExtensions::Validations::PresenceValidator, :attr => attr_name, :locales => locales
      end

    private

      # configure model
      def make_it_armot!
        include InstanceMethods

        after_save :armot_update_translations!
        after_destroy :armot_remove_i18n_entries
      end
    end

    module InstanceMethods
      private

      def armot_attributes
        @armot_attributes ||= Hash.new { |hash, key| hash[key] = {} }
      end

      def armot_update_translations!
        return if armot_attributes.empty?

        armot_attributes.each do |locale, attributes|
          attributes.each do |k, v|
            translation = I18n::Backend::ActiveRecord::Translation.find_or_initialize_by_locale_and_key(locale.to_s, "armot.#{self.class.to_s.underscore.pluralize}.#{k}.#{k}_#{id}")
            translation.update_attribute(:value, v)
          end
        end

        reload_armot! if respond_to?(:"reload_armot!")
        armot_attributes.clear
      end

      def armot_remove_i18n_entries
        t = I18n::Backend::ActiveRecord::Translation.arel_table
        I18n::Backend::ActiveRecord::Translation.delete_all(t[:key].matches("armot.#{self.class.to_s.underscore.pluralize}%_#{id}"))
      end

      def armot_wrap_in_locale(locale)
        aux = I18n.locale
        I18n.locale = locale.to_sym
        res = yield
        I18n.locale = aux
        res
      end
    end

    module Validations
      class PresenceValidator < ActiveModel::Validator
        def validate(record)
          attr_name = options[:attr]
          locales = options[:locales]

          valid = locales.map do |locale|
            I18n.locale = locale.to_sym
            record.send("#{attr_name}_raw").present?
          end.inject(:&)

          record.errors.add(attr_name, "has to be present for locales #{locales.to_sentence}") unless valid
        end
      end
    end
  end
end

ActiveRecord::Base.extend Armot::ActiveRecordExtensions::ClassMethods
