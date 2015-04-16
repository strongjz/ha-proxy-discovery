require 'sinatra'
require 'net/http'
require 'net/https'
require 'erb'
require 'json'
require 'digest/md5'
$LOAD_PATH.unshift File.dirname(__FILE__)
require '../hbc-class/honeybadger'


@application = Honeybadger.new
# Read in config file
@config = YAML.load(File.open('/apps/hbc-config/config.yml'))
@@marathon = @config['marathon']
@riak = @config["riak"]
@riak_port = @config['riak_port']
$lb_host = @config['lb_host']
@haproxy_config_file = '/etc/haproxy/haproxy.cfg'


def generate_configs

#get all the apps

#for each app
	#get all the marathon data about that app
	
	#create the backend app


end

def register(marathon)
  begin
		puts "[DEBUG][Discovery.register] Registering with #{marathon}"

    uri = URI.parse("http://#{marathon}:8080/v2/eventSubscriptions")
    puts "[INFO][Discover.register] request uri #{uri}"
		http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    found_callback = false

		puts "[DEBUG][Discover.register] response from #{marathon} #{response.code} #{response.message}"

    if response.code.to_i == 200 or response.code.to_i == 204
      callbacks = JSON.parse(response.body)

      for callback in callbacks['callbackUrls']
        if callback.include? $lb_host
          found_callback = true
          puts "[INFO][Register] Callback already present, nothing to do"
          break
        end
      end

      if not found_callback
        uri = URI.parse("http://#{marathon}:8080/v2/eventSubscriptions?callbackUrl=http://#{$lb_host}:7070/events")
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        response = http.request(request)

        if response.code.to_i == 200
          puts "[INFO][Register] Successfully registered callback for #{$lb_host} with #{marathon}"
					status 200
        else
          puts "[ERROR][Register] failed to register callback for #{$lb_host} with #{marathon}"
					status 500
        end
      else
        puts "[INFO][Register] Callback found for #{$lb_host}, nothing to do"
				status 304
      end
    else
      puts "[ERROR][Register] Getting callbacks from #{marathon}"
			status 500
    end
  rescue Exception => e 
    puts "[ERROR][Register] Some generic error occurred #{e} #{e.message}"
		status 500
  end
end

def unregister (marathon)
  begin
    uri = URI.parse("http://#{marathon}:8080/v2/eventSubscriptions?callbackUrl=http://#{$lb_host}:7070/events")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Delete.new(uri.request_uri)
    response = http.request(request)

    if response.code.to_i == 200
      puts "[INFO][Unregister] Seccuessfully unregistered call for #{$lb_host} with #{marathon}"
			status 200
    else "[ERROR][Unregister] Unregistered call for #{$lb_host} with #{marathon}"
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
	puts "[INFO][Register] API CALLED for #{@@marathon}"

	@@marathon.each do |m| 	
	puts "[INFO][Register] API CALLED for #{m[1]}"
		register(m[1])
	end

end

delete '/unregister' do
	puts "[INFO][Unregister] API CALLED"
	@@marathon.each do |m| 	
	puts "[INFO][Register] API CALLED for #{m[1]}"
		unregister(m[1])
	end
end

