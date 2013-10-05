# tensaix2j

require 'net/http'
require 'net/https'

http = Net::HTTP.new('popsg.com', 80)
path = '/forum2/upload/forum.php'

# Step 1, Get the login page so the host can set his cookies
resp, data = http.get(path, nil)
cookie = resp.response['set-cookie']


# Step 2, Attempt to login
login_path = '/forum2/upload/member.php'

# Fill up the kv pairs
data = {}
data["mod"] = "logging"
data["action"] = "login"
data["loginsubmit"] = "yes"
data["infloat"] = "yes"
data["lssubmit"] = "yes"
data["username"] = "tester123"
data["password"] = "tester123"
data["quickforward"] = "yes"
data["handlekey"] = "ls"


data_str = data.map{|k,v| "#{k}=#{v}"}.join('&')

headers = {
  'Cookie' => cookie,
  'Content-Type' => 'application/x-www-form-urlencoded'
}

resp, data = http.post(login_path, data_str, headers)



# Output on the screen -> we should get either a 302 redirect (after a successful login) or an error page
puts 'Code = ' + resp.code
puts 'Message = ' + resp.message
resp.each {|key, val| puts key + ' = ' + val}
puts data

# Now, we can post a new msg

params = {}
params[:mod] = "post" 
params[:action] = "newthread" 
params[:fid] = 2 
params[:topicsubmit] = "yes" 
params[:infloat] = "yes"
params[:handlekey] = "fastnewpost" 
params[:subject] = "from script" 
params[:message] = "test123 test123" 
params[:formhash] = "d1eef85d" 
params[:usesig] = 1 
params[:posttime] = 1380949962




