require "base64"
require "nokogiri"
require "selenium-webdriver"

class Presentation::Pdf
  class Error < StandardError; end
  class Busy < Error; end

  # Reject overlapping exports instead of consuming all Puma threads or queuing
  # unbounded Chromium sessions on the shared Selenium service.
  LOCK = Mutex.new
  PAGE_OPTIONS = {
    orientation: "landscape", page: { width: 21.0, height: 29.7 },
    margin: { top: 1.0, bottom: 1.0, left: 1.2, right: 1.2 },
    background: true, shrinkToFit: false
  }.freeze

  def initialize(html:, theme: nil, public_url:)
    @html = html
    @theme = theme == "light" ? "light" : "dark"
    @public_url = public_url
  end

  def call
    raise Busy unless LOCK.try_lock

    begin
      driver = browser
      driver.navigate.to("about:blank")
      # A self-contained document needs no public tunnel, second Rails request,
      # cookies, user-supplied URL, or network fetches from the renderer.
      driver.execute_script("document.open(); document.write(arguments[0]); document.close();", document)
      driver.execute_cdp("Emulation.setEmulatedMedia", media: "print")
      Selenium::WebDriver::Wait.new(timeout: 20).until do
        driver.execute_script(<<~JS)
          return document.fonts.status === "loaded" &&
            [...document.images].every(image => image.complete && image.naturalWidth > 0);
        JS
      end
      fit_slides(driver)

      # Selenium 4.47's public print_page wrapper nests the W3C options; send
      # them at the protocol's root so Chromium respects A4 and our margins.
      encoded = driver.send(:bridge).send(:execute, :print_page, {}, PAGE_OPTIONS)
      content = Base64.strict_decode64(encoded)
      raise Error, "Chromium returned an invalid PDF" unless content.start_with?("%PDF-")

      content
    rescue Selenium::WebDriver::Error::WebDriverError, Timeout::Error, ArgumentError, IOError, SystemCallError => error
      raise Error, error.message
    ensure
      begin
        driver&.quit
      rescue Selenium::WebDriver::Error::WebDriverError, Timeout::Error, IOError, SystemCallError
        # A disconnected renderer must not prevent the export lock being released.
      ensure
        LOCK.unlock
      end
    end
  end

  private

  def browser
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1440,1000")
    http = Selenium::WebDriver::Remote::Http::Default.new(open_timeout: 10, read_timeout: 45)
    if ENV["SELENIUM_REMOTE_URL"].present?
      Selenium::WebDriver.for(:remote, url: ENV.fetch("SELENIUM_REMOTE_URL"), options: options, http_client: http)
    else
      Selenium::WebDriver.for(:chrome, options: options, http_client: http)
    end
  end

  def document
    doc = Nokogiri::HTML(@html)
    doc.at_css("html")["data-theme"] = @theme
    doc.at_css("body")["class"] = "#{doc.at_css('body')['class']} apr-pdf"
    doc.css("script, link, meta[http-equiv], [hidden], .apr-bar, .apr-nav, .apr-toc, .apr-skip, dialog, .apr-share-rail, .apr-sr-only").remove
    doc.css(@theme == "light" ? ".apr-theme-only--dark" : ".apr-theme-only--light").remove
    add_access_page(doc)
    style = Nokogiri::XML::Node.new("style", doc)
    style.content = stylesheet("theme.css") + stylesheet("presentation.css")
    doc.at_css("head").add_child(style)
    doc.css("img[src]").each do |image|
      path = URI.parse(image["src"]).path
      raise Error, "Non-asset image in presentation" unless path.start_with?("/assets/")

      logical, = Propshaft::Asset.extract_path_and_digest(path.delete_prefix("/assets/"))
      asset = Rails.application.assets.load_path.find(logical)
      raise Error, "Missing presentation image: #{logical}" unless asset

      image["src"] = "data:#{asset.content_type};base64,#{Base64.strict_encode64(asset.content)}"
      image.remove_attribute("srcset")
      image.remove_attribute("loading")
    end
    doc.css("a[href^='/']").each do |link|
      link["href"] = URI.join(@public_url, link["href"]).to_s
    end
    # Only the server's rendered catalog is used, never HTML from the request.
    doc.to_html
  end

  def add_access_page(doc)
    qr = doc.at_css("#s-capa .apr-access img")
    raise Error, "Missing presentation QR code" unless qr

    page = Nokogiri::XML::Node.new("section", doc)
    page["class"] = "apr-pdf-access"
    page["aria-label"] = "Acesse a apresentação"
    link = Nokogiri::XML::Node.new("a", doc)
    link["href"] = @public_url
    link["class"] = "apr-pdf-access__code"
    link.add_child(qr.dup)
    page.add_child(link)
    heading = Nokogiri::XML::Node.new("h1", doc)
    heading.content = "Acompanhe a apresentação"
    page.add_child(heading)
    address = Nokogiri::XML::Node.new("a", doc)
    address["href"] = @public_url
    address.content = @public_url.split("#").first
    page.add_child(address)
    doc.at_css(".apr-slide").add_previous_sibling(page)
  end

  def stylesheet(path)
    asset = Rails.application.assets.load_path.find(path)
    raise Error, "Missing presentation stylesheet: #{path}" unless asset

    asset.content(encoding: "UTF-8").gsub(/@import\s+url\(["']([^"']+)["']\);/) do
      stylesheet(Pathname.new(File.join(File.dirname(path), Regexp.last_match(1))).cleanpath.to_s)
    end
  end

  def fit_slides(driver)
    overflow = driver.execute_script(<<~JS)
      return [...document.querySelectorAll(".apr-slide")].filter(slide => {
        const inner = slide.querySelector(".apr-slide__inner");
        const style = getComputedStyle(slide);
        const available = slide.clientHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom) - 2;
        const fits = () => inner.getBoundingClientRect().height <= available && inner.scrollWidth <= inner.clientWidth + 1;
        // Measure at the physical print width, then grow each main slide to fit.
        // Appendices keep their separate diagram layout and existing typography.
        if (slide.dataset.appendix !== "true") {
          let low = 10.5, high = 20;
          for (let attempt = 0; attempt < 12; attempt++) {
            const size = (low + high) / 2;
            slide.style.setProperty("--apr-pdf-font", `${size}pt`);
            if (fits()) low = size; else high = size;
          }
          slide.style.setProperty("--apr-pdf-font", `${low}pt`);
        }
        let scale = 1;
        for (let attempt = 0; attempt < 16; attempt++) {
          inner.style.setProperty("--apr-pdf-scale", scale);
          if (fits()) return false;
          const height = inner.getBoundingClientRect().height;
          scale *= Math.min(0.98, available / height * 0.99);
        }
        return true;
      }).map(slide => slide.id);
    JS
    raise Error, "Slides overflow printable area: #{overflow.join(', ')}" if overflow.any?
  end
end
