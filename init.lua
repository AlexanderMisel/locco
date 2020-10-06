local locco = require('locco.locco')
local template = require('locco.template')

-- Ensure the `docs` directory exists and return the _path_ of the source file.<br>
-- Parameter:<br>
-- _source_: The source file for which documentation is generated.<br>
local function ensure_directory(path)
  if not path then path = '.' end
  os.execute('mkdir -p '..path..'/docs')
end

-- Make sure the output directory exists, generate the HTML files for each
-- source file, print what's happening and write the style sheet.
keys['ctrl+alt+d'] = function()
  local full = buffer.filename
  local path, filename = full:match('(.+)/(.+)$')
  ensure_directory(path)
  locco.generate_documentation(full, path, filename, '')

  local f, err = io.open(path..'/'..'docs/locco.css', 'wb')
  if err then ui.print(err) end
  f:write(template.css)
  f:close()
end
