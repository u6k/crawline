$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "crawline"

# Database config
db_config = {
  adapter: "postgresql",
  database: ENV["DB_DATABASE"],
  host: ENV["DB_HOST"],
  port: ENV["DB_PORT"],
  username: ENV["DB_USERNAME"],
  password: ENV["DB_PASSWORD"],
  sslmode: ENV["DB_SSLMODE"]
}

ActiveRecord::Base.establish_connection db_config
