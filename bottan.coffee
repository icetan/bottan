fs = require 'fs'
resolve = require('path').resolve
watch = require 'watch'
Client = require('nirc').Client
match = require('./lib/dispatch').match

conf = JSON.parse(fs.readFileSync 'config.json')

pluginFilter = (file) ->
  file[0] isnt '.' and (file[-3..] is '.js' or file[-7..] is '.coffee')

class Bottan
  constructor: (@conf) ->
    @plugins = {}
    @client = new Client @conf.server, @conf.port, @conf.nick, @conf.name,
      @conf.serverPass
    @client.on 'parsed', (msg) =>
      console.log msg
      @emit msg
    @client.connect =>
      @loadPlugins @conf.plugins
      @watchPlugins @conf.plugins
      @chan = @client.join @conf.channel, @conf.password

  watchPlugins: (dir) ->
    watch.createMonitor dir, {
      filter: (file) -> not pluginFilter file
    }, (monitor) =>
      monitor.on 'created', (file, stat) => @loadPlugin file
      monitor.on 'removed', (file, stat) => @unloadPlugin file
      monitor.on 'changed', (file, curr, prev) =>
        if curr.mtime.getTime() isnt prev.mtime.getTime()
          @reloadPlugin file

  loadPlugins: (dir) ->
    fs.readdir dir, (err, files) =>
      for file in files
        if pluginFilter file
          @loadPlugin "#{dir}/#{file}"

  loadPlugin: (file) ->
    file = resolve file
    console.log "loading plugin #{file}"
    try
      plugin = require file
      if plugin instanceof Function
        plugin = plugin.call
          client: @client
          config: @conf
      @plugins[plugin.name] = plugin
    catch err
      console.log err
    console.log "registered plugins:"
    console.log @plugins

  unloadPlugin: (file) ->
    file = resolve file
    console.log "unloading plugin #{file}"
    delete @plugins[require(file).name]
    delete require.cache[file]
  
  reloadPlugin: (file) ->
    file = resolve file
    console.log "reloading plugin #{file}"
    delete require.cache[file]
    @loadPlugin file

  _send: (txt, to) ->
    to ?= @channel
    to = if to is @client.nick then @nick else to
    @client.raw "PRIVMSG #{to} :#{txt}"

  _tome: (txt) ->
    (new RegExp("^\\s*#{@client.nick}[:, ]\\s*(.+)$").exec(txt))?[1]
    
  emit: (msg) ->
    cmd = msg.command.toLowerCase()
    msg.client = @client
    msg.config = @conf
    if cmd in ['privmsg', 'join', 'part', 'topic', 'mode']
      msg.channel = msg.params[0]
      msg.send = @_send
    @callPlugins cmd, msg
    if cmd is 'privmsg'
      if msg.channel isnt @client.nick
        msg.trailing = @_tome msg.trailing
      if msg.trailing? then @callPlugins 'tome', msg

  callPlugins: (cmd, data) ->
    for name, plugin of @plugins
      if cmd of plugin
        console.log "plugin #{name} is registered on command #{cmd}"
        try
          if plugin[cmd] instanceof Function
            plugin[cmd].call data
          else if data.trailing?
            match data.trailing, plugin[cmd], (fn, args) ->
              fn.apply data, args
        catch err
          console.log "Plugin '#{name}' produced an error:"
          console.log err

bottan = new Bottan conf

process.on "SIGINT", ->
  if bottan.client.connected
    bottan.client.quit "Väl mött"
  process.exit 0

