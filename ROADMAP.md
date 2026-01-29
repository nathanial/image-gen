# image-gen Roadmap

Feature ideas and future directions for the image-gen CLI tool.

## Current Features (v0.1.0)

- Text-to-image generation via OpenRouter API
- Image-to-image generation with reference images (`-i` flag)
- Aspect ratio selection (`-a`: 16:9, 1:1, 4:3, 9:16, 3:4)
- Model selection (`-m` flag, default: gemini-2.5-flash-image)
- Verbose mode (`-v`)
- Custom output path (`-o`)

---

## High Priority

### Interactive Mode
Add REPL-style interactive mode for iterative refinement.

```bash
image-gen -i
> A mountain landscape at sunset
[Generated: image_001.png]
> Make the sky more dramatic
[Generated: image_002.png]
> /undo
[Reverted to image_001.png]
> /save final.png
```

**Commands:** `/quit`, `/undo`, `/redo`, `/save`, `/history`, `/clear`, `/model`

**Files:** `ImageGen/Interactive.lean`

---

### Batch Generation
Generate multiple images from a prompts file.

```bash
# Generate from prompts file
image-gen --batch prompts.txt --output-dir ./generated/

# Prompts file format (one per line)
image-gen --batch - < prompts.txt  # Read from stdin
```

**Flags:**
- `--batch <FILE>` - Read prompts from file (one per line)
- `--output-dir <DIR>` - Output directory for batch mode
- `--prefix <STRING>` - Filename prefix (default: "image")

**Files:** `ImageGen/Batch.lean`

---

### Image Variations
Generate N variations of a prompt or image.

```bash
# Generate 4 variations
image-gen -n 4 "A cyberpunk city"

# Variations of an existing image
image-gen -i photo.jpg -n 3 "Similar to this"
```

**Flags:**
- `-n, --count <INT>` - Number of images to generate (default: 1)

---

### Seed Control
Enable reproducible generation with seed values.

```bash
# Use specific seed
image-gen --seed 12345 "A red apple"

# Show seed in output
image-gen -v "A red apple"
# Output: Seed: 48291037

# Reuse seed for consistency
image-gen --seed 48291037 "A red apple on a table"
```

**Flags:**
- `--seed <INT>` - Random seed for reproducibility
- `--show-seed` - Display seed in output (implied by `-v`)

---

## Medium Priority

### Negative Prompts
Specify what to avoid in generation.

```bash
image-gen "A forest landscape" --negative "people, buildings, cars"
image-gen "Portrait photo" -N "blurry, distorted, cartoon"
```

**Flags:**
- `--negative, -N <STRING>` - Negative prompt (things to avoid)

---

### Style Presets
Built-in style modifiers for common artistic styles.

```bash
image-gen --style watercolor "A garden"
image-gen --style "oil painting" "Portrait of a woman"
image-gen --style cyberpunk "City street"
image-gen --list-styles
```

**Built-in styles:**
- `watercolor` - Soft, flowing watercolor painting
- `oil-painting` - Classical oil painting style
- `pencil-sketch` - Black and white pencil drawing
- `anime` - Japanese anime style
- `photorealistic` - Highly realistic photograph
- `cyberpunk` - Neon-lit futuristic aesthetic
- `pixel-art` - Retro pixel art style
- `minimalist` - Clean, minimal design

**Flags:**
- `--style <NAME>` - Apply a style preset
- `--list-styles` - List available style presets

**Files:** `ImageGen/Styles.lean`

---

### Progress Indicator
Show generation progress with spinner/progress bar.

```bash
image-gen "A complex scene"
# Output:
# Generating image... [=====>    ] 60%
# Image saved to image.png
```

Uses `Parlance.Output.Spinner` for visual feedback.

---

### List Models
Show available image generation models.

```bash
image-gen --list-models

# Output:
# Available image generation models:
#   google/gemini-2.5-flash-image  (default)
#   google/gemini-3-pro-image-preview
#   ...
```

**Flags:**
- `-l, --list-models` - List available models

---

### Temperature Control
Adjust creativity/randomness of generation.

```bash
image-gen -t 0.3 "A house"  # More deterministic
image-gen -t 1.5 "A house"  # More creative/varied
```

**Flags:**
- `-t, --temperature <FLOAT>` - Sampling temperature (0.0-2.0)

---

### Output Format Selection
Choose output image format.

```bash
image-gen --format jpg "A photo"
image-gen --format webp --quality 90 "A photo"
```

