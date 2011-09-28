fs = require 'fs'
path = require 'path'
watch = require 'watch'
cron = require 'cron'
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
      @_watchPlugins @conf.plugins
      @chan = @client.join @conf.channel, @conf.password
#    @on '433', =>
#       do better nick change handling

  _watchPlugins: (dir) ->
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
    file = path.resolve file
    console.log "loading plugin #{file}"
    try
      plugin = require file
      if plugin instanceof Function
        plugin = @_call plugin
      plugin.jobs = []
      for time, fn of plugin.cron
        plugin.jobs.push cron.job time, => @_call fn
      @plugins[path.basename file] = plugin
    catch err
      console.log "plugin #{file} caused an error on load:"
      console.log err
    console.log "registered plugins:"
    console.log @plugins

  unloadPlugin: (file) ->
    file = path.resolve file
    name = path.basename file
    console.log "unloading plugin #{file}"
    if name of @plugins
      plugin = @plugins[name]
      delete @plugins[name]
      delete require.cache[file]
      try
        for job in plugin.jobs
          job.stop()
        if plugin.unload instanceof Function
          @_call plugin.unload
      catch err
        console.log "plugin #{file} caused an error on unload:"
        console.log err
  
  reloadPlugin: (file) ->
    file = path.resolve file
    console.log "reloading plugin #{file}"
    @unloadPlugin file
    @loadPlugin file
  
# support for named/grouped cron jobs, a bit complex so commenting for now
#
#  _setCronJobs: (plugin) ->
#    plugin.jobs = {}
#    for name, crons of plugin.cron
#      plugin.jobs[name] = group = []
#      group.stop = ->
#        for job in @
#          job.stop()
#      for time, fn of crons
#        group.push cron.job(time, => @_call fn)

  _call: (fn) ->
    fn.call
      client: @client
      config: @conf

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
    @_callPlugins cmd, msg
    if cmd is 'privmsg'
      if msg.channel isnt @client.nick
        msg.trailing = @_tome msg.trailing
      if msg.trailing? then @_callPlugins 'tome', msg

  _callPlugins: (cmd, data) ->
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

