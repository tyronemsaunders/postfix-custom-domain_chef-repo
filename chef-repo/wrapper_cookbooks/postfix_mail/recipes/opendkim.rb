#
# Cookbook:: postfix_mail
# Recipe:: opendkim
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

# install openDKIM
package "install OpenDKIM" do
  package_name ['opendkim', 'opendkim-tools']
  action :upgrade
end

# add the postfix user to the opendkim group
group "opendkim" do
  action :modify
  append true
  members ['postfix']
end

# configure openDKIM
template "#{node['opendkim']['config']['file']}" do
  source "opendkim.conf.erb"
end

cookbook_file "/etc/default/opendkim" do
  source "opendkim-default"
end

# create opendkim.d directory
directory "#{node['opendkim']['config']['dir']}"

# create socket directory
directory "/var/spool/postfix/var/run/opendkim/" do
  user 'opendkim'
  group 'opendkim'
  mode '0775'
  recursive true
  action :create
end

# create configuration for creation, deletion and cleaning of volatile and temporary files
file "/usr/lib/tmpfiles.d/opendkim.conf" do
  content "d /var/run/opendkim 0775 postfix opendkim"
  mode '0644'
  owner 'root'
  group 'root'
end

# set the trusted hosts
template "#{node['opendkim']['config']['dir']}/TrustedHosts" do
  source "TrustedHosts.erb"
end

# generate DKIM signing keys
execute "generate DKIM signing keys" do
  live_stream true
  cwd node['opendkim']['config']['dir']
  command "opendkim-genkey -s mail -d #{node['deploy']['mail'][node.chef_environment]['domain']}"
end

# set permissions on DKIM signing key
file "#{node['opendkim']['config']['dir']}/mail.private" do
  mode '0600'
  owner 'opendkim'
end

# start the opendkim server
service "opendkim" do
  action [:enable, :start]
  provider Chef::Provider::Service::Systemd
end

# restart postfix
bash "restart postfix" do
  live_stream true
  code <<-EOH
    postfix stop
    postfix start
    postfix reload
  EOH
end
