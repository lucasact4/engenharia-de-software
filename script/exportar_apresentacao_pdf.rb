# Exporta /apresentacao em PDF (A4 paisagem) usando o Chrome do serviço Selenium do Dev Container.
#
# Uso, dentro do Dev Container, com o servidor da apresentação rodando na porta 3100:
#   bundle exec ruby script/exportar_apresentacao_pdf.rb [arquivo.pdf]
#
# Variáveis opcionais:
#   APRESENTACAO_URL  URL vista pelo Chrome do Selenium (padrão: http://rails-app:3100/apresentacao?modo=leitura)
#   SELENIUM_REMOTE_URL  definida pelo Dev Container (padrão: http://selenium:4444/wd/hub)
#
# O servidor precisa aceitar o host "rails-app": inicie-o com RAILS_DEVELOPMENT_HOSTS=rails-app.
require "base64"
require "fileutils"
require "selenium-webdriver"

url = ENV.fetch("APRESENTACAO_URL", "http://rails-app:3100/apresentacao?modo=leitura")
output = File.expand_path(ARGV[0] || "tmp/apresentacao/sgu-segunda-entrega.pdf")
FileUtils.mkdir_p(File.dirname(output))

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument("--headless=new")
driver = Selenium::WebDriver.for(:remote, url: ENV.fetch("SELENIUM_REMOTE_URL", "http://selenium:4444/wd/hub"), options: options)

begin
  driver.navigate.to(url)
  wait = Selenium::WebDriver::Wait.new(timeout: 20)
  wait.until do
    driver.execute_script(<<~JS)
      return document.readyState === "complete" &&
        document.querySelector(".apr #s-capa") !== null &&
        document.querySelectorAll(".apr-slide").length > 0 &&
        getComputedStyle(document.documentElement).getPropertyValue("--apr-g-800").trim() !== "";
    JS
  end
  wait.until do
    driver.execute_script(<<~JS)
      return document.fonts.status === "loaded" &&
        [...document.querySelectorAll(".apr-slide img")].every(image =>
          image.complete && image.naturalWidth > 0);
    JS
  end

  # O comando W3C "print" recebe os parâmetros no nível raiz. Driver#print_page (4.47) os aninha
  # em "options" e o Chrome passa a usar o tamanho Carta; por isso a chamada direta ao bridge.
  pdf = driver.send(:bridge).send(:execute, :print_page, {}, {
    orientation: "landscape",
    page: { width: 21.0, height: 29.7 },
    margin: { top: 1.0, bottom: 1.0, left: 1.2, right: 1.2 },
    background: true,
    shrinkToFit: false
  })

  content = Base64.strict_decode64(pdf)
  raise "O Chrome não retornou um PDF válido." unless content.start_with?("%PDF-")

  File.binwrite(output, content)
  puts "PDF gerado: #{output}"
rescue Selenium::WebDriver::Error::TimeoutError
  abort "Exportação cancelada: a apresentação, os estilos ou as imagens não carregaram em #{url}. Verifique o servidor, o host permitido e o Selenium. Nenhum PDF foi gravado."
ensure
  driver.quit
end
