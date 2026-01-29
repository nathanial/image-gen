/-
  ImageGen - Base64 Encoding
  Encode binary data to base64 for API requests
-/

namespace ImageGen

private def base64Chars : String :=
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

private def charAtIndex (s : String) (i : Nat) : Char :=
  s.data[i]!

/-- Encode a ByteArray to Base64 string -/
def base64Encode (data : ByteArray) : String := Id.run do
  if data.size == 0 then return ""

  let mut result : String := ""
  let mut i := 0

  while i + 2 < data.size do
    let b0 := data.data[i]!.toNat
    let b1 := data.data[i + 1]!.toNat
    let b2 := data.data[i + 2]!.toNat

    let c0 := b0 >>> 2
    let c1 := ((b0 &&& 0x03) <<< 4) ||| (b1 >>> 4)
    let c2 := ((b1 &&& 0x0F) <<< 2) ||| (b2 >>> 6)
    let c3 := b2 &&& 0x3F

    result := result.push (charAtIndex base64Chars c0)
    result := result.push (charAtIndex base64Chars c1)
    result := result.push (charAtIndex base64Chars c2)
    result := result.push (charAtIndex base64Chars c3)
    i := i + 3

  let remaining := data.size - i
  if remaining == 1 then
    let b0 := data.data[i]!.toNat
    let c0 := b0 >>> 2
    let c1 := (b0 &&& 0x03) <<< 4
    result := result.push (charAtIndex base64Chars c0)
    result := result.push (charAtIndex base64Chars c1)
    result := result ++ "=="
  else if remaining == 2 then
    let b0 := data.data[i]!.toNat
    let b1 := data.data[i + 1]!.toNat
    let c0 := b0 >>> 2
    let c1 := ((b0 &&& 0x03) <<< 4) ||| (b1 >>> 4)
    let c2 := (b1 &&& 0x0F) <<< 2
    result := result.push (charAtIndex base64Chars c0)
    result := result.push (charAtIndex base64Chars c1)
    result := result.push (charAtIndex base64Chars c2)
    result := result ++ "="

  return result

/-- Base64 decoding lookup table. Returns 255 for invalid characters, 0-63 for valid. -/
private def base64DecodeTable : Array UInt8 := Id.run do
  let mut table : Array UInt8 := Array.replicate 256 255
  -- A-Z = 0-25
  for i in [:26] do
    table := table.set! ('A'.toNat + i) i.toUInt8
  -- a-z = 26-51
  for i in [:26] do
    table := table.set! ('a'.toNat + i) (i + 26).toUInt8
  -- 0-9 = 52-61
  for i in [:10] do
    table := table.set! ('0'.toNat + i) (i + 52).toUInt8
  -- + = 62, / = 63
  table := table.set! '+'.toNat 62
  table := table.set! '/'.toNat 63
  return table

/-- Decode a base64 string to bytes -/
def base64Decode (s : String) : Option ByteArray := Id.run do
  let chars := s.toList.filter fun c => c != '\n' && c != '\r' && c != ' '
  let mut result := ByteArray.empty
  let mut buffer : UInt32 := 0
  let mut bits : Nat := 0

  for c in chars do
    if c == '=' then
      continue  -- padding
    let idx := c.toNat
    if idx >= 256 then return none
    let val := base64DecodeTable[idx]!
    if val == 255 then return none

    buffer := (buffer <<< 6) ||| val.toUInt32
    bits := bits + 6

    if bits >= 8 then
      bits := bits - 8
      let byte := ((buffer >>> bits.toUInt32) &&& 0xFF).toUInt8
      result := result.push byte

  return some result

end ImageGen
