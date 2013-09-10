# TODO: serious concern -- bundling of b & r means they are not passed
# separately, which prohibits elegant things like "rows tell children
# how tall they should be, children declare aspect ratios".
#
# (of course, this involves going beyond a DAG of boxes anyway, so
# it's not exactly "phase 1".)

require ['pins', 'boxes', 'cpmc'], (pins, boxes, cpmc) ->

  # technical setup

  for o in [d3.selection.prototype, d3.selection.enter.prototype]
    cpmc.ify(o, ["append", "select", "selectAll"])
  cpmc.ifyReturnedObjectInsanity(d3.selection.prototype, "data",
                                ["enter", "exit"])
  pins.install(d3)

  remove = (array, elem) ->
    array.splice(array.map(String).indexOf(String(elem)), 1)

  d3extension = (creator) ->
    return (selection, args...) ->
      selection.each (d, i) ->
        # Setter/getter framework
        @selfAttrs = {}
        @old_setAttribute = @setAttribute
        @old_getAttribute = @getAttribute
        @setAttribute = (attr, val) ->
          if attr of @selfAttrs
            info = @selfAttrs[attr]
            if info.var? then @[info.var] = val
            if info.onSet? then info.onSet.call(@, val)
          else
            @old_setAttribute.call(@, attr, val)
        @getAttribute = (attr) ->
          if attr of @selfAttrs
            info = @selfAttrs[attr]
            if info.var? then return @[info.var]
            if info.onGet? then return info.onGet.call(@)
          else
            return @old_getAttribute.call(@, attr)

        # The real content
        creator.call(@, d, i, args...)
      return selection

  brace = d3extension (d, i, params) ->
    params ?= {}
    params.dir ?= "right"

    switch params.dir
      when "left"  then @pattern = [[0,0],[1,0.5],[0,1]]
      when "right" then @pattern = [[1,0],[0,0.5],[1,1]]
      when "up"    then @pattern = [[0,0],[0.5,1],[1,0]]
      when "down"  then @pattern = [[0,1],[0.5,0],[1,1]]
      else
        throw "params.dir must be 'left', 'right', 'up', or 'down'!"

    @selfAttrs =
      "x": {var: "x", onSet: -> @redraw()}
      "y": {var: "y", onSet: -> @redraw()}
      "width": {var: "width", onSet: -> @redraw()}
      "height": {var: "height", onSet: -> @redraw()}

    @polyline = d3.select(@).append("polyline").style("fill", "none")

    @redraw = () ->
      if @x? and @y? and @width? and @height?
        points = ("#{@x+@width*x},#{@y+@height*y}" for [x, y] in @pattern)
          .join(" ")
        @polyline.attr("points", points)

  # abstract models & views

  class Domino
    constructor: ([d1, d2]) ->
      if (d1[0] + d1[1]) % 2 == 0
        @d = [d1, d2]
      else
        @d = [d2, d1]
    isVertical: () ->
      return @d[0][0] == @d[1][0]
    tl: () ->
      return [Math.min(@d[0][0], @d[1][0]),
              Math.min(@d[0][1], @d[1][1])]
    br: () ->
      return [Math.max(@d[0][0], @d[1][0]),
              Math.max(@d[0][1], @d[1][1])]

  class BoardModel
    constructor: (@m, @n) ->
      @partSize = @m*@n/2
      @cellCoords = [].concat ([i,j] for i in [0...@m] for j in [0...@n])...
      @part1 = ([i,j] for [i,j] in @cellCoords when (i+j) % 2 == 0)
      @part2 = ([i,j] for [i,j] in @cellCoords when (i+j) % 2 == 1)

      @dominoes = []

      @selectedDomino = false
      @selectedCell = false
      @dragOrigin = false

      @events = d3.dispatch(["change"])

    @distance: (coord1, coord2) ->
      Math.abs(coord1[0]-coord2[0]) + Math.abs(coord1[1]-coord2[1])

    validCoord: (coord) ->
      return (0 <= coord[0] < @m) and (0 <= coord[1] < @n)

    neighbors: (coord) ->
      deltas = [[0,1],[0,-1],[1,0],[-1,0]]
      posses = ([coord[0]+delta[0], coord[1]+delta[1]] for delta in deltas)
      return (poss for poss in posses when @validCoord(poss))

    allTilings: () ->
      toReturn = []
      partialTilings = (tilingSoFar, remainingCoords) =>
        if remainingCoords.length == 0
          toReturn.push(tilingSoFar)
        else
          cur = remainingCoords[0]
          for n in @neighbors(cur)
            if String(n) in remainingCoords.map(String)
              newTiling = tilingSoFar.concat([new Domino([cur, n])])
              newRemainingCoords = remainingCoords.slice(0)
              remove(newRemainingCoords, cur)
              remove(newRemainingCoords, n)
              partialTilings(newTiling, newRemainingCoords)
      partialTilings([], @cellCoords)
      return toReturn
  window.BoardModel = BoardModel

  class SimpleBoard
    constructor: (@sel, @model) ->
      @boardGrid = new boxes.GridBox("boardGrid", [@model.m, @model.n])
      .pin({
        top: sel.pin("top")
        left: sel.pin("left")
        bottom: sel.pin("bottom")
        right: sel.pin("right")
        aspect: @model.n/@model.m
        width: sel.pin("width")     # "shouldn't" be necessary, but is
        hmid: sel.pin("hmid")
      })

      @singleVisibleCell = false

      @sel.append("rect").boxify("s").pin("all", @boardGrid.all)
      .style("stroke", "black").style("stroke-width", "1px")
      .style("fill", "transparent")  # should catch mouse events

      @render()

    render: ->
      view = @

      @sel.selectAll("rect.square")
      .data(@model.cellCoords)
      .enter ->
        @.append("rect").classed("square", true)
        .boxify("board-square-background")
        .pin("all", (d) -> view.boardGrid.cell(d).all)
        .style("stroke", "black").style("stroke-width", "1px")
      .style("fill", (d) ->
        if not view.singleVisibleCell or (String(view.singleVisibleCell) == String(d))
          if (d[0]+d[1])%2 then "black" else "red"
        else "none")

  class BoardView
    constructor: (@sel, @model) ->
      @boardGrid = new boxes.GridBox("boardGrid", [@model.m, @model.n])
      .pin({
        top: sel.pin("top")
        left: sel.pin("left")
        bottom: sel.pin("bottom")
        right: sel.pin("right")
        aspect: @model.n/@model.m
        width: sel.pin("width")     # "shouldn't" be necessary, but is
        hmid: sel.pin("hmid")
      })

      @domMargin = 10
      @hoverMode = false
      @dragMode = false

      id = Math.floor(Math.random()*1000000000)
      @model.events.on("change.BoardView#{id}", => @render())

      @render()

    render: ->
      # for convenience and @-preservation...
      view = @
      model = @model
      change = model.events.change

      @sel.selectAll("g.square")
      .data(model.cellCoords)
      .enter ->
        @.append("g").classed("square", true)
        .append "rect", ->   # this is the red/black guy!
          @.classed("background", true)
          .boxify("board-square-background")
          .pin("all", (d) -> view.boardGrid.cell(d).all)
          .style("fill", ([di, dj]) -> if (di+dj)%2 then "black" else "red")
        .append "rect", ->   # this is the cross-hatched cover!
          @.classed("cover", true)
          .boxify("board-square-cover")
          .pin("all", (d) -> view.boardGrid.cell(d).all)
          .style("fill", "none")
        .on("mouseover", (d) ->
          if view.hoverMode then model.selectedCell = d; change())
        .on("mouseout", (d) ->
          if view.hoverMode then model.selectedCell = false; change())
        .on("mousedown", (d) ->
          if view.dragMode then model.dragOrigin = d; change())
        .on("mouseup", (d) ->
          if view.dragMode and model.dragOrigin
            if BoardModel.distance(d, model.dragOrigin) == 1
              model.dominoes.push(new Domino([model.dragOrigin, d]))
              model.dragOrigin = false
              change())
        .style("cursor", if view.dragMode then "pointer" else "auto")
      .selectAll "rect.cover", ->
        @.style("fill", (d) ->
          if String(d) == String(model.selectedCell)
            "url(#hatch00)"
          else
            "none")

      @sel.selectAll("rect.domino")
      .data(model.dominoes, String)
      .enter ->
        @.append("rect").classed("domino", true).boxify("board-domino")
        .pin("tl", (d) -> boxes.translate(view.boardGrid.cell(d.tl()).tl,
                                          [view.domMargin, view.domMargin]))
        .pin("br", (d) -> boxes.translate(view.boardGrid.cell(d.br()).br,
                                          [-view.domMargin, -view.domMargin]))
        .style("stroke", "black")
        .on("mouseover", (d) ->
          if view.hoverMode then model.selectedDomino = d; change())
        .on("mouseout", (d) ->
          if view.hoverMode then model.selectedDomino = false; change())
        .on("mousedown", (d) ->
          if view.dragMode
            remove(model.dominoes, d)
            change())
        .style("cursor", if view.dragMode then "pointer" else "auto")
      .style("fill", (d) ->
        if d == model.selectedDomino then "rgb(150,150,255)" else "white")
      .exit -> @.remove()

  class PermView
    constructor: (@sel, @model) ->
      @textSpace = 20
      @permGrid = new boxes.GridBox("permGrid", [1, model.partSize])
      .pin({
        "tl": boxes.translate(sel.pin("tl"), [0, @textSpace])
        "br": boxes.translate(sel.pin("br"), [0, -@textSpace])})

      id = Math.floor(Math.random()*1000000000)
      @model.events.on("change.PermView#{id}", => @render())

      @render()

    render: ->
      # for convenience and @-preservation...
      view = @
      model = @model
      change = model.events.change

      @sel.selectAll("line.domino")
      .data(model.dominoes, String)
      .enter ->
        @.append("line").classed("domino", true).boxify()
        .pin("tl", (d) ->
          index = model.part1.map(String).indexOf(String(d.d[0]))
          boxes.translate(view.permGrid.cell([0, index]).tm, [0, 5]))
        .pin("br", (d) ->
          index = model.part2.map(String).indexOf(String(d.d[1]))
          boxes.translate(view.permGrid.cell([0, index]).bm, [0, -5]))
        .style("stroke-width", "5px")
        .on("mouseover", (d) -> model.selectedDomino = d; change())
        .on("mouseout", (d) -> model.selectedDomino = false; change())
        .on("mousedown", (d) ->
          model.dominoes.splice(model.dominoes.indexOf(d), 1)
          change())
        .style("cursor", "pointer")
      .style("stroke", (d) -> if d == model.selectedDomino then "blue" else "black")
      .exit -> @.remove()

      @sel.selectAll("g.labelPair")
      .data([0...model.partSize])
      .enter ->
        @.append "g", ->
          @.classed("labelPair", true)
          .append "g", ->
            @.classed("subboard", true).classed("top", true)
          .append "g", ->
            @.classed("subboard", true).classed("bottom", true)
          .selectEach "g.subboard", (d) ->
            subModel = new BoardModel(model.m, model.n)

            is1 = @.classed("top")  # short for "is part of part1"
            part = if is1 then model.part1 else model.part2
            @.boxify("perm-board-#{if is1 then 'top' else 'bottom'}")
            .pin((if is1 then "bm" else "tm"), (d) ->
              view.permGrid.cell([0,d])[if is1 then 'tm' else 'bm'])
            .pin((if is1 then "top" else "bottom"), (d) ->
              view.sel.pin(if is1 then "top" else "bottom"))

            subView = new SimpleBoard(@, subModel)
            subView.singleVisibleCell = part[d]
            subView.render()

            @.on("mouseover", (d) -> model.selectedCell = part[d]; change())
            .on("mouseout", (d) -> model.selectedCell = false; change())
            .on("mousedown", (d) ->
              model.dragOrigin = part[d]
              d3.event.preventDefault())
            .on("mouseup", (d) ->
              if model.dragOrigin
                dragDest = part[d]
                if BoardModel.distance(dragDest, model.dragOrigin) == 1
                  model.dominoes.push(new Domino([model.dragOrigin, dragDest]))
                  model.dragOrigin = false
              change())
            .style("cursor", "pointer")

      .selectEach "text", (d) -> 
        part = if @.classed("top") then model.part1 else model.part2
        if String(part[d]) == String(model.selectedCell)
          @.style("fill", "blue").style("font-weight", "bold")
        else
          @.style("fill", "black").style("font-weight", "normal")
      .selectEach "g.subboard", (d) ->
        part = if @.classed("top") then model.part1 else model.part2
        if String(part[d]) == String(model.selectedCell)
          @.selectAll("rect").style("stroke", "blue")
        else
          @.selectAll("rect").style("stroke", "black")

  class MatrixView
    constructor: (@sel, @model) ->
      @matrixGrid = new boxes.GridBox("matrixGrid",
                                      [@model.partSize, @model.partSize])
      .pin("all", @sel.pin("all"))

      @matrixText =
        for i in [0...@model.partSize]
          for j in [0...@model.partSize]
            d1 = @model.part1[i]
            d2 = @model.part2[j]
            if Math.abs(d1[0]-d2[0]) == 1 and Math.abs(d1[1]-d2[1]) == 0
              1
            else if Math.abs(d1[0]-d2[0]) == 0 and Math.abs(d1[1]-d2[1]) == 1
              "i"
            else
              0
      @matrixCoords = [].concat((
        for i in [0...@model.partSize]
          for j in [0...@model.partSize]
            [i, j])...)

      @model.events.on("change.MatrixView", => @render())

      @render()

    render: ->
      # for convenience and @-preservation...
      view = @
      model = @model
      change = model.events.change

      @sel.selectAll("text.label")
      .data(view.matrixCoords)
      .enter ->
        @.append("text").classed("label", true).boxify("text")
        .text((d) -> "#{view.matrixText[d[0]][d[1]]}")
        .style("text-anchor", "middle").style("dominant-baseline", "central")
        .style("font-style", (d) ->
          if view.matrixText[d[0]][d[1]]=="i" then "italic" else "normal")
        .pin("tl", (d) -> view.matrixGrid.cell(d).mm)

      @sel.selectAll("circle.mark")
      .data(model.dominoes, String)
      .enter ->
        @.append("circle").classed("mark", true).boxify("domino-circle")
        .pin("mm", (d) ->
          i = model.part1.map(String).indexOf(String(d.d[0]))
          j = model.part2.map(String).indexOf(String(d.d[1]))
          view.matrixGrid.cell([i, j]).mm)
        .pin({width: 20, height: 20})
        .style("fill", "none")
        .style("stroke", "black").style("stroke-width", "2px")
      .style("stroke", (d) ->
        if d.d == model.selectedDomino.d then "blue" else "black")
      .exit -> @.remove()

      @sel.selectAll("rect.row")
      .data([0...model.partSize])
      .enter ->
        @.append("rect").classed("row", true).boxify("matrix-row")
        .pin("tl", (d) -> view.matrixGrid.cell([d,0]).tl)
        .pin("br", (d) -> view.matrixGrid.cell([d,model.partSize-1]).br)
        .style("fill", "none").style("stroke-width", "2px")
      .style("stroke", (d) ->
        if String(model.selectedCell) == String(model.part1[d]) then "blue" else "none")
      @sel.selectAll("rect.col")
      .data([0...model.partSize])
      .enter ->
        @.append("rect").classed("col", true).boxify("matrix-row")
        .pin("tl", (d) -> view.matrixGrid.cell([0,d]).tl)
        .pin("br", (d) -> view.matrixGrid.cell([model.partSize-1,d]).br)
        .style("fill", "none").style("stroke-width", "2px")
      .style("stroke", (d) ->
        if String(model.selectedCell) == String(model.part2[d]) then "blue" else "none")

  # this particular app

  d3.select("document").on("dragstart", () -> false)

  do ->
    svg = d3.select("#diag1 svg")

    row = svg.append("g").classed("row", true).boxify("row").pin
      height: 120
    board = row.append("g").classed("board", true).boxify("board").pin
      tl:     row.pin("tl")
      bottom: row.pin("bottom")  # NO ASPECT
    perm = row.append("g").classed("perm", true).boxify("perm").pin
      tl:     boxes.translate(board.pin("tr"), [20, 0])
      bottom: row.pin("bottom")
      aspect: 2
    matrix = row.append("g").classed("matrix", true).boxify("matrix").pin
      tl:     boxes.translate(perm.pin("tr"), [20, 0])
      bottom: row.pin("bottom")
      aspect: 1

    row.pin("right", matrix.pin("right"))

    svg.boxify("svg").pin
      tl: boxes.translate(row.pin("tl"), [-10, -10])
      br: boxes.translate(row.pin("br"), [10, 10])

    boardModel = new BoardModel(3, 4)

    boardView = new BoardView(board, boardModel)
    boardView.hoverMode = true
    boardView.dragMode = true
    new PermView(perm, boardModel)
    new MatrixView(matrix, boardModel)

    boardModel.dominoes = [new Domino([[0,0],[1,0]])]
    boardModel.events.change()
