import Oracle
import Parlance
import Wisp
import ImageGen.Base64
import ImageGen.Batch
import ImageGen.ImageInput
import ImageGen.Interactive

open Parlance
open Oracle

def defaultModel : String := Models.geminiFlashImage

def validAspectRatios : List String := ["16:9", "1:1", "4:3", "9:16", "3:4"]

/-- Generate numbered output path for variations.
    When total == 1, returns the base path unchanged.
    Otherwise returns base_01.png, base_02.png, etc. with appropriate zero-padding. --/
def numberedOutput (base : String) (index : Nat) (total : Nat) : String :=
  if total == 1 then base
  else
    let stem := if base.endsWith ".png" then base.dropRight 4 else base
    let width := if total >= 100 then 3 else if total >= 10 then 2 else 1
    let indexStr := toString index
    let padding := String.mk (List.replicate (width - indexStr.length) '0')
    s!"{stem}_{padding}{indexStr}.png"

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

def main (args : List String) : IO UInt32 := do
  match parse cmd args with
  | .error .helpRequested =>
    IO.println cmd.helpText
    return 0
  | .error e =>
    printParseError e
    return 1
  | .ok result =>
    -- Handle --list-models first (doesn't require API key)
    if result.getBool "list-models" then
      IO.println "Available image generation models:"
      IO.println ""
      IO.println s!"  {Models.geminiFlashImage} (default)"
      IO.println "    Google Gemini 2.5 Flash - Fast image generation"
      IO.println ""
      IO.println s!"  {Models.geminiProImage}"
      IO.println "    Google Gemini 3 Pro - Higher quality image generation"
      IO.println ""
      IO.println "Usage: image-gen -m <model> \"your prompt\""
      return 0

    let prompt := result.getString "prompt"
    let output := result.getString! "output" "image.png"
    let aspectRatio := result.getString "aspect-ratio"
    let model := result.getString! "model" defaultModel
    let verbose := result.getBool "verbose"
    let imagePaths := result.getStrings "image"
    let batchFile := result.getString "batch"
    let outputDir := result.getString "output-dir"
    let filePrefix := result.getString! "prefix" "image"
    let count := result.getNatD "count" 1

    -- Check for API key
    let some apiKey ← IO.getEnv "OPENROUTER_API_KEY"
      | do
        printError "OPENROUTER_API_KEY environment variable is required"
        return 1

    -- Create client
    let client := Client.withModel apiKey model

    -- Interactive mode
    if result.getBool "interactive" then
      let config : ImageGen.Interactive.Config := {
        client := client
        model := model
        aspectRatio := aspectRatio
        verbose := verbose
        outputDir := outputDir.getD "."
      }
      ImageGen.Interactive.run config
      return 0

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
        count := count
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
        if count > 1 then
          -- Multiple variations
          let mut succeeded := 0
          let mut failed := 0
          for i in [1:count+1] do
            let outPath := numberedOutput output i count
            if verbose then
              printInfo s!"[{i}/{count}] Generating variation..."
            match ← client.generateImageToFile promptText outPath aspectRatio with
            | .ok path =>
              printSuccess s!"[{i}/{count}] Saved: {path}"
              succeeded := succeeded + 1
            | .error err =>
              printError s!"[{i}/{count}] Failed: {err}"
              failed := failed + 1
          Wisp.HTTP.Client.shutdown
          printInfo s!"Complete: {succeeded}/{count} succeeded, {failed} failed"
          return if failed > 0 then 1 else 0
        else
          -- Single image
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
