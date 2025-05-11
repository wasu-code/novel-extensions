-- {"ver":"0.0.2","author":"wasu-code","dep":[]}

--- Readability Library
-- This library processes an HTML document using Mozilla's Readability.js.
-- @module Readability

local Readability = {}

--- Processes the given HTML document.
-- Removes unnecessary elements and prepares the document for readability parsing.
-- @param doc The HTML document to process.
function Readability.parse(doc)
  -- Remove <script>, <style>, and <head> elements
  doc:select("script"):remove()
  doc:select("style"):remove()
  doc:select("head"):remove()

  -- Select the <body> element and set its ID
  local body = doc:selectFirst("body")
  body:attr("id", "shosetsu-content")

  -- JavaScript code to process the document using Readability
  local script = [[
    var styleBackup = []; /*backup shosetsu and user stylesheets*/
    document.querySelectorAll("style").forEach(function(style) {
      styleBackup.push(style.outerHTML);
    });

    var article = new Readability(document, {
      keepClasses: true
    }).parse();
    document.getElementById("shosetsu-content").innerHTML = article.content;

    styleBackup.forEach(function(style) {
      document.head.insertAdjacentHTML("beforeend", style);
    });
  ]]

  -- Append the Readability library and the script to the <body>
  body:append('<script src="https://cdnjs.cloudflare.com/ajax/libs/readability/0.6.0/Readability.min.js" integrity="sha512-gUyZHlv5aSSuW4HZmQxiuWLagqsiddDmftdPnfgjzjfGlbYnK+Ukam3TAAqKnZ3JXdsaFEwx8o9HGRaj6++ZnA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>')
  body:append('<script>' .. script .. '</script>')

  return doc
end

return Readability