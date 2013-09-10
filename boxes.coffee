define ['constraints'], (constraints) ->
  constant = constraints.constantConnector

  class Box
    constructor: (@label) ->
      @top = constraints.probedConnector("#{@label} top")
      @bottom = constraints.probedConnector("#{@label} bottom")
      @height = constraints.probedConnector("#{@label} height")
      @vmid = constraints.probedConnector("#{@label} vmid")

      @left = constraints.probedConnector("#{@label} left")
      @right = constraints.probedConnector("#{@label} right")
      @width = constraints.probedConnector("#{@label} width")
      @hmid = constraints.probedConnector("#{@label} hmid")

      @size = constraints.probedConnector("#{@label} size")
      @aspect = constraints.probedConnector("#{@label} aspect")

      # @top + @height = @bottom, @top + (@height/2) = @vmid (etc.)
      constraints.dividedSegmentConstraint(@top, @bottom, @height, @vmid)

      # @left + @width = @right, @left + (@width/2) = @hmid (etc.)
      constraints.dividedSegmentConstraint(@left, @right, @width, @hmid)

      # (@width, @height) = @size
      new constraints.PairerConstraint(@width, @height, @size)
      # @height * @aspect = @width
      new constraints.MultiplierConstraint(@height, @aspect, @width)

      # corners & midpoints aplenty
      @tl = constraints.probedConnector("#{@label} tl")
      new constraints.PairerConstraint(@left, @top, @tl)
      @tm = constraints.probedConnector("#{@label} tm")
      new constraints.PairerConstraint(@hmid, @top, @tm)
      @tr = constraints.probedConnector("#{@label} tr")
      new constraints.PairerConstraint(@right, @top, @tr)
      @ml = constraints.probedConnector("#{@label} ml")
      new constraints.PairerConstraint(@left, @vmid, @ml)
      @mm = constraints.probedConnector("#{@label} mm")
      new constraints.PairerConstraint(@hmid, @vmid, @mm)
      @mr = constraints.probedConnector("#{@label} mr")
      new constraints.PairerConstraint(@right, @vmid, @mr)
      @bl = constraints.probedConnector("#{@label} bl")
      new constraints.PairerConstraint(@left, @bottom, @bl)
      @bm = constraints.probedConnector("#{@label} bm")
      new constraints.PairerConstraint(@hmid, @bottom, @bm)
      @br = constraints.probedConnector("#{@label} br")
      new constraints.PairerConstraint(@right, @bottom, @br)

      @all = constraints.probedConnector("#{@label} all")
      new constraints.PairerConstraint(@tl, @br, @all)

      @pinnable = [
        'top', 'bottom', 'height', 'vmid',
        'left', 'right', 'width', 'hmid', 'size', 'aspect',
        'tl', 'tm', 'tr', 'ml', 'mm', 'mr', 'bl', 'bm', 'br',
        'all', ]
  
    pin: (source, target = undefined) ->
      if target is undefined
        # either a dictionary of sets, or a request for a pin!
        if typeof source == "string"
          return @[source]
        else
          dict = source
          for source, target of dict
            @.pin(source, target)
      else
        if not (target instanceof constraints.Connector)
          target = constraints.constantConnector(target)
        new constraints.EqualityConstraint(@[source], target)
      return @

  class GridBox extends Box
    constructor: (@label, [@m, @n]) ->
      super(@label)

      @cells = for i in [0...@m]
        for j in [0...@n]
          cell = new Box()
          new constraints.MultiplierConstraint(cell.height, constant(@m), @height)
          new constraints.MultiplierConstraint(cell.width, constant(@n), @width)
          constraints.partwaysConstraint(@top, @bottom, i/@m, cell.top)
          constraints.partwaysConstraint(@left, @right, j/@n, cell.left)
          cell
      
      @pinnable.push("cells")
      @pinnable.push("cell")

    cell: ([i, j]) -> @cells[i][j]

  translate = (connector, vector) ->
    if vector.length?
      splitConnector = [new constraints.Connector("translate-in-x"),
                        new constraints.Connector("translate-in-y")]
      new constraints.PairerConstraint(splitConnector[0], splitConnector[1],
                                       connector)

      splitToReturn = [new constraints.Connector("translate-out-x"),
                       new constraints.Connector("translate-out-y")]
      for i in [0, 1]
        new constraints.AdderConstraint(splitConnector[i], constant(vector[i]),
                                        splitToReturn[i])
      toReturn = new constraints.Connector("translate-out-pair")
      new constraints.PairerConstraint(splitToReturn[0], splitToReturn[1],
                                       toReturn)
      return toReturn
    else  # let's accept scalar addition; why the hell not
      toReturn = new constraints.Connector("translate-out")
      new constraints.AdderConstraint(connector, constant(vector), toReturn)
      return toReturn

  return {
    Box: Box,
    GridBox: GridBox,
    translate: translate
  }
