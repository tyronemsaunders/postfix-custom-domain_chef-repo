#
# Cookbook:: postfix_mail
# Recipe:: postfix
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

# https://seasonofcode.com/posts/custom-domain-e-mails-with-postfix-and-gmail-the-missing-tutorial.html

# include recipes as a run-list
include_recipe 'postfix'

###################################
# Sender Dependent Relayhost Maps #
###################################
# pcre map type allows you to specify regular expressions with the PERL style notation
package 'Install PCRE map support for Postfix' do
  package_name ['postfix-pcre']
  action :upgrade
end

# if the envelope sender address begins with "srs." or "SRS."
# lookup returns a result of DUNNO which terminates the search without overriding
# the global relayhost parameter setting (i.e. doesn't use the relayhost but uses local mail server to forward)
# otherwise sender relay hash table is looked up.
cookbook_file '/etc/postfix/sender_relay.pcre' do
  group 'postfix'
  mode '0644'
end

########################
# SQLite virtual alias #
########################
# install SQLite
package 'Install SQLite' do
  package_name ['sqlite3', 'libsqlite3-dev', 'postfix-sqlite']
  action :upgrade
end

# install the sqlite ruby gem
gem_package 'sqlite3' do
  action :install
end

mail_forwarding = node['secrets']['mail'][node.chef_environment]['forwarding']

# setup SQLite database
ruby_block 'sqlite virtual alias database' do
  block do
    require 'sqlite3'
    db = SQLite3::Database.new('/etc/postfix/sqlite-virtual.db')
    rows = db.execute <<-SQL
      CREATE TABLE virtual_aliases (
        mailbox varchar(255),
        destination varchar(255)
      );
    SQL

    mail_forwarding.each do |k, v|
      db.execute('INSERT INTO virtual_aliases (mailbox, destination)
                  VALUES (?, ?)', [k, v])
    end
  end
  action :run
end
################
# postmap hash #
################
postmap_hashes = [
  '/etc/postfix/sasl_passwd',
  #'/etc/postfix/virtual',
  '/etc/postfix/sender_relay'
]

postmap_hashes.each do |hash_file|
  execute "run postmap hash on #{hash_file}" do
    live_stream true
    command "postmap hash:#{hash_file}"
  end
  file "#{hash_file}.db" do
    mode '0644'
    group 'postfix'
  end
end

#############
# firewalls #
#############
bash 'set postfix firewalls' do
  code <<-EOH
    ufw allow Postfix
    ufw allow 25
    ufw allow 465
    ufw allow 587
  EOH
end

#############
# log files #
#############
bash 'harden mail logs' do
  code <<-EOH
    chown root:postfix /var/log/mail*
    chmod 660 /var/log/mail*
  EOH
end

###################
# restart postfix #
###################
bash 'restart postfix' do
  live_stream true
  code <<-EOH
    postfix stop
    postfix start
    postfix reload
  EOH
end
