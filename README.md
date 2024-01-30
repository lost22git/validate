
A simple, not flexible, mediocre performance Object Fields Validator

## Features

* based on pragma and macro
* tags to group/filter validation rules
    *  compile-time: tagsFilter expr
    *  runtime: filterTags params
* custom validation function
* custom validation error message 
* nested validation

## TODO

* i18n validation error message

## pragmas

`{.valid: @[built-in rules].}` for built-in validation rules

`{.validFn(fn="function name").}` for custom validation function

`{.validate: "tag filter expr".}` for marking a proc as validation proc

## built-in validation rules

|rules|for types|usage|description|
|:----|:----|:----|:----|
|nonNil|ref \| ptr \| pointer \| cstring|`a {.valid: @[nonNil()].}: ptr int`|not nil|
|nonEmpty|string \| array \| set \| seq|`a {.valid: nonEmpty().}: string`|len > 0|
|nonBlank|string|`a {.valid: @[nonBlank()].}: string`|not isEmptyOrWhiteSpace, use std/strutils|
|regex|string|`a {.valid: @[regex(pattern="\d+")].}: string`| use std/re|
|range|int|`a {.valid: @[range(min=1, max=10)].}: int`|int range|
|frange|float|`a {.valid: @[frange(min=1,max=10)].}: float`|float range|
|length|string \| array \| set \| seq|`a {.valid: @[length(min=1,max=10)].}: string`|length range|


## usage

> NOTE: 
Due to use std/strutils, std/sequtils in generated code, you should import them where you use `{.validate.}`

* code:
```nim
import validate
import std/[sequtils, strutils]

type Category = ref object
  name {.valid: @[length(min = 2)].}: string

type Status = enum
  onsale
  sold

proc isHttpUrl(v: string): bool =
    v.startswith("http://")

type Book = object
  # use built-in validation rules
  isbn {.valid: @[regex(pattern = r"ISBN \d{3}-\d{10}", tags = ["show"])].}: string
  # {.validFn.} use custom validate function
  url {.validFn(fn = "isHttpUrl", tags = ["show"], msg = "the url is not http url").}: string
  # nested validation
  category {.valid: @[nonNil()].}: Category
  tags {.valid: @[length(min = 2, max = 4, tags = ["show"])].}: seq[string]
  # msg template interpolation: $min and $max
  price {.valid: @[frange(min = 5, max = 50, tags = ["hide"], msg = "the price requires from $min to $max")].}: float
  # support object variants
  case status: Status
  of onsale, sold:
    count {.valid: @[range(min = 100, tags = ["hide"])].}: int

# validate book with filterTags
proc validate(book: Book, filterTags: varargs[string]): ValidateResult {.validate: "".}

# validate book with tagFilterExpr
proc validateWithTagFilterExpr(book: Book): ValidateResult {.validate: """ it in ["default","show","hide"] """.}


let category = Category(name: "T")
let book = Book(
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
```

* output:
```
the url is not http url
Book.category.name: require match range `2 .. 9223372036854775807`
Book.tags: require match range `2 .. 4`
the price requires from 5.0 to 50.0
Book.count: require match range `100 .. 9223372036854775807`
```

## benchmark

[bench.nim](bench/bench.nim)

```
root in validate/bench on  main [✘?] via 👑 v2.0.2
❯ ./bench filterTags
len: 1000000
tag filter method: filterTags
result: 1.203444μs/op

root in validate/bench on  main [✘?] via 👑 v2.0.2
❯ ./bench tagFilterExpr
len: 1000000
tag filter method: tagFilterExpr
result: 1.186805μs/op
```
