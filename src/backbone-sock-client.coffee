'use-strict'
global = exports ? this
global.Fun = {}
#### getFunctionName(fun)
# Attempts to safely determine name of a named function returns null if undefined
Fun.getFunctionName = (fun)->
  if (n = fun.toString().match /function+\s{1,}([a-zA-Z_0-9]*)/)? then n[1] else null
#### getConstructorName(fun)
# Attempts to safely determine name of the Class Constructor returns null if undefined
Fun.getConstructorName = (fun)->
  fun.constructor.name || if (name = @getFunctionName fun.constructor)? then name else null
global.WebSock ?= CHAT_PROTO:'http', CHAT_ADDR:'0.0.0.0', CHAT_PORT:3000
class WebSock.Client
  constructor:(connect = false)->
    _.extend @, Backbone.Events
    @model = WebSock.SockData
    (@stream = new Bacon.Bus).filter( (message) -> !message.id ).onValue (message, params) =>
      @socket.emit "#{(message.__type.replace /^([A-Z]{1,1})/, (s)->s.toLowerCase()).replace /[A-Z]{1}/g, (s)-> ' '+s.toLowerCase()}", message   
    @messages = new WebSock.Messages
    @send = (message)=>
      msg = new WebSock.Message body:message
      .save 
        success:=> 
          @model.add msg
    @connect = =>
      @socket  = io.connect "#{WebSock.CHAT_PROTO}://#{WebSock.CHAT_ADDR}:#{WebSock.CHAT_PORT}/".replace /\:+$/, ''
      .on 'message', (data)=>
        @messages.add new @model data
      .on 'connect', =>
        WebSock.SockModel.__connection__ = @
        @trigger 'connected', @
      .on 'disconnect', =>
        @trigger 'disconnected'
      .on 'message', (data)=> 
        @trigger 'message', data
      @
    @connect() if connect? and connect
  getClientId:->
    return null unless @socket?.io?.engine?
    @socket.io.engine.id
class WebSock.SockModel extends Backbone.Model
  _t: null
  constructor:(attributes, options)->
    super attributes, options
    @__type = Fun.getConstructorName( this )
  sync: (mtd, mdl, opt) ->
    # Create-operations get routed to Socket.io
    if mtd == 'create'
      mdl.attributes = _.extend mdl.attributes, __type : @__type
      SockModel.__connection__.stream.push mdl.toJSON()
class WebSock.Message extends WebSock.SockModel
  defaults:
    body:""
class WebSock.SockData extends Backbone.Model
  models:
    message:WebSock.Message
  defaults:
    ts: new Date().getTime()
    tz_offset:  new Date().getTimezoneOffset()
  parse: (response)->
    _.each @models, (v,k)=>
      embeddedClass = @models[key]
      embeddedData  = response[key]
      response[key] = new embeddedClass embeddedData, parse:true if embeddedClass?
class WebSock.Messages extends Backbone.Collection
  model:WebSock.SockData
  messageFilter:(message)-> 
    true
  consume: (@stream) ->
    @stream.onValue (message) =>
      @add message
      Bacon.more