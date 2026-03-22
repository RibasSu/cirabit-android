#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

DEFAULT_REPO_SLUG="sarahsec/cirabit-android"
DEFAULT_WORKFLOW_PATH=".github/workflows/release.yml"

RUN_LOCAL_BUILD=true
AUTO_CONFIRM=false
VERSION_INPUT=""

usage() {
  cat <<'EOF'
Uso:
  ./publish-github-release.sh <versao> [--no-build] [--yes]

Exemplos:
  ./publish-github-release.sh 1.7.2
  ./publish-github-release.sh v1.7.2
  ./publish-github-release.sh 1.7.2 --no-build
  ./publish-github-release.sh 1.7.2 --yes

O que o script faz:
1. (Opcional) Roda build local de release assinado.
2. Cria tag anotada no formato vX.Y.Z.
3. Envia a tag para origin.
4. Dispara o workflow .github/workflows/release.yml no GitHub.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      RUN_LOCAL_BUILD=false
      shift
      ;;
    --yes|-y)
      AUTO_CONFIRM=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Erro: opcao desconhecida: $1"
      usage
      exit 1
      ;;
    *)
      if [[ -n "$VERSION_INPUT" ]]; then
        echo "Erro: informe apenas uma versao."
        usage
        exit 1
      fi
      VERSION_INPUT="$1"
      shift
      ;;
  esac
done

if [[ -z "$VERSION_INPUT" ]]; then
  echo "Erro: versao obrigatoria."
  usage
  exit 1
fi

VERSION="${VERSION_INPUT#v}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Erro: versao invalida '$VERSION_INPUT'. Use formato X.Y.Z (ex: 1.7.2)."
  exit 1
fi
TAG="v$VERSION"

if ! command -v git >/dev/null 2>&1; then
  echo "Erro: git nao encontrado no PATH."
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Erro: pasta atual nao e um repositorio git."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Erro: existem mudancas locais nao commitadas. Commit/stash antes do release."
  git status --short
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "Aviso: branch atual e '$CURRENT_BRANCH' (esperado: main)."
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Erro: tag local '$TAG' ja existe."
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Erro: tag remota '$TAG' ja existe em origin."
  exit 1
fi

if [[ "$RUN_LOCAL_BUILD" == "true" ]]; then
  if [[ ! -x "$ROOT_DIR/build-signed-release.sh" ]]; then
    echo "Erro: build-signed-release.sh nao encontrado/executavel."
    exit 1
  fi
  echo "Rodando build local de validacao..."
  "$ROOT_DIR/build-signed-release.sh" :app:assembleRelease
fi

if [[ "$AUTO_CONFIRM" != "true" ]]; then
  echo ""
  echo "Repositorio: ${GITHUB_REPOSITORY:-$DEFAULT_REPO_SLUG}"
  echo "Branch atual: $CURRENT_BRANCH"
  echo "Tag de release: $TAG"
  read -r -p "Confirmar criacao e push da tag? [y/N] " CONFIRM
  case "$CONFIRM" in
    y|Y|yes|YES) ;;
    *)
      echo "Cancelado."
      exit 0
      ;;
  esac
fi

git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

REPO_SLUG="${GITHUB_REPOSITORY:-$DEFAULT_REPO_SLUG}"
WORKFLOW_URL="https://github.com/$REPO_SLUG/actions/workflows/$(basename "$DEFAULT_WORKFLOW_PATH")"
RELEASES_URL="https://github.com/$REPO_SLUG/releases"

echo ""
echo "Tag enviada com sucesso: $TAG"
echo "Workflow de release disparado: $WORKFLOW_URL"
echo "Pagina de releases: $RELEASES_URL"

if command -v gh >/dev/null 2>&1; then
  echo ""
  echo "Comandos uteis:"
  echo " - gh run list --workflow $(basename "$DEFAULT_WORKFLOW_PATH") --limit 5"
  echo " - gh run watch"
fi
