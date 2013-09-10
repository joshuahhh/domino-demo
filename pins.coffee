define ['boxes', 'constraints'], (boxes, constraints) ->
  debug = false

  install = (d3) ->
    d3sp = d3.selection.prototype
    attachBoxes = (sel, box) ->
      sel.each (d, i) -> attachBox(@, d3.functor(box)(d, i))
    attachBox = (elem, box) ->
      elem.box = box
      d3elem = d3.select(elem)
      switch elem.nodeName
        when "rect", "image", "g"
          new constraints.WatcherPseudoconstraint(elem.box.tl,
            ([x, y]) => d3elem.attr("x", x).attr("y", y))
          new constraints.WatcherPseudoconstraint(elem.box.size,
            ([w, h]) => d3elem.attr("width", w).attr("height", h))
        when "svg"
          new constraints.ConstantConstraint(elem.box.tl, [0, 0])
          new constraints.WatcherPseudoconstraint(elem.box.size,
            ([w, h]) => d3elem.attr("width", w).attr("height", h))
        when "text"
          #srstodo
          new constraints.WatcherPseudoconstraint(elem.box.tl,
            ([x, y]) => d3elem.attr("x", x).attr("y", y))
        when "ellipse"
          #minortodo
          new constraints.WatcherPseudoconstraint(elem.box.mm,
            ([x, y]) => d3elem.attr("cx", x).attr("cy", y))
          new constraints.WatcherPseudoconstraint(elem.box.size,
            ([w, h]) => d3elem.attr("rx", w/2).attr("ry", h/2))
        when "circle"
          #minortodo
          new constraints.WatcherPseudoconstraint(elem.box.mm,
            ([x, y]) => d3elem.attr("cx", x).attr("cy", y))
          new constraints.WatcherPseudoconstraint(elem.box.size,
            ([w, h]) => d3elem.attr("r", Math.min(w, h)/2))
        when "line"
          #yeahyouguessedittodo
          new constraints.WatcherPseudoconstraint(elem.box.tl,
            ([x, y]) => d3elem.attr("x1", x).attr("y1", y))
          new constraints.WatcherPseudoconstraint(elem.box.br,
            ([x, y]) => d3elem.attr("x2", x).attr("y2", y))
        
      if debug
        elem.rect = d3elem.append("rect").style('fill','none').style('stroke','black')
        elem.text = d3elem.append("text").text(box.label).style("dominant-baseline", "hanging")
        new constraints.WatcherPseudoconstraint(elem.box.size,
          ([width, height]) -> elem.rect.attr("width", width).attr("height", height))
        new constraints.WatcherPseudoconstraint(elem.box.tl,
          ([x, y]) ->
            elem.rect.attr("x", x).attr("y", y)
            elem.text.attr("x", x).attr("y", y))

    d3sp.boxify = (@label) ->
      attachBoxes(@, () => new boxes.Box(@label))
      return @

    d3sp.pin = (source, target = undefined) ->
      if target is undefined
        # either a dictionary of sets, or a request for a pin!
        if typeof source == "string"
          return @.node().box[source]
        else
          obj = source
          for source, target of obj
            @.pin(source, target)
      else
        # OK welcome to pinning funtimes
        @.each((d, i) -> @.box.pin(source, d3.functor(target)(d, i)))
      return @

    d3sp.selectEach = (selector, func) ->
      @.selectAll(selector).each((d,i) -> func.call(d3.select(@), d, i))
      return @

  return {
    install: install
  }
