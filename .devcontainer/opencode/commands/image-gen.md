---
description: Generate or edit one image through the configured LiteLLM proxy
---

Handle this request only through the image command:

$ARGUMENTS

1. Resolve the prompt, image model, and desired output path from the request or
   established conversation. Ask for missing prompt/model information. Never
   impose a provider, endpoint, or model, or reuse the chat model automatically.
2. For a new image use `/images/generations`. For an explicit edit use
   `/images/edits` with a local reference PNG and optional PNG mask. A reference
   alone does not prove edit capability; confirm support for the selected model
   from available documentation/configuration. Do not claim an untested backend
   supports edits. Never fall back to generation after an edit failure.
3. Write the exact prompt to a temporary UTF-8 file using a file-writing tool.
   Keep user text out of shell code. Choose a descriptive `.png` output in the
   current project unless another destination was requested. Do not overwrite.
4. Invoke the installed script in one tool call, safely quoting paths and values:

   ```bash
   bash "$HOME/.config/opencode/commands/image-gen.sh" \
     --model '<image-model-id>' --prompt-file '<prompt-file>' --output '<output.png>'
   ```

   Add `--image '<reference.png>'` and optionally `--mask '<mask.png>'` for edits.
   Add `--size '<WIDTHxHEIGHT>'` only when requested and supported by the backend;
   otherwise the backend chooses dimensions. Use `--config '<config.json>'` for
   a non-default setup location. JSONC is unsupported. Run `--help` for usage.
5. Remove only the temporary prompt file you created, including on failure.
   Report the script's result or sanitized error; never read/display credentials
   or raw API responses. Do not automatically retry timeouts. Use an available
   viewer when the user asks to review the image.

The Bash script handles configuration, private credential files, requests,
PNG header/dimension checks, cleanup, and exclusive output creation. This is a
lightweight format check, not complete image validation. It accepts one
base64 PNG per request; other formats, URL-only responses,
multiple outputs, and provider-specific extras are deliberately unsupported.
