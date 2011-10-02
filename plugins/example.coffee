
module.exports = (bot) ->
  join: (m) ->
    if m.nick bot.client.nick
      m.send "Jag är här!"
    else
      m.send "hej #{m.nick}, välkommen till #{m.channel}"
      
  privmsg: (m) ->
    console.log m
    m.match /reddit/i, ->
      if m.nick.toLowerCase() is 'anth'
        bot.client.raw "KICK #{m.channel} #{m.nick} :sluta prata om Reddit!"
      
  tome: (m) ->
    m.match /^du är bäst$/i, ->
      m.send "#{m.nick}: one internets to you sir"
      m.client.raw "MODE #{m.channel} +o #{m.nick}"
    m.match /^vad har du plannerat?/i, ->
      for job in @jobs
        for fn in job._callbacks
          m.send "#{job.cronTime} -> do stuff"
    m.match /^du heter nu +([a-z0-9_]{3,16})/i, (_, nick) ->
      bot.client.raw "NICK #{nick}"
      bot.client.nick = nick

  part: (m) ->
    m.send "#{m.nick} couldn't handle #{m.channel}"

  cron:
    '00 37 13 * * *': ->
      for name, chan of bot.client.channels
        chan.send 'happy leet!'
    '00 03 02 * * *': ->
      for name, chan of bot.client.channels
        chan.send 'är kl 02:03?'

