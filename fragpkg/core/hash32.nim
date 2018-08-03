import
  strutils

type
  Hash* = int32 ## a hash value; hash tables using these values should
                ## always have a size of a power of two and can use the ``and``
                ## operator instead of ``mod`` for truncation of the hash value.

proc `!&`*(h: Hash, val: int32): Hash {.inline.} =
  ## mixes a hash value `h` with `val` to produce a new hash value. This is
  ## only needed if you need to implement a hash proc for a new datatype.
  result = h +% val
  result = result +% result shl 10
  result = result xor (result shr 6)

proc `!$`*(h: Hash): Hash {.inline.} =
  ## finishes the computation of the hash value. This is
  ## only needed if you need to implement a hash proc for a new datatype.
  result = h +% h shl 3
  result = result xor (result shr 11)
  result = result +% result shl 15

proc hashData*(data: pointer, size: int32): Hash =
  ## hashes an array of bytes of size `size`
  var h: Hash = 0
  when defined(js):
    var p: cstring
    asm """`p` = `Data`;"""
  else:
    var p = cast[cstring](data)
  var i = 0
  var s = size
  while s > 0:
    h = h !& ord(p[i]).int32
    inc(i)
    dec(s)
  result = !$h

when defined(js):
  var objectID = 0

proc hash*(x: pointer): Hash {.inline.} =
  ## efficient hashing of pointers
  when defined(js):
    asm """
      if (typeof `x` == "object") {
        if ("_NimID" in `x`)
          `result` = `x`["_NimID"];
        else {
          `result` = ++`objectID`;
          `x`["_NimID"] = `result`;
        }
      }
    """
  else:
    result = (cast[Hash](x)) shr 3 # skip the alignment

# Just treat it as pointer
proc hash*(x:uint): Hash {.inline.} =
  hash(cast[pointer](x))
when not defined(booting):
  proc hash*[T: proc](x: T): Hash {.inline.} =
    ## efficient hashing of proc vars; closures are supported too.
    when T is "closure":
      result = hash(rawProc(x)) !& hash(rawEnv(x))
    else:
      result = hash(pointer(x))

proc hash*(x: int32): Hash {.inline.} =
  ## efficient hashing of int32egers
  result = x

proc hash*(x: char): Hash {.inline.} =
  ## efficient hashing of characters
  result = ord(x).int32

proc hash*[T: Ordinal](x: T): Hash {.inline.} =
  ## efficient hashing of other ordinal types (e.g., enums)
  result = ord(x).int32

proc hash*(x: string): Hash =
  ## efficient hashing of strings
  var h: Hash = 0
  for i in 0..x.len-1:
    h = h !& ord(x[i]).int32
  result = !$h

proc hash*(x: cstring): Hash =
  ## efficient hashing of null-terminated strings
  var h: Hash = 0
  var i = 0
  while x[i] != 0.char:
    h = h !& ord(x[i]).int32
    inc i
  result = !$h

proc hash*(sBuf: string, sPos, ePos: int32): Hash =
  ## efficient hashing of a string buffer, from starting
  ## position `sPos` to ending position `ePos`
  ##
  ## ``hash(myStr, 0, myStr.high)`` is equivalent to ``hash(myStr)``
  var h: Hash = 0
  for i in sPos..ePos:
    h = h !& ord(sBuf[i]).int32
  result = !$h

proc hashIgnoreStyle*(x: string): Hash =
  ## efficient hashing of strings; style is ignored
  var h: Hash = 0
  var i = 0
  let xLen = x.len
  while i < xLen:
    var c = x[i]
    if c == '_':
      inc(i)
    else:
      if c in {'A'..'Z'}:
        c = chr(ord(c) + (ord('a') - ord('A'))) # toLower()
      h = h !& ord(c).int32
      inc(i)

  result = !$h

proc hashIgnoreStyle*(sBuf: string, sPos, ePos: int32): Hash =
  ## efficient hashing of a string buffer, from starting
  ## position `sPos` to ending position `ePos`; style is ignored
  ##
  ## ``hashIgnoreStyle(myBuf, 0, myBuf.high)`` is equivalent
  ## to ``hashIgnoreStyle(myBuf)``
  var h: Hash = 0
  var i = sPos
  while i <= ePos:
    var c = sBuf[i]
    if c == '_':
      inc(i)
    else:
      if c in {'A'..'Z'}:
        c = chr(ord(c) + (ord('a') - ord('A'))) # toLower()
      h = h !& ord(c).int32
      inc(i)
  result = !$h

proc hashIgnoreCase*(x: string): Hash =
  ## efficient hashing of strings; case is ignored
  var h: Hash = 0
  for i in 0..x.len-1:
    var c = x[i]
    if c in {'A'..'Z'}:
      c = chr(ord(c) + (ord('a') - ord('A'))) # toLower()
    h = h !& ord(c).int32
  result = !$h

proc hashIgnoreCase*(sBuf: string, sPos, ePos: int32): Hash =
  ## efficient hashing of a string buffer, from starting
  ## position `sPos` to ending position `ePos`; case is ignored
  ##
  ## ``hashIgnoreCase(myBuf, 0, myBuf.high)`` is equivalent
  ## to ``hashIgnoreCase(myBuf)``
  var h: Hash = 0
  for i in sPos..ePos:
    var c = sBuf[i]
    if c in {'A'..'Z'}:
      c = chr(ord(c) + (ord('a') - ord('A'))) # toLower()
    h = h !& ord(c).int32
  result = !$h

proc hash*(x: float): Hash {.inline.} =
  ## efficient hashing of floats.
  var y = x + 1.0
  result = cast[ptr Hash](addr(y))[]


# Forward declarations before methods that hash containers. This allows
# containers to contain other containers
proc hash*[A](x: openArray[A]): Hash
proc hash*[A](x: set[A]): Hash


proc hash*[T: tuple](x: T): Hash =
  ## efficient hashing of tuples.
  for f in fields(x):
    result = result !& hash(f)
  result = !$result

proc hash*[A](x: openArray[A]): Hash =
  ## efficient hashing of arrays and sequences.
  for it in items(x): result = result !& hash(it)
  result = !$result

proc hash*[A](aBuf: openArray[A], sPos, ePos: int32): Hash =
  ## efficient hashing of portions of arrays and sequences.
  ##
  ## ``hash(myBuf, 0, myBuf.high)`` is equivalent to ``hash(myBuf)``
  for i in sPos..ePos:
    result = result !& hash(aBuf[i])
  result = !$result

proc hash*[A](x: set[A]): Hash =
  ## efficient hashing of sets.
  for it in items(x): result = result !& hash(it)
  result = !$result