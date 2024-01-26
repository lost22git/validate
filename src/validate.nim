import std/[macros, re, strutils, strformat, sequtils]

type
  ValidateRuleKind* = enum
    rkNonNil
    rkNonEmpty
    rkNonBlank
    rkRegex
    rkRange
    rkFloatRange
    rkLengthRange
    rkCustom # used by {.validFn.}

type
  ValidateRule* = object
    msgId*: string
    msg*: string
    tags*: seq[string]
    case kind*: ValidateRuleKind
    of rkNonNil, rkNonEmpty, rkNonBlank:
      discard
    of rkRegex:
      pattern*: string
    of rkRange:
      irange*: Slice[int]
    of rkFloatRange:
      frange*: Slice[float]
    of rkLengthRange:
      lenrange*: Slice[Natural]
    of rkCustom: # used by {.validFn.}
      fn*: string

type
  ValidateError* = object of ValueError
    path*: seq[string]
    rule*: ValidateRule

proc newValidateError*(path: seq[string], rule: ValidateRule): ValidateError =
  ValidateError(path: path, rule: rule)

#!fmt: off
proc `$`*(error: ValidateError): string =
  let path = error.path.join(".")
  let rule = error.rule
  if rule.msg.isEmptyOrWhitespace():
    result =
      case rule.kind
      of rkNonNil:
        fmt"{path}: require not nil"
      of rkNonEmpty:
        fmt"{path}: require not empty"
      of rkNonBlank:
        fmt"{path}: require not blank"
      of rkRegex:
        fmt"{path}: require match regex pattern `{rule.pattern}`"
      of rkRange:
        fmt"{path}: require match range `{rule.irange}`"
      of rkFloatRange:
        fmt"{path}: require match range `{rule.frange}`"
      of rkLengthRange:
        fmt"{path}: require match range `{rule.lenrange}`"
      of rkCustom:
        fmt"{path}: custom function `{rule.fn}` validate failed"
  else:
    result =
      case rule.kind
      of rkNonNil, rkNonEmpty, rkNonBlank:
        rule.msg
      of rkRegex:
        rule.msg % ["pattern", rule.pattern]
      of rkRange:
        rule.msg % [
          "irange", $(rule.irange), "min", $(rule.irange.a), "max", $(rule.irange.b)
        ]
      of rkFloatRange:
        rule.msg % [
          "frange", $(rule.frange), "min", $(rule.frange.a), "max", $(rule.frange.b)
        ]
      of rkLengthRange:
        rule.msg % [
          "lenrange", $(rule.lenrange), "min", $(rule.lenrange.a), "max", $(rule.lenrange.b)
        ]
      of rkCustom:
        rule.msg % ["fn", $(rule.fn)]
#!fmt: on
type
  ValidateResult* = object
    errors*: seq[ValidateError]

func hasError*(validateResult: ValidateResult): bool =
  validateResult.errors.len > 0

func nonEmpty*(
    msgId: string = "", msg: string = "", tags: openArray[string] = []
): ValidateRule =
  ValidateRule(kind: rkNonEmpty, msgId: msgId, msg: msg, tags: tags.toSeq())

func nonNil*(
    msgId: string = "", msg: string = "", tags: openArray[string] = []
): ValidateRule =
  ValidateRule(kind: rkNonNil, msgId: msgId, msg: msg, tags: tags.toSeq())

func nonBlank*(
    msgId: string = "", msg: string = "", tags: openArray[string] = []
): ValidateRule =
  ValidateRule(kind: rkNonBlank, msgId: msgId, msg: msg, tags: tags.toSeq())

func regex*(
    msgId: string = "", msg: string = "", tags: openArray[string] = [], pattern: string
): ValidateRule =
  ValidateRule(
    kind: rkRegex, msgId: msgId, msg: msg, tags: tags.toSeq(), pattern: pattern
  )

func range*(
    msgId: string = "",
    msg: string = "",
    tags: openArray[string] = [],
    min: int = int.low,
    max: int = int.high,
): ValidateRule =
  ValidateRule(
    kind: rkRange, msgId: msgId, msg: msg, tags: tags.toSeq(), irange: min..max
  )

