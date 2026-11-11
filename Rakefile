require 'rubygems'
require 'rake'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'bundler/gem_tasks'

desc "Run all specs in spec directory (excluding plugin specs)"
RSpec::Core::RakeTask.new(:spec)

INTEGRATION_LIBS = %w(will_paginate kaminari active_record active_model_serializers rspec)
# kaminari and the rspec matchers are not maintained in this fork, and their specs fail.
MAINTAINED_INTEGRATION_LIBS = INTEGRATION_LIBS - %w(kaminari rspec)

namespace :spec do

  namespace :integration do

    INTEGRATION_LIBS.each do |lib|

      desc "Run the #{lib} integrate specs"
      RSpec::Core::RakeTask.new(lib.to_sym) do |t|
        t.rspec_opts = "--tag integration"
        t.pattern = "./spec/integration/#{lib}_spec.rb"
      end

    end

  end

  # separate process: rails must be loaded before rocket_pants for the railtie to exist.
  desc "Run the specs that boot a real Rails application"
  RSpec::Core::RakeTask.new(:smoke) do |t|
    t.pattern = "./smoke/*_spec.rb"
  end

  desc "Run all specs with rcov"
  RSpec::Core::RakeTask.new(:rcov) do |t|
    t.rcov = true
    t.pattern = "./spec/**/*_spec.rb"
    t.rcov_opts = '--exclude spec/,/gems/,/Library/,/usr/,lib/tasks,.bundle,config,/lib/rspec/,/lib/rspec-'
  end
end

task :default => ([:spec, "spec:smoke"] + MAINTAINED_INTEGRATION_LIBS.map { |l| "spec:integration:#{l}" })
