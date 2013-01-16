
#Dependancies
express = require('express')
routes = require('./routes')
http = require('http')
path = require('path')
oauth = require 'oauth'
util = require 'util'
fs = require 'fs'
parser = require 'xml2json'

app = express()

app.configure ->
  app.set('port', process.env.PORT || 3000)
  app.set('views', __dirname + '/views')
  app.set('view engine', 'jade')
  app.use(express.favicon())
  app.use(express.logger('dev'))
  app.use(express.cookieParser('merp'))
  app.use(express.cookieSession())
  app.use(express.bodyParser())  
  app.use(express.methodOverride())
  app.use(app.router)
  app.use(express.static(path.join(__dirname, 'public')))
  # app.use (req, res, next) ->
  #   console.log("Middleware")
  #   checkToken req
  #   next()


base_hostname = "recursivefaults.tumblr.com"
oauth_consumer_key = "y1dyoQz0j81ShI8IhzzxHGZ3wAdGYnEcZATU8hpnexk2MrZzee"
client_secret = "dNKmrxQGrmTKJwr6LtbfWxIaKwMoORVAISSNUOrnMEqnaa6Niz"
redirect = "http://localhost:3000/callback"

oa = () -> new oauth.OAuth("http://www.tumblr.com/oauth/request_token", 
      "http://www.tumblr.com/oauth/access_token", 
      oauth_consumer_key,
      client_secret,
      "1.0",
      redirect,
      "HMAC-SHA1")


checkToken = (request) ->
  console.log("Checking token")

convertToTumblr = (wp_item) ->
    post = {}
    post.type = 'text'
    post.title = wp_item.title
    post.body = wp_item['content:encoded'].replace /<!--more-->/, '[[MORE]]'
    post.tweet = 'off'
    post.date = wp_item['wp:post_date_gmt']
    tags = []
    if wp_item.category
        for tag in wp_item.category
            if tag.domain == 'post_tag'
                tags.push tag.nicename
    post.tags = tags.join ','
    post

parseFile = (file) ->
    data = fs.readFileSync file
    result = parser.toJson data, {reversible: false, object:true, sanitize:false}
    console.log "Converting #{result.rss.channel.item.length} entries..."
    converted = []
    for item in result.rss.channel.item
        converted.push(convertToTumblr item)
    console.log("Successfully converted #{converted.length} entries")
    converted

converted = parseFile "wordpress.xml"

getPageOfPosts = (page) ->
    data = ""
    posts = {}
    http.get "http://api.tumblr.com/v2/blog/#{base_hostname}/posts/text?api_key=#{oauth_consumer_key}&offset=#{page}&limit=20", (tumblr) ->
        console.log tumblr.statusCode
        tumblr.on 'error', (error) ->
            console.log "Error getting page #{page}"
            console.log error
        tumblr.on 'data', (chunk) ->
            data += chunk
        tumblr.on 'end', () ->
            data = JSON.parse(data)
            console.log data
            posts.posts = data.response.posts 
            posts.total = data.response.total_posts
            console.log posts.total
    posts

app.configure 'development', -> 
  app.use(express.errorHandler())

app.get '/sessions/cleanup', (request, response) ->
    console.log "Sending request to tumblr"
    posts = []
    offset = 0
    first_set = getPageOfPosts(0).posts
    for page in [0..first_set.total/20]
        posts.push getPageOfPosts(page).posts
    for post in posts
        console.log post
    

app.get '/sessions/connect', (request, response) ->
  oa().getOAuthRequestToken (error, oauthToken, oauthTokenSecret, results) ->
    if error
      response.send('Error getting OAuth access token')
    else
      console.log oauthToken
      console.log oauthTokenSecret
      request.session.oauthRequestToken = oauthToken
      request.session.oauthRequestTokenSecret = oauthTokenSecret
      console.log("Redirecting")
      response.redirect("http://www.tumblr.com/oauth/authorize?oauth_token=#{request.session.oauthRequestToken}")


app.get '/callback', (request, response) ->
  console.log "In Callback"
  oa().getOAuthAccessToken request.session.oauthRequestToken, request.session.oauthRequestTokenSecret, request.query.oauth_verifier, (error, oauthAccessToken, oauthAccessTokenSecret, results) ->
    if error
    else
      request.session.oauthAccessToken = oauthAccessToken
      request.session.oauthAccessTokenSecret = oauthAccessTokenSecret
      errors = 0
      successes = 0
      for convert in converted
          console.log("About to post #{JSON.stringify(convert)}")
          oa().post "http://api.tumblr.com/v2/blog/#{base_hostname}/post", oauthAccessToken, oauthAccessTokenSecret, convert, null, (error, oauth_token, oauth_token_secret, results) -> 
              if error
                  errors += 1
              else
                  successes += 1
      response.send "We had #{errors} errors and #{successes} successes out of #{converted.length}"

app.get('/', routes.index)
app.post('/', routes.start)

http.createServer(app).listen app.get('port'), ->
  console.log("Express server listening on port " + app.get('port'))

