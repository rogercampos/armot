module Armot
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/puret_migration.rake"
    end
  end
end
