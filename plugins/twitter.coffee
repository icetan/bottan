http = require 'http'

lastTweetId = null

collect = (res, fn) ->
  json = ''
  res.setEncoding 'utf8'
  res.on 'data', (data) -> json += data
  res.on 'end', -> fn JSON.parse json

twitter = (path, fn) ->
  http.get {
    host: 'api.twitter.com'
    path
  }, (res) ->
    collect res, fn

module.exports =
  privmsg: (m) ->
    m.match /twitter.com\/(?:#!\/)?([^/]+)\/status\/([^/]+)/, (url, user, id) ->
      http.get {
        host: 'api.twitter.com'
        path: "/1/statuses/show.json?id=#{id}"
      }, (res) ->
        collect res, (tweet) ->
          m.send "tweet: #{user}> #{tweet.text}"
###  
  cron:
    '0 */2 * * * *': -> # every 2min
      user = @config.twitter?.user
      if user
        path = "/1/statuses/home_timeline.json?count=3&include_rts=true&screen_name=#{user}"+
          (if lastTweetId? then "&since_id=#{lastTweetId}" else '')
        console.log "PLUGIN: twitter: getting user #{user}'s feed: #{path}"
        http.get {
          host: 'api.twitter.com'
          path
        }, (res) =>
          collect res, (tweets) =>
            #tweets.sort (a, b) -> b-a
            for tweet in tweets
              lastTweetId = tweet.id
              for name, chan of @client.channels
                chan.send "tweet: #{tweet.user.screen_name}> #{tweet.text}"
