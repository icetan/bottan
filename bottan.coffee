fs = require 'fs'
path = require 'path'
util = require 'util'
watch = require 'watch'
cron = require 'cron'
Client = require('nirc').Client

pluginFilter = (file, dir) ->
  file = path.resolve file
  base = path.basename file
  inc = path.dirname(file) is path.resolve(dir) and base[0] isnt '.' and
    (base[-3..] is '.js' or base[-7..] is '.coffee')
  console.log "watch filter: #{file}: #{inc}"
  inc

iter = (q, fn, d) -> if (i=q.shift())? then fn i, (-> iter q, fn, d) else d?()
concat = (a, exp...) -> (for k,v of b then a[k] = v) for b in exp; a

class Bottan
  constructor: (@conf) ->
    @_sendQueue = []
    @plugins = {}
    @client = new Client @conf.server, @conf.port, @conf.nick, @conf.name,
      @conf.serverPass
    @client.on 'parsed', (data) =>
      if @conf.verbose then console.log data
      @_callPlugins data
    @client.connect =>
      @loadPlugins @conf.plugins
      @_watchPlugins @conf.plugins
      @client.join @conf.channel, @conf.password
#    @on '433', =>
#       do better nick change handling

  _watchPlugins: (dir) ->
    watch.createMonitor dir, {
      filter: (file) -> not pluginFilter(file, dir)
    }, (monitor) =>
      monitor.on 'created', (file, stat) => @loadPlugin file
      monitor.on 'removed', (file, stat) => @unloadPlugin file
      monitor.on 'changed', (file, curr, prev) =>
        if curr.mtime.getTime() isnt prev.mtime.getTime()
          @reloadPlugin file

  loadPlugins: (dir) ->
    fs.readdir dir, (err, files) =>
      for file in files
        file = "#{dir}/#{file}"
        if pluginFilter file, dir
          @loadPlugin file

  loadPlugin: (file) ->
    file = path.resolve file
    util.log "loading plugin #{file}"
    try
      plugin = require file
      if plugin instanceof Function
        plugin = plugin @
      plugin.jobs = []
      for time, fn of plugin.cron
        do (time, fn) ->
          plugin.jobs.push cron.job time, -> fn.call plugin
      @plugins[path.basename file] = plugin
    catch err
      util.log "plugin #{file} caused an error on load:"
      console.log err
    console.log "registered plugins:"
    console.log @plugins

  unloadPlugin: (file) ->
    file = path.resolve file
    name = path.basename file
    util.log "unloading plugin #{file}"
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
        util.log "plugin #{file} caused an error on unload:"
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
    
  throttle: (len) -> len * 100

  _message: (plugin, data) ->
    msg = concat {}, data
    cmd = msg.command.toLowerCase()
    if cmd in ['privmsg', 'join', 'part', 'topic', 'mode']
      msg.channel = msg.params[0]
      msg.send = (txt, to) =>
        @_sendQueue.push =>
          to ?= msg.channel
          to = if to is @client.nick then msg.nick or to else to
          @client.raw "PRIVMSG #{to} :#{txt}"
        if @_sendQueue.length is 1
          setTimeout =>
            iter @_sendQueue, (i, next) =>
              i()
              setTimeout next, @throttle @_sendQueue.length
          ,@throttle @_sendQueue.length
    if msg.trailing?
      msg.match = (pairs...) ->
        while pairs.length > 1
          [re, fn] = pairs.splice 0, 2
          if (m = msg.trailing.match re)?
            fn.apply plugin, m
            return true
        false
    msg

  _callPlugins: (data) ->
    cmd = data.command.toLowerCase()
    for name, plugin of @plugins
      do (name, plugin) =>
        msg = @_message plugin, data
        @_execPluginCmd name, cmd, msg
        if cmd is 'privmsg'
          if msg.channel isnt @client.nick
            msg.trailing = @_tome msg.trailing
          if msg.trailing? then @_execPluginCmd name, 'tome', msg

  _execPluginCmd: (name, cmd, msg) ->
    plugin = @plugins[name]
    if cmd of plugin
      try
        plugin[cmd]?(msg)
      catch err
        util.log "Plugin '#{name}' produced an error:"
        console.log err

conf = JSON.parse fs.readFileSync(process.argv[2] ? 'config.json')
bottan = new Bottan conf

process.on "SIGINT", ->
  if bottan.client.connected
    bottan.client.quit "Väl mött"
  process.exit 0

process.on 'uncaughtException', (err) ->
  console.log err
  for name, chan of bottan.client.channels
    chan.send 'I puked a little, check my logs.'
