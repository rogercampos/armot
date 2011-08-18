if defined?(I18n::Backend::ActiveRecord)
  require 'armot/active_record_extensions'
end

require 'armot/railtie' if defined?(Rails)

module Armot
  mattr_accessor :token
  @@token = "aXqvyiainsvQWivbpo13/asf/tTG27cbASBFPOQ"
end

