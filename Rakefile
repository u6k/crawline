require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

# Database migration tasks

require "standalone_migrations"
StandaloneMigrations::Tasks.load_tasks
