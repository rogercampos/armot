require 'armot/active_record_extensions'
require 'armot/railtie' if defined?(Rails)

module Armot
  mattr_accessor :token
  @@token = "aXqvyiainsvQWivbpo13/asf/tTG27cbASBFPOQ"

  class DoubleDeclarationError < RuntimeError; end
end

