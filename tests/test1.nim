# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import validate
import std/[sequtils, strutils]
test "test-book":
  type
    Category = ref object
      name {.valid: @[length(min = 2)].}: string

  type
    Status = enum
      onsale
      sold

  proc isHttpUrl(v: string): bool =
    v.startswith("http://")

  #!fmt: off

  type
    Book = object
      isbn {.valid: @[regex(pattern = r"ISBN \d{3}-\d{10}", tags = ["show"])].}: string
      url {.validFn(fn = "isHttpUrl", tags = ["show"], msg = "the url is not http url").}: string
      category {.valid: @[nonNil()].}: Category
      tags {.valid: @[length(min = 2, max = 4, tags = ["show"])].}: seq[string]
      price {.valid: @[frange(min = 5, max = 50, tags = ["hide"])].}: float
      case status: Status
      of onsale, sold:
        count {.valid: @[range(min = 100, tags = ["hide"])].}: int

  #!fmt: on

  proc validate(
    book: Book, filterTags: varargs[string]
  ): ValidateResult {.validate: "".}

  proc validateWithTagFilterExpr(
    book: Book
  ): ValidateResult {.validate: """ it in ["default","show","hide"] """.}

  let category = Category(name: "T")
  let
    book =
      Book(
        isbn: "ISBN 979-8836539412",
        url: "ftp://127.0.0.1/books/1.pdf",
        category: category,
        tags: @["nim"],
        price: 52'd,
        status: onsale,
        count: 10,
      )
  # let validateResult = book.validate("default", "show", "hide")
  let validateResult = book.validateWithTagFilterExpr()
  for error in validateResult.errors:
    echo error
