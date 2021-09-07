# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.
import jsffi, macros, asyncjs
export jsffi, asyncjs

let console {.importc, nodecl.}: JsObject
let window {.importc, nodecl.}: JsObject


type Attributes = JsAssoc[cstring, JsObject]
type VNode* = distinct JsObject
type MithrilSelector* = distinct JsObject
type ViewProc* = proc(vnode: JsObject): VNode
type LifecycleHook* = proc(vnode: JsObject): Future[void]
type BeforeUpdateHook* = proc(vnode, old: JsObject): bool
type EventHandler* = proc(e: JsObject)

proc toJsAssoc*(props: openarray[(cstring | string, JsObject)]): Attributes =
  result = newJsAssoc[cstring, JsObject]()
  for prop in props:
    result[cstring prop[0]] = prop[1]


template view*(name, body: untyped): untyped {.dirty.}=
  let name: ViewProc = (
    proc (vnode: JsObject): VNode =
      body
    )
  

template viewFn*(name, body: untyped): ViewProc {.dirty.} =
  (
    proc (vnode: JsObject): VNode =
      var state = vnode.state.to(name)
      body
  )
    
template converters*(name: untyped): untyped =
  converter toSelector*(self: name): MithrilSelector =
    let jsObj = self.toJs
    MithrilSelector(jsObj)
    
  converter toVNode*(self: name): VNode =
    m(toSelector self)


template eventHandler*(body: untyped): EventHandler {.dirty.} =
  (
    proc(e: JsObject) =
      body
  )

template lifecycleHook*(body: untyped): LifecycleHook {.dirty.} =
  (
    proc(vnode: JsObject) {.async.} =
      var state = vnode.state
      body
  )

template beforeUpdateHook*(body: untyped): BeforeUpdateHook {.dirty.} =
  (
    proc(vnode, old: JsObject): bool =
      #let state = vnode.state
      body
  )



macro a*(args: untyped): untyped =
  #echo args.treeRepr
  args.expectKind nnkTableConstr
  for arg in args:
    arg.expectKind nnkExprColonExpr
    let key = if arg[0].kind == nnkIdent: newStrLitNode(arg[0].strVal) else: arg[0]
        
    arg[0] = newCall(newIdentNode("cstring"), key)

    let value = arg[1]

    arg[1] = newCall(newIdentNode("toJs"), value)

  return newCall( newIdentNode("toJsAssoc"), args)


type MComponent* = ref object of RootObj
  view*: ViewProc
  oninit*: LifecycleHook
  oncreate*: LifecycleHook
  onupdate*: LifecycleHook
  onbeforeremove*: LifecycleHook
  onremove*: LifecycleHook
  onbeforeupdate*: BeforeUpdateHook #TODO has a different signature


type HttpMethod* = enum
  Get = "GET"
  Post = "POST"
  Put = "PUT"
  Patch = "PATCH"
  Delete = "DELETE"
  Head = "HEAD"
  Options = "OPTIONS"

proc len(h: HttpMethod): int = 1

converter toCstring*(h: HttpMethod): cstring =
  cstring $(h)

type ResponseType* = enum
  JsonResponse = "json"
  TextResponse = "text"
  DocumentResponse = "document"
  BlobResponse = "blob"
  ArrayBuffer = "arraybuffer"
  Empty = ""

proc mBase(tag: MithrilSelector, attributes: Attributes, children: JsObject): VNode {.importc: "m".}
proc mBase(tag: MithrilSelector, attributes: Attributes): VNode {.importc: "m".}
proc mBase(tag: MithrilSelector, children: JsObject): VNode {.importc: "m".}
proc mBase(tag: MithrilSelector): VNode {.importc: "m".}
proc mrequestBase(options: JsObject): Future[JsObject] {.importc: "m.request".}
proc mroutesetBase(path: cstring, params: JsObject, options: JsObject) {.importc: "m.route.set".}
proc mroutegetBase: cstring {.importc: "m.route.get".}


