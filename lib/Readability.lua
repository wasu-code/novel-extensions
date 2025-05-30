-- {"ver":"1.0.27","author":"wasu-code","dep":[]}

--- Readability Library
-- This library processes an HTML document using Mozilla's Readability.js.
-- @module Readability

local Readability = {}

--- Processes the given HTML document.
-- Removes unnecessary elements and prepares the document for readability parsing.
-- @param doc The HTML document to process.
-- @param threshold (optional) Character threshold to consider as a chapter (default: 1500)
-- @param proxyURL (optional) URL of CORS proxy server (default: "https://api.allorigins.win/raw?url=")
--        This proxyURL is used to bypass CORS issues when fetching content from other domains. 
function Readability.parse(doc, threshold, proxyURL)
  threshold = threshold or 1500
  proxyURL = proxyURL or "https://api.allorigins.win/raw?url="

  -- Remove <script>, <style>, and <head> elements
  doc:select("script"):remove()
  doc:select("style"):remove()
  doc:select("head"):remove()
  doc:select("link"):remove()

  local webpage = doc:selectFirst("body")

  -- Create element to hold content of parsed article
  local container = doc:createElement("div")
  local content = doc:createElement("div")
  content:attr("id", "shosetsu-content")
  content:append(webpage)
  container:append(content)

  -- JavaScript code to process the document using Readability
  local script = ([[
    var styleBackup = []; /*backup shosetsu and user stylesheets*/
    document.querySelectorAll("style").forEach(function(style) {
      styleBackup.push(style.outerHTML);
    });

    // Parse current webpage
    var article = new Readability(document, {
      keepClasses: true
    }).parse();

    function setArticle(content) {
      document.querySelector("#shosetsu-content").innerHTML = content;
    }

    if (article.length > %d) {
      // If longer than threshold it's probably a chapter
      setArticle(article.content)
    } else {
      // Button to force parse anyway
      const banner = document.createElement("div");
      banner.id = "shosetsu-banner";
      banner.style = `
        background: #fffbcc;
        color: #333;
        box-sizing: border-box;
        padding: 20px;
        margin: 10px auto 20px auto;
        border: 0.2em dashed black;
      `;
      banner.innerHTML = `
        <span>Page probably doesn't contain full chapter. Click on chapter link or</span>
        <button id="shosetsu-parse-btn">Parse anyway</button>
      `;
      document.body.prepend(banner);
      document.getElementById("shosetsu-parse-btn").onclick = () => setArticle(article.content);

      // Intercept clicked link and parse url
      document.addEventListener("click", function(e) {
        const link = e.target.closest("a");
        if (!link || link.hasAttribute("download") || link.href.startsWith("javascript:")) {
          return;
        }

        e.preventDefault();

        fetch("%s"+link.href)
          .then(response => {
            if (!response.ok) alert("Network response was not ok");
            return response.text();
          })
          .then(htmlText => {
            const parser = new DOMParser();
            const doc = parser.parseFromString(htmlText, "text/html");

            const article = new Readability(doc, { keepClasses: true }).parse();
            if (article && article.content) {
              setArticle(article.content);
            } else {
              alert("Failed to extract article content.");
            }
          })
          .catch(err => {
            console.error("Fetch or parse error:", err);
            alert("Error loading article.");
          });
      });
    }
    
    styleBackup.forEach(function(style) {
      document.head.insertAdjacentHTML("beforeend", style);
    });
  ]]):format(threshold, proxyURL)

  -- Append the Readability library and the script to the <body>
  container:append('<script src="https://cdnjs.cloudflare.com/ajax/libs/readability/0.6.0/Readability.min.js" integrity="sha512-gUyZHlv5aSSuW4HZmQxiuWLagqsiddDmftdPnfgjzjfGlbYnK+Ukam3TAAqKnZ3JXdsaFEwx8o9HGRaj6++ZnA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>')
  container:append('<script>' .. script .. '</script>')

  return container
end

return Readability