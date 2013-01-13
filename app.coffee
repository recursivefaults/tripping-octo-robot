
#Dependancies
express = require('express')
routes = require('./routes')
http = require('http')
path = require('path')
oauth = require 'oauth'
util = require 'util'

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

app.configure 'development', -> 
  app.use(express.errorHandler())


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
      response.redirect('/')

app.get('/', routes.index)
app.post('/', routes.start)

http.createServer(app).listen app.get('port'), ->
  console.log("Express server listening on port " + app.get('port'))