**Flags:**
- `--format <png|jpg|webp>` - Output format (default: png)
- `--quality <INT>` - Quality for lossy formats (1-100)

**Note:** Requires image format conversion, may need raster library.

---

## Lower Priority

### Config File Support
Persist settings in a config file.

```bash
# Create default config
image-gen --init-config

# Config location: ~/.config/image-gen/config.toml
```

**Config example:**
```toml
[defaults]
model = "google/gemini-2.5-flash-image"
aspect_ratio = "16:9"
output_dir = "~/Pictures/generated"

[styles]
my-style = "in the style of Van Gogh, swirling brushstrokes"
```

**Files:** `ImageGen/Config.lean`

---

### Prompt Templates
Reusable prompt templates with variables.

```bash
# Use template
image-gen --template portrait --var name="Alice" --var style="renaissance"

# Template file (~/.config/image-gen/templates/portrait.txt):
# A ${style} portrait of ${name}, masterful lighting
```

**Flags:**
- `--template <NAME>` - Use a saved template
- `--var <KEY>=<VALUE>` - Set template variable

---

### Prompt History
Track and recall previous prompts.

```bash
image-gen --history           # Show recent prompts
image-gen --history 5         # Reuse prompt #5
image-gen --history search "mountain"  # Search history
```

**Storage:** `~/.local/share/image-gen/history.json`

---

### Gallery Viewer
TUI-based gallery for browsing generated images.

```bash
image-gen --gallery           # Browse all generated images
image-gen --gallery ./output  # Browse specific directory
```

**Features:**
- Thumbnail grid view
- Full-size preview
- Prompt display
- Delete/rename/copy actions
- Filter by date/prompt

**Depends on:** terminus, raster

---

### Watch Mode
Regenerate when prompt file changes.

```bash
image-gen --watch prompt.txt -o output.png
# Regenerates whenever prompt.txt is modified
```

Useful for iterative prompt engineering.

---

### Inpainting
Edit specific regions of an image.

```bash
# With mask image (white = edit, black = keep)
image-gen -i photo.jpg --mask mask.png "A red hat"

# Interactive mask drawing (requires TUI)
image-gen -i photo.jpg --inpaint "Replace the background"
```

**Note:** Requires model support for inpainting.

---

### Outpainting
Extend image canvas beyond original boundaries.

```bash
image-gen -i photo.jpg --extend left 200 "Continue the scene"
image-gen -i photo.jpg --extend all 100 "Expand the landscape"
```

---

### Upscaling
Increase image resolution.

```bash
image-gen -i small.png --upscale 2x
image-gen -i small.png --upscale 4x --output large.png
```

**Note:** May require dedicated upscaling model or integration with external tools.

---

### Metadata Embedding
Store generation parameters in image metadata.

```bash
image-gen --embed-metadata "A sunset"
# Embeds in PNG: prompt, model, seed, timestamp

image-gen --show-metadata image.png
# Displays embedded generation info
```

---

### Pipe Support
Output raw image data for piping.

```bash
# Output to stdout (for piping)
image-gen --stdout "A logo" | convert - -resize 50% thumbnail.png

# Base64 output
image-gen --base64 "An icon" | pbcopy
```

---

### Cost Estimation
Show estimated cost before generation.

```bash
image-gen --estimate "A detailed landscape"
# Estimated cost: $0.003 (google/gemini-2.5-flash-image)
# Proceed? [Y/n]

image-gen --no-confirm "A quick test"  # Skip confirmation
```

---

### Retry with Backoff
Automatic retry on transient failures.

```bash
image-gen --retry 3 "A complex scene"
# Retries up to 3 times with exponential backoff
```

Already partially supported via Oracle's retry mechanisms.

---

## Integration Ideas

### With ask
```bash
# Generate image based on ask conversation
ask "Describe a fantasy creature" | image-gen -
```

### With terminus apps
- Use generated images as game assets
- Create sprites for twenty48, minefield, etc.

### With raster
- Post-process generated images
- Resize, crop, apply filters

### With afferent
- Display generated images in GPU-accelerated viewer
- Create image generation UI

---

## Technical Debt

- [ ] Reduce code duplication between text-only and image-input paths
- [ ] Extract common HTTP shutdown pattern
- [ ] Add structured logging (chronicle integration)
- [ ] Improve error messages with actionable suggestions
- [ ] Add shell completion generation

---

## Contributing

Ideas welcome! Open an issue or submit a PR.
