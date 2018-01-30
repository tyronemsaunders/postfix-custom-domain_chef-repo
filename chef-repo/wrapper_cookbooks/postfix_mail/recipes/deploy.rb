#
# Cookbook:: postfix_mail
# Recipe:: deploy
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.


#############
# variables #
#############
ssh_wrapper = node['secrets']['github'][node.chef_environment]
env_vars = node['env']['vars'].to_hash
env_vars['HOME'] = ::Dir.home(node['app']['user'])
env_vars['USER'] = node['app']['user']
env_vars['NODE_ENV'] = node.chef_environment

###############
# Directories #
###############
directory node['mail']['directories']['runtime'] do
  mode '0755'
  recursive true
end

directory node['mail']['directories']['configuration'] do
  owner node['app']['user']
  group node['app']['user']
  mode '0750'
  recursive true
end

################
# Install Cron #
################
include_recipe 'cron'

##############
# Deployment #
##############
# retrieve configuration details from data bag
apps = node['deploy']['mail'][node.chef_environment]

apps.each do |app|

  ###############
  # Directories #
  ###############
  directory "/var/log/#{app['subdomain']}.#{app['domain']}" do
    recursive true
    owner node['app']['user']
    group node['app']['user']
    mode '0775'
  end

  #############
  # variables #
  #############
  env_vars['APP_NAME'] = app['hostname']
  env_vars["#{app['hostname'].upcase}_PORT"] = app['port']
  env_vars['SUBDOMAIN'] = app['subdomain']
  env_vars['DOMAIN'] = app['domain']
  env_vars['POSTFIX_PORT'] = node['postfix']['port']
  subdomain = app['subdomain']
  domain = app['domain']
  port = app['port']
  force_ssl = app['ssl']
  nginx_template = app['nginx_config_template']
  acme_cert = app['acme_cert']['requested']
  acme_cert_challenge = app['acme_cert']['challenge']

  if subdomain == 'www'
    server_name = domain
  else
    server_name = "#{subdomain}.#{domain}"
  end

  ###########################
  # Deploy app (github) #
  ###########################
  repository = app['git']['repository']
  branch = app['git']['branch']

  # create the directory for the application
  directory "/var/#{domain}/#{subdomain}" do
    owner node['ssh']['user']
    group node['ssh']['user']
    mode '0755'
    action :create
    recursive true
  end

  # Deploy the web application - use synced folder if development env else use github
  if ['staging', 'production'].include? node.chef_environment
    git "/var/#{domain}/#{subdomain}" do
      repository repository
      revision branch
      ssh_wrapper "#{ssh_wrapper['keypair_path']}/#{ssh_wrapper['ssh_wrapper_filename']}"
      environment(
        lazy {
          {
            'HOME' => ::Dir.home(node['ssh']['user']),
            'USER' => node['ssh']['user']
          }
        }
      )
      group node['ssh']['user']
      user node['ssh']['user']
      action :sync
    end
  end

  # install apt packages
  app['apt'].each do |apt_package|
    package apt_package do
      action :upgrade
    end
  end

  # install npm packages
  app['npm']['global'].each do |npm_package|
    nodejs_npm npm_package
  end

  app['npm']['local'].each do |npm_package|
    nodejs_npm npm_package do
      path "/var/#{domain}/#{subdomain}"
    end
  end

  # run npm install
  nodejs_npm "install packages for #{subdomain}.#{domain}" do
    path "/var/#{domain}/#{subdomain}"
    json true
  end

  # configure pm2
  pm2_app = {}
  pm2_app['name'] = app['hostname']
  pm2_app['script'] = "/var/#{domain}/#{subdomain}/src/index.js"
  pm2_app['cwd'] = "/var/#{domain}/#{subdomain}"
  pm2_app['error_file'] = "/var/log/#{app['subdomain']}.#{app['domain']}/#{app['hostname']}.stderr.log"
  pm2_app['out_file'] = "/var/log/#{app['subdomain']}.#{app['domain']}/#{app['hostname']}.stdout.log"
  pm2_app['watch'] = true
  pm2_app['env'] = env_vars

  node.override['pm2']['app_names'][pm2_app['name']] = pm2_app
  node.override['pm2']['ecosystem']['apps'] = node['pm2']['app_names'].values

  if acme_cert && acme_cert_challenge == 'http-01'
    directory "/.acme-cert/mail.#{domain}/.well-known/acme-challenge" do
      mode '0755'
      user node['app']['user']
      group node['app']['user']
      recursive true
    end
  end

  # setup nginx configuration
  nginx_site server_name do
    action :enable
    template nginx_template
    variables(
      :default => false,
      :sendfile => 'off',
      :subdomain => subdomain,
      :domain => domain,
      :port => port,
      :force_ssl => force_ssl,
      :ssl_directory => node['mail']['directories']['ssl'],
      :acme_cert => acme_cert,
      :acme_cert_challenge => acme_cert_challenge
    )

    notifies :reload, 'service[nginx]', :immediately
  end

  # setup cron jobs
  cron_manage node['app']['user'] do
    user node['app']['user']
    action :allow
  end

  app['cron_jobs'].each do |cron_job|
    cron_d cron_job['name'] do
      minute cron_job['minute']
      hour cron_job['hour']
      day cron_job['day']
      month cron_job['month']
      weekday cron_job['weekday']
      mailto cron_job['mailto'] || node['secrets']['openssl']['distinguished_name']['email']
      command cron_job['command']
      environment env_vars
      user node['app']['user']
    end
  end
end

# get healthcheck subdomain and domain
app = apps.first

# setup nginx configuration
nginx_site "mail.#{app['domain']}" do
  action :enable
  template app['nginx_config_template']
  variables(
    :default => false,
    :sendfile => 'off',
    :subdomain => 'mail',
    :domain => app['domain'],
    :port => app['port'],
    :force_ssl => app['force_ssl'],
    :ssl_directory => node['mail']['directories']['ssl'],
    :acme_cert => app['acme_cert'],
    :acme_cert_challenge => app['acme_cert_challenge']
  )

  notifies :reload, 'service[nginx]', :immediately
end

# create directory for pm2 ecosystem file
directory "/var/#{app['domain']}/pm2" do
  recursive true
end

# write the pm2 ecosystem file
file "/var/#{app['domain']}/pm2/ecosystem.json" do
  content Chef::JSONCompat.to_json_pretty(node['pm2']['ecosystem'])
  action :create # If a file already exists (but does not match), update that file to match.
end

# run commands
cmd_env_vars = env_vars.clone
cmd_env_vars['HOME'] = ::Dir.home(node['ssh']['user'])
cmd_env_vars['USER'] = node['ssh']['user']
cmd_line_env = cmd_env_vars.keys.map { |key| "#{key}=#{cmd_env_vars[key]}" }.join(' ')
app['commands'].each do |cmd|
  execute "run #{cmd} command" do
    live_stream true
    user node['ssh']['user']
    group node['ssh']['user']
    environment(
      lazy {
        {
          'HOME' => ::Dir.home(node['ssh']['user']),
          'USER' => node['ssh']['user']
        }
      }
    )
    cwd "/var/#{domain}/#{subdomain}"
    command "#{cmd_line_env} #{cmd}"
  end
end
