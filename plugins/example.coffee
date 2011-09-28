
module.exports = plugin =
  join: ->
    if @nick is @client.nick
      @send "Jag är här!"
    else
      @send "hej #{@nick}, välkommen till #{@channel}"
      
  privmsg:
    'reddit': ->
      if @nick.toLowerCase() is 'anth'
        @client.raw "KICK #{@channel} #{@nick} :sluta prata om Reddit!"
      
  tome:
    '^du är bäst$': ->
      @send "#{@nick}: one internets to you sir"
      @client.raw "MODE #{@channel} +o #{@nick}"
    '^vad har du plannerat?': ->
      for job in plugin.jobs
        for fn in job._callbacks
          @send "#{job.cronTime} -> #{fn}"
    '^du heter nu +([a-z0-9_]{3,16})': (nick) ->
      @client.raw "NICK #{nick}"
      @client.nick = nick

  part: ->
    @send "#{@nick} couldn't handle #{@channel}"

  cron:
    '00 37 13 * * *': ->
      for name, chan of @client.channels
        chan.send 'happy leet!'
    '00 03 02 * * *': ->
      for name, chan of @client.channels
        chan.send 'är kl 02:03?'