func range*(
    msgId: string = "",
    msg: string = "",
    tags: openArray[string] = [],
    irange: Slice[int],
): ValidateRule =
  ValidateRule(
    kind: rkRange, msgId: msgId, msg: msg, tags: tags.toSeq(), irange: irange
  )

func frange*(
    msgId: string = "",
    msg: string = "",
    tags: openArray[string] = [],
    min: float = float.low,
    max: float = float.high,
): ValidateRule =
  ValidateRule(
    kind: rkFloatRange, msgId: msgId, msg: msg, tags: tags.toSeq(), frange: min..max
  )

func frange*(
    msgId: string = "",
    msg: string = "",
    tags: openArray[string] = [],
    frange: Slice[float],
): ValidateRule =
  ValidateRule(
    kind: rkFloatRange, msgId: msgId, msg: msg, tags: tags.toSeq(), frange: frange
  )

func length*(
    msgId: string = "",
    msg: string = "",
    tags: openArray[string] = [],
    min: Natural = Natural.low,
    max: Natural = Natural.high,
): ValidateRule =
  ValidateRule(
    kind: rkLengthRange, msgId: msgId, msg: msg, tags: tags.toSeq(), lenrange: min..max
  )

func length*(
    msgId: string = "",
    msg: string = "",
    tags: openArray[string] = [],
    lenrange: Slice[Natural],
): ValidateRule =
  ValidateRule(
    kind: rkLengthRange, msgId: msgId, msg: msg, tags: tags.toSeq(), lenrange: lenrange
  )

# ------ macro -------------------------

template valid*(rules: seq[ValidateRule] = @[]) {.pragma.}

template validFn*(
  fn: string, msgId: string = "", msg: string = "", tags: openArray[string] = []
) {.pragma.}

proc validateRule(
    validateResult: var ValidateResult,
    rule: sink ValidateRule,
    path: sink seq[string],
    v: auto,
) =
  case rule.kind
  of rkNonNil:
    when v is ref | ptr | pointer | cstring:
      if v.isNil:
        validateResult.errors.add ValidateError(path: path, rule: rule)
  of rkNonEmpty:
    when v is string | array | set | seq:
      if v.len == 0:
        validateResult.errors.add ValidateError(path: path, rule: rule)
  of rkNonBlank:
    when v is string:
      if v.isEmptyOrWhitespace():
        validateResult.errors.add ValidateError(path: path, rule: rule)
  of rkRegex:
    when v is string:
      if not match(v, re(rule.pattern)):
        validateResult.errors.add ValidateError(path: path, rule: rule)
  of rkRange:
    when v is int:
      if not rule.irange.contains(v):
        validateResult.errors.add ValidateError(path: path, rule: rule)
  of rkFloatRange:
    when v is float:
      if not rule.frange.contains(v):
        validateResult.errors.add ValidateError(path: path, rule: rule)
  of rkLengthRange:
    when v is string | array | set | seq:
      if not rule.lenrange.contains(v.len):
        validateResult.errors.add ValidateError(path: path, rule: rule)
  else:
    discard

macro callCustomFn(f: static string, v: untyped): untyped =
  ## f(v)
  nnkStmtList.newTree(nnkCommand.newTree(newIdentNode(f), v))

macro doTagFilter(t: untyped, f: static string): untyped =
  ## t.anyIt(f)
  nnkCall.newTree(nnkDotExpr.newTree(t, newIdentNode("anyIt")), parseExpr(f))

const default_tags = @["default"]

