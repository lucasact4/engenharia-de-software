# Turnstile para publicações anônimas

A opção de ocultar a identidade no mural fica disponível quando o projeto recebe as duas variáveis:

- TURNSTILE_SITE_KEY: chave pública exibida no formulário.
- TURNSTILE_SECRET_KEY: segredo usado apenas pelo servidor para validar o token no Siteverify.

Configure chaves diferentes para desenvolvimento, homologação e produção no painel da Cloudflare. Em produção, restrinja o widget aos domínios do projeto. O segredo nunca deve ser colocado no JavaScript, no repositório ou em logs.

A publicação continua vinculada à conta autenticada para atendimento e auditoria. O mapa e o mural não recebem o ID, avatar, nome de perfil ou selo de verificação da pessoa quando ela seleciona a opção anônima. Sem as chaves, a publicação autenticada normal continua disponível e a opção de anonimato fica desativada.