#
# Cookbook:: postfix_mail
# Recipe:: send-dkim-public-key
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

# install mailutils
package 'install mailutils' do
  package_name ['mailutils']
  action :upgrade
end

# email public key
execute 'Email the DKIM public Key' do
  command "echo \"Please find the public DKIM key that is attached.  Publish your public key through DNS.\" | sudo mail -s \"Public DKIM key for #{node['deploy']['mail'][node.chef_environment]['domain']}\" -a \"From: info@#{node['deploy']['mail'][node.chef_environment]['domain']}\" #{node['opendkim']['recipient_email']} -A #{node['opendkim']['config']['dir']}/mail.txt"
end