template doValidate*(
    validateResult: var ValidateResult,
    path: sink seq[string],
    t: typed,
    filterTags: seq[string],
    tagFilterExpr: static string,
) =
  template makeFieldPath(fpath: var seq[string], fname: string) =
    if fpath.len == 0:
      fpath.add $(t.type)
    fpath.add fname

  template fpairs(a: typed): untyped =
    when a is ref:
      a[].fieldPairs
    else:
      a.fieldPairs

  when tagFilterExpr == "":
    let inclDefault = filterTags.anyIt(it in default_tags)

  #!fmt: off

  template ruleMatchTags(r: typed, body: untyped) =
    block:
      let tags {.inject.} = r.tags
      # filter by filterTags from varargs params of proc
      when tagFilterExpr == "":
        if (tags.len == 0 and filterTags.len == 0) or (inclDefault and tags.len == 0) or (tags.anyIt(filterTags.contains it)): 
          body
      # filter by tagFilter expr from {.validate.} of proc
      else:
        block:
          let tt {.inject.} = if tags.len == 0: default_tags else: tags
          if doTagFilter(tt, tagFilterExpr): 
            body

  for fname, fval in fpairs(t):
    var fpath = path
    makeFieldPath(fpath, fname)
    # {.valid.}
    when fval.hasCustomPragma(valid):
      for rule in fval.getCustomPragmaVal(valid):
        ruleMatchTags(rule):
          validateRule(validateResult, rule, fpath, fval)
    # `callCustomFn` need `fn name` static string on compile-time but we can not get it from the rule of `{.valid.}`
    # we add a new pragma `{.validFn.}` to get it
    # {.validFn.} 
    when fval.hasCustomPragma(validFn):
      const (fn, msgId, msg, ttags) = fval.getCustomPragmaVal(validFn)
      let validFnRule = ValidateRule(kind: rkCustom, fn: fn, msgId: msgId, msg: msg, tags: ttags.toSeq())
      ruleMatchTags(validFnRule):
        if not callCustomFn(fn, fval):
          validateResult.errors.add newValidateError(fpath, validFnRule)
    # nested validate
    when fval is object | ref object:
      if (not (fval is ref object)) or (not fval.isNil()):
        doValidate(validateResult, fpath, fval, filterTags, tagFilterExpr)

  #!fmt: on

macro validate*(tagFilter: static string = "", p: untyped): untyped =
  template expectVarStringParam(n: NimNode) =
    expectKind(n, nnkIdentDefs)
    expectKind(n[1], nnkBracketExpr)
    expectIdent(n[1][0], "varargs")
    expectIdent(n[1][1], "string")

  expectKind(p, nnkProcDef) # expect p is a proc
  expectKind(p.body, nnkEmpty) # expect body is empty
  let returnType = p.params[0]
  expectIdent(returnType, "ValidateResult") # expect result type is ValidateResult
  let firstParamDef = p.params[1]
  expectKind(firstParamDef, nnkIdentDefs) # expect has first param
  let firstParamName = firstParamDef[0]

  if p.params.len > 2 and tagFilter != "":
    error "`tagFilter` and `varargs params` can not be used at the same time."

  var tagsDef: NimNode
  if p.params.len <= 2:
    # let __tags = newSeqOfCap[string](0)
    # cap == 0
    tagsDef =
      nnkLetSection.newTree(
        nnkIdentDefs.newTree(
          newIdentNode("__tags"),
          newEmptyNode(),
          nnkCall.newTree(
            nnkBracketExpr.newTree(newIdentNode("newSeqOfCap"), newIdentNode("string")),
            newLit(0),
          ),
        )
      )
  else:
    # expect secondParam is a varargs[string]
    let secondParamDef = p.params[2]
    expectVarStringParam secondParamDef
    let secondParamName = secondParamDef[0]

    # let __tags = secondParamName.toSeq()
    tagsDef =
      nnkLetSection.newTree(
        nnkIdentDefs.newTree(
          newIdentNode("__tags"),
          newEmptyNode(),
          nnkCall.newTree(nnkDotExpr.newTree(secondParamName, newIdentNode("toSeq"))),
        )
      )

  # var __validateResult = ValidateResult()
  let
    validateResultDef =
      nnkVarSection.newTree(
        nnkIdentDefs.newTree(
          newIdentNode("__validateResult"),
          newEmptyNode(),
          nnkCall.newTree(newIdentNode("ValidateResult")),
        )
      )

  # doValidate(__validateResult, newSeq[string](), firstParamName, __tags, tagFilter)
  let
    doValidateCall =
      nnkCall.newTree(
        newIdentNode("doValidate"),
        newIdentNode("__validateResult"),
        nnkCall.newTree(
          nnkBracketExpr.newTree(newIdentNode("newSeq"), newIdentNode("string"))
        ),
        firstParamName,
        newIdentNode("__tags"),
        newLit(tagFilter),
      )

  let
    newBody =
      nnkStmtList.newTree(
        tagsDef,
        validateResultDef,
        doValidateCall,
        # result = __validateResult
        nnkAsgn.newTree(newIdentNode("result"), newIdentNode("__validateResult")),
      )

  # add to body
  p.body = newBody
  result = p
