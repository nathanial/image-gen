import Crucible
import Parlance
import ImageGen.Base64
import ImageGen.Batch

open Crucible
open Parlance

def validAspectRatios : List String := ["16:9", "1:1", "4:3", "9:16", "3:4"]
def defaultModel : String := "google/gemini-2.5-flash-image"

def cmd : Command := command "image-gen" do
  Cmd.version "0.1.0"
  Cmd.description "Generate images from text prompts using AI"

  Cmd.flag "output" (short := some 'o')
    (argType := .path)
    (description := "Output file path")
    (defaultValue := some "image.png")

  Cmd.flag "aspect-ratio" (short := some 'a')
    (argType := .choice validAspectRatios)
    (description := "Image aspect ratio (16:9, 1:1, 4:3, 9:16, 3:4)")

  Cmd.flag "model" (short := some 'm')
    (argType := .string)
    (description := "Image generation model")
    (defaultValue := some defaultModel)

  Cmd.boolFlag "verbose" (short := some 'v')
    (description := "Enable verbose output")

  Cmd.repeatableFlag "image" (short := some 'i')
    (argType := .path)
    (description := "Input image file path (can be specified multiple times)")

  Cmd.flag "batch" (short := some 'b')
    (argType := .path)
    (description := "Read prompts from file (one per line, use '-' for stdin)")

  Cmd.flag "output-dir" (short := some 'd')
    (argType := .path)
    (description := "Output directory for batch mode")

  Cmd.flag "prefix"
    (argType := .string)
    (description := "Filename prefix for batch output")
    (defaultValue := some "image")

  Cmd.flag "count" (short := some 'n')
    (argType := .nat)
    (description := "Number of image variations to generate")
    (defaultValue := some "1")

  Cmd.boolFlag "list-models" (short := some 'l')
    (description := "List available image generation models")

  Cmd.boolFlag "interactive" (short := some 'I')
    (description := "Start interactive REPL mode")

  Cmd.arg "prompt"
    (argType := .string)
    (description := "Text prompt describing the image to generate")
    (required := false)

namespace Tests.CLI

testSuite "image-gen CLI"

test "parses prompt as positional argument" := do
  match parse cmd ["A beautiful sunset"] with
  | .ok result =>
    result.getString "prompt" ≡ some "A beautiful sunset"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses output flag with short form" := do
  match parse cmd ["-o", "output.png", "A cat"] with
  | .ok result =>
    result.getString "output" ≡ some "output.png"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses output flag with long form" := do
  match parse cmd ["--output", "output.png", "A cat"] with
  | .ok result =>
    result.getString "output" ≡ some "output.png"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses aspect-ratio flag with short form" := do
  match parse cmd ["-a", "16:9", "A landscape"] with
  | .ok result =>
    result.getString "aspect-ratio" ≡ some "16:9"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses aspect-ratio flag with long form" := do
  match parse cmd ["--aspect-ratio", "9:16", "A portrait"] with
  | .ok result =>
    result.getString "aspect-ratio" ≡ some "9:16"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses model flag" := do
  match parse cmd ["-m", "some-model", "A test"] with
  | .ok result =>
    result.getString "model" ≡ some "some-model"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses verbose flag" := do
  match parse cmd ["-v", "A test"] with
  | .ok result =>
    shouldSatisfy (result.getBool "verbose") "verbose should be true"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "uses default output value" := do
  match parse cmd ["A test prompt"] with
  | .ok result =>
    result.getString! "output" "" ≡ "image.png"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "uses default model value" := do
  match parse cmd ["A test prompt"] with
  | .ok result =>
    result.getString! "model" "" ≡ defaultModel
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "verbose defaults to false" := do
  match parse cmd ["A test prompt"] with
  | .ok result =>
    shouldSatisfy (!result.getBool "verbose") "verbose should be false"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "rejects invalid aspect ratio" := do
  match parse cmd ["--aspect-ratio", "2:1", "A test"] with
  | .ok _ =>
    throw (IO.userError "Should have rejected invalid aspect ratio")
  | .error _ =>
    pure ()

