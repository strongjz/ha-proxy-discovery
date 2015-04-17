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
@hbc_api_key = @config['api_key']

def generate_configs

	puts "[DEBUG] Generating Config for HAPROXY"

	#get all the apps
	uri = URI.parse("https://honeybadgercloud.io/hbc/api/v1/applications")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  request['Content-Type'] = 'application/json'
  request['Accept'] = 'application/json'
	request['X-Api-Key'] = @hbc_api_key
  response = http.request(request)

  if response.code.to_i == 200
		puts "[INFO][Generate-configs]  Retrived all applications"
		apps = JSON.parse(response.body)
		
		config = File.open("./haproxy.cfg.erb", 'r').read
    template = ERB.new(config, nil, '-').result binding
    new_hash = Digest::MD5.hexdigest(template)
		
		begin
    	existing_hash = Digest::MD5.hexdigest(File.read(i@haproxy_config_file))
    rescue => e
    	existing_hash = nil
    end

      # drop config and reload
     if existing_hash != new_hash
     	File.write(@haproxy_config_file, template)
     	reload = `/etc/init.d/haproxy reload`
      
			if $?.existstatus != 0
				puts "[ERROR] Reloading HAproxy config Exit code #{$?} #{reload}"
				status 500
			else
				puts "[INFO] Successfully reloaded HAproxy config"
				status 201
			end
     else
     	puts "[INFO][Generate-config] Configuration is the same, not reloading."
			status 304
		end
		puts "[ERROR][Generate-configs] Retriving all applicaitons from HBC #{response.code} #{response.message}"
		status 500
	end

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
        request["Content-Type"] = "application/json"
				response = http.request(request)
				
        if response.code.to_i == 200
          puts "[INFO][Register] Successfully registered callback for #{$lb_host} with #{marathon}"
					status 200
        else
          puts "[ERROR][Register] failed to register callback for #{$lb_host} with #{marathon} #{response.code} #{response.message}"
					status 500
        end
      else
        puts "[INFO][Register] Callback found for #{$lb_host}, nothing to do"
				status 304
      end
    else
      puts "[ERROR][Register] Getting callbacks from #{marathon} #{response.code} #{response.message}"
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
    request["Content-Type"] = "application/json"
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
	
	puts "[INFO] Events api endpoint called"
	
	event = JSON.parse(request.body.read)
	
	puts "[DEBUG] #{event}"

	if !event['eventType'].nil? && event['eventType'] == 'deployment_step_success'
    if generate_configs()
			status 200
		else
			status 500 
		end
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

