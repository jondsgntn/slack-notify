#!/usr/bin/env ruby

require 'dotenv'
require 'net/http'
require 'uri'
require 'slack-notify'
require 'timeout'
require 'twilio-ruby'

Dotenv.load

#get twilio account info from .env
TWILIO_ACCOUNT_SID = ENV['TWILIO_ACCOUNT_SID']
TWILIO_AUTH_TOKEN  = ENV['TWILIO_AUTH_TOKEN']

#open sites.txt, get URLs and error counters
lines = File.open("sites.txt", "r"){ |datafile| 
   datafile.readlines
}

#create array to store new results
newlines = Array.new
x = 0

#run loop on list of sites
lines.each do |line|
    #split lines into URL and counter
	values = line.split(" ")
	count = values[1].gsub(/[^0-9]/,'').to_i
	uri = URI.parse(values[0])
	http = Net::HTTP.new(uri.host, uri.port)
	http.open_timeout = 10
	http.read_timeout = 10

    #make HTTP request to site
	request = Net::HTTP::Get.new(uri.request_uri)
	begin
		#store results of request
		res = http.request(request)
	rescue Timeout::Error
		#if request timeout, set results to nil
		res = nil
	end
	#open connection with slack
	client = SlackNotify::Client.new(
	  webhook_url: ENV['SLACK_WEBHOOK_URL'],
	  username: "DesiBot",
	  channel: "#websitestatus"
	)
	#if request results in 40x or 50x error (site is down)
	if res.code =~ /4|5\d{2}/
		client.notify(":x: #{uri.host} is down (#{res.code})")
		print ":x: - #{uri.host} is down (#{res.code}) \n"
		count += 1
	#if request results in 10x, 20x, or 30x (site is up)
	elsif res!=nil
		#client.notify(":white_check_mark: #{uri.host} is up (#{res.code})")
		print ":white_check_mark: - #{uri.host} is up (#{res.code}) \n"
		#since site is working, reset counter to 0
		count = 0
	#if request results in nil (request timed out)
	else
		client.notify(":x: #{uri.host} is down (connection timed out)")
		print ":x: - #{uri.host} is down (connection timed out) \n"
		count += 1
	end
	#append results to array
	newlines[x] = "http://#{uri.host} #{count} \n"
	x += 1
    #if error has been returned for a site for the 5th time in a row, send a text message
	if count == 5
		@twilio = Twilio::REST::Client.new TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN
		desibot_number = ENV['DESIBOT_PHONE_NUMBER']
		receive_number = ENV['RECEIVE_PHONE_NUMBER']
		@twilio.messages.create(
		  from: desibot_number, to: receive_number, body: "The website #{uri.host} has returned 5 errors in a row"
		)
		print "Text sent for #{uri.host}"
	end
end

#delete old sites.txt and replace it with new results
File.truncate('sites.txt', 0)
file = File.open("sites.txt", "w")
newlines.each do |newline|
	file.puts newline
end
file.close
#client.notify(":white_check_mark: - #{url} is up")
#client.notify(":x: - Some Other Site is down")
