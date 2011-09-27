http = require 'http'

module.exports =
  name: 'twitter'
  privmsg:
    'twitter.com/(#!/)?([^/]+)/status/([^/]+)': (_, user, id) ->
      http.get {
        host: 'api.twitter.com'
        path: "/1/statuses/show.json?id=#{id}"
      }, (res) =>
        json = ''
        res.setEncoding 'utf8'
        res.on 'data', (data) => json += data
        res.on 'end', =>
          @send "tweet: #{user}> #{JSON.parse(json).text}"
