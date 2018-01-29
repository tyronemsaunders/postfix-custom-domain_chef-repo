#
# Cookbook:: postfix_mail
# Recipe:: postsrsd
#
# Copyright:: 2018, Tyrone Saunders, All Rights Reserved.

# prerequisites for PostSRSd
package 'install prerequisites for PostSRSd' do
  package_name ['unzip', 'cmake']
  action :upgrade
end

# download the source code from github
remote_file '/tmp/postsrsd.zip' do
  source 'https://github.com/roehling/postsrsd/archive/master.zip'
end

execute 'unzip /tmp/postsrsd.zip' do
  cwd 'tmp'
  command 'unzip postsrsd.zip'
end

directory '/tmp/postsrsd-master/build' do
  recursive true
end

# build and install PostSRSd
bash 'build and install PostSRSd' do
  live_stream true
  cwd '/tmp/postsrsd-master/build'
  code <<-EOH
    cmake -DINIT_FLAVOR=systemd -DCMAKE_INSTALL_PREFIX=/usr ../
    make
    make install
  EOH
end

# start PostSRSd
service 'postsrsd' do
  action [:enable, :start]
  provider Chef::Provider::Service::Systemd
end

# restart postfix
bash 'restart postfix' do
  live_stream true
  code <<-EOH
    postfix stop
    postfix start
    postfix reload
  EOH
end
