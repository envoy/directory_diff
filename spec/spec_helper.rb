$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "directory_diff"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }
