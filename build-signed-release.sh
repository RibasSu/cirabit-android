#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

SIGNING_FILE="$ROOT_DIR/signing.properties"
GRADLEW="$ROOT_DIR/gradlew"
OUT_ROOT_DEFAULT="$ROOT_DIR/release-artifacts"

read_prop() {
  local key="$1"
  local value
  value="$(awk -F= -v k="$key" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$SIGNING_FILE" 2>/dev/null || true)"
  printf '%s' "$value"
}

print_usage() {
  cat <<'EOF'
Uso:
  ./build-signed-release.sh [--clean] [--out-dir <pasta>] [tarefas_gradle...]

Exemplos:
  ./build-signed-release.sh
  ./build-signed-release.sh --clean
  ./build-signed-release.sh --out-dir /tmp/cirabit-builds
  ./build-signed-release.sh :app:assembleRelease
EOF
}

if [[ ! -f "$SIGNING_FILE" ]]; then
  echo "Erro: signing.properties nao encontrado em $SIGNING_FILE"
  exit 1
fi

STORE_FILE="$(read_prop "STORE_FILE")"
STORE_PASSWORD="$(read_prop "STORE_PASSWORD")"
KEY_ALIAS="$(read_prop "KEY_ALIAS")"
KEY_PASSWORD="$(read_prop "KEY_PASSWORD")"

for required in STORE_FILE STORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
  value="$(read_prop "$required")"
  if [[ -z "$value" ]]; then
    echo "Erro: propriedade obrigatoria '$required' ausente em signing.properties"
    exit 1
  fi
done

if [[ ! -f "$ROOT_DIR/$STORE_FILE" && ! -f "$STORE_FILE" ]]; then
  echo "Erro: keystore nao encontrada. Verifique STORE_FILE em signing.properties"
  exit 1
fi

OUT_ROOT="$OUT_ROOT_DEFAULT"
RUN_CLEAN=false
CUSTOM_TASKS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      RUN_CLEAN=true
      shift
      ;;
    --out-dir)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Erro: --out-dir exige um caminho."
        exit 1
      fi
      OUT_ROOT="$1"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      CUSTOM_TASKS+=("$1")
      shift
      ;;
  esac
done

TASKS=(":app:assembleRelease" ":app:bundleRelease")
if [[ ${#CUSTOM_TASKS[@]} -gt 0 ]]; then
  TASKS=("${CUSTOM_TASKS[@]}")
fi

if [[ "$RUN_CLEAN" == "true" ]]; then
  TASKS=("clean" "${TASKS[@]}")
fi

echo "Iniciando build assinado com tarefas: ${TASKS[*]}"
"$GRADLEW" "${TASKS[@]}" --no-daemon

TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
RELEASE_DIR="$OUT_ROOT/$TIMESTAMP"

mkdir -p \
  "$RELEASE_DIR/apk/universal" \
  "$RELEASE_DIR/apk/arm64-v8a" \
  "$RELEASE_DIR/apk/armeabi-v7a" \
  "$RELEASE_DIR/apk/x86" \
  "$RELEASE_DIR/apk/x86_64" \
  "$RELEASE_DIR/apk/other" \
  "$RELEASE_DIR/aab" \
  "$RELEASE_DIR/mapping"

APK_OUTPUT_DIR="$ROOT_DIR/app/build/outputs/apk/release"
if [[ -d "$APK_OUTPUT_DIR" ]]; then
  mapfile -t APK_FILES < <(find "$APK_OUTPUT_DIR" -maxdepth 1 -type f -name "*.apk" | sort)
  if [[ ${#APK_FILES[@]} -eq 0 ]]; then
    echo "Aviso: nenhum APK encontrado em $APK_OUTPUT_DIR"
  else
    for apk in "${APK_FILES[@]}"; do
      file_name="$(basename "$apk")"
      case "$file_name" in
        *universal*.apk) target_dir="$RELEASE_DIR/apk/universal" ;;
        *arm64-v8a*.apk) target_dir="$RELEASE_DIR/apk/arm64-v8a" ;;
        *armeabi-v7a*.apk) target_dir="$RELEASE_DIR/apk/armeabi-v7a" ;;
        *x86_64*.apk) target_dir="$RELEASE_DIR/apk/x86_64" ;;
        *x86*.apk) target_dir="$RELEASE_DIR/apk/x86" ;;
        *) target_dir="$RELEASE_DIR/apk/other" ;;
      esac
      cp -f "$apk" "$target_dir/"
    done
  fi
else
  echo "Aviso: pasta de APKs nao encontrada: $APK_OUTPUT_DIR"
fi

AAB_OUTPUT_DIR="$ROOT_DIR/app/build/outputs/bundle/release"
if [[ -d "$AAB_OUTPUT_DIR" ]]; then
  mapfile -t AAB_FILES < <(find "$AAB_OUTPUT_DIR" -maxdepth 1 -type f -name "*.aab" | sort)
  if [[ ${#AAB_FILES[@]} -eq 0 ]]; then
    echo "Aviso: nenhum AAB encontrado em $AAB_OUTPUT_DIR"
  else
    for aab in "${AAB_FILES[@]}"; do
      cp -f "$aab" "$RELEASE_DIR/aab/"
    done
  fi
else
  echo "Aviso: pasta de AABs nao encontrada: $AAB_OUTPUT_DIR"
fi

MAPPING_FILE="$ROOT_DIR/app/build/outputs/mapping/release/mapping.txt"
if [[ -f "$MAPPING_FILE" ]]; then
  cp -f "$MAPPING_FILE" "$RELEASE_DIR/mapping/"
fi

if command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$RELEASE_DIR"
    find . -type f ! -name "SHA256SUMS.txt" -print0 \
      | sort -z \
      | xargs -0 sha256sum > SHA256SUMS.txt
  )
fi

mkdir -p "$OUT_ROOT"
ln -sfn "$RELEASE_DIR" "$OUT_ROOT/latest"

echo ""
echo "Build concluido."
echo "Artefatos organizados em: $RELEASE_DIR"
echo ""
echo "Resumo:"
find "$RELEASE_DIR" -type f | sed "s|$RELEASE_DIR/| - |"
