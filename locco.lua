#!/usr/bin/env lua
-- __Locco__ is a Lua port of [Docco](http://jashkenas.github.com/docco/),
-- the quick-and-dirty, hundred-line-long, literate-programming-style
-- documentation generator. It produces HTML that displays your comments
-- alongside your code. Comments are passed through
-- [Markdown](http://daringfireball.net/projects/markdown/), and code is
-- syntax highlighted.
-- This page is the result of running Locco against its own source file:
--     locco.lua locco.lua
--
-- For its syntax highlighting Locco relies on the help of
-- [David Manura](http://lua-users.org/wiki/DavidManura)'s
-- [Lua Balanced](https://github.com/davidm/lua-balanced) to split
-- up the code. As a markdown engine it ships with
-- [Niklas Frykholm](http://www.frykholm.se/)'s
-- [markdown.lua](http://www.frykholm.se/files/markdown.lua) in the [Lua 5.2
-- compatible version](https://github.com/speedata/luamarkdown) from
-- [Patrick Gundlach](https://github.com/pgundlach). Otherwise there
-- are no external dependencies.
--
-- The generated HTML documentation for the given source files is saved
-- into a `docs` directory. If you have Locco on your path you can run it from
-- the command-line:
--     locco.lua project/*.lua
--
-- Locco is monolingual, but there are many projects written in
-- and with support for other languages, see the
-- [Docco](http://jashkenas.github.com/docco/) page for a list.<br>
-- The [source for Locco](https://github.com/rgieseke/locco) is available on
-- GitHub, and released under the MIT
-- license.

-- ### Setup & Helpers

-- Load markdown.lua.
local md = require('locco.markdown')
-- Load Lua Balanced.
local lb = require('locco.luabalanced')
-- Load HTML templates.
local template = require('locco.template')

-- Insert HTML entities in a string.<br>
-- Parameter:<br>
-- _s_: String to escape.<br>
local function escape(s)
  s = s:gsub('&', '&amp;')
  s = s:gsub('<', '&lt;')
  s = s:gsub('>', '&gt;')
  s = s:gsub('%%', '&#37;')
  return s
end

--local function replace_percent(s)
--  s = s:gsub('%%', '%%%%')
--  return s
--end

-- Define the Lua keywords, built-in functions and operators that should
-- be highlighted.
local keywords = { 'break', 'do', 'else', 'elseif', 'end', 'false', 'for',
                   'function', 'if', 'in', 'local', 'nil', 'repeat', 'return',
                   'then', 'true', 'until', 'while' }
local functions = { 'assert', 'collectgarbage', 'dofile', 'error', 'getfenv',
                    'getmetatable', 'ipairs', 'load', 'loadfile', 'loadstring',
                    'module', 'next', 'pairs', 'pcall', 'print', 'rawequal',
                    'rawget', 'rawset', 'require', 'setfenv', 'setmetatable',
                    'tonumber', 'tostring', 'type', 'unpack', 'xpcall' }
local operators = { 'and', 'not', 'or' }

-- Wrap an item from a list of Lua keywords in a span template or return the
-- unchanged item.<br>
-- Parameters:<br>
-- _item_: An item of a code snippet.<br>
-- _item\_list_: List of keywords or functions.<br>
-- _span\_class_: Style sheet class.<br>
local function wrap_in_span(item, item_list, span_class)
  for i=1, #item_list do
    if item_list[i] == item then
      item = '<span class="'..span_class..'">'..item..'</span>'
      break
    end
  end
  return item
end

-- Quick and dirty source code highlighting. A chunk of code is split into
-- comments (at the end of a line), strings and code using the
-- [Lua Balanced](https://github.com/davidm/lua-balanced/blob/master/luabalanced.lua)
-- module. The code is then split again and matched against lists
-- of Lua keywords, functions or operators. All Lua items are wrapped into
-- a span having one of the classes defined in the Locco style sheet.<br>
-- Parameter:<br>
-- _code_: Chunk of code to highlight.<br>
local function highlight_lua(code)
  local out = lb.gsub(code,
    function(u, s)
      local sout
      if u == 'c' then -- Comments.
        sout = '<span class="c">'..escape(s)..'</span>'
      elseif u == 's' then -- Strings.
        sout = '<span class="s">'..escape(s)..'</span>'
      elseif u == 'e' then -- Code.
        s = escape(s)
        -- First highlight function names.
        s = s:gsub('function ([%w_:%.]+)', 'function <span class="nf">%1</span>')
        -- There might be a non-keyword at the beginning of the snippet.
        sout = s:match('^(%A+)') or ''
        -- Iterate through Lua items and try to wrap operators,
        -- keywords and built-in functions in span elements.
        -- If nothing was highlighted go to the next category.
        for item, sep in s:gmatch('([%a_]+)(%A+)') do
          local span, n = wrap_in_span(item, operators, 'o')
          if span == item then
            span, n = wrap_in_span(item, keywords, 'k')
          end
          if span == item then
            span, n = wrap_in_span(item, functions, 'nt')
          end
          sout = sout..span..sep
        end
      end
      return sout
    end)
    out = '<div class="highlight"><pre>'..out..'</pre></div>'
  return out
end


-- ### Main Documentation Generation Functions

-- Given a string of source code, parse out each comment and the code that
-- follows it, and create an individual section for it. Sections take the form:
--
--     {
--       docs_text = ...,
--       docs_html = ...,
--       code_text = ...,
--       code_html = ...,
--     }
--
-- Parameter:<br>
-- _source_: The source file to process.<br>
local function parse(source)
  local sections = {}
  local has_code = false
  local docs_text, code_text = '', ''
  for line in io.lines(source) do
    if line:match('^%s*%-%-') then
      if has_code then
        code_text = code_text:gsub('\n\n$', '\n') -- remove empty trailing line
        sections[#sections + 1] = { ['docs_text'] = docs_text,
                                    ['code_text'] = code_text }
        has_code = false
        docs_text, code_text = '', ''
      end
      docs_text = docs_text..line:gsub('%s*(%-%-%s?)', '', 1)..'\n'
    else
      if not line:match('^#!') then -- ignore #!/usr/bin/lua
        has_code = true
        code_text = code_text..line..'\n'
      end
    end
  end
  sections[#sections + 1] = { ['docs_text'] = docs_text,
                              ['code_text'] = code_text }
  return sections
end

local function cleanup(docs_text)
  return docs_text:gsub('^%(c%)([^\r\n]*)', '&copy;%1<br>')
    :gsub('\n%(c%)([^\r\n]*)', '\n&copy;%1<br>')
    :gsub('\n@param%s+(%w+)%s+([^\r\n]*)', '\n- _%1_: %2')
    :gsub('\n@return%s+([^\r\n]*)', '\n- return: %1')
end

-- Loop through a table of split sections and convert the documentation
-- from Markdown to HTML and pass the code through Locco's syntax
-- highlighting. Add  _docs\_html_ and _code\_html_ elements to the sections
-- table.<br>
-- Parameter:<br>
-- _sections_: A table with split sections.<br>
local function highlight(sections)
  for i=1, #sections do
    sections[i]['docs_html'] = md(cleanup(sections[i]['docs_text'])):gsub('%%', '&#37;')
    sections[i]['code_html'] = highlight_lua(sections[i]['code_text'])
  end
  return sections
end

-- After the highlighting is done, the template is filled with the documentation
-- and code snippets and an HTML file is written.<br>
-- Parameters:<br>
-- _source_: The source file.<br>
-- _path_: Path of the source file.<br>
-- _filename_: The filename of the source file.<br>
-- _sections_: A table with the original sections and rendered as HTML.<br>
-- _jump\_to_: A HTML chunk with links to other documentation files.
local function generate_html(source, path, filename, sections, jump_to)
  local f, err = io.open(path..'/'..'docs/'..filename:gsub('lua$', 'html'), 'wb')
  if err then print(err) end
  local h = template.header:gsub('%%title%%', filename)
  h = h:gsub('%%jump%%', jump_to)
  f:write(h)
  for i=1, #sections do
    local t = template.table_entry:gsub('%%index%%', i..'')
    t = t:gsub('%%docs_html%%', sections[i]['docs_html'])
    t = t:gsub('%%code_html%%', sections[i]['code_html'])
    f:write(t)
  end
  f:write(template.footer)
  f:close()
end

-- Generate the documentation for a source file by reading it in,
-- splitting it up into comment/code sections, highlighting and merging
-- them into an HTML template.<br>
-- Parameters:<br>
-- _source_: The source file to process.<br>
-- _path_: Path of the source file.<br>
-- _filename_: The filename of the source file.<br>
-- _jump\_to_: A HTML chunk with links to other documentation files.
local function generate_documentation(source, path, filename, jump_to)
  local sections = parse(source)
  sections = highlight(sections)
  generate_html(source, path, filename, sections, jump_to)
end

return {
  generate_documentation = generate_documentation
}
