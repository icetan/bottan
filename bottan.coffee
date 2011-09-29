fs = require 'fs'
path = require 'path'
watch = require 'watch'
cron = require 'cron'
Client = require('nirc').Client
match = require('./lib/dispatch').match

pluginFilter = (file) ->
  file[0] isnt '.' and (file[-3..] is '.js' or file[-7..] is '.coffee')

class Bottan
  constructor: (@conf) ->
    @plugins = {}
    @client = new Client @conf.server, @conf.port, @conf.nick, @conf.name,
      @conf.serverPass
    @client.on 'parsed', (msg) =>
      if @conf.verbose then console.log msg
      @emit msg
    @client.connect =>
      @loadPlugins @conf.plugins
      @_watchPlugins @conf.plugins
      @client.join @conf.channel, @conf.password
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
        plugin = plugin.call
          conf: @conf
          client: @client
      plugin.bot = @
      plugin.jobs = []
      for time, fn of plugin.cron
        do (time, fn) ->
          plugin.jobs.push cron.job time, -> fn.call plugin
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
          plugin.unload()
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

  _tome: (txt) ->
    (new RegExp("^\\s*#{@client.nick}[:, ]\\s*(.+)$").exec(txt))?[1]
    
  emit: (msg) ->
    cmd = msg.command.toLowerCase()
    if cmd in ['privmsg', 'join', 'part', 'topic', 'mode']
      msg.channel = msg.params[0]
      msg.send = (txt) =>
        to ?= msg.channel
        to = if to is @client.nick then msg.nick else to
        @client.raw "PRIVMSG #{to} :#{txt}"
    @_callPlugins cmd, msg
    if cmd is 'privmsg'
      if msg.channel isnt @client.nick
        msg.trailing = @_tome msg.trailing
      if msg.trailing? then @_callPlugins 'tome', msg

  _callPlugins: (cmd, data) ->
    for name, plugin of @plugins
      do (name, plugin) ->
        if cmd of plugin
          console.log "plugin #{name} is registered on command #{cmd}"
          try
            args = []
            if plugin[cmd] instanceof Function
              handlers = plugin[cmd] data
            else
              handlers = plugin[cmd]
              args.push data
            # match regexp handlers
            if data.trailing? and handlers?
              stop = false
              match data.trailing, handlers, (fn, matches) ->
                if not stop and (fn.apply plugin, args.concat matches) is false
                  stop = true
          catch err
            console.log "Plugin '#{name}' produced an error:"
            console.log err

conf = JSON.parse fs.readFileSync(process.argv[2] ? 'config.json')
bottan = new Bottan conf

process.on "SIGINT", ->
  if bottan.client.connected
    bottan.client.quit "Väl mött"
  process.exit 0