proc mrouteset*(path:string | cstring, params: Attributes = nil, replace = false, state: JsObject = nil, title = "") =
  var options = newJsObject()
  options.replace = replace
  if state != nil: options.state = state
  if title.len != 0: options.title = cstring title
  mroutesetBase(cstring path, toJs params, options)

proc mrouteget*: string = $ mroutegetBase()

proc mrequest*(url: string | cstring, `method`:  string | cstring = "", body: JsObject = nil, params: JsObject = nil, user = "",  password = "", withCredentials: bool = false, timeout: int = -1, responseType: ResponseType = Empty, headers: openarray[(string, string)] = [], background = false): Future[JsObject]=
  var options = newJsObject()
  options.url = cstring url
  if (`method`).len != 0: options.`method` = cstring `method`
  if body != nil: options.body = toJs body
  if params != nil: options.params = toJs params
  if user.len != 0: options.user = cstring user
  if password.len != 0: options.password = cstring password
  options.withCredentials = withCredentials

  if timeout != -1: options.timeout = timeout
  if responseType != Empty: options.responseType = cstring($responseType)
  if headers.len > 0:
    var requestHeaders = newJsObject()
    for header in headers:
      requestHeaders[cstring header[0]] = cstring header[1]

    options.headers = requestHeaders
      
  return mrequestBase(options)


proc mrender*[T](mountPoint: T, tree: VNode) {.importc: "m.render".}
proc mmount*[T](mountPoint: T, tree: MithrilSelector) {.importc: "m.mount".}
proc mrouteBase[T](mountPoint: T, defaultRoutes: cstring, routes: JsAssoc[cstring, MithrilSelector]) {.importc: "m.route".}
proc mredraw*() {.importc: "m.redraw".}
proc mredrawsync*() {.importc: "m.redraw.sync".}
proc mrouteparam*: JsObject {.importc: "m.route.param".}
proc mrouteparam*(s: cstring): cstring {.importc: "m.route.param".}
var mrouteLink* {.importc: "m.route.Link".}: MithrilSelector
proc mparseQueryString*(s: cstring): JsObject {.importc: "m.parseQueryString".}
proc mbuildQueryString*(o: JsObject): cstring {.importc: "m.buildQueryString".}

proc mroute*[T](mountPoint: T, defaultRoutes: cstring, routes: openarray[(cstring | string, MithrilSelector)]) =
  var assoc = newJsAssoc[cstring, MithrilSelector]()
  for route in routes:
    assoc[cstring route[0]] = route[1]
  mrouteBase(mountPoint, defaultRoutes, assoc)

proc m*(tag: MithrilSelector, attributes: Attributes, children: varargs[VNode]): VNode =
  if children.len == 0: mBase(tag, attributes)
  else: mBase(tag, attributes, toJs children)
  

proc m*(tag: MithrilSelector, children: varargs[VNode]): VNode =
  if children.len == 0: mBase(tag)
  else: mBase(tag, toJs children)
  
converter toSelector*(s: string): MithrilSelector =
  MithrilSelector(toJs(cstring(s)))

converter toVNode*(s: string): VNode =
  VNode(toJs(cstring(s)))

converter toVNode*(s: cstring): VNode =
  VNode(toJs(s))

converter toSelector*(vp:ViewProc): MithrilSelector =
  let jsObj = newJsObject()
  jsObj.view = toJs vp
  MithrilSelector(jsObj)


converter toVNode*(vp: ViewProc): VNode =
  m(toSelector vp)

converter toVNode*(js: JsObject): VNode =
  VNode(js)


template registerSelector*(symbol: untyped, name: string =""): untyped =
  var tagName = name
  if tagName.len == 0:
    tagName = astToStr(symbol)
  template `symbol`*(attributes: Attributes, children: varargs[VNode]): VNode {.inject.} =
    m(tagName, attributes, children)

  template `symbol`*(children: varargs[VNode]): VNode {.inject.} =
    m(tagName, children)
    
    
converters(MComponent)
  
