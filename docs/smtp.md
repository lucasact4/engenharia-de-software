# Prévia de e-mails do SGU

O ambiente de desenvolvimento usa [Letter Opener](https://github.com/ryanb/letter_opener) para gerar a prévia em HTML e abri-la no navegador. As mensagens ficam em `tmp/letter_opener` na máquina que executa o envio. Cada prévia de confirmação contém um link temporário de acesso à conta de teste.

1. Na raiz do SGU, execute `bundle install`, `bundle exec rails db:prepare` e `bundle exec rails tailwindcss:build`.
2. Inicie o SGU com `bundle exec rails server -b 127.0.0.1 -p 3000` e o processador de tarefas com `bundle exec ruby bin/jobs` em outro terminal.
3. Entre com uma conta de teste e clique em **Reenviar confirmação de e-mail** no perfil. Abra a prévia da mensagem no navegador, siga o link e clique em **Confirmar e-mail**.
4. Na central de notificações, habilite avisos por e-mail. Com uma conta administrativa, altere o status de uma ocorrência da conta de teste e confira a prévia de **SGU UFRPE · Nova notificação**.

Em uma máquina sem navegador, use `LAUNCHY_DRY_RUN=true` e abra o HTML em `tmp/letter_opener` manualmente. Para processar notificações pendentes em uma sessão local sem o processo de tarefas, execute `DeliverNotificationsJob.perform_now` no console Rails.

O Letter Opener funciona em desenvolvimento e mantém as mensagens locais. A entrega a caixas postais reais continua disponível em produção com um provedor SMTP autorizado, por meio de `SGU_SMTP_ADDRESS`, `SGU_SMTP_PORT`, `SGU_SMTP_USERNAME`, `SGU_SMTP_PASSWORD` e `SGU_NOTIFICATION_FROM`. O SMTP de produção exige STARTTLS.
