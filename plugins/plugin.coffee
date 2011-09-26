fs = require 'fs'

logFile = fs.createWriteStream './log.txt', {flags:'a'}

module.exports = ->
  #@client.raw "PRIVMSG NickServ :IDENTIFY #{@config.nickServPassword}"

  name: 'test-plugin'
  join: ->
    if @nick is @client.nick
      @send "Jag är här!"
    else
      @send "hej #{@nick}, välkommen till #{@channel}"
      
  privmsg:
    '^(.*)$': (all) ->
      logFile.write "<#{@nick}> #{all}\n"
    '^!log': ->
      fs.readFile './log.txt', 'utf8', (err, data) =>
        for line in data.split('\n')[-4..]
          @send line, @nick
    '^([a-zA-Z0-9]+).\\s*(.+)$': (to, msg) ->
      if to.toLowerCase() is @client.nick.toLowerCase()
        @send "#{@nick} you talking to me?"

  part: ->
    @send "#{@nick} couldn't handle #{@channel}"
