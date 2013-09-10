define () ->
  CPMCify = (object, method) ->
  
    """ Suppose a class generally has methods written in the
    method-chaining style (returning 'this'), but there are
    exceptions, which return a new object as context. (For instance --
    d3's 'selectAll' or 'append'.)

    Continuation-passing method-chaining style rewrites that to
    conform to the 'every method returns this' expectation, by adding
    a new function argument to the end of the list of arguments. If
    this argument is provided, it will be called immediately on the
    'new object' (the appended or selected or .... object), but the
    method itself will return 'this'. This allows the user to
    construct method-tree, where descent to lower levels occurs inside
    these functions ('continuations'). """

    """ CPMCify takes a prototype object and the name of a method, and
    patches the prototype object with a CPMCified version of that
    method. It's pretty hackish. """

    # can't do an "object.length > 0" thing --
    #   works on prototypes, but not particular objects
    if typeof method != "string"
      for m in method
        CPMCify(object, m)
      return

    oldMethod = object[method]

    object[method] = () ->
      args = Array.prototype.slice.call(arguments)
      if args.length == oldMethod.length
        return oldMethod.apply(@, args)
      else if args.length == oldMethod.length + 1
        returned = oldMethod.apply(@, args[...(args.length-1)])
        args[args.length-1].apply(returned)
        return @

  CPMCifyReturnedObjectInsanity = (object, method, methodOfReturned) ->

    """ CPMCify relies upon the fact that the method to be CPMCified
    exists on a prototype, where we can mess with it. Suppose,
    instead, that it is generated dynamically and put onto an object
    returned from a second method. We then must instead patch this
    second method, to make sure whatever object it returns is
    appropriately CPMCified. """

    """ That is what CPMCifyReturnedObjectInsanity does. It is
    insanely hackish. """

    oldMethod = object[method]
    object[method] = () ->
      returned = oldMethod.apply(@, arguments)
      CPMCify(returned, methodOfReturned)
      return returned

  return {
    ify: CPMCify,
    ifyReturnedObjectInsanity: CPMCifyReturnedObjectInsanity,
  }