test "allows missing prompt when batch flag is provided" := do
  match parse cmd ["--batch", "prompts.txt"] with
  | .ok result =>
    result.getString "batch" ≡ some "prompts.txt"
    result.getString "prompt" ≡ none
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses all flags together" := do
  match parse cmd ["-o", "out.png", "-a", "4:3", "-m", "mymodel", "-v", "A complex prompt"] with
  | .ok result =>
    result.getString "output" ≡ some "out.png"
    result.getString "aspect-ratio" ≡ some "4:3"
    result.getString "model" ≡ some "mymodel"
    shouldSatisfy (result.getBool "verbose") "verbose should be true"
    result.getString "prompt" ≡ some "A complex prompt"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses prompt with spaces" := do
  match parse cmd ["A beautiful mountain landscape at sunset with clouds"] with
  | .ok result =>
    result.getString "prompt" ≡ some "A beautiful mountain landscape at sunset with clouds"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses single image flag with short form" := do
  match parse cmd ["-i", "reference.png", "Make this vintage"] with
  | .ok result =>
    result.getStrings "image" ≡ ["reference.png"]
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses single image flag with long form" := do
  match parse cmd ["--image", "reference.png", "Make this vintage"] with
  | .ok result =>
    result.getStrings "image" ≡ ["reference.png"]
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses multiple image flags" := do
  match parse cmd ["-i", "style.jpg", "-i", "content.png", "Combine styles"] with
  | .ok result =>
    result.getStrings "image" ≡ ["style.jpg", "content.png"]
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "image flag empty when not provided" := do
  match parse cmd ["A simple prompt"] with
  | .ok result =>
    result.getStrings "image" ≡ []
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses image with other flags" := do
  match parse cmd ["-i", "ref.png", "-o", "out.png", "-a", "16:9", "Transform this"] with
  | .ok result =>
    result.getStrings "image" ≡ ["ref.png"]
    result.getString "output" ≡ some "out.png"
    result.getString "aspect-ratio" ≡ some "16:9"
    result.getString "prompt" ≡ some "Transform this"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses batch flag with short form" := do
  match parse cmd ["-b", "prompts.txt"] with
  | .ok result =>
    result.getString "batch" ≡ some "prompts.txt"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses batch flag with long form" := do
  match parse cmd ["--batch", "prompts.txt"] with
  | .ok result =>
    result.getString "batch" ≡ some "prompts.txt"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses output-dir flag with short form" := do
  match parse cmd ["-b", "prompts.txt", "-d", "/tmp/output"] with
  | .ok result =>
    result.getString "output-dir" ≡ some "/tmp/output"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses output-dir flag with long form" := do
  match parse cmd ["--batch", "prompts.txt", "--output-dir", "/tmp/output"] with
  | .ok result =>
    result.getString "output-dir" ≡ some "/tmp/output"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses prefix flag" := do
  match parse cmd ["--batch", "prompts.txt", "--prefix", "art"] with
  | .ok result =>
    result.getString "prefix" ≡ some "art"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "uses default prefix value" := do
  match parse cmd ["--batch", "prompts.txt"] with
  | .ok result =>
    result.getString! "prefix" "" ≡ "image"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "batch with stdin indicator" := do
  match parse cmd ["--batch", "-"] with
  | .ok result =>
    result.getString "batch" ≡ some "-"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses batch with other flags" := do
  match parse cmd ["-b", "prompts.txt", "-d", "/tmp/out", "--prefix", "gen", "-a", "16:9", "-m", "mymodel", "-v"] with
  | .ok result =>
    result.getString "batch" ≡ some "prompts.txt"
    result.getString "output-dir" ≡ some "/tmp/out"
    result.getString "prefix" ≡ some "gen"
    result.getString "aspect-ratio" ≡ some "16:9"
    result.getString "model" ≡ some "mymodel"
    shouldSatisfy (result.getBool "verbose") "verbose should be true"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses count flag with short form" := do
  match parse cmd ["-n", "3", "A sunset"] with
  | .ok result =>
    result.getNatD "count" 0 ≡ 3
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses count flag with long form" := do
  match parse cmd ["--count", "5", "A sunset"] with
  | .ok result =>
    result.getNatD "count" 0 ≡ 5
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "uses default count value of 1" := do
  match parse cmd ["A test prompt"] with
  | .ok result =>
    result.getNatD "count" 0 ≡ 1
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses count with batch mode" := do
  match parse cmd ["--batch", "prompts.txt", "-n", "2"] with
  | .ok result =>
    result.getString "batch" ≡ some "prompts.txt"
    result.getNatD "count" 0 ≡ 2
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses count with other flags combined" := do
  match parse cmd ["-o", "out.png", "-n", "4", "-a", "16:9", "-v", "A prompt"] with
  | .ok result =>
    result.getString "output" ≡ some "out.png"
    result.getNatD "count" 0 ≡ 4
    result.getString "aspect-ratio" ≡ some "16:9"
    shouldSatisfy (result.getBool "verbose") "verbose should be true"
    result.getString "prompt" ≡ some "A prompt"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses list-models flag with short form" := do
  match parse cmd ["-l"] with
  | .ok result =>
    shouldSatisfy (result.getBool "list-models") "list-models should be true"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses list-models flag with long form" := do
  match parse cmd ["--list-models"] with
  | .ok result =>
    shouldSatisfy (result.getBool "list-models") "list-models should be true"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "list-models defaults to false" := do
  match parse cmd ["A test prompt"] with
  | .ok result =>
    shouldSatisfy (!result.getBool "list-models") "list-models should be false"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses interactive flag with short form" := do
  match parse cmd ["-I"] with
  | .ok result =>
    shouldSatisfy (result.getBool "interactive") "interactive should be true"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "parses interactive flag with long form" := do
  match parse cmd ["--interactive"] with
  | .ok result =>
    shouldSatisfy (result.getBool "interactive") "interactive should be true"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "interactive defaults to false" := do
  match parse cmd ["A prompt"] with
  | .ok result =>
    shouldSatisfy (!result.getBool "interactive") "interactive should be false"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

