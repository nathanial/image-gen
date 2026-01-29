import Crucible
import Parlance

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

  Cmd.arg "prompt"
    (argType := .string)
    (description := "Text prompt describing the image to generate")
    (required := true)

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

test "fails when prompt is missing" := do
  match parse cmd ["--output", "test.png"] with
  | .ok _ =>
    throw (IO.userError "Should have required prompt")
  | .error _ =>
    pure ()

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

end Tests.CLI

def main : IO UInt32 := runAllSuites
