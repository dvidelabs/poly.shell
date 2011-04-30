
# min .. max integer range, both incl.
exports.randomIntRangeIncl = (min, max) ->
  Math.floor(Math.random() * (max - min + 1)) + min

# min .. max integer range, max excl.
exports.randomIntRange = (min, max) ->
  Math.floor(Math.random() * (max - min)) + min

# 0 .. max integer range, both incl.
exports.randomIntIncl = (max) ->
  Math.floor(Math.random() * (max + 1))

# 0 .. max integer range, max excl.
exports.randomInt = (max) ->
  Math.floor(Math.random() * max)
  
# Creates a fixed length random string from a given alphabet.
# Default length is 10 with the alphabet A-Za-z0-9.
exports.uid = (len = 10, alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') ->
  uid = ''
  n = alphabet.length
  for i in [0...len]
    uid += alphabet[Math.floor(Math.random() * n)]
  uid

# Takes a map (object) and creates an array of one element at the given key
# or pushes to an already existing array.
exports.pushmap = (map, key, elem) -> a = map[key]; if a then a.push elem else map[key] = [elem]

# Takes a map (object) and increments a value at the given key
# or creates a first value plus increment. Increment defaults to 1 and first
# value defaults to zero. 
exports.addmap = (map, key, inc = 1, first = 0) -> val = map[key] or first; map[key] = val + inc

# Write text to a named buffer in a object, similar to pushmap and addmap.
exports.writemap = (map, key, msg = 1, first = "") -> val = map[key] or first; map[key] = val + msg

# Compare two arrays interpreted as sets.
# True if x and y has the same members. Duplicates ignored.
exports.eqSet = (x, y) ->
  h = {}
  for v in x
    h[v] = true
  for v in y
    return false unless h[v]
  return true

# Like eqSet, but the number of duplicates must match.
exports.eqlSet = (x, y) ->
    return false if x.length != y.length
    return exports.eqSet(x, y)


# Prints an indent list on multiple lines
# list : single element or array of elements to display
#  returns empty string on empty list
#  returns formatted string otherwise
#
# optional options:
#  indent : string before start of each line, default 4 spaces
#  sep : string after each element, except last on a line, default ", "
#  eol : end of line string, except last line, default "\n"
#  limit: maximum line width (not counting eol string), default 70
#    limit exceeded when an indented single element won't fit.
exports.formatList = (list, opts) ->
  return "" unless list
  unless list instanceof Array
    list = [list]
  opts = opts or {}
  limit = opts.limit or 70
  indent = opts.indent or "    "
  sep = opts.sep or ", "
  eol = opts.eol or "\n"
  buf = ""
  return "" unless list.length
  e = list.shift().toString()
  while true
    ln = indent + e
    return buf + ln unless list.length
    e = list.shift()
    e = e.toString()
    while ln.length + sep.length + e.length <= limit
      ln += sep + e
      return buf + ln unless list.length
      e = list.shift()
      e = e.toString()
    buf += ln + eol

# Splits a string into lines and returns
# a new string with a lines  indented
#
# Optional options:
#  indent: string inserted at start of each line, default 4 spaces
#  eol: string inserted at the end of each line, except the last, default '\n'
#  split: string used to split into lines, default '\n'
exports.indentMsg = (msg, opts) ->
  msg = msg.toString()
  opts = opts or {}
  indent = opts.indent or "    "
  eol = opts.eol or '\n'
  split = opts.split or '\n'
  lines = msg.split(split)
  buf = ""
  n = lines.length
  for l in lines
    buf += indent + l
    buf += eol if --n
  return buf
