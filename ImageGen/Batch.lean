import Oracle
import Parlance
import Wisp

open Parlance
open Oracle

namespace ImageGen.Batch

structure BatchConfig where
  promptsFile : String        -- Path or "-" for stdin
  outputDir : String
  filePrefix : String
  model : String
  aspectRatio : Option String
  verbose : Bool
  count : Nat                 -- Number of variations per prompt

structure BatchResult where
  total : Nat
  succeeded : Nat
  failed : Nat

/-- Read prompts from file or stdin, one per line, filtering empty lines --/
def readPrompts (path : String) : IO (List String) := do
  let content ← if path == "-" then
    let stdin ← IO.getStdin
    stdin.readToEnd
  else
    IO.FS.readFile path
  return content.splitOn "\n"
    |>.map String.trim
    |>.filter (!·.isEmpty)

/-- Generate output filename with zero-padded index --/
def outputFilename (filePrefix : String) (index : Nat) (total : Nat) : String :=
  let width := if total >= 100 then 3 else if total >= 10 then 2 else 1
  let indexStr := toString index
  let padding := String.mk (List.replicate (width - indexStr.length) '0')
  s!"{filePrefix}_{padding}{indexStr}.png"

/-- Ensure output directory exists --/
def ensureOutputDir (dir : String) : IO Unit := do
  let path : System.FilePath := dir
  if !(← path.pathExists) then
    IO.FS.createDirAll dir

/-- Run batch generation with progress reporting --/
def runBatch (client : Client) (config : BatchConfig) : IO BatchResult := do
  -- Ensure output directory exists
  ensureOutputDir config.outputDir

  -- Read prompts
  let prompts ← readPrompts config.promptsFile
  if prompts.isEmpty then
    printError "No prompts found in batch file"
    return { total := 0, succeeded := 0, failed := 0 }

  let total := prompts.length * config.count
  let mut succeeded := 0
  let mut failed := 0
  let mut idx := 0

  for prompt in prompts do
    for _ in [0:config.count] do
      idx := idx + 1
      let filename := outputFilename config.filePrefix idx total
      let outputPath := s!"{config.outputDir}/{filename}"

      if config.verbose then
        printInfo s!"[{idx}/{total}] Generating: {prompt.take 50}..."

      match ← client.generateImageToFile prompt outputPath config.aspectRatio with
      | .ok path =>
        printSuccess s!"[{idx}/{total}] Saved: {path}"
        succeeded := succeeded + 1
      | .error err =>
        printError s!"[{idx}/{total}] Failed: {err}"
        failed := failed + 1

  return { total, succeeded, failed }

end ImageGen.Batch
