import ../src/validate

import std/[strutils, sequtils, times, monotimes, cmdline]
type
  Category = ref object
    name {.valid: @[length(min = 2)].}: string

type
  Status = enum
    onsale
    sold

proc isHttpUrl(v: string): bool =
  v.startswith("http")

#!fmt: off

type
  Book = object
    url {.validFn(fn = "isHttpUrl", msg = "url is not a http url", tags = @["show"]).}: string
    category {.valid: @[nonNil()].}: Category
    tags {.valid: @[length(min = 2, max = 4, tags = ["show"])].}: seq[string]
    price {.valid: @[frange(min = 5, max = 50, tags = ["hide"])].}: float
    case status: Status
    of onsale, sold:
      count {.valid: @[range(min = 100, tags = ["hide"])].}: int

#!fmt: on

proc validate(book: Book, filterTags: varargs[string]): ValidateResult {.validate: "".}

proc validateWithTagFilterExpr(
  book: Book
): ValidateResult {.validate: """ it in ["default","show","hide"] """.}

let category = Category(name: "T")
let
  book =
    Book(
      url: "ftp://127.0.0.1/books/979-8836539412jk",
      category: category,
      tags: @["nim"],
      price: 52'd,
      status: onsale,
      count: 10,
    )

let size = 1000000
let all = newSeqWith(size, book)
echo "len: ", all.len

let tagFilterMethod = paramStr(1)
echo "tag filter method: ", tagFilterMethod

let st = getmonoTime()

for s in all:
  let
    validateResult =
      case tagFilterMethod
      of "filterTags":
        s.validate("default", "show", "hide")
      of "tagFilterExpr":
        s.validateWithTagFilterExpr()
      else:
        ValidateResult()

  if validateResult.errors.len == 0:
    raise newException(ValueError, "panic")

let ed = getmonoTime()
echo "result: ", (ed - st).inMicroseconds() / size, "μs/op"
