require 'armot/puret_integration'

namespace :armot do
  desc 'dump all the existing translations in puret to i18n'
  task :migrate_puret => :environment do
    Armot::PuretIntegration.migrate
  end
end
