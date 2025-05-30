-- {"ver":"1.1.0","author":"wasu-code","dep":[]}

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

  local bodyElement = doc:selectFirst("body") -- body of original document

  -- Create element to hold content of parsed article
  local outerContainer = doc:createElement("div")
  local contentContainer = doc:createElement("div")
  contentContainer:attr("id", "shosetsu-content")
  contentContainer:append(bodyElement)
  outerContainer:append(contentContainer)

  -- JavaScript code to process the document using Readability
  local readabilityScript = ([[
    const STYLE_BANNER_ID = "shosetsu-banner";
    const STYLE_CONTENT_ID = "shosetsu-content";
    const STYLE_PARSE_BTN_ID = "shosetsu-parse-btn";
    const CHARACTER_THRESHOLD = %d;
    const PROXY_URL = "%s";

    // Backup styles (shosetsu and user stylesheets)
    const styleBackup = [];
    document.querySelectorAll("style").forEach(style => {
      styleBackup.push(style.outerHTML);
    });

    // Inject loading bar styles
    (() => {
      const style = document.createElement('style');
      style.textContent = `
        .loading-bar {
          position: fixed;
          top: 0;
          left: 0;
          width: 100%%;
          height: 3px;
          background: transparent;
          overflow: hidden;
          z-index: 9999;
          display: none;
        }
        .loading-bar::before {
          content: "";
          display: block;
          height: 100%%;
          width: 30%%;
          background: #3498db;
          animation: loading 2.5s linear infinite;
        }
        @keyframes loading {
          0%%   { transform: translateX(-100%%); }
          100%% { transform: translateX(300%%); }
        }
      `;
      document.head.appendChild(style);
    })();

    function setArticle(content) {
      document.getElementById(STYLE_CONTENT_ID).innerHTML = content;
    }

    function showLoadingBar() {
      const bar = document.getElementById('loadingBar');
      if (bar) bar.style.display = 'block';
    }

    function hideLoadingBar() {
      const bar = document.getElementById('loadingBar');
      if (bar) bar.style.display = 'none';
    }

    function showBanner() {
      if (!document.getElementById(STYLE_BANNER_ID)) {
        const banner = document.createElement("div");
        banner.id = STYLE_BANNER_ID;
        banner.style = `
          background: #fffbcc;
          color: #333;
          box-sizing: border-box;
          padding: 20px;
          margin: 10px auto 20px auto;
          border: 0.2em dashed black;
          position: relative;
        `;
        banner.innerHTML = `
          <div class="loading-bar" id="loadingBar"></div>
          <span>It seems a little short for a chapter... Find and click the chapter link or... </span>
          <button id="` + STYLE_PARSE_BTN_ID + `">Parse anyway</button>
        `;
        document.body.prepend(banner);
        document.getElementById(STYLE_PARSE_BTN_ID).onclick = () => setArticle(article.content);
      }
    }

    function hideBanner() {
      const banner = document.getElementById(STYLE_BANNER_ID);
      if (banner) banner.remove();
    }

    // Parse current webpage
    const article = new Readability(document, { keepClasses: true }).parse();

    if (article.content && article.content.length > CHARACTER_THRESHOLD) {
      // If longer than threshold it's probably a chapter
      setArticle(article.content);
    } else {
      showBanner();

      // Intercept clicked link and parse url
      document.addEventListener("click", function(e) {
        const link = e.target.closest("a");
        if (!link || link.hasAttribute("download") || link.href.startsWith("javascript:")) return;

        e.preventDefault();
        showLoadingBar();

        fetch(PROXY_URL + link.href)
          .then(response => {
            if (!response.ok) alert("Network response was not ok");
            return response.text();
          })
          .then(htmlText => {
            const parser = new DOMParser();
            const doc = parser.parseFromString(htmlText, "text/html");
            const newArticle = new Readability(doc, { keepClasses: true }).parse();
            if (newArticle && newArticle.content) {
              setArticle(newArticle.content);
              if (newArticle.content.length > CHARACTER_THRESHOLD) hideBanner();
            } else {
              alert("Failed to extract article content.");
            }
          })
          .catch(err => {
            console.error("Fetch or parse error:", err);
            alert("Error loading article.");
          })
          .finally(()=>{ hideLoadingBar(); });
      });
    }

    // Restore backed-up styles
    styleBackup.forEach(style => {
      document.head.insertAdjacentHTML("beforeend", style);
    });
  ]]):format(threshold, proxyURL)

  -- Append the Readability library and the script to the <body>
  outerContainer:append('<script src="https://cdnjs.cloudflare.com/ajax/libs/readability/0.6.0/Readability.min.js" integrity="sha512-gUyZHlv5aSSuW4HZmQxiuWLagqsiddDmftdPnfgjzjfGlbYnK+Ukam3TAAqKnZ3JXdsaFEwx8o9HGRaj6++ZnA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>')
  outerContainer:append('<script>' .. readabilityScript .. '</script>')

  return outerContainer
end

return Readability