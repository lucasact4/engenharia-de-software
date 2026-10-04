# Captura as telas do slide "Protótipo com o conceito visual do projeto" nos temas escuro e claro.
# Usa o Chrome do serviço Selenium do Dev Container e a mesma preferência de tema do sistema
# (localStorage "sgu.theme"); nenhuma imagem é editada ou filtrada depois da captura.
#
# Uso, dentro do Dev Container, com um servidor acessível pelo Selenium (ver LEIAME.md):
#   RAILS_DEVELOPMENT_HOSTS=rails-app bin/rails server -b 0.0.0.0 -p 3100 -P tmp/pids/apresentacao-3100.pid
#   bundle exec ruby script/capturar_conceito_visual.rb [pasta-de-saida]
#
# Saída padrão: tmp/conceito_visual/. Revise as imagens antes de copiá-las para
# app/assets/images/presentation/ e atualize capturado_em em config/presentation/conceito_visual.yml.
#
# Variáveis opcionais:
#   CAPTURA_URL          raiz do SGU vista pelo Selenium (padrão: http://rails-app:3100)
#   SELENIUM_REMOTE_URL  definida pelo Dev Container (padrão: http://selenium:4444/wd/hub)
require "fileutils"
require "selenium-webdriver"

BASE_URL = ENV.fetch("CAPTURA_URL", "http://rails-app:3100")
OUTPUT = File.expand_path(ARGV[0] || "tmp/conceito_visual")

# nome do arquivo => [rota, largura, altura, página inteira?]
SHOTS = {
  "landing-desktop" => [ "/", 1440, 1000, false ],
  "landing-completa" => [ "/", 1440, 1000, true ],
  "landing-mobile" => [ "/", 390, 844, false ],
  "entrar-desktop" => [ "/entrar", 1440, 1000, false ]
}.freeze
THEMES = { "dark" => "", "light" => "-claro" }.freeze

def resize_viewport(driver, width, height)
  driver.manage.window.resize_to(width, height)
  inner_width, inner_height = driver.execute_script("return [innerWidth, innerHeight]")
  driver.manage.window.resize_to(width + (width - inner_width), height + (height - inner_height))
end

def wait_for_page(driver)
  Selenium::WebDriver::Wait.new(timeout: 20).until do
    driver.execute_script(<<~JS)
      return document.readyState === "complete" && document.fonts.status === "loaded" &&
        [...document.images].filter(image => image.getClientRects().length > 0)
          .every(image => image.complete && image.naturalWidth > 0) &&
        document.documentElement.scrollWidth <= innerWidth;
    JS
  end
  sleep 0.4 # transições de entrada
end

FileUtils.mkdir_p(OUTPUT)
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--headless=new")
options.add_argument("--hide-scrollbars")
driver = Selenium::WebDriver.for(:remote, url: ENV.fetch("SELENIUM_REMOTE_URL", "http://selenium:4444/wd/hub"), options: options)

begin
  THEMES.each do |theme, suffix|
    driver.navigate.to(BASE_URL)
    driver.execute_script("localStorage.setItem('sgu.theme', arguments[0])", theme)

    SHOTS.each do |name, (path, width, height, full_page)|
      resize_viewport(driver, width, height)
      driver.navigate.to("#{BASE_URL}#{path}")
      wait_for_page(driver)
      applied = driver.execute_script("return document.documentElement.dataset.theme")
      raise "Tema #{theme} não aplicado em #{path} (#{applied})." unless applied == theme

      if full_page
        resize_viewport(driver, width, driver.execute_script("return document.documentElement.scrollHeight"))
        wait_for_page(driver)
      end
      file = File.join(OUTPUT, "#{name}#{suffix}.png")
      driver.save_screenshot(file)
      puts "#{file} (#{theme}, #{width}px, #{path})"
    end
  end
rescue Selenium::WebDriver::Error::TimeoutError
  abort "Captura cancelada: a página não terminou de carregar em #{BASE_URL}. Verifique o servidor, o host permitido e o Selenium."
ensure
  driver.quit
end
