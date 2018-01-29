#
# Cookbook:: postfix_mail
# Recipe:: spamassassin
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

# install spamassassin
package 'install spamassassin' do
  package_name ['spamassassin', 'spamc']
  action :upgrade
end

directory '/var/log/spamassassin'

# create user and groups
group 'spamd'
user 'spamd' do
  group 'spamd'
  home '/var/log/spamassassin'
end

directory '/var/log/spamassassin' do
  user 'spamd'
  group 'spamd'
end

# configure spamassassin
cookbook_file '/etc/default/spamassassin' do
  source 'spamassassin'
end

# configure spamassassin rules
cookbook_file '/etc/spamassassin/local.cf' do
  source 'spamassassin-local.cf'
end

# start the start spam assassin
service 'spamassassin' do
  action [:enable, :start]
  provider Chef::Provider::Service::Systemd
end

# restart postfix
bash 'restart postfix' do
  live_stream true
  code <<-EOH
    postfix stop
    postfix start
    postfix reload
  EOH
end
