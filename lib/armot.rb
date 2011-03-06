if defined?(I18n::Backend::ActiveRecord)
  require 'armot/active_record_extensions'
end

require 'armot/railtie' if defined?(Rails)

module Armot
end

