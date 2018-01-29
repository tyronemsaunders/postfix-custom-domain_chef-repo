#
# Cookbook:: postfix_base
# Recipe:: base
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

node.override['authorization']['sudo']['users'] = ['ubuntu', 'vagrant']
node.override['authorization']['sudo']['passwordless'] = true

# include recipes as a run list
include_recipe  'apt'
include_recipe  'git'
include_recipe  'vim'
include_recipe  'sudo'
include_recipe  'users'
include_recipe  'openssl'

#######################
# Add users to groups #
#######################
users_manage 'sysadmin' do
  group_id 2300
  action [:create]
end

#############################
# set environment variables #
#############################
directory '/etc/profile.d'
template '/etc/profile.d/env_vars.sh' do
  source 'env_vars.sh.erb'
  variables(
    :env_vars => node['environment']['variables']
  )
  not_if { ::File.exist?('/etc/profile.d/env_vars.sh') }
end

###################
# create ssh keys #
###################
ssh_keys = node['secrets']['ssh_keys'][node.chef_environment]

directory '/.ssh' do
  owner node['ssh']['user']
  mode '0700'
end

# public key
unless ssh_keys['public_key_filename'].empty?
  file "/.ssh/#{ssh_keys['public_key_filename']}" do
    content ssh_keys['public_key']
    owner node['ssh']['user']
    mode '0400'
  end
end

# private key
unless ssh_keys['private_key_filename'].empty?
  file "/.ssh/#{ssh_keys['private_key_filename']}" do
    content ssh_keys['private_key']
    owner node['ssh']['user']
    mode '0400'
  end
end

###############################
# Change system time and date #
###############################
bash 'change timzone' do
  code "timedatectl set-timezone #{node['timezone']}"
end
