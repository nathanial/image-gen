/-
  ImageGen.Interactive - Interactive REPL mode for image generation

  Provides an iterative refinement workflow where users can:
  - Generate images interactively
  - Undo/redo prompts
  - Save images with custom names
  - View and manage prompt history
  - Switch models and aspect ratios
-/
import Oracle
import Parlance
import Parlance.Repl
import Wisp
import ImageGen.Base64

open Parlance
open Oracle

namespace ImageGen.Interactive

/-- State for interactive session -/
structure State where
  client : Client
  model : String
  aspectRatio : Option String
  verbose : Bool
  promptHistory : Array String      -- All prompts entered
  imageHistory : Array String       -- File paths of generated images
  historyIndex : Nat                -- Current position (for undo/redo)
  outputDir : String                -- Where to save images
  imageCounter : Nat                -- For unique filenames

/-- Configuration for starting REPL -/
structure Config where
  client : Client
  model : String
  aspectRatio : Option String
  verbose : Bool
  outputDir : String

def initialState (cfg : Config) : State := {
  client := cfg.client
  model := cfg.model
  aspectRatio := cfg.aspectRatio
  verbose := cfg.verbose
  promptHistory := #[]
  imageHistory := #[]
  historyIndex := 0
  outputDir := cfg.outputDir
  imageCounter := 1
}

/-- Generate unique filename -/
def nextFilename (state : State) : String × State :=
  let name := s!"image_{state.imageCounter}.png"
  let path := if state.outputDir == "." then name else s!"{state.outputDir}/{name}"
  (path, {state with imageCounter := state.imageCounter + 1})

/-- Generate image and update state -/
def generateImage (state : State) (prompt : String) : IO (State × Bool) := do
  let (outPath, state) := nextFilename state
  if state.verbose then
    printInfo s!"Generating: {prompt.take 50}..."
  match ← state.client.generateImageToFile prompt outPath state.aspectRatio with
  | .ok path =>
    printSuccess s!"Saved: {path}"
    let newState := {state with
      promptHistory := state.promptHistory.push prompt
      imageHistory := state.imageHistory.push path
      historyIndex := state.promptHistory.size + 1  -- Point after new entry
    }
    pure (newState, false)
  | .error err =>
    printError s!"Failed: {err}"
    pure (state, false)

/-- Valid aspect ratios -/
def validAspectRatios : List String := ["16:9", "1:1", "4:3", "9:16", "3:4"]

/-- Handle slash commands -/
def handleCommand (state : State) (input : String) : IO (State × Bool) := do
  let parts := input.trim.splitOn " "
  let cmd := parts.head?.getD ""
  let args := parts.drop 1

  match cmd.toLower with
  | "/quit" | "/q" | "/exit" =>
    printInfo "Goodbye!"
    pure (state, true)

  | "/help" | "/?" =>
    IO.println "Commands:"
    IO.println "  /quit, /q      Exit interactive mode"
    IO.println "  /undo          Revert to previous prompt"
    IO.println "  /redo          Redo after undo"
    IO.println "  /save [name]   Save current image with custom name"
    IO.println "  /history       Show prompt history"
    IO.println "  /clear         Clear history"
    IO.println "  /model [name]  Show or switch model"
    IO.println "  /aspect [r]    Show or set aspect ratio"
    IO.println ""
    IO.println "Enter a prompt to generate an image."
    pure (state, false)

  | "/history" =>
    if state.promptHistory.isEmpty then
      printInfo "No history yet."
    else
      IO.println "Prompt history:"
      let prompts := state.promptHistory.toList
      for i in [:prompts.length] do
        let prompt := prompts[i]!
        let marker := if i == state.historyIndex - 1 then ">" else " "
        IO.println s!"{marker} {i + 1}. {prompt.take 60}"
    pure (state, false)

  | "/clear" =>
    printInfo "History cleared."
    pure ({state with promptHistory := #[], imageHistory := #[], historyIndex := 0}, false)

  | "/model" =>
    match args.head? with
    | none =>
      printInfo s!"Current model: {state.model}"
      pure (state, false)
    | some newModel =>
      printInfo s!"Model changed to: {newModel}"
      let newClient := Client.withModel state.client.config.apiKey newModel
      pure ({state with model := newModel, client := newClient}, false)

  | "/aspect" =>
    match args.head? with
    | none =>
      let ar := state.aspectRatio.getD "default"
      printInfo s!"Current aspect ratio: {ar}"
      pure (state, false)
    | some ratio =>
      if ratio ∈ validAspectRatios then
        printInfo s!"Aspect ratio set to: {ratio}"
        pure ({state with aspectRatio := some ratio}, false)
      else
        printError s!"Invalid ratio. Use: 16:9, 1:1, 4:3, 9:16, 3:4"
        pure (state, false)

  | "/undo" =>
    if state.historyIndex > 1 then
      let newIndex := state.historyIndex - 1
      let prompt := state.promptHistory[newIndex - 1]!
      printInfo s!"Undone. Previous prompt: {prompt.take 50}"
      pure ({state with historyIndex := newIndex}, false)
    else
      printWarning "Nothing to undo."
      pure (state, false)

  | "/redo" =>
    if state.historyIndex < state.promptHistory.size then
      let newIndex := state.historyIndex + 1
      let prompt := state.promptHistory[newIndex - 1]!
      printInfo s!"Redone. Prompt: {prompt.take 50}"
      pure ({state with historyIndex := newIndex}, false)
    else
      printWarning "Nothing to redo."
      pure (state, false)

  | "/save" =>
    if state.imageHistory.isEmpty then
      printWarning "No images to save."
      pure (state, false)
    else
      let lastImage := state.imageHistory.back!
      let targetName := match args.head? with
        | some name => if name.endsWith ".png" then name else s!"{name}.png"
        | none => lastImage
      if targetName != lastImage then
        try
          let content ← IO.FS.readBinFile lastImage
          IO.FS.writeBinFile targetName content
          printSuccess s!"Saved as: {targetName}"
        catch _ =>
          printError "Failed to save file."
      else
        printInfo s!"Image already at: {lastImage}"
      pure (state, false)

  | _ =>
    printError s!"Unknown command: {cmd}. Type /help for commands."
    pure (state, false)

/-- Main REPL loop -/
def run (cfg : Config) : IO Unit := do
  printInfo "Interactive image generation mode"
  printInfo s!"Model: {cfg.model}"
  printInfo "Type a prompt to generate an image, or /help for commands."
  IO.println ""

  let stateRef ← IO.mkRef (initialState cfg)

  Parlance.Repl.simple "image> " none fun input => do
    let trimmed := input.trim
    if trimmed.isEmpty then
      pure false
    else if trimmed.startsWith "/" then
      let state ← stateRef.get
      let (newState, shouldExit) ← handleCommand state trimmed
      stateRef.set newState
      pure shouldExit
    else
      -- Generate image from prompt
      let state ← stateRef.get
      let (newState, shouldExit) ← generateImage state trimmed
      stateRef.set newState
      pure shouldExit

  Wisp.HTTP.Client.shutdown

end ImageGen.Interactive
