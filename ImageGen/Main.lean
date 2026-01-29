import Oracle
import Parlance
import Wisp

open Parlance
open Oracle

def defaultModel : String := Models.geminiFlashImage

def validAspectRatios : List String := ["16:9", "1:1", "4:3", "9:16", "3:4"]

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

def main (args : List String) : IO UInt32 := do
  match parse cmd args with
  | .error .helpRequested =>
    IO.println cmd.helpText
    return 0
  | .error e =>
    printParseError e
    return 1
  | .ok result =>
    let prompt := result.getString! "prompt" ""
    let output := result.getString! "output" "image.png"
    let aspectRatio := result.getString "aspect-ratio"
    let model := result.getString! "model" defaultModel
    let verbose := result.getBool "verbose"

    -- Check for API key
    let some apiKey ← IO.getEnv "OPENROUTER_API_KEY"
      | do
        printError "OPENROUTER_API_KEY environment variable is required"
        return 1

    if verbose then
      printInfo s!"Model: {model}"
      printInfo s!"Prompt: {prompt}"
      printInfo s!"Output: {output}"
      if let some ar := aspectRatio then
        printInfo s!"Aspect ratio: {ar}"

    -- Create client and generate image
    let client := Client.withModel apiKey model

    if verbose then
      printInfo "Generating image..."

    match ← client.generateImageToFile prompt output aspectRatio with
    | .ok path =>
      printSuccess s!"Image saved to {path}"
      Wisp.HTTP.Client.shutdown
      return 0
    | .error err =>
      printError s!"Failed to generate image: {err}"
      Wisp.HTTP.Client.shutdown
      return 1
