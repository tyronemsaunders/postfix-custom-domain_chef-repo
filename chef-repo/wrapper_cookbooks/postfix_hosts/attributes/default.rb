# Cookbook Name:: postfix_hosts
# Attribute:: default
#
# Copyright 2017, Tyrone Saunders. All Rights Reserved.

# when deploying multiple programs to an EC2 instance assume all programs have the same domain
mail_apps = node['deploy']['mail'][node.chef_environment]

# when deploying multiple programs to an EC2 instance assume all programs have the same domain
mail = mail_apps.first
default['hosts']['hostname'] = mail['domain']

aliases = []
aliases.push('mail', "mail.#{mail['domain']}")
mail_apps.each do |m|
  aliases.push("#{m['subdomain']}.#{m['domain']}")
  aliases.push(m['subdomain'])
end

default['hosts']['aliases'] = aliases

default['hosts']['IPv4_loopback']['hostname'] = node['hosts']['hostname']
default['hosts']['IPv4_loopback']['aliases'] = node['hosts']['aliases'] + ['localhost']

default['hosts']['elastic_ip']['hostname'] = node['hosts']['hostname']
default['hosts']['elastic_ip']['aliases'] = node['hosts']['aliases']
