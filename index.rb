require 'sinatra'
require 'net/http'
require 'net/https'
require 'erb'
require 'json'
require 'digest/md5'

# Read in config file
@config = YAML.load(File.open('/apps/hbc-config/config.yml'))
@marathon = @config['marathon_host']
@lb_host = @config['lb_host']
@haproxy_config_file = '/etc/haproxy/haproxy.cfg'


def generate_configs
end

def register
end

def unregister
end


get '/status' do
	status 200
end
post '/reload' do
  generate_configs()
end

post '/events' do
  event = JSON.parse(request.body.read)
  if !event['eventType'].nil? && event['eventType'] == 'deployment_step_success'
    generate_configs()
  end
end

post '/register' do
  register()
end

delete '/unregister' do
	unregister()
end

