import std/[macros, re, strutils, strformat, tables]

type
  ValidateRuleKind* = enum
    rkNonNil
    rkNonEmpty
    rkNonBlank
    rkRegex
    rkRange
    rkFloatRange
    rkLengthRange

type
  ValidateRule* = object
    msgId*: string = ""
    msg*: string = ""
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

type
  ValidateError* = object of ValueError
    path*: seq[string]
    rule*: ValidateRule

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
  else:
    result =
      case rule.kind
      of rkNonNil, rkNonEmpty, rkNonBlank:
        rule.msg
      of rkRegex:
        rule.msg % ["pattern", rule.pattern]
      of rkRange:
        rule.msg % ["irange", $(rule.irange)]
      of rkFloatRange:
        rule.msg % ["frange", $(rule.frange)]
      of rkLengthRange:
        rule.msg % ["lenrange", $(rule.lenrange)]

type
  ValidateResult* = object
    errors*: seq[ValidateError]

func nonEmpty*(msgId: string = "", msg: string = ""): ValidateRule =
  ValidateRule(kind: rkNonEmpty, msgId: msgId, msg: msg)

func nonNil*(msgId: string = "", msg: string = ""): ValidateRule =
  ValidateRule(kind: rkNonNil, msgId: msgId, msg: msg)

func nonBlank*(msgId: string = "", msg: string = ""): ValidateRule =
  ValidateRule(kind: rkNonBlank, msgId: msgId, msg: msg)

func regex*(msgId: string = "", msg: string = "", pattern: string): ValidateRule =
  ValidateRule(kind: rkRegex, msgId: msgId, msg: msg, pattern: pattern)

func range*(
    msgId: string = "", msg: string = "", min: int = int.low, max: int = int.high
): ValidateRule =
  ValidateRule(kind: rkRange, msgId: msgId, msg: msg, irange: min..max)

func range*(msgId: string = "", msg: string = "", irange: Slice[int]): ValidateRule =
  ValidateRule(kind: rkRange, msgId: msgId, msg: msg, irange: irange)

func frange*(
    msgId: string = "",
    msg: string = "",
    min: float = float.low,
    max: float = float.high,
): ValidateRule =
  ValidateRule(kind: rkFloatRange, msgId: msgId, msg: msg, frange: min..max)

func frange*(msgId: string = "", msg: string = "", frange: Slice[float]): ValidateRule =
  ValidateRule(kind: rkFloatRange, msgId: msgId, msg: msg, frange: frange)

func length*(
    msgId: string = "",
    msg: string = "",
    min: Natural = Natural.low,
    max: Natural = Natural.high,
): ValidateRule =
  ValidateRule(kind: rkLengthRange, msgId: msgId, msg: msg, lenrange: min..max)

func length*(
    msgId: string = "", msg: string = "", lenrange: Slice[Natural]
): ValidateRule =
  ValidateRule(kind: rkLengthRange, msgId: msgId, msg: msg, lenrange: lenrange)

# ------ macro -------------------------

template valid*(rules: seq[ValidateRule] = @[]) {.pragma.}

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
    when v is string | array | set | seq | Table | TableRef:
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
    when v is string | array | set | seq | Table | TableRef:
      if not rule.lenrange.contains(v.len):
        validateResult.errors.add ValidateError(path: path, rule: rule)

template doValidate*(
    validateResult: var ValidateResult, path: sink seq[string], t: typed
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

  for fname, fval in fpairs(t):
    when fval.hasCustomPragma(valid):
      var fpath = path
      makeFieldPath(fpath, fname)
      let rules = fval.getCustomPragmaVal(valid)
      for rule in rules:
        validateRule(validateResult, rule, fpath, fval)
      # nested valid
      when fval is object | ref object:
        if (not (fval is ref object)) or (not fval.isNil()):
          doValidate(validateResult, fpath, fval)

macro validate*(p: untyped): untyped =
  expectKind(p, nnkProcDef)
  expectKind(p.body, nnkEmpty) # expect body is empty
  let returnType = p.params[0]
  expectIdent(returnType, "ValidateResult") # expect result type is ValidateResult
  let firstParamDef = p.params[1]
  expectKind(firstParamDef, nnkIdentDefs) # expect has first param
  let firstParamName = firstParamDef[0]

  # var __validateResult = ValidateResult()
  # doValidate(__validateResult, newSeq[string](), firstParamName)
  # result = __validateResult
  let
    doValidateCall =
      nnkStmtList.newTree(
        nnkVarSection.newTree(
          nnkIdentDefs.newTree(
            newIdentNode("__validateResult"),
            newEmptyNode(),
            nnkCall.newTree(newIdentNode("ValidateResult")),
          )
        ),
        nnkCall.newTree(
          newIdentNode("doValidate"),
          newIdentNode("__validateResult"),
          nnkCall.newTree(
            nnkBracketExpr.newTree(newIdentNode("newSeq"), newIdentNode("string"))
          ),
          firstParamName,
        ),
        nnkAsgn.newTree(newIdentNode("result"), newIdentNode("__validateResult")),
      )

  # add to body
  p.body = doValidateCall
  result = p
