if defined?(I18n::Backend::ActiveRecord)
  require 'armot/active_record_extensions'
else
  raise StandardError, "I18n active-record backend must be loaded in order to use armot"
end

module Armot
end

