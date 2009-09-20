require 'rubygems'
require 'facets/kernel/require_local'

#---------------------------------------------------------------------------------------------------------------------------------
# Specification and description

module Project
  PrettyName = "Quality Rake Tasks"
  Name       = "quality_rake_tasks"
  RubyForgeName = Name
  Version    = "0.1.1"
end

specification = Gem::Specification.new do |s|
  s.name    = Project::Name
  s.version = Project::Version
  s.summary = "..."
  s.description = s.summary
  s.author  = '...'
  s.homepage = "http://#{Project::Name}.rubyforge.org/"
  s.rubyforge_project = Project::Name
  s.platform = Gem::Platform::RUBY
  s.add_dependency("facets")
  #s.add_dependency("quality_extensions")

  # Documentation
  s.has_rdoc = true
  s.extra_rdoc_files = ['Readme']
  s.rdoc_options << '--title' << Project::Name << '--main' << 'Readme' << '--line-numbers'

  # Files
  #s.autorequire = "#{Project::Name}"  # autorequire is deprecated (unfortunately). Don't use it.
  s.files = FileList['{lib,test,examples,vendor}/**/*.rb', 'bin/*', 'Readme'].exclude('ToDo').to_a
  s.test_files = Dir.glob('test/*.rb')
  s.require_path = "lib"
  #s.executables = "some_command"
end

require_local "lib/#{Project::Name}"    # Bootstrap self

#---------------------------------------------------------------------------------------------------------------------------------
# Tests

#task :default => :test
#SharedTasks.normal_test_task

#---------------------------------------------------------------------------------------------------------------------------------
# Documentation

# If someone knows a cleaner way to ensure that the "tasks/list" task is *always* executed (not just if the file doesn't exist), PLEASE let me know for crying out load.
task :rdoc => :remove_tasks_list
task :rdoc => "tasks/list-other"

SharedTasks.rdoc_task do |rdoc|
  rdoc.title = Project::PrettyName
  rdoc.rdoc_files.include(
    'tasks/list-*',
    'tasks/*.rake'
  )
end

def write_task_list(filename, filter)
  Dir[File.dirname(__FILE__) + '/tasks/*.rake'].each {|f| load f} # The tasks actually have to be *loaded* in order for them to show up in Rake::Tasks.tasks...
  File.open(filename, "w") do |file|
    # To do: rewrite as functor so it chains the filter call rather than nesting something within it?
    filter.call(
      Rake::Task.tasks.select {|t|
        t.name =~ /./ and t.comment
      }
    ).each do |t|
      file.puts "[<tt>rake #{t.name}</tt>]".ljust(40) + " " +
        (t.comment || ".")
    end
  end
end

file "tasks/list-other" do |task|
  write_task_list(task.name, 
    filter = Proc.new {|tasks|
      tasks.select {|task| task.name =~ /^ssh$|^run_all/}
    } 
  )
end

task :remove_tasks_list do
  Dir[File.dirname(__FILE__) + '/tasks/list-*'].each {|f| rm f}
  #puts `ls tasks/list-*`
end

#---------------------------------------------------------------------------------------------------------------------------------
# Packaging

SharedTasks.package_task(specification)

#---------------------------------------------------------------------------------------------------------------------------------
# Publishing

SharedTasks.publish_task
SharedTasks.inc_version(__FILE__)

#---------------------------------------------------------------------------------------------------------------------------------
