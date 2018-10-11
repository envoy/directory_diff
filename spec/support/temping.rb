require "temping"
require "yaml"

RSpec.configure do |config|
  config.before :suite do
    yaml = File.join(File.dirname(__FILE__), "database.yml")
    db_config = YAML::load(File.open(yaml))
    ActiveRecord::Base.establish_connection(db_config)
  end

  config.after do
    Temping.teardown
  end
end
