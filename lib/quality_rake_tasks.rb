require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

# *Audience*: World

module SharedTasks
  #---------------------------------------------------------------------------------------------------------------------------------
  # Tests

  # Lets you very concisely create a test task using some common default options. A block may be provided if you want to set additional options.
  # *Example*:
  #   SharedTasks.normal_test_task
  # *Audience*: World
  def self.normal_test_task()
    module_eval do
      desc 'Run tests'
      Rake::TestTask.new(:test) do |task|
        task.libs << 'lib'
        task.pattern = 'test/**/*_test.rb'
        task.verbose = true
        # To do: autorequire color library? Could do something like this once we switch to gem dependencies...
        #task.ruby_opts << "-r /home/tyler/code/gemables/test_extensions/lib/test_helper.rb"
        yield task if block_given?
      end
    end
  end
  #---------------------------------------------------------------------------------------------------------------------------------
  # Documentation

  # Generates an RDoc task for you with common options enabled, including a nicer template than the default.
  # Pass it a block if you need to customize it.
  # Example:
  #   SharedTasks.rdoc_task do |rdoc|
  #     rdoc.title = Project::PrettyName
  #   end
  # *Audience*: World
  def self.rdoc_task(&block)
    begin
      module_eval do
        #-------------------------------------------------------------------------------------------
        desc 'Generate RDoc'
        Rake::RDocTask.new(:rdoc) do |rdoc|
          rdoc.rdoc_dir = 'doc'
          rdoc.options << 
            '--line-numbers' <<                 # Include line numbers in the source code
            '--inline-source' <<                # Causes "Show source" link to display source inline rather than as a popup
            '--all' <<                          # Include private methods
            '--diagram' <<                      # Include diagrams showing modules and classes.
            '--accessor' << 'mattr_accessor' << # So that attributes defined with mattr_accessor will be listed
            '--extension' << 'rake=rb'          # Treat .rake files as files that contain Ruby code
          gem     'quality_rdoc'
          require 'quality_rdoc'
          rdoc.template = QualityRDoc.path_to_template
          rdoc.rdoc_files.include(
            'Readme',
            'lib/**/*.rb'
          )
          yield rdoc
        end
      end
    rescue Gem::LoadError
      p $!
    end
  end

  # Put images and stuff under doc_include and you can refer to them with links such as Screenshot[link:include/screenshot1.png]
  task :doc_include do
    mkdir 'doc' rescue nil
    cp_r 'doc_include', target = 'doc/include'

    # Remove those pesky .svn directories
    require 'find'
    require 'fileutils'
    Find.find(target) do |path|
      if File.basename(path) == '.svn'
        FileUtils.remove_dir(path, true)
        Find.prune
      end
    end
  end

  # Well, I'd rather make :doc_includes a "postrequisite" for :rdoc, but unfortunately Rake doesn't seem to provide a way to specify postrequisites.
  # and :clobber_rdoc (lib/rake/rdoctask.rb) does a rm_r rdoc_dir so anything we do to the directory *before* :rdoc will get wiped out.
  # So... we are left with making :doc_include a prerequisite for the publishing tasks. Unless you have a better idea??
  #task :publish_rdoc_local => :rerdoc
  #task :publish_rdoc_local => :doc_include


  #---------------------------------------------------------------------------------------------------------------------------------
  # Packaging (creating a new version/release)

  require 'rake/gempackagetask'

  def release_notes; "doc_include/ReleaseNotes-#{Project::Version}"; end

  def self.package_task(specification, &block)
    module_eval do
      Rake::GemPackageTask.new(specification) do |package|
         package.need_zip = true
         package.need_tar = true
      end
    end
  end

  def self.inc_version(file)
    module_eval do
      desc "Increment version number and create release notes"
      task :inc_version do
        # This will be easier once we change to a YAML-based ProjectInfo file...
        require 'facets/file/rewrite'
        new_version = Project::Version
        File.rewrite(file) do |contents| 
          contents.gsub!(/(Version *=.*?)(\d+\.\d+\.\d+)(.*)$/) do
            before, version, after = $1, $2, $3
            version = version.split('.')
            new_version = version[0] + '.' + version[1] + '.' + (version[2].to_i+1).to_s
            new_text = before + new_version + after
            puts new_text
            new_text
          end
        end
        Project.const_set(:Version, new_version)

        system(%(vim #{release_notes}))
        sh %(svn add #{release_notes})
        puts "When you're ready to commit, you can use this:"
        puts "svn ci -F #{release_notes}"
      end
    end
  end

  desc 'Use ruby1.9/gem1.9'
  task :'1.9' do
    ENV['ruby_command'] = 'ruby1.9'
    ENV['gem_command']  = 'gem1.9'
  end

  desc "Test installing the gem locally"
  # Use rake clean to force rebuilding of gem. Otherwise it may see that it has already built a gem file with that name and just try to reinstall the one we've already got.
  task :gem_install => [:clean, :gem] do
    # :todo:
    # This should give a loud warning and require confirmation if this version already installed.
    # Ask if they want to increment the version number instead (default). It doesn't cost anything to just increment the version number,
    # and it's bad practice to use the same version number for two versions that are actually *different*.
    # It would be okay to reinstall (--force) the current version if one is just testing something *prior* to official release.
    # But once a version is released, it should never be changed. So I guess rather than checking if this version is installed locally,
    # we should check some flag that we keep in ProjectVersion containing the last version number that has been published and refuse to
    # rebuild a gem version that has already been released...
    sh %{sudo #{ENV['gem_command']||'gem'} install --local --force --no-rdoc --no-ri pkg/#{Project::Name}-#{Project::Version}.gem }
  end

  desc "Remove generated directories."
  task :clean do
    sh %(rm -rf doc/ pkg/)
  end


  #---------------------------------------------------------------------------------------------------------------------------------
  # Publishing

  require File.dirname(__FILE__) + '/../vendor/rake/lib/rake/contrib/sshpublisher'

  def self.publish_task()
    module_eval do
      desc "Upload RDoc to RubyForge"
      task :publish_rdoc do  #=> [:publish_rdoc_local]
        Rake::SshDirPublisher.new("#{ENV['RUBYFORGE_USER']}@rubyforge.org", "/var/www/gforge-projects/#{Project::RubyForgeName}", "doc").upload
      end

      # This can be invoked from the command line:
      #   rake release RUBYFORGE_USER=myuser \
      #                RUBYFORGE_PASSWORD=mypassword
      task :verify_user do
        raise "RUBYFORGE_USER environment variable not set!" unless ENV['RUBYFORGE_USER']
      end
      task :verify_password do
        raise "RUBYFORGE_PASSWORD environment variable not set!" unless ENV['RUBYFORGE_PASSWORD']
      end

      desc "Publish package files on RubyForge."
      task :publish_packages => [:verify_user, :verify_password, :package] do
        require 'meta_project'
        require 'rake/contrib/xforge'
        release_files = FileList[
          "pkg/#{Project::Name}-#{Project::Version}.gem",
          "pkg/#{Project::Name}-#{Project::Version}.tgz",
          "pkg/#{Project::Name}-#{Project::Version}.zip"
        ]

        Rake::XForge::Release.new(MetaProject::Project::XForge::RubyForge.new(Project::RubyForgeName)) do |release|
          release.user_name = ENV['RUBYFORGE_USER']
          release.password = ENV['RUBYFORGE_PASSWORD']
          release.files = release_files.to_a
          release.package_name = "#{Project::Name}"
          release.release_name = "#{Project::Name} #{Project::Version}"
          release.release_changes = ''
          #release.release_notes = File.read(release_notes)       # Probably want to put them somewhere else, but for now...
        end
      end
    end
  end


  #---------------------------------------------------------------------------------------------------------------------------------
  # Announcing

  task :commits_since_last_release do
    # Look at last release number/revision
    # Display log messages for all revisions since then
    # Can use it to write the release notes for you
  end

end # SharedTasks

include SharedTasks
