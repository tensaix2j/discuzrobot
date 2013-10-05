# tensaix2j

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
$from_cari = []
$tid_posted = {}

def get_cari_rss() 

	host		= "cforum.cari.com.my"
	$from_cari 	= []
	http 		= Net::HTTP.new(host, 80)
	maxpage 	= 1
	
	(1..maxpage).each { |page|

		path 	= "/forum.php?mod=rss&fid=159&page=#{page}"
		puts path

		resp, data = http.get(path)
		
		utf_8_title 	= ""
		link 			= ""
		utf_8_desc 		= ""
		utf_8_author 	= ""
		tid 			= ""

		forumitemset = 0

		if data
			data.each { |line|


				if line[/item/] 
					forumitemset = 1

				elsif line[/title/] && forumitemset == 1
					
					gbk_title = line.gsub("<title>","").gsub("</title>","").strip
					utf_8_title = Iconv.conv('utf-8', 'gbk', gbk_title )
					
				elsif line[/link/] && forumitemset == 1

					
					link =  line.gsub("<link>","").gsub("</link>","").gsub("&amp;","&").strip
					tid =  link.split("&").last.split("=").last
					
				elsif line[/description/] && forumitemset == 1

					gbk_desc 	= line.gsub("<description>","").gsub("</description>","").strip
					utf_8_desc 	= Iconv.conv('utf-8', 'gbk', gbk_desc )
				
				elsif line[/author/] && forumitemset == 1

					gbk_author 		= line.gsub("<author>","").gsub("</author>","").strip
					utf_8_author 	= Iconv.conv('utf-8', 'gbk', gbk_author )
				
					if $tid_posted[tid] == nil	
						$from_cari << [ utf_8_title , link, utf_8_desc , utf_8_author , tid ]	
						$tid_posted[tid] = 1
					end
				
				end
			}
		end	
	}

	puts "#{ $from_cari.length } new topics\n"

end
#------
# So you don't repeat the post when reboot the script
def save_posted_tid( )
	
	tid_file = "posted_tid.dat"
	fp = File.open(tid_file,"a")
	$tid_posted.keys.each { |tid|
		fp.puts( tid )
	}
	fp.close()	
end

#----
def load_posted_tid() 
	
	tid_file = "posted_tid.dat"
	if File.exist?(tid_file)
		fp = File.open("posted_tid.dat")
		while ( !fp.eof ) 
			line = fp.gets.gsub("\n","")
			$tid_posted[line] = 1
		end
		fp.close
	else
		puts "No tid file."
	end

	p $tid_posted

end


#-----------
def forward_to_forum

	host 		= "cari.com.sg"
	http 		= Net::HTTP.new(host, 80)
	forum_root = "/"
	username 	= "discuzrobot"
	password 	= "discuzrobot123"
	fid 		= 50
	

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


	if formhashfound == 1
	
		if $from_cari.length > 0 

			$from_cari.each { |fc|

				title = fc[0]
				link = fc[1]
				desc = fc[2]
				author = fc[3]

				
				if title && title.length > 0

					data = {}
					data[:mod] 			= "post" 
					data[:action] 		= "newthread" 
					data[:fid] 			= fid 
					data[:topicsubmit] 	= "yes" 
					data[:infloat] 		= "yes"
					data[:handlekey] 	= "fastnewpost" 
					data[:subject] 		= CGI::escape( title )
					data[:message] 		= CGI::escape( "#{desc} \n [url=#{link}]#{link}[/url]\n by #{author}" )
					data[:formhash] 	= formhash
					data[:usesig] 		= 1 
					data[:posttime] 	= Time.now().to_i

					new_topic_path = "#{forum_root}/forum.php"
					data_str = data.map{|k,v| "#{k}=#{v}"}.join('&')
					
					resp, data = http.post(new_topic_path, data_str, headers)

					sleep 15

				end	
			}	
		end
	
	end	

end


load_posted_tid() 
get_cari_rss
forward_to_forum()
save_posted_tid()





