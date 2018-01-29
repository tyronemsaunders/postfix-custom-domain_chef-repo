#
# Cookbook:: postfix_mail
# Recipe:: letsencrypt
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

include_recipe 'acme'

# subject alternative names for apps
alt_names = []
apps = node['deploy']['mail'][node.chef_environment]
apps.each do |app|
  alt_names.push("#{app['subdomain'].app['domain']}")
end
alt_names.push("#{node['deploy']['mail'][node.chef_environment][0]['domain']}")

# tls challenge
if node['deploy']['mail'][node.chef_environment][0]['acme_cert']['requested'] && node['deploy']['mail'][node.chef_environment][0]['acme_cert']['challenge'] == 'tls-sni-01'
  acme_ssl_certificate "#{node['mail']['directories']['ssl']}/ssl.pem" do
    cn            "mail.#{node['deploy']['mail'][node.chef_environment][0]['domain']}"
    alt_names     alt_names
    output        :fullchain
    key           "#{node['mail']['directories']['ssl']}/ssl.key"
    webserver     :nginx
    notifies      :reload, 'service[nginx]'
  end
end

# http challenge
if node['deploy']['mail'][node.chef_environment][0]['acme_cert']['requested'] && node['deploy']['mail'][node.chef_environment][0]['acme_cert']['challenge'] == 'http-01'
  acme_certificate "mail.#{node['deploy']['mail'][node.chef_environment][0]['domain']}" do
    cn        "mail.#{node['deploy']['mail'][node.chef_environment][0]['domain']}"
    alt_names alt_names
    crt       "#{node['mail']['directories']['ssl']}/ssl.pem"
    chain     "#{node['mail']['directories']['ssl']}/ssl-chain.pem"
    key       "#{node['mail']['directories']['ssl']}/ssl.key"
    wwwroot   "/.acme-cert/mail.#{node['deploy']['mail'][node.chef_environment][0]['domain']}"
    notifies  :reload, 'service[nginx]'
  end
end
