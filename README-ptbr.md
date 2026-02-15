# Key Manager 🔑

Readme: [English](README.md)

<img src="https://github.com/user-attachments/assets/14bb0446-a6f2-49d4-9e4a-ed384365ab20" width="700">

![License](https://img.shields.io/github/license/sr00t3d/key_manager)
![Shell Script](https://img.shields.io/badge/shell-script-green)

O Key Manager é uma ferramenta utilitária desenvolvida em Shell Script para simplificar a gestão de chaves SSH e credenciais em ambientes Linux. Foi desenhado para administradores de sistemas e programadores que necessitam de uma forma rápida e segura de organizar, rodar ou implementar chaves de acesso.

## ✨ Funcionalidades

- **Gestão de Chaves SSH**: Adição, remoção e listagem de chaves públicas/privadas.
- **Automação**: Configuração rápida de chaves em servidores remotos.
- **Segurança**: Verificação de permissões de ficheiros (chmod 600/700) para garantir a integridade das chaves.
- **Backup**: Funções integradas para salvaguardar chaves existentes antes de qualquer alteração.
- **Interface Intuitiva**: Menus interativos via terminal para facilitar a navegação.

## 📋 Pré-requisitos

- Sistema Operacional baseado em Linux (Ubuntu, Debian, CentOS, etc.).
- `bash` (versão 4.0 ou superior).
- `openssh-client` instalado e configurado.
- `ssh-keygen`, `ssh-copy-id`, `sshpass`, `ssh-keyscan`

## 🚀 Instalação

Para começar a utilizar o Key Manager, clone o repositório e atribua permissões de execução ao script principal:

1. Clonar o repositório
```bash
git clone https://github.com/sr00t3d/key_manager.git
```

2. Entrar na pasta

```bash
cd key_manager
```

3. Dar permissão de execução

```bash
chmod +x key_manager.sh
```

## 🛠️ Como Utilizar

Execute o script diretamente do terminal:

```bash
./key_manager.sh
```
*Dica: Mova o arquivo para `/usr/local/bin` para facilitar seu uso*

## Comandos Comuns (Exemplos)

```bash
./key_manager.sh server_ip [-u] [-p password] [-P port] [-c] [-n keyname] [-q]
```

- `--add`:            Adiciona uma nova chave ao agente SSH.
- `--list`:           Lista todas as chaves geridas pelo sistema.
- `--deploy`:         Copia a chave pública para um servidor remoto (ajuste automático do authorized_keys).
- `-server_ip`:       Endereço IP do servidor de destino (IPv4/IPv6)
- `-u`:               Atualizar chave SSH existente
- `-p` senha:         Senha do usuário root para cópia da chave
- `-P` porta:         Porta SSH personalizada (padrão: 22)
- `-c`:               Forçar cópia da chave SSH para o servidor
- `-n` nome_da_chave: Nome de arquivo personalizado da chave SSH (padrão: id_rsa)
- `-q`:               Modo silencioso para automação
- `-h`:               Mostrar mensagem de ajuda

## 🌟 Exemplos

**Utilização com IPv4**

```bash
./key_manager.sh 192.168.1.100
```
**Usando porta e chave customizada**

```bash
./key_manager.sh 192.168.1.100 -P 2222 -n custom_key
```
**Força a atualização de senha**

```bash
./key_manager.sh 192.168.1.100 -u -p mypassword -c
```

## 🛡️ Segurança

Lembre-se sempre:
- **Nunca partilhe as suas chaves privadas**.
- Utilize sempre uma passphrase forte ao gerar novas chaves.
- Este script foi criado para facilitar a gestão, mas a responsabilidade sobre a segurança das credenciais é do utilizador.

## ⚠️ Aviso Legal

> [!WARNING]
> Este software é fornecido "como está". Certifique-se sempre de testar primeiro em um ambiente de desenvolvimento. O autor não se responsabiliza por qualquer uso indevido, consequências legais ou impacto em dados causado por esta ferramenta.

## 📚 Tutorial Detalhado

Para um guia completo, passo a passo, confira meu artigo completo:

👉 [**Easy Manager your SSH Keys**](https://perciocastelo.com.br/blog/easy-manager-your-ssh-keys.html)

## Licença 📄

Este projeto está licenciado sob a **GNU General Public License v3.0**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.
