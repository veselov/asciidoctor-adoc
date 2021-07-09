require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
end

task :default => :test

task :check_lib_permissions do
  Dir["lib/*.rb"].each do |filename|
    if !File.world_readable?(filename)
      raise 'All lib/*.rb files must be world readable'
    end
  end
end

Rake::Task[:build].enhance [:check_lib_permissions]
