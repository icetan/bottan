fs = require 'fs'
watch = require 'watch'
Client = require('nirc').Client
conf = JSON.parse(fs.readFileSync 'config.json')

fn2mod = (file) -> './'+file

class Bottan
  constructor: (@client, @pluginDir) ->
    @plugins = {}
    @client.on 'parsed', (msg) ->
      console.log msg
    @client.connect()
    watch.createMonitor @pluginDir, {
      ignoreDotFiles: yes
      filter: (file) -> file[-3..] isnt '.js' and file[-7..] isnt '.coffee'
    }, (monitor) =>
      monitor.on 'created', (file, stat) =>
        @loadPlugin fn2mod file
      monitor.on 'removed', (file, stat) =>
        @unloadPlugin fn2mod file
      monitor.on 'changed', (file, curr, prev) =>
        if curr.mtime.getTime() isnt prev.mtime.getTime()
          @reloadPlugin fn2mod file

  loadPlugin: (file) ->
    console.log "loading plugin #{file}"
    try
      if not (require.resolve(file) of require.cache)
        require(file).load @
    catch err
      console.log err

  unloadPlugin: (file) ->
    console.log "unloading plugin #{file}"
    if require.resolve(file) of require.cache
      require(file).unload()
      delete require.cache[require.resolve file]
  
  reloadPlugin: (file) ->
    console.log "reloading plugin #{file}"
    if require.resolve(file) of require.cache
      require(file).reload()
      delete require.cache[require.resolve file]
    @loadPlugin file

process.on "SIGINT", ->
  if client.connected
    client.quit "Väl mött"
  process.exit 0

client = new Client "irc.freenode.net", 6667, "bottan", "Bot Tan"
bottan = new Bottan client, "./plugins"

