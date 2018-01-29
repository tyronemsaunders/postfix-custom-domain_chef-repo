# Cookbook Name:: postfix_base
# Attribute:: default
#
# Copyright 2017, Tyrone Saunders. All Rights Reserved.

#####################
# env specific vars #
#####################
if ["development"].include?(node.chef_environment)
  default['ssh']['user'] = 'vagrant'
elsif ["staging"].include?(node.chef_environment)
  default['ssh']['user'] = 'ubuntu'
else
  default['ssh']['user'] = 'ubuntu'
end

default['timezone'] = 'America/Chicago' # or use UTC, America/Chicago, America/Anchorage, America/Los_Angeles

###############################
# user/owner for applications #
###############################
default['app']['user'] = 'www-data'

#########################
# Environment variables #
#########################
default['environment']['variables'] = {}
default['environment']['variables']['APPLICATION_MODE'] = node.chef_environment.upcase
default['environment']['variables']['TIMEZONE'] = node['timezone']

# literal
default['env']['vars'] = {}
default['env']['vars']['APPLICATION_MODE'] = node.chef_environment.upcase
default['env']['vars']['TIMEZONE'] = node['timezone']

####################
# Data Bag Secrets #
####################
if Chef::Config[:solo]
  default['secrets']['aws'] = Chef::DataBagItem.load('secrets', 'aws')
  default['secrets']['github'] = Chef::DataBagItem.load('secrets', 'github')
  default['secrets']['data_bag'] = Chef::DataBagItem.load('secrets', 'data_bag')
  default['secrets']['host_machine'] = Chef::DataBagItem.load('secrets', 'host_machine')
  default['secrets']['openssl'] = Chef::DataBagItem.load('secrets', 'openssl')
  default['secrets']['ssh_keys'] = Chef::DataBagItem.load('secrets', 'ssh_keys')
else
  default['secrets']['aws'] = Chef::EncryptedDataBagItem.load('secrets', 'aws')
  default['secrets']['github'] = Chef::EncryptedDataBagItem.load('secrets', 'github')
  default['secrets']['data_bag'] = Chef::EncryptedDataBagItem.load('secrets', 'data_bag')
  default['secrets']['host_machine'] = Chef::EncryptedDataBagItem.load('secrets', 'host_machine')
  default['secrets']['openssl'] = Chef::EncryptedDataBagItem.load('secrets', 'openssl')
  default['secrets']['ssh_keys'] = Chef::EncryptedDataBagItem.load('secrets', 'ssh_keys')
end
##########################
# Un-encrypted Data Bags #
##########################
default['deploy']['mail'] = Chef::DataBagItem.load('deploy', 'mail')

# Other attributes
node.override['sysctl']['conf_file'] = '/etc/sysctl.conf'
