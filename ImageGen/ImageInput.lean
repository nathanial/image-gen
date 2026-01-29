/-
  ImageGen - Image Input
  Load and encode image files for API requests
-/

import Oracle
import ImageGen.Base64

namespace ImageGen

open Oracle

/-- Detect media type from file extension -/
def mediaTypeFromPath (path : String) : Option String :=
  let ext := path.toLower
  if ext.endsWith ".png" then some "image/png"
  else if ext.endsWith ".jpg" || ext.endsWith ".jpeg" then some "image/jpeg"
  else if ext.endsWith ".gif" then some "image/gif"
  else if ext.endsWith ".webp" then some "image/webp"
  else none

/-- Load an image file and return as ImageSource.base64 -/
def loadImageFile (path : String) : IO ImageSource := do
  let data ← IO.FS.readBinFile path
  match mediaTypeFromPath path with
  | some mediaType =>
    let encoded := base64Encode data
    return .base64 mediaType encoded
  | none =>
    throw <| IO.userError s!"Unsupported image format: {path}. Supported formats: png, jpg, jpeg, gif, webp"

end ImageGen
