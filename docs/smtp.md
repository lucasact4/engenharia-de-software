# E-mail do SGU em outra máquina

Use o Mailpit para conferir o envio do SGU em desenvolvimento. Ele recebe mensagens por SMTP e mostra o conteúdo em uma caixa de entrada local. Para entregar mensagens ao Gmail ou a outros destinatários externos, configure um provedor autorizado conforme a segunda seção.

## Teste local com Mailpit

1. Baixe o binário para seu sistema operacional na página de versões e extraia o arquivo. [Versões oficiais do Mailpit](https://github.com/axllent/mailpit/releases)
2. No terminal, inicie o Mailpit com o SMTP e a caixa de entrada acessíveis somente nesta máquina. No Linux e no macOS, execute `./mailpit` com os mesmos parâmetros. [Opções do Mailpit](https://mailpit.axllent.org/docs/configuration/runtime-options/)

   ```powershell
   .\mailpit.exe --smtp 127.0.0.1:1025 --listen 127.0.0.1:8025
   ```

3. Na raiz do SGU, configure o servidor web e o processo de tarefas com as mesmas variáveis. Use um perfil local de desenvolvimento e deixe `SGU_SMTP_USERNAME` e `SGU_SMTP_PASSWORD` sem valor.

   **PowerShell**

   ```powershell
   $env:RAILS_ENV = 'development'
   $env:SGU_SMTP_ADDRESS = '127.0.0.1'
   $env:SGU_SMTP_PORT = '1025'
   $env:SGU_SMTP_STARTTLS = 'false'
   $env:SGU_NOTIFICATION_FROM = 'notifications@example.test'
   ```

   **Bash**

   ```bash
   export RAILS_ENV=development
   export SGU_SMTP_ADDRESS=127.0.0.1
   export SGU_SMTP_PORT=1025
   export SGU_SMTP_STARTTLS=false
   export SGU_NOTIFICATION_FROM=notifications@example.test
   ```

4. Em uma instalação nova, execute `bundle install`, `bundle exec rails db:prepare` e `bundle exec rails tailwindcss:build`. Inicie o SGU com `bundle exec rails server -b 127.0.0.1 -p 3000`. Em outro terminal com as mesmas variáveis, inicie o processador de tarefas com `bundle exec ruby bin/jobs`. O comando `bin/dev`, em um ambiente compatível, já inicia o servidor e o processador juntos.
5. Entre com a conta de teste e, no perfil, clique em **Reenviar confirmação de e-mail**. Abra a mensagem **SGU UFRPE · Confirme seu e-mail** no [Mailpit local](http://127.0.0.1:8025), siga o link e clique em **Confirmar e-mail**. O link local abre o SGU na porta 3000 e expira em 24 horas.
6. Na conta de teste, abra **Notificações → Preferências de entrega** e ative as atualizações por e-mail. Crie uma ocorrência pela conta de teste, entre com uma conta administrativa e mude o status dessa ocorrência. Confira a mensagem **SGU UFRPE · Nova notificação** no Mailpit. O processamento periódico ocorre a cada 15 segundos.

`SGU_SMTP_STARTTLS=false` só tem efeito no ambiente de desenvolvimento com endereço SMTP `127.0.0.1` ou `::1`. Se o SGU estiver em outro endereço de teste, configure `SGU_MAILER_HOST` com o nome acessível ao navegador, incluindo a porta se necessário e sem o esquema. Defina `SGU_MAILER_HTTPS=true` se esse endereço usar HTTPS.

Para executar os dois envios manualmente em desenvolvimento quando o processador de tarefas estiver indisponível, inicie o console com `bundle exec rails console`, usando as mesmas variáveis SMTP. Para gerar a confirmação de uma conta de teste ainda pendente, use `NotificationMailer.confirm_email(User.find_by!(email_address: "visitante@example.test")).deliver_now!` com o endereço cadastrado. Após confirmar o endereço, ativar os avisos e mudar o status da ocorrência, execute `DeliverNotificationsJob.perform_now` para processar as entregas pendentes.

## Entrega real em produção

1. Solicite ao provedor SMTP o servidor, a porta com STARTTLS, o usuário, a senha e um endereço remetente autorizado. Se usar um domínio próprio, publique os registros SPF e DKIM fornecidos pelo provedor e configure a política DMARC desse domínio. Se o provedor estiver em modo de testes, libere também o destinatário de teste.
2. Configure as variáveis abaixo no servidor web e no processador de tarefas, usando o cofre de segredos da implantação para as credenciais.

   | Variável | Valor |
   | --- | --- |
   | `RAILS_ENV` | `production` |
   | `APP_HOST` | Nome público do SGU, por exemplo `sgu.exemplo.edu.br`, sem `https://` |
   | `SGU_SMTP_ADDRESS` | Nome do servidor SMTP fornecido pelo provedor |
   | `SGU_SMTP_PORT` | Porta de envio com STARTTLS, normalmente `587` |
   | `SGU_SMTP_USERNAME` | Usuário de SMTP fornecido pelo provedor |
   | `SGU_SMTP_PASSWORD` | Senha ou token de SMTP armazenado no cofre |
   | `SGU_NOTIFICATION_FROM` | Endereço remetente autorizado no provedor |
   | `SGU_SMTP_STARTTLS` | Deixe sem valor para usar o padrão seguro de produção |
   | `SGU_MAILER_HOST` | Opcional. Substitui `APP_HOST` nos links dos e-mails e aceita uma porta. Informe o valor sem `https://`. |

3. Aplique as migrações e reinicie o servidor web e o processador. O SGU precisa estar acessível por HTTPS pelo endereço em `APP_HOST` para abrir os links em outros dispositivos.
4. Repita o teste de confirmação e mudança de status usando uma conta de homologação e confira as duas mensagens na caixa postal real. Se a mensagem não aparecer, confira a pasta de spam e os eventos de entrega do provedor. Se o SGU não tentar o envio, confira o endereço confirmado, o consentimento na central de notificações e o processo de tarefas.

Veja a descrição do fluxo de filas e dos demais canais no [guia de notificações do SGU](notifications.md).
