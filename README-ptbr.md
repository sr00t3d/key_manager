# Key Manager 🔑 - Enterprise Audit Edition

Readme: [EN](README.md)

![Shell Script](https://img.shields.io/badge/shell-script-green) ![Security Audited](https://img.shields.io/badge/security-audited-blue)

O **Key Manager** é uma ferramenta utilitária avançada desenvolvida em Shell Script para simplificar, automatizar e auditar a gestão de chaves SSH em ambientes Linux. 

Diferente de scripts de deploy comuns, esta ferramenta foi desenhada com foco em **Cybersecurity** e **Rastreabilidade**, resolvendo o "problema do ovo e da galinha" (precisar de senha para configurar o acesso sem senha) de forma segura, silenciosa e rastreável.

---

## ✨ Funcionalidades Avançadas

- 🧠 **Conexão Inteligente:** Testa a conectividade via chave antes de tentar qualquer alteração, evitando duplicidade no `authorized_keys`.
- 🚀 **Deploy Automático (`sshpass`):** Injeta a chave pública no servidor remoto sem prompts interativos, ideal para automação e pipelines.
- 🛡️ **Rastreabilidade Total:** Adiciona o `Hostname`, `IP de Origem` e `Timestamp` como comentário na chave pública instalada no destino.
- 📋 **Audit Log Remoto:** Registra de forma centralizada todas as ações de deploy e acessos no arquivo `/var/log/key.audit` do servidor remoto.
- 🧹 **Modo Force Update:** Permite limpar (purge) o `authorized_keys` e o `known_hosts` para forçar a renovação limpa de um acesso comprometido ou desatualizado.
- 🛡️ **Proteção Anti-Lixo:** Utiliza `trap` para garantir que senhas em memória e arquivos temporários `/tmp/deploy_*.pub` sejam destruídos mesmo se o script for abortado abruptamente.

---

## 📋 Pré-requisitos

Para que o script funcione corretamente, a sua máquina local (cliente) precisa ter os seguintes pacotes instalados:

```bash
# Em sistemas baseados em Debian/Ubuntu:
sudo apt update && sudo apt install sshpass openssh-client curl gawk -y
```
> Nota para o Servidor Destino:
> Para o primeiro deploy, o servidor remoto deve permitir temporariamente a autenticação por senha (PasswordAuthentication yes no /etc/ssh/sshd_config). Após o deploy, recomenda-se desativar esta opção.

## 🚀 Instalação

1. **Baixe o arquivo no servidor:**

```bash
curl -O https://raw.githubusercontent.com/sr00t3d/key_manager/refs/heads/main/key_manager.sh
```

2. **Dê permissão de execução:**

```bash
chmod +x key_manager.sh
```

3. **Execute o script:**

```bash
./key_manager.sh
```

## 🛠️ Como Utilizar

Sintaxe Básica:

```bash
key-manager <IP_SERVIDOR> [opções]
```
```bash
Flag        Argumento       Descrição
-p          <senha>         Senha do usuário remoto para o deploy automático.
-P          <porta>         Porta SSH customizada (Padrão: 22).
-u          <usuario>       Usuário do servidor remoto (Padrão: root).
-n          <nome>          Nome do arquivo da chave local (Padrão: id_rsa).
-c          <texto>         Substitui a rastreabilidade automática por um comentário customizado.
-k          Nenhum          Force Update: Limpa registros antigos e força re-instalação da chave.
-h          Nenhum          Exibe o menu de ajuda.
```

## 🌟 Exemplos de Uso Prático

1. Primeiro Acesso (Deploy Automático) Gera a chave (se não existir), adiciona o host confiável, instala a chave e loga no servidor:

```bash
key-manager 192.168.1.100 -p "minhasenha_secreta"
```

2. Uso Diário (Conexão Rápida) Detecta que a chave já existe e abre o terminal imediatamente:

```bash
key-manager 192.168.1.100
```

3. Atualizar Chave Comprometida / Troca de Máquina O parâmetro -k varre o authorized_keys antigo e instala a nova chave de forma limpa:

```bash
key-manager 192.168.1.100 -p "minhasenha_secreta" -k
```

4. Deploy para Usuário Específico com Nome Customizado

```bash
key-manager 10.0.0.5 -u ubuntu -p "senha" -c "Acesso_Temporario_Dev"
```

## 🕵️‍♂️ Sistema de Auditoria (Compliance)

Sempre que uma ação é executada, o script grava um log no servidor de destino em /var/log/key.audit. Isso é fundamental para manter a conformidade e saber quem acessou de onde.

Exemplo da saída no servidor remoto:

```bash
[28/02/2026 14:30:12] ACTION: KEY_DEPLOYED | FROM: 177.10.x.x | HOST: sr00t3d-pc
[28/02/2026 15:45:00] ACTION: LOGIN_SUCCESS | FROM: 177.10.x.x | HOST: sr00t3d-pc
```

*Além disso, executando cat ~/.ssh/authorized_keys, você verá a marca d'água exata de origem no final da string da chave pública.*

## ⚠️ Aviso de Segurança

Este script manipula credenciais. Nunca hardcode senhas em scripts automatizados. Para maior segurança, evite deixar senhas no histórico do terminal (em distribuições Linux padrão, iniciar um comando com um espaço em branco  ./key-manager... evita que ele seja salvo no ~/.bash_history).

## ⚠️ Aviso Legal

> [!WARNING]
> Este software é fornecido "tal como está". Certifique-se sempre de ter permissão explícita antes de executar. O autor não se responsabiliza por qualquer uso indevido, consequências legais ou impacto nos dados causados ​​por esta ferramenta.

## 📚 Detailed Tutorial

Para um guia completo, passo a passo, confira meu artigo completo:

👉 [**Easily manage your SSH keys**](https://perciocastelo.com.br/blog/easy-manager-your-ssh-keys.html)

## Licença 📄

Este projeto está licenciado sob a **GNU General Public License v3.0**. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.