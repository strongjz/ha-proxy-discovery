require 'sinatra'
require 'net/http'
require 'net/https'
require 'erb'
require 'json'
require 'digest/md5'

# Read in config file
@config = YAML.load(File.open('/apps/hbc-config/config.yml'))
@marathon_aws = "#{@config['marathon']['aws']}"
@marathon_gce = "#{@config['marathon']['gce']}"
@riak = @@config["riak"]
@riak_port = @@config['riak_port']
@lb_host = @config['lb_host']
@haproxy_config_file = '/etc/haproxy/haproxy.cfg'


def generate_configs

#get all the apps

#for each app
	#get all the marathon data about that app
	
	#create the backend app


end

def register(marathon)
  begin
    uri = URI.parse("http://#{marathon}v2/eventSubscriptions")
    puts "[INFO][register] request uri #{uri}"
		http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    found_callback = false

    if response.code.to_i == 200
      callbacks = JSON.parse(response.body)

      for callback in callbacks['callbackUrls']
        if callback.include? @lb_host
          found_callback = true
          puts "[IFNO][Register] Callback already present, nothing to do"
          break
        end
      end

      if not found_callback
        uri = URI.parse("http://#{marathon}v2/eventSubscriptions?callbackUrl=http://#{@lb_host}:7070/events")
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        response = http.request(request)

        if response.code.to_i == 200
          puts "[INFO][Register] Successfully registered callback for #{@lb_host} with #{@marathon}"
        else
          puts "[ERROR][Register] failed to register callback for #{@lb_host} with #{@marathon}"
        end
      else
        puts "[INFO][Register] Callback found for #{@lb_host}, nothing to do"
      end
    else
      puts "[ERROR][Register] Getting callbacks from #{@marathon}"
    end
  rescue Exception => e 
    puts "[ERROR] Some generic error occurred #{e}"
  end
end

def unregister (marathon)
  begin
    uri = URI.parse("#{marathon}v2/eventSubscriptions?callbackUrl=http://#{@lb_host}:7070/events")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Delete.new(uri.request_uri)
    response = http.request(request)

    if response.code.to_i == 200
      puts "[INFO][Unregister] Seccuessfully unregistered call for #{@lb_host} with #{marathon}"
			status 200
    else "[ERROR][Unregister] Unregistered call for #{@lb_host} with #{marathon}"
      status 404
    end
  rescue Exception => e
		puts "[ERROR][Unregister] Error unregistering callback #{e}"
    halt 404 , "[ERROR] Error unregistering callback #{e}"
  end
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
	puts "[INFO][Register] API CALLED"
  register(@marathon_aws)
  register(@marathon_gce)
end

delete '/unregister' do
	puts "[INFO][Unregister] API CALLED"
	unregister(@marathon_aws)
	unregister(@marathon_gce)
end

