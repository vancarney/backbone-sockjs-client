'use-strict'
global = exports ? this
# Includes Backbone & Underscore if the environment is NodeJS
_         = (unless typeof exports is 'undefined' then require 'underscore' else global)._
Backbone  = unless typeof exports is 'undefined' then require 'backbone' else global.Backbone
Fun = global.Fun = {}
#### getFunctionName(fun)
# Attempts to safely determine name of a named function returns null if undefined
Fun.getFunctionName = (fun)->
  if (n = fun.toString().match /function+\s{1,}([a-zA-Z_0-9]*)/)? then n[1] else null
#### getConstructorName(fun)
# Attempts to safely determine name of the Class Constructor returns null if undefined
Fun.getConstructorName = (fun)->
  fun.constructor.name || if (name = @getFunctionName fun.constructor)? then name else null
WebSock = global.WebSock ?= CHAT_PROTO:'http', CHAT_ADDR:'0.0.0.0', CHAT_PORT:3000
class WebSock.Client
  __options:{}
  __streamHandlers:{}
  constructor:(opts={})->
    _.extend @, Backbone.Events
    @model = WebSock.SockData
    @__options.protocol  = opts.protocol || WebSock.PROTOCOL || 'http'
    @__options.host      = opts.host || WebSock.HOST || '0.0.0.0'
    @__options.port      = opts.port || WebSock.PORT || '3000'   
    @connect() unless @__options.auto_connect? and @__options.auto_connect is false
  connect:->
    validationModel = Backbone.Model.extend
      defaults:
        header:
          sender_id: String
          type: String
          sntTime: Date
          srvTime: Date
          rcvTime: Date
          size: Number
        body:null
      validate:(o)->
        o ?= @attributes
        return "required part 'header' was not defined" unless o.header?
        for key in @defaults.header
          return "required header #{key} was not defined" unless o.header[key]?
        return "wrong value for sender_id header" unless typeof o.header.sender_id is 'string'
        return "wrong value for type header" unless typeof o.header.type is 'string'
        return "wrong value for sntTime header" unless (new Date o.header.sntTime).getTime() is o.header.sntTime
        return "wrong value for srvTime header" unless (new Date o.header.srvTime).getTime() is o.header.srvTime
        return "wrong value for rcvTime header" unless (new Date o.header.rcvTime).getTime() is o.header.rcvTime
        return "required part 'body' was not defined" unless o.body
        return "content size was invalid" unless JSON.stringify o.body is o.size
        return
    @socket  = io.connect "#{@__options.protocol}://#{@__options.host}:#{@__options.port}/".replace /\:+$/, ''
    .on 'ws:datagram', (data)=>
      data.header.rcvTime = Date.now()
      (dM = new validationModel).set data
      stream.add dM.attributes if dM.isValid() and (stream = @__streamHandlers[dM.attributes.header.type])?
    .on 'connect', =>
      WebSock.SockData.__connection__ = @
      @trigger 'connected', @
    .on 'disconnect', =>
      @trigger 'disconnected'
    @
  addStream:(name,clazz)->
    return throw "stream handler for #{name} is already set" if @__streamHandlers[name]?
    @__streamHandlers[name] = clazz
  removeStream:(name)->
    return throw "no stream handler for #{name} is defined" unless @__streamHandlers[name]?
    delete @__streamHandlers[name]
  getClientId:->
    return null unless @socket?.io?.engine?
    @socket.io.engine.id
class WebSock.SockData extends Backbone.Model
  header:{}
  constructor:(attributes, options)->
    super attributes, options
    @__type = Fun.getConstructorName @
  sync: (mtd, mdl, opt={}) ->
    m = {}
    _.extend @header opt.header if opt.header?
    # Create-operations get routed to Socket.io
    if mtd == 'create'
      # apply Class Name as type if not set by user
      @header.type ?= @__type
      m.header  = _.extend @header, sntTime: Date.now()
      m.body    = mdl.attributes
      SockData.__connection__.socket.emit 'ws:datagram', m
  getSenderId:->
    @header.sender_id || null
  getSentTime:->
    @header.sntTime || null
  getServedTime:->
    @header.srvTime || null
  getRecievedTime:->
    @header.rcvTime || null
  getSize:->
    @header.size || null
  setRoomId:(id)->
    @header.room_id = id
  getRoomId:->
    @header.room_id
  parse: (data)->
    @header = Object.freeze data.header
    SockData.__super__.parse.call data.body
class WebSock.Message extends WebSock.SockData
  defaults:
    text:""
class WebSock.RoomMessage extends WebSock.SockData
  defaults:
    text:""
  initialize:(attrs,options={})->
    @header.room_id = options.room_id if options.room_id?
class WebSock.JoinRoom extends WebSock.SockData
  defaults:
    room_id:null
    status:"pending"
  set:(attrs,opts)->
    if attrs.room_id?
      @header.room_id = attrs.room_id
    JoinRoom.__super__.set.call @, attrs, opts
  sync:(mtd,mdl,opts)->
    delete mdl.body
    JoinRoom.__super__.sync.call @, mtd, mdl, opts
  validate:(o)->
    return "parameter 'room_id' must be set" unless o.room_id? or @attributes.room_id
  initialize:(attrs,options={})->
    @header.room_id = options.room_id if options.room_id?
class WebSock.LeaveRoom extends WebSock.JoinRoom
class WebSock.StreamCollection extends Backbone.Collection
  model:WebSock.SockData
  fetch:->
    # not implemented
    return false
  sync:()-> 
    # not implemented
    return false
  _prepareModel: (attrs,options)->
    if attrs instanceof Backbone.Model
      attrs.collection = @ unless attrs.collection
      return attrs
    options = if options then _.clone options else {}
    options.collection = @
    model = new @model attrs.body, options
    model.header = Object.freeze attrs.header
    return model unless model.validationError
    @trigger 'invalid', @, model.validationError, options
    false
  send:(data)->
    @create data
  initialize:->
    _client = arguments[0] if arguments[0] instanceof WebSock.Client
if module?.exports?.WebSock?
  module.exports.init = (io)->
    io.sockets.on 'connect', (client)=>
      client.on 'ws:datagram', (data)->
        data.header.srvTime   = Date.now()
        data.header.sender_id = client.id
        if data.header.type is 'JoinRoom'
          if data.body.room_id
            client.join data.body.room_id
            data.body = status:"success"
            client.emit 'ws:datagram', data
          return
        if data.header.type is 'LeaveRoom'
          client.leave data.header.room_id
          data.body = status:"success"
          client.emit 'ws:datagram', data
          return
        (if typeof data.header.room_id is 'undefined' or data.header.room_id is null then io.sockets else io.in data.header.room_id).emit 'ws:datagram', data