test "interactive with model flag" := do
  match parse cmd ["-I", "-m", "google/gemini-3-pro"] with
  | .ok result =>
    shouldSatisfy (result.getBool "interactive") "interactive should be true"
    result.getString "model" ≡ some "google/gemini-3-pro"
  | .error e =>
    throw (IO.userError s!"Parse failed: {e}")

end Tests.CLI

namespace Tests.Base64

testSuite "Base64 Encoding"

test "encodes empty array" := do
  let data := ByteArray.empty
  ImageGen.base64Encode data ≡ ""

test "encodes single byte" := do
  let data := ByteArray.mk #[65]  -- 'A'
  ImageGen.base64Encode data ≡ "QQ=="

test "encodes two bytes" := do
  let data := ByteArray.mk #[65, 66]  -- "AB"
  ImageGen.base64Encode data ≡ "QUI="

test "encodes three bytes" := do
  let data := ByteArray.mk #[65, 66, 67]  -- "ABC"
  ImageGen.base64Encode data ≡ "QUJD"

test "encodes Hello" := do
  let data := ByteArray.mk #[72, 101, 108, 108, 111]  -- "Hello"
  ImageGen.base64Encode data ≡ "SGVsbG8="

test "decodes empty string" := do
  match ImageGen.base64Decode "" with
  | some data => data.size ≡ 0
  | none => throw (IO.userError "Decode failed")

test "decodes single byte" := do
  match ImageGen.base64Decode "QQ==" with
  | some data =>
    let expected := ByteArray.mk #[65]
    shouldSatisfy (data == expected) "decoded bytes should match"
  | none => throw (IO.userError "Decode failed")

test "decodes Hello" := do
  match ImageGen.base64Decode "SGVsbG8=" with
  | some data =>
    let expected := ByteArray.mk #[72, 101, 108, 108, 111]
    shouldSatisfy (data == expected) "decoded Hello bytes should match"
  | none => throw (IO.userError "Decode failed")

test "roundtrip encoding" := do
  let original := ByteArray.mk #[0, 127, 255, 128, 1, 254]
  let encoded := ImageGen.base64Encode original
  match ImageGen.base64Decode encoded with
  | some decoded =>
    shouldSatisfy (decoded == original) "roundtrip should preserve bytes"
  | none => throw (IO.userError "Roundtrip decode failed")

end Tests.Base64

namespace Tests.ImageInput

testSuite "Image Input"

/-- Local copy of mediaTypeFromPath for testing without Oracle dependency -/
def mediaTypeFromPath (path : String) : Option String :=
  let ext := path.toLower
  if ext.endsWith ".png" then some "image/png"
  else if ext.endsWith ".jpg" || ext.endsWith ".jpeg" then some "image/jpeg"
  else if ext.endsWith ".gif" then some "image/gif"
  else if ext.endsWith ".webp" then some "image/webp"
  else none

test "detects PNG media type" := do
  mediaTypeFromPath "image.png" ≡ some "image/png"

test "detects PNG media type uppercase" := do
  mediaTypeFromPath "IMAGE.PNG" ≡ some "image/png"

test "detects JPG media type" := do
  mediaTypeFromPath "photo.jpg" ≡ some "image/jpeg"

test "detects JPEG media type" := do
  mediaTypeFromPath "photo.jpeg" ≡ some "image/jpeg"

test "detects GIF media type" := do
  mediaTypeFromPath "animation.gif" ≡ some "image/gif"

test "detects WebP media type" := do
  mediaTypeFromPath "modern.webp" ≡ some "image/webp"

test "returns none for unsupported format" := do
  mediaTypeFromPath "document.pdf" ≡ none

test "returns none for no extension" := do
  mediaTypeFromPath "noextension" ≡ none

test "handles path with directories" := do
  mediaTypeFromPath "/path/to/image.png" ≡ some "image/png"

end Tests.ImageInput

namespace Tests.Batch

testSuite "Batch Processing"

test "outputFilename pads single digit for small batch" := do
  ImageGen.Batch.outputFilename "art" 1 5 ≡ "art_1.png"

test "outputFilename pads to 2 digits for 10+ batch" := do
  ImageGen.Batch.outputFilename "art" 1 15 ≡ "art_01.png"

test "outputFilename pads to 2 digits middle of batch" := do
  ImageGen.Batch.outputFilename "art" 9 15 ≡ "art_09.png"

test "outputFilename no padding needed for double digit" := do
  ImageGen.Batch.outputFilename "art" 12 15 ≡ "art_12.png"

test "outputFilename pads to 3 digits for 100+ batch" := do
  ImageGen.Batch.outputFilename "img" 1 150 ≡ "img_001.png"

test "outputFilename pads to 3 digits middle" := do
  ImageGen.Batch.outputFilename "img" 42 150 ≡ "img_042.png"

test "outputFilename no padding for triple digit" := do
  ImageGen.Batch.outputFilename "img" 123 150 ≡ "img_123.png"

test "outputFilename custom prefix" := do
  ImageGen.Batch.outputFilename "landscape" 5 10 ≡ "landscape_05.png"

end Tests.Batch

def main : IO UInt32 := runAllSuites
