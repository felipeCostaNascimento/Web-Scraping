#!/usr/bin/env ruby


#author: Felipe Costa Nascimento
#created: 02-08-2019
#description: Script used to collect posts data from Linkedin page.


require 'watir'
require 'cucumber'
require 'selenium-webdriver'
require 'net/http'
require 'clipboard'


class FeedRobot 

	REQUEST_TYPE_GET = 1
  	REQUEST_TYPE_POST = 2

  	ID_MEDIA_ENTERPRISE = 1

	EXTERNAL_ENDPOINT = "http://xxxx.com"
	HEADER = {'Content-Type' => 'application/json'}

	USER_EMAIL = ""	
	USER_PASSWORD = ""
	LINKEDIN_URL = "https://www.linkedin.com/"
	FEED_URL = "company/ibm/"

	N_POSTS_TO_GET = 50
	INDEX_LIMIT = 500

	def initialize(user, pass, driver = :chrome)
	    puts 'Iniciando o browser...'
	    
	    args = ['--ignore-certificate-errors', '--disable-popup-blocking', '--disable-notifications'] 
	    @browser = Watir::Browser.new driver, options: {args: args}
	    
	    puts 'Carregando o Linkedin...'
	    @browser.goto(LINKEDIN_URL)
	    
	    puts "Logando no Linkedin com o usuário #{user}..."
	    @browser.text_field(:id => 'login-email').set(user)
	    @browser.text_field(:id => 'login-password').set(pass)
	    @browser.button(:id => 'login-submit').wait_until(&:present?).click
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

  	def get_post_count_by_scroll_index( scrollIndex )
  		if divIndex == 1
  			return 26
  		else 
  			return 20
  		end
  	end


  	def get_post_xpath_by_div_id( divIndex )
  		return "//*[@id='organization-feed']/div[#{divIndex}]"
  	end


  	def navigate_to_feed
  		urlFeed = "#{LINKEDIN_URL}#{FEED_URL}"
	    puts "navengado para o feed: #{urlFeed}"
	    
	    @browser.goto(urlFeed)
	    
	    rescue Watir::Wait::TimeoutError
	    raise 'Não foi possível carregar o feed.'
	end


	def get_feed
		continueMapping = true
		currentIndex = 0
		feedData = Array.new

		while continueMapping do
			currentIndex +=1

			puts "Index #{currentIndex}"

			if feedData.length >= N_POSTS_TO_GET || currentIndex >= INDEX_LIMIT
				continueMapping = false
				break
			end

			currentDiv = @browser.element(:xpath => get_post_xpath_by_div_id(currentIndex))

			if !currentDiv.exists?
				puts "não existe"
				next
				
			elsif currentDiv.class_name.include?('feed-shared-update-attachments')
				puts "div não possui os dados"
				next
			end

			
			divYPosition = currentDiv.location.y
			@browser.execute_script("window.scrollTo(0, #{divYPosition}-52)")
			sleep(1)
			
			currentDiv.div.wait_until(&:present?)

			if !currentDiv.div(:class => 'feed-shared-text__text-view').exists?
				puts 'Esta publicação não é um post.'
				next
			end


			if currentDiv.button(:class => 'see-more').exists?
				currentDiv.button(:class => 'see-more').click
			end
			
			currentDiv.element(:tag_name => 'artdeco-dropdown').click
			currentDiv.element(:tag_name => 'artdeco-dropdown-item').wait_until(&:present?).click

			postImage = ""

			if currentDiv.imgs.count > 1
				postImage = currentDiv.imgs[1].src

			elsif currentDiv.iframe.exists? && currentDiv.iframe.div(:class => 'vjs-poster').exists?
				postImage = currentDiv.iframe.div(:class => 'vjs-poster').style 'background-image'

			elsif currentDiv.div(:class => 'video-s-loader__thumbnail').exists?
				postImage = currentDiv.div(:class => 'video-s-loader__thumbnail').style 'background-image'	

				postImageRegex = /^url\("(.+)"\)$/.match(postImage)
				if !postImageRegex.nil?
					postImage = postImageRegex[1]
				end
			end

			postLink = Clipboard.paste.encode('UTF-8')
			idPost = ""
			idPostRegex = /urn:li:activity:(\d+)$/.match(postLink)
			if !idPostRegex.nil?
				idPost = idPostRegex[1]
			end

			postDesc = currentDiv.div(:class => 'feed-shared-text__text-view').text
			postDesc = postDesc.gsub(/\s?\nhashtag\n/, ' ')

			puts "desc: #{postDesc}"
			puts "img: #{postImage}"
			puts "link: #{Clipboard.paste.encode('UTF-8')}"
			puts "date: #{currentDiv.span(:class => 'feed-shared-actor__sub-description').text}"
			puts "idPost: #{idPost}"
			puts "----------------------------------------"

			feedData << {:time => currentDiv.span(:class => 'feed-shared-actor__sub-description').text, 
						 :text => postDesc, 
						 :img => postImage, 
						 :id_post => idPost, 
						 :link => postLink}

			currentIndex += 1
		end

		puts feedData.length

	end


	begin
		robot = FeedRobot.new(USER_EMAIL, USER_PASSWORD)
		robot.navigate_to_feed
		
		puts robot.get_feed
	end

end