chan = null

exports.load = (bot) ->
  chan = bot.client.join '#bottan'
  bot.client.on 'JOIN', (msg) ->
    console.log "JOIN detected #{msg}"
    chan.send "hej #{msg.nick}, välkommen till #{chan.name}"

exports.unload = unload = ->
  chan.part()

exports.reload = ->

exports =
  name: 'test-plugin'
  msg: 
    '': (msg) ->

