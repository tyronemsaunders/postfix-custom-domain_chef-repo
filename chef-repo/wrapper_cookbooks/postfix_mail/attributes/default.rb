# Cookbook Name:: postfix_mail
# Attribute:: default
#
# Copyright 2018, Tyrone Saunders. All Rights Reserved.

####################
# Data Bag Secrets #
####################
if Chef::Config[:solo]
  default['secrets']['aws'] = Chef::DataBagItem.load('secrets', 'aws')
  default['secrets']['github'] = Chef::DataBagItem.load('secrets', 'github')
  default['secrets']['ssh_keys'] = Chef::DataBagItem.load('secrets', 'ssh_keys')
  default['secrets']['data_bag'] = Chef::DataBagItem.load('secrets', 'data_bag')
  default['secrets']['host_machine'] = Chef::DataBagItem.load('secrets', 'host_machine')
  default['secrets']['openssl'] = Chef::DataBagItem.load('secrets', 'openssl')
  default['secrets']['mail'] = Chef::DataBagItem.load('secrets', 'mail')
else
  default['secrets']['aws'] = Chef::EncryptedDataBagItem.load('secrets', 'aws')
  default['secrets']['github'] = Chef::EncryptedDataBagItem.load('secrets', 'github')
  default['secrets']['ssh_keys'] = Chef::EncryptedDataBagItem.load('secrets', 'ssh_keys')
  default['secrets']['data_bag'] = Chef::EncryptedDataBagItem.load('secrets', 'data_bag')
  default['secrets']['host_machine'] = Chef::EncryptedDataBagItem.load('secrets', 'host_machine')
  default['secrets']['openssl'] = Chef::EncryptedDataBagItem.load('secrets', 'openssl')
  default['secrets']['mail'] = Chef::EncryptedDataBagItem.load('secrets', 'mail')
end

##########################
# Un-encrypted Data Bags #
##########################
default['deploy']['mail'] = Chef::DataBagItem.load('deploy', 'mail')

default['mail']['directories']['runtime'] = '/srv/mail'
default['mail']['directories']['configuration'] = '/etc/mail'
default['mail']['directories']['ssl'] = "#{node['mail']['directories']['runtime']}/ssl"
default['mail']['directories']['log'] = '/var/log/mail'

############################
# ACME certificate contact #
############################
unless ['development'].include?(node.chef_environment)
  node.override['acme']['contact'] = ["mailto:#{node['secrets']['openssl']['distinguished_name']['email']}"]
  if ['staging'].include?(node.chef_environment)
    node.override['acme']['endpoint'] = 'https://acme-staging.api.letsencrypt.org'
  end
  if ['production'].include?(node.chef_environment)
    node.override['acme']['endpoint'] = 'https://acme-v01.api.letsencrypt.org'
  end
end

#########################
# Postfix Configuration #
#########################
postfix = node['secrets']['mail'][node.chef_environment]['postfix']
mail_forwarding = node['secrets']['mail'][node.chef_environment]['forwarding']

node.override['postfix']['port'] = 587
node.override['postfix']['relayhost'] = postfix['relayhost'] || '[email-smtp.us-east-1.amazonaws.com]:587'
# mail configuration type ('master' will set up a server/relayhost)
node.override['postfix']['mail_type'] = 'master'

node.override['postfix']['main']['inet_interfaces'] = 'all'
node.override['postfix']['main']['myhostname'] = "mail.#{node['deploy']['mail'][node.chef_environment]['domain']}"
node.override['postfix']['main']['mydomain'] = node['deploy']['mail'][node.chef_environment]['domain']
node.override['postfix']['main']['myorigin'] = node['deploy']['mail'][node.chef_environment]['domain']

node.override['postfix']['main']['smtp_use_tls'] = 'yes'
node.override['postfix']['main']['smtp_tls_security_level'] = 'encrypt' # force TLS for everything
node.override['postfix']['main']['smtp_tls_note_starttls_offer'] = 'yes'
node.override['postfix']['main']['smtpd_tls_cert_file'] = "#{node['mail']['directories']['ssl']}/ssl.pem"
node.override['postfix']['main']['smtpd_tls_key_file'] = "#{node['mail']['directories']['ssl']}/ssl.key"

node.override['postfix']['use_virtual_aliases'] = true
node.override['postfix']['main']['virtual_alias_domains'] = node['deploy']['mail'][node.chef_environment]['domain']
node.override['postfix']['main']['virtual_alias_maps'] = 'sqlite:/etc/postfix/sqlite-virtual.cf' # "hash:/etc/postfix/virtual"
node.override['postfix']['maps']['hash']['/etc/postfix/virtual'] = mail_forwarding
node.override['postfix']['maps']['sqlite']['/etc/postfix/sqlite-virtual.cf'] = {
  'dbpath' => '/etc/postfix/sqlite-virtual.db',
  'query' => "SELECT destination FROM virtual_aliases WHERE mailbox = '%s'"
}

