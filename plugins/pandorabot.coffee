http = require 'http'
querystring = require 'querystring'

class PandoraBot
  constructor: (@botid, @custid) ->

  ask: (input, fn) ->
    query = {@botid, input}
    if @custid then query.custid = @custid
    console.log "asking #{@botid} #{input} /#{@custid}"
    http.get
      host: 'www.pandorabots.com'
      path: "/pandora/talk-xml?#{querystring.stringify query}"
    ,(res) =>
      data = ''
      res.setEncoding 'utf8'
      res.on 'data', (d) =>
        data += d
        if not @custid
          match = /custid="(\w+)"/.exec data
          if match? and match[1]? then @custid = match[1]
        match = /<that[^>]*>([^<]+)<\/that>/i.exec data
        if match? and match[1]?
          res.destroy()
          fn match[1].replace(/[\r\n\t]+/g, '').trim()

module.exports = (bot) ->
  if bot.conf.pandora?.id?
    conversationTimer = null
    conversationTimeout = bot.conf.pandora.conversationTimeout or 1000*60*5
    pandoraBot = new PandoraBot bot.conf.pandora.id

    tome: (m) ->
      m.match /^.+$/, (all) ->
        pandoraBot.ask all, m.send
        clearTimeout conversationTimer
        conversationTimer = setTimeout ->
          pandoraBot.custid = null
        ,conversationTimeout
