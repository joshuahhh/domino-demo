define () ->
  equal = (a, b) ->
    if (a instanceof Array)
      return ((b instanceof Array) and
              (a.length == b.length) and
              a.every (elem, i) -> elem == b[i])
    else
      return a == b

  class Connector
    constructor: (@name) ->
      @value = false
      @informant = false
      @constraints = []
    hasValue: () -> (@informant != false)
    getValue: () -> @value
    setValue: (value, informant) ->
      if not @.hasValue()
        @value = value
        @informant = informant
        for constraint in @constraints when constraint != informant
          constraint.processNewValue()
      else if not equal(value, @value)
        throw new Error("inconsistency in connector #{@name}")
    forgetValue: (retractor) ->
      if retractor == @informant
        @informant = false
        for constraint in @constraints when constraint != retractor
          constraint.processForgetValue()
    connect: (constraint) ->
      if not (constraint in @constraints)
        if !constraint.processNewValue
          throw new Error()
        @constraints.push(constraint)
      if @hasValue()
        constraint.processNewValue()

  class WatcherPseudoconstraint
    constructor: (@connector, @onNew, @onForget) ->
      @connector.connect(@)
    processNewValue: () ->
      if @onNew
        @onNew(@connector.getValue())
    processForgetValue: () ->
      if @onForget
        @onForget()
  
  class ProbePseudoconstraint extends WatcherPseudoconstraint
    constructor: (@connector, @label) ->
      super(@connector,
            (value) -> console.log "PROBE: #{@label} = #{value}",
            ()      -> console.log "PROBE: #{@label} = ?")

  class ConstantConstraint
    constructor: (@connector, @value) ->
      @connector.connect(@)
      @connector.setValue(@value, @)
    processNewValue: () ->
      throw new Exception()
    processForgetValue: () ->
      throw new Exception()

  class EqualityConstraint
    constructor: (@e1, @e2) ->
      @e1.connect(@)
      @e2.connect(@)
    processNewValue: () ->
      if @e1.hasValue()
        @e2.setValue(@e1.getValue(), @)
      else if @e2.hasValue()
        @e1.setValue(@e2.getValue(), @)
    processForgetValue: () ->
      @e1.forgetValue(@)
      @e2.forgetValue(@)

  class AdderConstraint
    constructor: (@a1, @a2, @sum) ->
      @a1.connect(@)
      @a2.connect(@)
      @sum.connect(@)
    processNewValue: () ->
      if @a1.hasValue() and @a2.hasValue()
        @sum.setValue(@a1.getValue() + @a2.getValue(), @)
      else if @a1.hasValue() and @sum.hasValue()
        @a2.setValue(@sum.getValue() - @a1.getValue(), @)
      else if @a2.hasValue() and @sum.hasValue()
        @a1.setValue(@sum.getValue() - @a2.getValue(), @)
    processForgetValue: () ->
      @a1.forgetValue(@)
      @a2.forgetValue(@)
      @sum.forgetValue(@)

  class MultiplierConstraint
    constructor: (@m1, @m2, @product) ->
      @m1.connect(@)
      @m2.connect(@)
      @product.connect(@)
    processNewValue: () ->
      if @m1.hasValue() and @m2.hasValue()
        @product.setValue(@m1.getValue() * @m2.getValue(), @)
      else if @m1.hasValue() and @product.hasValue()
        @m2.setValue(@product.getValue() / @m1.getValue(), @)
      else if @m2.hasValue() and @product.hasValue()
        @m1.setValue(@product.getValue() / @m2.getValue(), @)
    processForgetValue: () ->
      @m1.forgetValue(@)
      @m2.forgetValue(@)
      @product.forgetValue(@)

  class PairerConstraint
    constructor: (@e1, @e2, @pair) ->
      @e1.connect(@)
      @e2.connect(@)
      @pair.connect(@)
    processNewValue: () ->
      if @e1.hasValue() and @e2.hasValue()
        @pair.setValue([@e1.getValue(), @e2.getValue()], @)
      else if @pair.hasValue()
        @e1.setValue(@pair.getValue()[0], @)
        @e2.setValue(@pair.getValue()[1], @)
    processForgetValue: () ->
      @e1.forgetValue(@)
      @e2.forgetValue(@)
      @pair.forgetValue(@)    

  constantConnector = (value) ->
    toReturn = new Connector("constant(#{value})")
    new ConstantConstraint(toReturn, value)
    return toReturn

  probedConnector = (label) ->
    toReturn = new Connector("probed(#{label})")
    # new ProbePseudoconstraint(toReturn, label)
    return toReturn

  dividedSegmentConstraint = (left, right, width, mid, part=0.5) ->
    # FYI, "left, right, width" here are just illustrative

    new AdderConstraint(left, width, right)

    leftWidth = new Connector("divdedSegment-left-width")
    new MultiplierConstraint(width, constantConnector(part), leftWidth)
    new AdderConstraint(left, leftWidth, mid)

    #rightWidth = new Connector("divdedSegment-right-width")
    #new MultiplierConstraint(width, constantConnector(1-part), rightWidth)
    #new AdderConstraint(mid, rightWidth, right)

  partwaysConstraint = (a, b, part, out) ->
    # out-a = part*(b-a)
    bigSubtract = new Connector("partways-big-subtract")
    smallSubtract = new Connector("partways-small-subtract")
    new AdderConstraint(a, bigSubtract, b)
    new AdderConstraint(a, smallSubtract, out)
    new MultiplierConstraint(bigSubtract, constantConnector(part), smallSubtract)

  return {
    Connector: Connector,
    WatcherPseudoconstraint: WatcherPseudoconstraint,
    ProbePseudoconstraint: ProbePseudoconstraint,
    ConstantConstraint: ConstantConstraint,
    EqualityConstraint: EqualityConstraint,
    AdderConstraint: AdderConstraint,
    MultiplierConstraint: MultiplierConstraint,
    PairerConstraint: PairerConstraint,
    constantConnector: constantConnector,
    probedConnector: probedConnector,
    dividedSegmentConstraint: dividedSegmentConstraint,
    partwaysConstraint: partwaysConstraint,
  }