node.override['postfix']['main']['smtp_sasl_auth_enable'] = 'yes'
node.override['postfix']['main']['smtp_sasl_security_options'] = 'noanonymous'
node.override['postfix']['sasl']['smtp_sasl_passwd'] = postfix['smtp_sasl_passwd']
node.override['postfix']['sasl']['smtp_sasl_user_name'] = postfix['smtp_sasl_user_name']
node.override['postfix']['main']['smtp_sasl_password_maps'] = 'hash:/etc/postfix/sasl_passwd'
node.override['postfix']['main']['sender_dependent_relayhost_maps'] = "pcre:/etc/postfix/sender_relay.pcre,hash:/etc/postfix/sender_relay"
node.override['postfix']['maps']['hash']['/etc/postfix/sender_relay'] = {
  "@#{node['deploy']['mail'][node.chef_environment]['domain']}" => node['postfix']['relayhost']
}
node.override['postfix']['main']['smtp_sender_dependent_authentication'] = "yes"
node.override['postfix']['maps']['hash']['/etc/postfix/sasl_passwd'] = {
  "@#{node['deploy']['mail'][node.chef_environment]['domain']}" => "#{node['postfix']['sasl']['smtp_sasl_user_name']}:#{node['postfix']['sasl']['smtp_sasl_passwd']}"
}

node.override['postfix']['master']['relay']['args'] = []
node.override['postfix']['master']['smtp']['args'] = [
  "-o content_filter=spamassassin"
]
node.override['postfix']['master']['submission']['active'] = true
node.override['postfix']['master']['submission']['args'] = [
  "-o syslog_name=postfix/submission",
  "-o smtpd_tls_security_level=may",
  "-o smtpd_tls_cert_file=#{node['postfix']['main']['smtpd_tls_cert_file']}",
  "-o smtpd_sasl_auth_enable=yes",
  "-o smtpd_reject_unlisted_recipient=no",
  "-o smtpd_relay_restrictions=permit_sasl_authenticated,reject",
  "-o milter_macro_daemon_name=ORIGINATING"
]
node.override['postfix']['master']['spamassassin']['active'] = true
node.override['postfix']['master']['spamassassin']['order'] = 260
node.override['postfix']['master']['spamassassin']['type'] = 'unix'
node.override['postfix']['master']['spamassassin']['unpriv'] = false
node.override['postfix']['master']['spamassassin']['chroot'] = false
node.override['postfix']['master']['spamassassin']['command'] = 'pipe'
node.override['postfix']['master']['spamassassin']['args'] = [
  "user=spamd argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f ${sender} ${recipient}"
]

# hardening
node.override['postfix']['main']['disable_vrfy_command'] = 'yes'
node.override['postfix']['main']['smtpd_helo_required'] = 'yes'
node.override['postfix']['main']['default_process_limit'] = 100
node.override['postfix']['main']['smtpd_client_connection_count_limit'] = 10
node.override['postfix']['main']['smtpd_client_connection_rate_limit'] = 15
node.override['postfix']['main']['queue_minfree'] = 20971520
node.override['postfix']['main']['smtpd_client_restrictions'] = 'permit_inet_interfaces,permit_mynetworks,permit_sasl_authenticated,reject_unknown_client_hostname,reject_non_fqdn_helo_hostname,reject_invalid_helo_hostname,reject_unknown_helo_hostname'

############
# OpenDKIM #
############
default['opendkim']['recipient_email'] = node['secrets']['openssl']['distinguished_name']['email']
default['opendkim']['config']['file'] = '/etc/opendkim.conf'
default['opendkim']['config']['dir'] = '/etc/opendkim.d'
default['opendkim']['syslog'] = 'yes'
default['opendkim']['syslogsuccess'] = 'yes'
default['opendkim']['logwhy'] = 'yes'
default['opendkim']['umask'] = '002'
default['opendkim']['mode'] = 'sv'
default['opendkim']['pidfile'] = '/var/run/opendkim/opendkim.pid'
default['opendkim']['userid'] = 'opendkim:opendkim'
default['opendkim']['socket'] = 'local:/var/spool/postfix/var/run/opendkim/opendkim.sock'
default['opendkim']['canonicalization'] = 'relaxed/simple'
default['opendkim']['signaturealgorithm'] = 'rsa-sha256'
default['opendkim']['domain'] = node['deploy']['mail'][node.chef_environment]['domain']
default['opendkim']['keyfile'] = '/etc/opendkim.d/mail.private'
default['opendkim']['selector'] = 'mail'
default['opendkim']['externalignorelist'] = 'refile:/etc/opendkim.d/TrustedHosts'
default['opendkim']['internalhosts'] = 'refile:/etc/opendkim.d/TrustedHosts'
default['opendkim']['removeoldsignatures'] = 'no'

node.override['postfix']['main']['milter_protocol'] = 2
node.override['postfix']['main']['milter_default_action'] ='accept'
node.override['postfix']['main']['smtpd_milters'] = 'unix:/var/run/opendkim/opendkim.sock'
node.override['postfix']['main']['non_smtpd_milters'] = 'unix:/var/run/opendkim/opendkim.sock'

node.override['postfix']['main']['sender_canonical_maps'] = 'tcp:localhost:10001'
node.override['postfix']['main']['sender_canonical_classes'] = 'envelope_sender'
node.override['postfix']['main']['recipient_canonical_maps'] = 'tcp:localhost:10002'
node.override['postfix']['main']['recipient_canonical_classes'] = 'envelope_recipient,header_recipient'
