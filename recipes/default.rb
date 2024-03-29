#
# Cookbook Name:: passenger
# Recipe:: production

include_recipe "rbenv"

package "curl"
if ['ubuntu', 'debian'].member? node[:platform]
  ['libcurl4-openssl-dev','libpcre3-dev'].each do |pkg|
    package pkg
  end
end

rbenv_gem "passenger" do
  action :install
end

log_path = node[:passenger][:production][:log_path]
nginx_path = node[:passenger][:production][:path]

rbenv_script "Install passenger Nginx" do
  code   %{passenger-install-nginx-module --auto --auto-download --prefix="#{nginx_path}" --extra-configure-flags="#{node[:passenger][:production][:configure_flags]}"}
  not_if "test -e #{nginx_path}"
end

directory log_path do
  mode 0755
  action :create
end

directory "#{nginx_path}/conf/conf.d" do
  mode 0755
  action :create
  recursive true
end

directory "#{nginx_path}/conf/sites.d" do
  mode 0755
  action :create
  recursive true
end

rbenv_script "Set passenger root" do
  code "passenger-config --root > /tmp/passenger_root"
end

rbenv_script "Set Ruby path" do
  code "rbenv which ruby > /tmp/ruby_path"
end

#template "#{nginx_path}/conf/nginx.conf" do
#  source "nginx.conf.erb"
#  owner "root"
#  group "root"
#  mode 0644
#  variables(
#    :log_path => log_path,
#    #:ruby_path => ruby_path.sub("\n",""),
#    #:passenger_root => passenger_root.sub("\n",""),
#    :passenger => node[:passenger][:production],
#    :pidfile => "#{nginx_path}/nginx.pid"
#  )
#end

template "/etc/init.d/nginx" do
  source "nginx.init.erb"
  owner "root"
  group "root"
  mode 0755
  variables(
    :pidfile => "#{nginx_path}/nginx.pid",
    :nginx_path => nginx_path
  )
end

if node[:passenger][:production][:status_server]
  cookbook_file "#{nginx_path}/conf/sites.d/status.conf" do
    source "status.conf"
    mode "0644"
  end
end

service "nginx" do
  service_name "nginx"
  reload_command "#{nginx_path}/sbin/nginx -s reload"
  start_command "#{nginx_path}/sbin/nginx"
  stop_command "#{nginx_path}/sbin/nginx -s stop"
  supports [ :start, :stop, :reload, :status, :enable ]
  action [ :enable, :start ]
  pattern "nginx: master"
end

