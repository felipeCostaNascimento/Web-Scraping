#!/usr/bin/env ruby


#author: Felipe Costa Nascimento
#created: 06-15-2018
#description: Script used to collect posts data from Facebook page.

require 'watir'
require 'cucumber'
require 'selenium-webdriver'
require 'watir-scroll'
require 'net/http'
require 'active_support/all'


class FeedRobot 

	REQUEST_TYPE_GET = 1
  	REQUEST_TYPE_POST = 2


	EXTERNAL_ENDPOINT = "http://endpoint.com"
	HEADER = {'Content-Type' => 'application/json'}

	FB_EMAIL = ""	
	FB_PASSWORD = ""
	FB_URL = "https://www.facebook.com/"
	FEED_URL = "xxx/posts/"

	N_POSTS_TO_GET = 7

	def initialize(user, pass, driver = :chrome)
	    puts 'Iniciando o browser...'
	    

	    args = ['--ignore-certificate-errors', '--disable-popup-blocking', '--disable-notifications'] 
	    @browser = Watir::Browser.new driver, options: {args: args}

	    puts 'Carregando o Facebook...'
	    @browser.goto(FB_URL)
	    puts "Logando no Facebook com o usuário #{user}..."
	    @browser.text_field(:id => 'email').set(user)
	    @browser.text_field(:id => 'pass').set(pass)
	    @browser.label(:id => 'loginbutton').wait_until_present.click
  	end

  	def makeRequest(endpoint, requestType = REQUEST_TYPE_GET, data = nil, header = nil)

	    url = URI.parse(endpoint)
	    req = nil
	    if requestType == REQUEST_TYPE_GET 
	        req = Net::HTTP::Get.new(url, header)
	    else
	        req = Net::HTTP::Post.new(url, header)

	        if !data.nil? 
	        	req.body = data.to_json
	        end
	    end
	    
	    res = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') {|http| http.request req}

	    if res.code == "200" 
	    	return res.body
	    	return JSON.parse(res.body, symbolize_names: true)
	    else
	    	puts "erro ao executar requisição"
	      	puts endpoint
	      	puts "error message: #{res.message}"
	      	return nil
    	end

  end

  	def get_post_xpath(indexes)
  		currentMainDivId = @browser.div(:id => 'pagelet_timeline_main_column').div.divs[1].id
  		postXpath = "//*[@id='#{currentMainDivId}']/div"
  		
  		indexes.map do |index|
  			postXpath += "/div[#{index}]"
  		end

  		return postXpath
  	end

  	def get_post_count_by_div_index( divIndex )
  		if divIndex == 1
  			return 7
  		else 
  			return 8
  		end
  	end


  	def get_first_post_index_by_div_index( divIndex )
  		if divIndex == 1
  			return 2
  		else 
  			return 1
  		end
  	end


  	def navigate_to_feed
  		urlFeed = "#{FB_URL}#{FEED_URL}"
	    puts "navengado para o feed: #{urlFeed}"
	    
	    @browser.goto(urlFeed)
	   
	    rescue Watir::Wait::TimeoutError
	    raise 'Não foi possível carregar o feed.'
	end


	def get_feed
		continueMapping = true
		currentDivIndex = 1
		currentPostIndex = 0
		indexes = Array.new
		feedData = Array.new

		while continueMapping do
			qtPosts = get_post_count_by_div_index(currentDivIndex)
			firstIndex = get_first_post_index_by_div_index(currentDivIndex)

			for i in firstIndex..firstIndex + qtPosts - 1 do
				tempIndexes = indexes.clone
				tempIndexes << i
				puts get_post_xpath( tempIndexes )
				currentPost = @browser.element(:xpath => get_post_xpath(tempIndexes)).wait_until_present
				
				if i == firstIndex
					puts 'waiting.......'
					sleep(1) #TEMPO DE RENDERIZAÇÃO DO HTML 
				end

				if !currentPost.p.exists? || currentPost.imgs.count == 0 || !currentPost.abbr.exists?
					puts 'Esta publicação não é um post (atualização de foto da capa, etc...).'
					next
				end

				idPostDiv = currentPost.div(:id => /^feed_subtitle_(\d+)(?:;|:-)(\d+)(;;\d)?$/)

				if !idPostDiv.exists? 
					puts 'Não foi possível capturar o id do post.'
					next
				end

				postImg = ''

				for j in 1..currentPost.imgs.count - 1 do
					if /(.png|.jpg|.jpeg)$/.match(currentPost.imgs[j].src).nil?
						postImg = currentPost.imgs[j].src

						break
					end

					puts "wrong image #{currentPost.imgs[j].src}"
				end
				# puts currentPost.as[4].href
				resultIdPost = /^feed_subtitle_(\d+)(?:;|:-)(\d+)(;;\d)?$/.match(idPostDiv.id)
				idPost = "#{resultIdPost[1]}_#{resultIdPost[2]}"
				feedData << {:time => currentPost.abbr.data_utime, :text => currentPost.p.text, :img => postImg, :id_post => idPost, :link => currentPost.as[4].href}
				puts "============================================="
				currentPostIndex += 1
			end

			if currentPostIndex >= N_POSTS_TO_GET - 1
				continueMapping = false
			else 
				indexes << firstIndex + qtPosts
				currentDivIndex += 1
				@browser.scroll.to :bottom
			end

		end


		return feedData

	end


	begin
		robot = FeedRobot.new(FB_EMAIL, FB_PASSWORD)
		robot.navigate_to_feed
		
		puts robot.makeRequest( EXTERNAL_ENDPOINT, REQUEST_TYPE_POST, {'data' => robot.get_feed}, HEADER )
	end

end