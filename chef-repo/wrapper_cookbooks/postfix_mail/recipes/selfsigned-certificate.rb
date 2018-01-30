#
# Cookbook:: postfix_mail
# Recipe:: selfsigned-certificate
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

# create ssl directory
directory node['mail']['directories']['ssl'] do
  owner "root"
  group "root"
  mode "0755"
  action :create
  recursive true
end

if ['development'].include?(node.chef_environment)
  # subject alternative names for apps
  alt_names = []
  apps = node['deploy']['mail'][node.chef_environment]
  apps.each do |app|
    alt_names.push("DNS:#{app['subdomain'].app['domain']}")
  end
  alt_names.push("DNS:#{node['deploy']['mail'][node.chef_environment][0]['domain']}")

  # mail.domain.tls ssl cert for postfix
  openssl_x509 "#{node['mail']['directories']['ssl']}/ssl.pem" do
    common_name "mail.#{node['deploy']['mail'][node.chef_environment][0]['domain']}"
    subject_alt_name alt_names
    org node['secrets']['openssl']['distinguished_name']['organization_name']
    org_unit node['secrets']['openssl']['distinguished_name']['organizational_unit_name']
    country node['secrets']['openssl']['distinguished_name']['country']
    expire 1095
    owner 'root'
    group 'root'
  end

  # generate dhparam.pem files
  openssl_dhparam "#{node['mail']['directories']['ssl']}/dhparam.pem" do
    key_length 2048
  end

else
  # for staging or development
  include_recipe 'acme'
  # subject alternative names for apps
  alt_names = []
  apps = node['deploy']['mail'][node.chef_environment]
  apps.each do |app|
    alt_names.push("#{app['subdomain'].app['domain']}")
  end
  alt_names.push("#{node['deploy']['mail'][node.chef_environment][0]['domain']}")

  # selfsigned certificate
  acme_selfsigned "mail.#{node['deploy']['mail'][node.chef_environment][0]['domain']}" do
    cn "mail.#{node['deploy']['mail'][node.chef_environment][0]['domain']}"
    alt_names alt_names
    crt "#{node['mail']['directories']['ssl']}/ssl.pem"
    key "#{node['mail']['directories']['ssl']}/ssl.key"
    chain "#{node['mail']['directories']['ssl']}/ssl-chain.pem"
  end

  # generate dhparam.pem files
  openssl_dhparam "#{node['mail']['directories']['ssl']}/dhparam.pem" do
    key_length 2048
  end
end
