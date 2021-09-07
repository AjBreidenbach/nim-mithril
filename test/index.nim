import ../src/mithril
import ../src/mithril/common_selectors
let document {.importc, nodecl.}: JsObject
let window {.importc, nodecl.}: JsObject
let console {.importc, nodecl.}: JsObject
from sugar import capture

converter toCstring(s: string): cstring = cstring s


view(TodoItem):
  mtr(
    mtd(
      mul(mli vnode.attrs.item)
    ),
    mtd(a {onclick: vnode.attrs.onclick}, "X")
  )



type PokemonInfo = ref object of MComponent
  currentPokemon: JsObject
  

#converters(PokemonInfo)


proc newPokemonInfo: PokemonInfo =
  var pokemonInfo = PokemonInfo()

  pokemonInfo.oninit = lifecycleHook:
    let data = await mrequest("https://pokeapi.co/api/v2/pokemon/" & $mrouteparam("name"))

    pokemonInfo.currentPokemon = data
    
  
  pokemonInfo.view = viewFn(PokemonInfo):
    var baseExperience = cstring "unknown"

    if pokemonInfo.currentPokemon != nil:
      baseExperience = pokemonInfo.currentPokemon.base_experience.to(cstring)
      

    mdiv(

      mh1(mrouteparam("name")),
      mtable(
        mtr(
          mtd("Base experience"),
          mtd(baseExperience)
        )
      )
    )



  pokemonInfo



type PokemonIndex = ref object of MComponent
  currentInput: cstring

#converters(PokemonIndex)

proc newPokemonIndex: PokemonIndex =
  result = PokemonIndex(currentInput: "")
  
  result.view = viewFn(PokemonIndex):
    let oninput = eventHandler:
      state.currentInput = e.target.value.to(cstring)


    mdiv(
      mlabel("search for a pokemon"),
      minput(a {oninput: oninput}),
      m(mrouteLink, a {href: "/pokemon/" & state.currentInput}, "go")

    )
  

type TodoList = ref object of MComponent
  listItems: seq[cstring]
  input: JsObject
  
  
#converters(TodoList)

proc newTodoList(listItems: openarray[cstring]): TodoList =
  var todoList = TodoList(listItems: @listItems)
  
  todoList.oncreate = lifecycleHook:
    todoList.input = vnode.dom.querySelector("input[type=text]")

  
  let addTodo = eventHandler:
    let newTodo = todoList.input.value.to(cstring)
    if newTodo.len == 0:
      e.redraw = false
      return

    todoList.listItems.add(newTodo)
    todoList.input.value = cstring""
    
    

  todoList.view = viewFn(TodoList):
    var todos = newSeq[VNode]()
    for i, todo in state.listItems:
      capture i:
        let onclick = eventHandler:
          state.listItems.delete i

        todos.add(
          m(TodoItem, a {item: todo, onclick: onclick})
        )

    mdiv(
      mtable(
        todos
      ),
      m("input[type=text]"),
      mbutton(a {onclick: addTodo }, "add")
    )
    
  todoList
view(Home):
  mh1("Welcome to my site!")


proc pageWrapper(selector: MithrilSelector): MithrilSelector =
  view(wrapperView):
    mdiv(
        mnav(
          mspan(
            m(mrouteLink, a {href: "/home"}, "home"),
            ),
          mspan(
            m(mrouteLink, a {href: "/todos"}, "todo list")
           ),

          mspan(
            m(mrouteLink, a {href: "/pokemon"}, "favorite pokemon")
          )
        ),
        m(selector)
      )

  wrapperView

let listItems = @[
  cstring"andrew",
  cstring"bob",
  cstring"john"
]

mroute(
  document.querySelector(cstring"#mount"),
  "/home",
  {
    "/home": pageWrapper(Home),
    "/todos": pageWrapper(newTodoList(listItems)),
    "/pokemon": pageWrapper(newPokemonIndex()),
    "/pokemon/:name": pageWrapper(newPokemonInfo())
  }
)
