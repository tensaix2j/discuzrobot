# tensaix2j

require 'rubygems'
require 'open-uri'
require 'simple-rss'
require 'net/http'
require 'iconv'
require 'cgi'


$cookie = {}

#---------
def setcookie( setcookie_rawval ) 

	setcookie_rawval = setcookie_rawval.gsub("/,","/;").gsub("httponly, ","")
	setcookie_rawval.split("; ").each { |kv|

		kvs = kv.split("=")
		key = kvs[0]
		val = kvs[1]
		$cookie[key] = val if key[/.*2132.*/] != nil
	}
end

#---------
def getcookiestr()
	
	cookiestr = ""
	$cookie.keys.each {  |k|
		cookiestr += "#{k}=#{$cookie[k]}; " 
	}

	return cookiestr
end

#-----------


$news_buffer = []
$link_posted = {}

#----------------
def get_zaobao_rss()

	$news_buffer = []

	rss = SimpleRSS.parse open('http://zaobao.feedsportal.com/c/34003/f/616933/index.rss')
	rss.entries.each { | entry | 

		
		new_entry = {}
		new_entry[:title] = entry.title
		new_entry[:link ] = entry.link
		new_entry[:description] = entry.description.split("&lt;")[0]

		if $link_posted[ entry.link ] == nil
			$news_buffer << new_entry
		end

	}
	puts "#{ $news_buffer.length } new topics\n"

end

#------
# So you don't repeat the post when reboot the script
def save_posted_link( )
	
	data_file = "posted_link.dat"
	fp = File.open(data_file,"a")
	$link_posted.keys.each { |link|
		fp.puts( link )
	}
	fp.close()	
end

#----
def save_single_link( link ) 

	data_file = "posted_link.dat"
	fp = File.open(data_file,"a")
	fp.puts( link )
	fp.close()	

end

#----
def load_posted_link() 
	
	data_file = "posted_link.dat"
	if File.exist?(data_file)
		fp = File.open( data_file )
		while ( !fp.eof ) 
			line = fp.gets.gsub("\n","")
			$link_posted[line] = 1
		end
		fp.close
	else
		puts "No data file."
	end

	

end


#-----------
def forward_to_forum

	host 		= "cari.com.sg"
	http 		= Net::HTTP.new(host, 80)
	forum_root = "/"
	username 	= "discuzrobot"
	password 	= "discuzrobot123"
	fid 		= 50


	#host 		= "popsg.com"
	#http 		= Net::HTTP.new(host, 80)
	#forum_root = "/forum2/upload"
	#username 	= "tester123"
	#password 	= "tester123"
	#fid 		= 2
		

	# Step 1, Login
	login_path = "#{forum_root}/member.php"
	puts login_path

	# Fill up the kv pairs
	data = {}
	data["mod"] = "logging"
	data["action"] = "login"
	data["loginsubmit"] = "yes"
	data["infloat"] = "yes"
	data["lssubmit"] = "yes"
	data["username"] = username
	data["password"] = password
	data["quickforward"] = "yes"
	data["handlekey"] = "ls"
	data_str = data.map{|k,v| "#{k}=#{v}"}.join('&')

	cookie = getcookiestr
	headers = {
	  'Cookie' => cookie,
	  'Content-Type' => 'application/x-www-form-urlencoded'
	}

	resp, data = http.post(login_path, data_str, headers)
	resp.each {|key, val| 
		if key == "set-cookie" 
			setcookie( val.gsub("\n","") )
		end
	}

	
	# Step 2: Now, we can navigate into forum fid to get formhash
	new_topic_path = "#{forum_root}/forum.php"
	data = {}
	data[:mod] = "forumdisplay"
	data[:fid] = fid
	data_str = data.map{|k,v| "#{k}=#{v}"}.join('&')
	cookie = getcookiestr
	headers = {
	  'Cookie' => cookie,
	  'Content-Type' => 'application/x-www-form-urlencoded'
	}

	puts new_topic_path
	resp, data = http.post(new_topic_path, data_str, headers)
	
	# Step 3: Scrape the formhash
	formhashfound = 0
	formhash = ""

	if data
		data.each { |line|
			if line[/formhash/] && line[/input\ type/]

				
				line.split(" ").each { |token|
					if token[/value/] 
						
						formhash = token.split("=")[1].gsub("\"","")
						formhashfound = 1
					end
				}

				break if formhashfound == 1
			end
		}
	end

	if formhashfound == 1
	

		if $news_buffer.length > 0 

			puts "Ready to post.."

			$news_buffer.each { |entry|


				data = {}
				data[:mod] 			= "post" 
				data[:action] 		= "newthread" 
				data[:fid] 			= fid 
				data[:topicsubmit] 	= "yes" 
				data[:infloat] 		= "yes"
				data[:handlekey] 	= "fastnewpost" 
				data[:subject] 		= entry[:title]
				data[:message] 		= "#{ entry[:description]}\n\n[url=#{ entry[:link] }]Source: Zaobao[/url]" 
				data[:formhash] 	= formhash
				data[:usesig] 		= 1 
				data[:posttime] 	= Time.now().to_i

				new_topic_path = "#{forum_root}/forum.php"
				data_str = data.map{|k,v| "#{k}=#{v}"}.join('&')
				
				resp, data = http.post(new_topic_path, data_str, headers)

				save_single_link( entry[:link] ) 
				
				puts "#{ entry[:title] } posted"


				sleep 15

					
			}	
		end
	
	else
		puts "No form hash!"
	end	

end


load_posted_link() 
get_zaobao_rss()
forward_to_forum()





