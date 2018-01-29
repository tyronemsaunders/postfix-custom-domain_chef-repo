#
# Cookbook:: postfix_mail
# Recipe:: cyrus-sasl
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

# Cyrus IMAP is an email, contacts and calendar server
# set a username and password to prevent an open relay using a plain database file

cyrus_sasl = node['secrets']['mail'][node.chef_environment]['cyrus_sasl']

# Install Cyrus SASL
package "Install Cyrus SASL" do
  package_name ['expect', 'sasl2-bin', 'libsasl2-modules']
  action :upgrade
end

# script to generate sasl user and password
cookbook_file "/etc/postfix/saslpasswd2.sh" do
  source "saslpasswd2.sh"
  mode '0755'
end

# create the user name / password database file in the default location /etc/sasldb2
execute "create sasl username and password" do
  live_stream true
  command "/etc/postfix/saslpasswd2.sh #{node['deploy']['mail'][node.chef_environment]['domain']} #{cyrus_sasl['username']} #{cyrus_sasl['password']}"
end

# adjust permissions for /etc/sasldb2
file "/etc/sasldb2" do
  mode '0400'
  owner 'postfix'
end

# create smtpd.conf for authentication instructions
# tell Cyrus SASL to use the file-based database to authenticate
cookbook_file "/etc/postfix/sasl/smtpd.conf" do
  source "smtpd.conf"
  group 'postfix'
  mode '0755'
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
