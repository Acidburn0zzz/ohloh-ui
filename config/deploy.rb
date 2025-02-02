# frozen_string_literal: true

lock '3.11.0'

set :whoami, `whoami`.strip
set :default_env, 'PATH' => '/home/serv-deployer/.rbenv/shims:$PATH',
                  'BASH_ENV' => '/home/serv-deployer/.production_vars'

set :application, ENV['APP'] || 'openhub'
set :repo_url, 'git@github.com:blackducksoftware/ohloh-ui.git'
set :user, 'serv-deployer'
set :use_sudo, false
set :passenger_restart_with_sudo, false
set :branch, ENV['branch'] || :master
# role :reverification_server, ['deployer@prd-oh-web02.dc2.lan']

set :deploy_to, "/var/local/#{fetch(:application)}"

# Use remote cache for deployment
set :deploy_via, :remote_cache
set :copy_exclude, ['.git']

# Defaults to false. If true, it's skip migration if files in db/migrate not modified
set :conditionally_migrate, true

set :pty, false

set :sidekiq_log, File.join(shared_path, 'log', 'sidekiq.log')
set :sidekiq_config, nil
set :sidekiq_default_hooks, true

set :whenever_roles, :sidekiq

before 'deploy:check:linked_files', 'deploy:update_configuration'
after 'deploy:updated', 'newrelic:notice_deployment'
