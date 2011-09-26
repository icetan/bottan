fs = require 'fs'

logFile = fs.createWriteStream './log.txt', {flags:'a'}
log = (fn) ->
  fs.readFile './log.txt', 'utf8', (err, data) =>
    for line in data.split('\n')[-4..]
      fn line

module.exports = ->
  #@client.raw "PRIVMSG NickServ :IDENTIFY #{@config.nickServPassword}"

  name: 'test-plugin'
  join: ->
    if @nick is @client.nick
      @send "Jag är här!"
    else
      @send "hej #{@nick}, välkommen till #{@channel}"
      
  privmsg:
    '': ->
      logFile.write "<#{@nick}> #{@trailing}\n"
    'reddit': ->
      if @nick.toLowerCase() is 'anth'
        @client.raw "KICK #{@channel} #{@nick} :sluta prata om Reddit!"
    '(ha.?ha|he.?he|hi.?hi|hiheha|lul|lol|rofl)': ->
      @send "#{@nick}: fan skrattar du åt?"
      
  tome:
    '^log': ->
      log (line) => @send line, @nick
    '^du är bäst$': ->
      @send "#{@nick}: one internets to you sir"
      @client.raw "MODE #{@channel} +o #{@nick}"

  part: ->
    @send "#{@nick} couldn't handle #{@channel}"
