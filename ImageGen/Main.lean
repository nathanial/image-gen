import Oracle
import Parlance
import Wisp
import ImageGen.Base64
import ImageGen.Batch
import ImageGen.ImageInput

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

  Cmd.arg "prompt"
    (argType := .string)
    (description := "Text prompt describing the image to generate")
    (required := false)

def main (args : List String) : IO UInt32 := do
  match parse cmd args with
  | .error .helpRequested =>
    IO.println cmd.helpText
    return 0
  | .error e =>
    printParseError e
    return 1
  | .ok result =>
    let prompt := result.getString "prompt"
    let output := result.getString! "output" "image.png"
    let aspectRatio := result.getString "aspect-ratio"
    let model := result.getString! "model" defaultModel
    let verbose := result.getBool "verbose"
    let imagePaths := result.getStrings "image"
    let batchFile := result.getString "batch"
    let outputDir := result.getString "output-dir"
    let filePrefix := result.getString! "prefix" "image"

    -- Check for API key
    let some apiKey ← IO.getEnv "OPENROUTER_API_KEY"
      | do
        printError "OPENROUTER_API_KEY environment variable is required"
        return 1

    -- Create client
    let client := Client.withModel apiKey model

    -- Batch mode takes precedence
    if let some batchPath := batchFile then
      let dir := outputDir.getD "."
      let config : ImageGen.Batch.BatchConfig := {
        promptsFile := batchPath
        outputDir := dir
        filePrefix := filePrefix
        model := model
        aspectRatio := aspectRatio
        verbose := verbose
      }
      let result ← ImageGen.Batch.runBatch client config
      Wisp.HTTP.Client.shutdown
      -- Print summary
      if result.total == 0 then
        return 1
      printInfo s!"Batch complete: {result.succeeded}/{result.total} succeeded, {result.failed} failed"
      return if result.failed > 0 then 1 else 0
    else
      -- Single image mode - requires prompt
      let some promptText := prompt
        | do
          printError "Prompt is required for single image mode (use --batch for batch mode)"
          return 1

      if verbose then
        printInfo s!"Model: {model}"
        printInfo s!"Prompt: {promptText}"
        printInfo s!"Output: {output}"
        if let some ar := aspectRatio then
          printInfo s!"Aspect ratio: {ar}"
        if !imagePaths.isEmpty then
          for path in imagePaths do
            printInfo s!"Input image: {path}"

      if verbose then
        printInfo "Generating image..."

      -- Check if we have input images
      if imagePaths.isEmpty then
        -- Simple text-to-image generation
        match ← client.generateImageToFile promptText output aspectRatio with
        | .ok path =>
          printSuccess s!"Image saved to {path}"
          Wisp.HTTP.Client.shutdown
          return 0
        | .error err =>
          printError s!"Failed to generate image: {err}"
          Wisp.HTTP.Client.shutdown
          return 1
      else
        -- Image-to-image generation with reference images
        -- Load input images
        let mut images : Array ImageSource := #[]
        for path in imagePaths do
          try
            let source ← ImageGen.loadImageFile path
            images := images.push source
          catch e =>
            printError s!"Failed to load image '{path}': {e}"
            Wisp.HTTP.Client.shutdown
            return 1

        -- Create multimodal message with images and prompt
        let msg := Message.userWithImages promptText images
        let req := ChatRequest.create model #[msg]
          |>.withImageGeneration aspectRatio
          |>.withMaxTokens 4096

        -- Execute request
        match ← client.chat req with
        | .ok resp =>
          -- Extract the generated image
          match Client.extractImages resp with
          | imgs =>
            if h : 0 < imgs.size then
              let img := imgs[0]
              -- Get the base64 data from the image
              match img.base64Data? with
              | some data =>
                match ImageGen.base64Decode data with
                | some bytes =>
                  IO.FS.writeBinFile output bytes
                  printSuccess s!"Image saved to {output}"
                  Wisp.HTTP.Client.shutdown
                  return 0
                | none =>
                  printError "Failed to decode base64 image data"
                  Wisp.HTTP.Client.shutdown
                  return 1
              | none =>
                printError "No base64 data in response image"
                Wisp.HTTP.Client.shutdown
                return 1
            else
              printError "No image in response"
              Wisp.HTTP.Client.shutdown
              return 1
        | .error err =>
          printError s!"Failed to generate image: {err}"
          Wisp.HTTP.Client.shutdown
          return 1
