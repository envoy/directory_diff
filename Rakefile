require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yaml"
require "active_record"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :db do
  db_config = YAML::load(File.open("spec/support/database.yml"))
  db_config_admin = db_config.merge({"database" => "postgres", "schema_search_path" => "public"})

  desc "Create the database"
  task :create do
    begin
      ActiveRecord::Base.establish_connection(db_config_admin)
      ActiveRecord::Base.connection.create_database(db_config["database"])
      puts "Database created."
    rescue ActiveRecord::StatementInvalid
      puts "Database already exist."
    end
  end
end
