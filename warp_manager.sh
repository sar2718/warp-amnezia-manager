#!/usr/bin/env bash

set -euo pipefail
umask 077

# -----------------------------------------------------------------------------
# Пути и константы
# -----------------------------------------------------------------------------

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
else
    # Покрывает запуск через process substitution, например: bash <(curl ...)
    SCRIPT_DIR="$PWD"
fi

CONFIG_DIR="${SCRIPT_DIR}/configs"
REVOKE_DIR="${SCRIPT_DIR}/revoke"
DATA_DIR="${SCRIPT_DIR}/.data"
REGISTRY_FILE="${DATA_DIR}/registrations.json"
LOCK_FILE="${DATA_DIR}/registrations.lock"

API_BASE="${WARP_API_BASE:-https://api.cloudflareclient.com/v0i1909051800}"
EXPIRING_SOON_SECONDS=$((7 * 24 * 60 * 60))

DNS_SERVERS="111.88.96.50, 2a00:ab00:1233:26::50, 111.88.96.51, 2a00:ab00:1233:26::51, 1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001"
WARP_ENDPOINT_HOST="162.159.192.1"
WARP_ENDPOINT_PORT="500"

# Значение AmneziaWG I1, используемое текущей конфигурацией проекта.
I1_VAL="<b 0xc2000000011419fa4bb3599f336777de79f81ca9a8d80d91eeec000044c635cef024a885dcb66d1420a91a8c427e87d6cf8e08b563932f449412cddf77d3e2594ea1c7a183c238a89e9adb7ffa57c133e55c59bec101634db90afb83f75b19fe703179e26a31902324c73f82d9354e1ed8da39af610afcb27e6590a44341a0828e5a3d2f0e0f7b0945d7bf3402feea0ee6332e19bdf48ffc387a97227aa97b205a485d282cd66d1c384bafd63dc42f822c4df2109db5b5646c458236ddcc01ae1c493482128bc0830c9e1233f0027a0d262f92b49d9d8abd9a9e0341f6e1214761043c021d7aa8c464b9d865f5fbe234e49626e00712031703a3e23ef82975f014ee1e1dc428521dc23ce7c6c13663b19906240b3efe403cf30559d798871557e4e60e86c29ea4504ed4d9bb8b549d0e8acd6c334c39bb8fb42ede68fb2aadf00cfc8bcc12df03602bbd4fe701d64a39f7ced112951a83b1dbbe6cd696dd3f15985c1b9fef72fa8d0319708b633cc4681910843ce753fac596ed9945d8b839aeff8d3bf0449197bd0bb22ab8efd5d63eb4a95db8d3ffc796ed5bcf2f4a136a8a36c7a0c65270d511aebac733e61d414050088a1c3d868fb52bc7e57d3d9fd132d78b740a6ecdc6c24936e92c28672dbe00928d89b891865f885aeb4c4996d50c2bbbb7a99ab5de02ac89b3308e57bcecf13f2da0333d1420e18b66b4c23d625d836b538fc0c221d6bd7f566a31fa292b85be96041d8e0bfe655d5dc1afed23eb8f2b3446561bbee7644325cc98d31cea38b865bdcc507e48c6ebdc7553be7bd6ab963d5a14615c4b81da7081c127c791224853e2d19bafdc0d9f3f3a6de898d14abb0e2bc849917e0a599ed4a541268ad0e60ea4d147dc33d17fa82f22aa505ccb53803a31d10a7ca2fea0b290a52ee92c7bf4aab7cea4e3c07b1989364eed87a3c6ba65188cd349d37ce4eefde9ec43bab4b4dc79e03469c2ad6b902e28e0bbbbf696781ad4edf424ffb35ce0236d373629008f142d04b5e08a124237e03e3149f4cdde92d7fae581a1ac332e26b2c9c1a6bdec5b3a9c7a2a870f7a0c25fc6ce245e029b686e346c6d862ad8df6d9b62474fbc31dbb914711f78074d4441f4e6e9edca3c52315a5c0653856e23f681558d669f4a4e6915bcf42b56ce36cb7dd3983b0b1d6fdf0f8efddb68e7ca0ae9dd4570fe6978fbb524109f6ec957ca61f1767ef74eb803b0f16abd0087cf2d01bc1db1c01d97ac81b3196c934586963fe7cf2d310e0739621e8bd00dc23fded18576d8c8f285d7bb5f43b547af3c76235de8b6f757f817683b2151600b11721219212bf27558edd439e73fce951f61d582320e5f4d6c315c71129b719277fc144bbe8ded25ab6d29b6e189c9bd9b16538faf60cc2aab3c3bb81fc2213657f2dd0ceb9b3b871e1423d8d3e8cc008721ef03b28e0ee7bb66b8f2a2ac01ef88df1f21ed49bf1ce435df31ac34485936172567488812429c269b49ee9e3d99652b51a7a614b7c460bf0d2d64d8349ded7345bedab1ea0a766a8470b1242f38d09f7855a32db39516c2bd4bcc538c52fa3a90c8714d4b006a15d9c7a7d04919a1cab48da7cce0d5de1f9e5f8936cffe469132991c6eb84c5191d1bcf69f70c58d9a7b66846440a9f0eef25ee6ab62715b50ca7bef0bc3013d4b62e1639b5028bdf757454356e9326a4c76dabfb497d451a3a1d2dbd46ec283d255799f72dfe878ae25892e25a2542d3ca9018394d8ca35b53ccd94947a8>"

# -----------------------------------------------------------------------------
# Вывод
# -----------------------------------------------------------------------------

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_BLUE=""
    C_CYAN=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
fi

info() {
    [[ "${QUIET:-0}" -eq 1 ]] && return 0
    printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"
}

ok() {
    [[ "${QUIET:-0}" -eq 1 ]] && return 0
    printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

warn() {
    printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2
}

error() {
    printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
}

die() {
    error "$*"
    exit 1
}

pause_ui() {
    [[ -t 0 ]] || return 0
    printf '\nНажмите Enter, чтобы продолжить...'
    read -r _
}

clear_ui() {
    # Очистка экрана — только косметика. Не вызываем внешнюю команду clear,
    # чтобы меню не зависело от TERM/terminfo в минимальных окружениях.
    if [[ -t 1 && -n "${TERM:-}" && "${TERM}" != "dumb" ]]; then
        printf '\033[2J\033[H'
    fi
}

print_title() {
    local title="$1"
    printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$C_CYAN" "$C_RESET"
    printf '  %s%s%s\n' "$C_BOLD" "$title" "$C_RESET"
    printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$C_CYAN" "$C_RESET"
}

print_menu_item() {
    local key="$1"
    local text="$2"
    printf '  %s[%s]%s %s\n' "$C_CYAN" "$key" "$C_RESET" "$text"
}

print_danger_item() {
    local key="$1"
    local text="$2"
    printf '  %s[%s] %s%s\n' "$C_RED" "$key" "$text" "$C_RESET"
}

print_divider() {
    printf '  %s────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"
}

# Печатает пары "поле: значение" с одной общей колонкой значений.
# ${#...} в UTF-8 locale считает символы, поэтому кириллица не ломает отступы.
print_field() {
    local label="$1"
    local value="$2"
    local width="${3:-25}"
    local text="${label}:"
    local padding=$((width - ${#text}))

    (( padding < 1 )) && padding=1
    printf '  %s%*s%s\n' "$text" "$padding" '' "$value"
}

# То же самое, но без перевода строки — удобно для цветного статуса.
print_field_prefix() {
    local label="$1"
    local width="${2:-25}"
    local text="${label}:"
    local padding=$((width - ${#text}))

    (( padding < 1 )) && padding=1
    printf '  %s%*s' "$text" "$padding" ''
}

# В меню Enter сам по себе ничего не выбирает.
# В интерактивном терминале пустой Enter не размножает строки «Выбор:»,
# а просто оставляет пользователя на том же поле ввода.
read_menu_choice() {
    local variable_name="$1"
    local input=""

    printf '\nВыбор: '

    while true; do
        if ! IFS= read -r input; then
            # EOF (например Ctrl+D): воспринимаем как возврат/выход.
            input="0"
            break
        fi

        if [[ -n "$input" ]]; then
            break
        fi

        if [[ -t 0 && -t 1 ]]; then
            # Enter перевёл курсор на следующую строку. Возвращаемся назад,
            # очищаем прежний prompt и рисуем его снова на том же месте.
            printf '\033[1A\r\033[2KВыбор: '
        else
            printf 'Выбор: '
        fi
    done

    printf -v "$variable_name" '%s' "$input"
}

fit_text() {
    local text="$1"
    local width="$2"

    if (( ${#text} > width )); then
        if (( width > 1 )); then
            text="${text:0:$((width - 1))}…"
        else
            text="${text:0:width}"
        fi
    fi

    printf '%s%*s' "$text" "$((width - ${#text}))" ''
}

mask_value() {
    local value="$1"
    if [[ ${#value} -le 12 ]]; then
        printf '••••••••'
    else
        printf '%s...%s' "${value:0:6}" "${value: -4}"
    fi
}

mask_optional_value() {
    local value="$1"
    if [[ -z "$value" ]]; then
        printf '—'
    else
        mask_value "$value"
    fi
}

# -----------------------------------------------------------------------------
# Справка
# -----------------------------------------------------------------------------

print_help() {
    cat <<'EOF'
WARP Amnezia Manager

Использование:
  bash warp_manager.sh
  bash warp_manager.sh --generate [ОПЦИИ] [PRIVATE_KEY [PUBLIC_KEY]]
  bash warp_manager.sh --list
  bash warp_manager.sh --revoke [НОМЕР|ПУТЬ_К_КОНФИГУ]
  bash warp_manager.sh --revoke-dir [ДИРЕКТОРИЯ] [--yes]
  bash warp_manager.sh --revoke-id REGISTRATION_ID
  bash warp_manager.sh --revoke-expired [--dry-run]

Без аргументов в интерактивном терминале открывается меню.
Навигация в меню выполняется цифрами; 0 — назад/отмена/выход.

Генерация:
  --generate             Явно перейти в режим генерации.
  -n, --count N          Создать N конфигов (по умолчанию 1).
  --label TEXT           Метка/комментарий, например "USER — iPhone".
                         При --count > 1 CLI добавляет #1, #2 и т.д.
  --ttl DURATION         Срок жизни: 30m, 12h, 7d, 4w.
  --expires DATE         Дата окончания, например "2026-10-15 18:00".
  -q, --quiet            Не печатать конфиг и vpn:// в терминал.

Отзыв и управление:
  --list                 Показать локальный реестр регистраций.
  --revoke               Открыть интерактивное меню отзыва.
  --revoke N             Отозвать регистрацию N из --list.
  --revoke FILE          Определить регистрацию по содержимому FILE и отозвать её.
                         Имя и прежний путь файла для поиска не используются.
  --revoke-dir           Проверить и отозвать подходящие *.conf из ./revoke/.
  --revoke-dir DIR       То же для указанной директории (только верхний уровень).
  --revoke-id ID         Отозвать по Cloudflare registration ID из локального реестра.
  --yes                  Не спрашивать подтверждение отзыва в CLI.
                         Файлы при этом никогда не удаляются автоматически.
  --revoke-expired       Отозвать все истёкшие активные регистрации.
  --dry-run              С --revoke-expired только показать, что истекло.

Как определяется регистрация по .conf:
  [Interface] PrivateKey -> wg pubkey -> registrations[].public_key

PrivateKey не сохраняется в реестре и не выводится при поиске.
Если совпадений нет или найдено больше одной записи, отзыв не выполняется.

Директории:
  configs/                   временно созданные конфиги с PrivateKey
  revoke/                    временная очередь *.conf для отзыва
  .data/registrations.json   id/token/public_key и метаданные регистраций

configs/, revoke/ и .data/ должны оставаться в .gitignore.

Примеры:
  bash warp_manager.sh
  bash warp_manager.sh --generate --label "Мой ноутбук" --ttl 30d
  bash warp_manager.sh -n 3 --label "USER" --expires "2026-12-31 23:59"
  bash warp_manager.sh --list
  bash warp_manager.sh --revoke 2
  bash warp_manager.sh --revoke ~/Downloads/WARP.conf
  bash warp_manager.sh --revoke-dir
  bash warp_manager.sh --revoke-dir ~/Downloads/old-warp
  bash warp_manager.sh --revoke-id <registration-id>
  bash warp_manager.sh --revoke-expired --dry-run
EOF
}

command_package() {
    local manager="$1"
    local command_name="$2"

    case "$command_name" in
        curl) printf 'curl' ;;
        jq) printf 'jq' ;;
        wg) printf 'wireguard-tools' ;;
        flock) printf 'util-linux' ;;
        date|base64) printf 'coreutils' ;;
        *)
            return 1
            ;;
    esac
}

detect_package_manager() {
    local manager
    for manager in apt-get pacman dnf zypper apk; do
        if command -v "$manager" >/dev/null 2>&1; then
            printf '%s' "$manager"
            return 0
        fi
    done
    return 1
}

install_packages() {
    local manager="$1"
    shift
    local packages=("$@")
    local privilege=()

    if (( EUID != 0 )); then
        if command -v sudo >/dev/null 2>&1; then
            privilege=(sudo)
        else
            error "Для установки зависимостей нужны права root или установленный sudo."
            return 1
        fi
    fi

    info "Устанавливаю недостающие зависимости через ${manager}..."

    case "$manager" in
        apt-get)
            "${privilege[@]}" apt-get update
            "${privilege[@]}" apt-get install -y "${packages[@]}"
            ;;
        pacman)
            "${privilege[@]}" pacman -S --needed --noconfirm "${packages[@]}"
            ;;
        dnf)
            "${privilege[@]}" dnf install -y "${packages[@]}"
            ;;
        zypper)
            "${privilege[@]}" zypper --non-interactive install "${packages[@]}"
            ;;
        apk)
            "${privilege[@]}" apk add "${packages[@]}"
            ;;
        *)
            error "Неподдерживаемый пакетный менеджер: $manager"
            return 1
            ;;
    esac
}

ensure_dependencies() {
    local mode="$1"
    local required=(jq date flock)
    local missing=()
    local command_name

    case "$mode" in
        list)
            ;;
        manage)
            required+=(curl)
            ;;
        revoke-file)
            required+=(curl wg)
            ;;
        generate)
            required+=(curl wg base64)
            ;;
        *)
            error "Внутренняя ошибка: неизвестный набор зависимостей '$mode'."
            return 1
            ;;
    esac

    for command_name in "${required[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    local manager
    if ! manager="$(detect_package_manager)"; then
        error "Не найдены команды: ${missing[*]}"
        error "Автоматически определить пакетный менеджер не удалось."
        return 1
    fi

    local packages=()
    local pkg
    for command_name in "${missing[@]}"; do
        pkg="$(command_package "$manager" "$command_name")" || {
            error "Не знаю, какой пакет устанавливает команду '$command_name'."
            return 1
        }
        if [[ ! " ${packages[*]} " =~ " ${pkg} " ]]; then
            packages+=("$pkg")
        fi
    done

    install_packages "$manager" "${packages[@]}"

    for command_name in "${required[@]}"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            error "После установки всё ещё не найдена команда: $command_name"
            return 1
        fi
    done
}

init_registry() {
    mkdir -p "$CONFIG_DIR" "$REVOKE_DIR" "$DATA_DIR"
    chmod 700 "$CONFIG_DIR" "$REVOKE_DIR" "$DATA_DIR"

    if [[ ! -e "$REGISTRY_FILE" ]]; then
        printf '%s\n' '{"version":1,"registrations":[]}' > "$REGISTRY_FILE"
    fi
    chmod 600 "$REGISTRY_FILE"

    if ! jq -e '
        (.version == 1)
        and (.registrations | type == "array")
    ' "$REGISTRY_FILE" >/dev/null 2>&1; then
        error "Повреждён или имеет неподдерживаемый формат:"
        error "$REGISTRY_FILE"
        return 1
    fi
}

registry_lock() {
    exec 9>"$LOCK_FILE"
    flock -x 9
}

registry_unlock() {
    flock -u 9 || true
    exec 9>&-
}

registry_write_from_jq() {
    local tmp_file
    tmp_file="$(mktemp "${DATA_DIR}/registrations.XXXXXX.tmp")"
    chmod 600 "$tmp_file"

    if ! jq "${@:1}" "$REGISTRY_FILE" > "$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    if ! jq -e '
        (.version == 1)
        and (.registrations | type == "array")
    ' "$tmp_file" >/dev/null 2>&1; then
        rm -f "$tmp_file"
        return 1
    fi

    mv -f "$tmp_file" "$REGISTRY_FILE"
}

public_key_registration_count() {
    local public_key="$1"
    jq -r --arg public_key "$public_key" '
        [.registrations[] | select((.public_key // "") == $public_key)] | length
    ' "$REGISTRY_FILE"
}

save_registration() {
    local id="$1"
    local token="$2"
    local public_key="$3"
    local label="$4"
    local created_at="$5"
    local expires_at="$6"

    registry_lock
    local rc=0

    # public_key — стабильная связь выданного .conf с регистрацией. Один ключ
    # не должен одновременно указывать на несколько registration ID.
    if jq -e \
        --arg id "$id" \
        --arg public_key "$public_key" \
        'any(.registrations[]; ((.public_key // "") == $public_key) and (.id != $id))' \
        "$REGISTRY_FILE" >/dev/null; then
        rc=3
    else
        registry_write_from_jq \
            --arg id "$id" \
            --arg token "$token" \
            --arg public_key "$public_key" \
            --arg label "$label" \
            --arg created_at "$created_at" \
            --arg expires_at "$expires_at" \
            '
            .registrations |=
                if any(.[]; .id == $id) then
                    map(
                        if .id == $id then
                            .token = $token
                            | .public_key = $public_key
                            | .label = $label
                            | .created_at = $created_at
                            | .expires_at = (if $expires_at == "" then null else $expires_at end)
                        else .
                        end
                    )
                else
                    . + [{
                        id: $id,
                        token: $token,
                        public_key: $public_key,
                        config: null,
                        label: $label,
                        created_at: $created_at,
                        expires_at: (if $expires_at == "" then null else $expires_at end),
                        revoked_at: null,
                        revoke_reason: null
                    }]
                end
            ' || rc=$?
    fi

    registry_unlock
    return "$rc"
}

save_emergency_registration_recovery() {
    local id="$1"
    local token="$2"
    local public_key="$3"
    local label="$4"
    local created_at="$5"
    local expires_at="$6"

    local stamp safe_id recovery_file
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    safe_id="${id//[^A-Za-z0-9._-]/_}"
    [[ -n "$safe_id" ]] || safe_id="unknown"

    recovery_file="$(mktemp "${DATA_DIR}/recovery-${stamp}-${safe_id}.XXXXXX.json" 2>/dev/null)" || return 1
    chmod 600 "$recovery_file" 2>/dev/null || {
        rm -f -- "$recovery_file"
        return 1
    }

    if ! jq -n \
        --arg id "$id" \
        --arg token "$token" \
        --arg public_key "$public_key" \
        --arg label "$label" \
        --arg created_at "$created_at" \
        --arg expires_at "$expires_at" \
        '{
            reason: "registry-save-and-rollback-failed",
            id: $id,
            token: $token,
            public_key: $public_key,
            label: $label,
            created_at: $created_at,
            expires_at: (if $expires_at == "" then null else $expires_at end)
        }' > "$recovery_file"; then
        rm -f -- "$recovery_file"
        return 1
    fi

    printf '%s' "$recovery_file"
}

update_registration_config() {
    local id="$1"
    local config_path="$2"

    registry_lock
    local rc=0
    registry_write_from_jq \
        --arg id "$id" \
        --arg config "$config_path" \
        '
        .registrations |= map(
            if .id == $id then .config = $config else . end
        )
        ' || rc=$?
    registry_unlock
    return "$rc"
}

update_registration_label() {
    local id="$1"
    local label="$2"

    registry_lock
    local rc=0
    registry_write_from_jq \
        --arg id "$id" \
        --arg label "$label" \
        '
        .registrations |= map(
            if .id == $id then .label = $label else . end
        )
        ' || rc=$?
    registry_unlock
    return "$rc"
}

update_registration_expiry() {
    local id="$1"
    local expires_at="$2"

    registry_lock
    local rc=0
    registry_write_from_jq \
        --arg id "$id" \
        --arg expires_at "$expires_at" \
        '
        .registrations |= map(
            if .id == $id then
                .expires_at = (if $expires_at == "" then null else $expires_at end)
            else .
            end
        )
        ' || rc=$?
    registry_unlock
    return "$rc"
}

mark_registration_revoked() {
    local id="$1"
    local reason="$2"
    local revoked_at="$3"

    registry_lock
    local rc=0
    registry_write_from_jq \
        --arg id "$id" \
        --arg reason "$reason" \
        --arg revoked_at "$revoked_at" \
        '
        .registrations |= map(
            if .id == $id then
                .revoked_at = $revoked_at
                | .revoke_reason = $reason
            else .
            end
        )
        ' || rc=$?
    registry_unlock
    return "$rc"
}

get_registration_by_index() {
    local index="$1"
    jq -c --argjson index "$index" '
        .registrations[$index - 1] // empty
    ' "$REGISTRY_FILE"
}

get_registration_by_id() {
    local id="$1"
    jq -c --arg id "$id" '
        first(.registrations[] | select(.id == $id)) // empty
    ' "$REGISTRY_FILE"
}

normalize_input_path() {
    local path="$1"

    # В интерактивном вводе пользователь иногда вставляет путь вместе с кавычками.
    if [[ ${#path} -ge 2 ]]; then
        if [[ "${path:0:1}" == '"' && "${path: -1}" == '"' ]]; then
            path="${path:1:${#path}-2}"
        elif [[ "${path:0:1}" == "'" && "${path: -1}" == "'" ]]; then
            path="${path:1:${#path}-2}"
        fi
    fi

    case "$path" in
        '~')
            printf '%s' "$HOME"
            ;;
        '~/'*)
            printf '%s/%s' "$HOME" "${path#\~/}"
            ;;
        *)
            printf '%s' "$path"
            ;;
    esac
}

trim_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# Коды возврата:
#   10 — путь не является обычным файлом;
#   11 — файл нельзя прочитать;
#   12 — PrivateKey в [Interface] не найден;
#   13 — найдено несколько PrivateKey в [Interface].
extract_interface_private_key() {
    local file="$1"

    [[ -f "$file" ]] || return 10
    [[ -r "$file" ]] || return 11

    local section=""
    local private_key=""
    local count=0
    local line value

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="${line#$'\xEF\xBB\xBF'}"
        line="$(trim_whitespace "$line")"

        [[ -z "$line" ]] && continue
        [[ "$line" == \#* || "$line" == \;* ]] && continue

        if [[ "$line" =~ ^\[([^][]+)\][[:space:]]*$ ]]; then
            section="${BASH_REMATCH[1],,}"
            continue
        fi

        [[ "$section" == "interface" ]] || continue

        if [[ "$line" =~ ^PrivateKey[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            value="${BASH_REMATCH[1]}"
            value="${value%%#*}"
            value="${value%%;*}"
            value="$(trim_whitespace "$value")"
            count=$((count + 1))
            private_key="$value"
        fi
    done < "$file"

    (( count > 0 )) || return 12
    (( count == 1 )) || return 13
    [[ -n "$private_key" ]] || return 12

    printf '%s' "$private_key"
}

# Код 14 означает, что найденный PrivateKey не принят wg pubkey.
public_key_from_config_file() {
    local file="$1"
    local private_key public_key rc

    private_key="$(extract_interface_private_key "$file")" || {
        rc=$?
        return "$rc"
    }

    public_key="$(printf '%s\n' "$private_key" | wg pubkey 2>/dev/null)" || {
        unset private_key
        return 14
    }
    unset private_key

    public_key="${public_key//$'\r'/}"
    public_key="${public_key//$'\n'/}"
    [[ -n "$public_key" ]] || return 14

    printf '%s' "$public_key"
}

find_registration_by_public_key() {
    local public_key="$1"
    local matches count

    matches="$(
        jq -c --arg public_key "$public_key" '
            [.registrations[] | select((.public_key // "") == $public_key)]
        ' "$REGISTRY_FILE"
    )" || return 22

    count="$(jq -r 'length' <<< "$matches")" || return 22

    if [[ "$count" -eq 0 ]]; then
        return 20
    fi
    if [[ "$count" -gt 1 ]]; then
        return 21
    fi

    jq -c '.[0]' <<< "$matches"
}

# Определяет регистрацию исключительно по содержимому .conf.
# Имя файла, basename и сохранённое поле .config намеренно не используются.
config_lookup_error_text() {
    case "$1" in
        10) printf 'путь не является обычным файлом' ;;
        11) printf 'нет прав на чтение файла' ;;
        12) printf 'в секции [Interface] не найден PrivateKey' ;;
        13) printf 'в секции [Interface] найдено несколько PrivateKey' ;;
        14) printf 'PrivateKey имеет некорректный формат' ;;
        20) printf 'соответствующая регистрация не найдена в локальном реестре' ;;
        21) printf 'одному public_key соответствует несколько записей реестра' ;;
        22) printf 'не удалось прочитать локальный реестр' ;;
        *) printf 'неизвестная ошибка сопоставления' ;;
    esac
}

registration_index_by_id() {
    local id="$1"
    jq -r --arg id "$id" '
        (.registrations | map(.id) | index($id)) as $i
        | if $i == null then empty else ($i + 1) end
    ' "$REGISTRY_FILE"
}

registration_status() {
    local registration="$1"
    local now_epoch="${2:-$(date -u +%s)}"

    local revoked_at expires_at config
    revoked_at="$(jq -r '.revoked_at // empty' <<< "$registration")"
    expires_at="$(jq -r '.expires_at // empty' <<< "$registration")"
    config="$(jq -r '.config // empty' <<< "$registration")"

    if [[ -n "$revoked_at" ]]; then
        printf 'revoked'
        return 0
    fi

    if [[ -n "$expires_at" ]]; then
        local expires_epoch
        if expires_epoch="$(date -u -d "$expires_at" +%s 2>/dev/null)"; then
            if (( expires_epoch <= now_epoch )); then
                printf 'expired'
                return 0
            fi
            if (( expires_epoch - now_epoch <= EXPIRING_SOON_SECONDS )); then
                printf 'soon'
                return 0
            fi
        fi
    fi

    if [[ -z "$config" ]]; then
        printf 'orphan'
    else
        printf 'active'
    fi
}

status_text() {
    case "$1" in
        active) printf 'АКТИВЕН' ;;
        soon) printf 'СКОРО' ;;
        expired) printf 'ИСТЁК' ;;
        revoked) printf 'ОТОЗВАН' ;;
        orphan) printf 'БЕЗ КОНФИГА' ;;
        *) printf '%s' "$1" ;;
    esac
}

status_display() {
    local status="$1"
    local text
    text="$(status_text "$status")"

    case "$status" in
        active) printf '%s%s%s' "$C_GREEN" "$text" "$C_RESET" ;;
        soon) printf '%s%s%s' "$C_YELLOW" "$text" "$C_RESET" ;;
        expired) printf '%s%s%s' "$C_RED" "$text" "$C_RESET" ;;
        revoked) printf '%s%s%s' "$C_DIM" "$text" "$C_RESET" ;;
        orphan) printf '%s%s%s' "$C_YELLOW" "$text" "$C_RESET" ;;
        *) printf '%s' "$text" ;;
    esac
}

format_date_local() {
    local value="$1"
    if [[ -z "$value" ]]; then
        printf '—'
    elif ! date -d "$value" '+%Y-%m-%d %H:%M' 2>/dev/null; then
        printf '%s' "$value"
    fi
}

short_registration_id() {
    local id="$1"
    if [[ -z "$id" ]]; then
        printf 'без id'
    elif (( ${#id} <= 12 )); then
        printf '%s' "$id"
    else
        printf '%s…%s' "${id:0:8}" "${id: -4}"
    fi
}

display_name_for_registration() {
    local registration="$1"
    local label id
    label="$(jq -r '.label // empty' <<< "$registration")"
    id="$(jq -r '.id // empty' <<< "$registration")"

    if [[ -n "$label" ]]; then
        printf '%s' "$label"
    else
        printf 'Регистрация %s' "$(short_registration_id "$id")"
    fi
}

registry_stats() {
    local now_epoch
    now_epoch="$(date -u +%s)"

    local active=0 soon=0 expired=0 revoked=0 orphan=0
    local registration status

    while IFS= read -r registration; do
        status="$(registration_status "$registration" "$now_epoch")"
        case "$status" in
            active) active=$((active + 1)) ;;
            soon) active=$((active + 1)); soon=$((soon + 1)) ;;
            expired) expired=$((expired + 1)) ;;
            revoked) revoked=$((revoked + 1)) ;;
            orphan) orphan=$((orphan + 1)) ;;
        esac
    done < <(jq -c '.registrations[]' "$REGISTRY_FILE")

    printf '%s %s %s %s %s' "$active" "$soon" "$expired" "$revoked" "$orphan"
}

# -----------------------------------------------------------------------------
# Работа со временем
# -----------------------------------------------------------------------------

duration_to_seconds() {
    local duration="$1"

    if [[ ! "$duration" =~ ^([1-9][0-9]*)(m|h|d|w)$ ]]; then
        return 1
    fi

    local value="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"

    case "$unit" in
        m) printf '%s' $((value * 60)) ;;
        h) printf '%s' $((value * 60 * 60)) ;;
        d) printf '%s' $((value * 24 * 60 * 60)) ;;
        w) printf '%s' $((value * 7 * 24 * 60 * 60)) ;;
    esac
}

expiry_from_ttl() {
    local created_at="$1"
    local ttl="$2"
    local seconds
    seconds="$(duration_to_seconds "$ttl")" || return 1

    local created_epoch
    created_epoch="$(date -u -d "$created_at" +%s)" || return 1
    date -u -d "@$((created_epoch + seconds))" +%FT%TZ
}

normalize_expiry_date() {
    local input="$1"
    local epoch

    epoch="$(date -d "$input" +%s 2>/dev/null)" || return 1

    if (( epoch <= $(date +%s) )); then
        return 2
    fi

    date -u -d "@$epoch" +%FT%TZ
}

sanitize_label() {
    local label="$1"
    label="${label//$'\n'/ }"
    label="${label//$'\r'/ }"
    printf '%s' "${label:0:120}"
}

# -----------------------------------------------------------------------------
# Cloudflare API
# -----------------------------------------------------------------------------

API_BODY=""
API_HTTP=""

api_request() {
    local method="$1"
    local endpoint="$2"
    local token="${3:-}"
    local payload="${4:-}"

    local response_file
    response_file="$(mktemp "${DATA_DIR}/api-response.XXXXXX.tmp")"
    chmod 600 "$response_file"

    local curl_args=(
        --silent
        --show-error
        --location
        --connect-timeout 10
        --max-time 30
        --output "$response_file"
        --write-out '%{http_code}'
        --request "$method"
        --header 'User-Agent: okhttp/3.12.1'
        --header 'Content-Type: application/json'
    )

    if [[ -n "$token" ]]; then
        curl_args+=(--header "Authorization: Bearer ${token}")
    fi

    if [[ -n "$payload" ]]; then
        curl_args+=(--data "$payload")
    fi

    if ! API_HTTP="$(curl "${curl_args[@]}" "${API_BASE}/${endpoint}")"; then
        rm -f "$response_file"
        API_BODY=""
        API_HTTP=""
        return 1
    fi

    API_BODY="$(cat "$response_file")"
    rm -f "$response_file"

    [[ "$API_HTTP" =~ ^2[0-9][0-9]$ ]]
}

require_json_api_body() {
    local stage="$1"

    if [[ -z "$API_BODY" ]] || ! jq -e . >/dev/null 2>&1 <<< "$API_BODY"; then
        error "Cloudflare вернул некорректный ответ на ${stage}."
        if [[ -n "$API_HTTP" ]]; then
            error "HTTP: $API_HTTP"
        fi
        if [[ -n "$API_BODY" ]]; then
            error "Ответ сервера (первые 500 символов): ${API_BODY:0:500}"
        fi
        return 1
    fi
}

revoke_api_registration() {
    local id="$1"
    local token="$2"

    if ! api_request DELETE "reg/${id}" "$token"; then
        if [[ -n "$API_HTTP" ]]; then
            error "Не удалось отозвать регистрацию ${id}: HTTP ${API_HTTP}."
        else
            error "Не удалось связаться с Cloudflare при отзыве регистрации ${id}."
        fi
        if [[ -n "$API_BODY" ]]; then
            error "Ответ API (первые 500 символов): ${API_BODY:0:500}"
        fi
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Генерация конфигураций
# -----------------------------------------------------------------------------

next_config_path() {
    local relative="configs/WARP.conf"
    local n=1

    while [[ -e "${SCRIPT_DIR}/${relative}" ]]; do
        relative="configs/WARP_${n}.conf"
        n=$((n + 1))
    done

    printf '%s' "$relative"
}

write_config_file() {
    local relative_path="$1"
    local content="$2"
    local target="${SCRIPT_DIR}/${relative_path}"
    local tmp_file

    tmp_file="$(mktemp "${CONFIG_DIR}/.warp.XXXXXX.tmp")"
    chmod 600 "$tmp_file"

    if ! printf '%s\n' "$content" > "$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    # Создаём конечное имя через hard link. В отличие от mv, ln не
    # перезапишет уже существующий конфиг, если два процесса случайно
    # выбрали одно и то же имя одновременно.
    if ! ln "$tmp_file" "$target" 2>/dev/null; then
        rm -f "$tmp_file"
        return 1
    fi

    rm -f "$tmp_file"
}

build_config() {
    local private_key="$1"
    local client_ipv4="$2"
    local client_ipv6="$3"
    local peer_public_key="$4"

    cat <<EOF
[Interface]
PrivateKey = ${private_key}
S1 = 0
S2 = 0
Jc = 120
Jmin = 23
Jmax = 911
H1 = 1
H2 = 2
H3 = 3
H4 = 4
MTU = 1280
I1 = ${I1_VAL}
Address = ${client_ipv4}, ${client_ipv6}
DNS = ${DNS_SERVERS}

[Peer]
PublicKey = ${peer_public_key}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${WARP_ENDPOINT_HOST}:${WARP_ENDPOINT_PORT}
EOF
}

build_vpn_key() {
    local private_key="$1"
    local client_ipv4="$2"
    local client_ipv6="$3"
    local peer_public_key="$4"
    local conf="$5"

    local awg_json
    awg_json="$(
        jq -n \
            --arg pr "$private_key" \
            --arg i1 "$I1_VAL" \
            --arg v4 "$client_ipv4" \
            --arg v6 "$client_ipv6" \
            --arg pp "$peer_public_key" \
            --arg cf "$conf" \
            --arg host "$WARP_ENDPOINT_HOST" \
            --arg port "$WARP_ENDPOINT_PORT" \
            '{
                H1: "1",
                H2: "2",
                H3: "3",
                H4: "4",
                I1: $i1,
                Jc: "120",
                Jmax: "911",
                Jmin: "23",
                S1: "0",
                S2: "0",
                allowed_ips: ["0.0.0.0/0", "::/0"],
                client_ip: ($v4 + ", " + $v6),
                client_priv_key: $pr,
                config: ($cf | gsub("\n"; "\r\n")),
                hostName: $host,
                mtu: 1280,
                port: ($port | tonumber),
                server_pub_key: $pp
            }'
    )"

    local amnezia_json
    amnezia_json="$(
        jq -n \
            --arg last "$awg_json" \
            --arg host "$WARP_ENDPOINT_HOST" \
            --arg port "$WARP_ENDPOINT_PORT" \
            '{
                containers: [{
                    container: "amnezia-awg",
                    awg: {
                        isThirdPartyConfig: true,
                        last_config: $last,
                        port: $port,
                        transport_proto: "udp"
                    }
                }],
                defaultContainer: "amnezia-awg",
                description: "Cloudflare WARP",
                hostName: $host
            }'
    )"

    printf 'vpn://%s' "$(printf '%s' "$amnezia_json" | base64 | tr -d '\n')"
}

print_partial_result() {
    if [[ ${#CREATED_FILES[@]} -gt 0 ]]; then
        printf '\nУже созданные в этом запуске конфиги:\n' >&2
        local file
        for file in "${CREATED_FILES[@]}"; do
            printf '  - %s\n' "$file" >&2
        done
    fi
}

generate_configs() {
    local count="$1"
    local base_label="$2"
    local ttl="$3"
    local absolute_expiry="$4"
    local hide_secrets="$5"
    local supplied_private_key="${6:-}"
    local supplied_public_key="${7:-}"

    ensure_dependencies generate || return 1
    init_registry || return 1

    CREATED_FILES=()
    CREATED_IDS=()
    local last_conf=""
    local last_vpn_key=""

    local i
    for ((i = 1; i <= count; i++)); do
        local private_key public_key

        if [[ "$i" -eq 1 && -n "$supplied_private_key" ]]; then
            private_key="$supplied_private_key"
        else
            private_key="$(wg genkey | tr -d '\n')"
        fi

        local derived_public_key
        if ! derived_public_key="$(printf '%s\n' "$private_key" | wg pubkey 2>/dev/null | tr -d '\r\n')"; then
            error "Не удалось получить public key: PrivateKey имеет некорректный формат."
            print_partial_result
            return 1
        fi
        if [[ -z "$derived_public_key" ]]; then
            error "wg pubkey вернул пустой public key."
            print_partial_result
            return 1
        fi

        if [[ "$i" -eq 1 && -n "$supplied_public_key" ]]; then
            if [[ "$supplied_public_key" != "$derived_public_key" ]]; then
                error "Переданный PUBLIC_KEY не соответствует PRIVATE_KEY."
                print_partial_result
                return 1
            fi
            public_key="$supplied_public_key"
        else
            public_key="$derived_public_key"
        fi

        local existing_key_count
        if ! existing_key_count="$(public_key_registration_count "$public_key")"; then
            error "Не удалось проверить уникальность client public key в registrations.json."
            print_partial_result
            return 1
        fi
        if (( existing_key_count > 0 )); then
            error "Этот client public key уже присутствует в registrations.json."
            error "Повторно использовать одну пару ключей для новой регистрации нельзя."
            print_partial_result
            return 1
        fi

        local created_at expires_at label
        created_at="$(date -u +%FT%TZ)"
        expires_at=""

        if [[ -n "$ttl" ]]; then
            expires_at="$(expiry_from_ttl "$created_at" "$ttl")" || {
                error "Некорректный срок: $ttl"
                print_partial_result
                return 1
            }
        elif [[ -n "$absolute_expiry" ]]; then
            expires_at="$absolute_expiry"
        fi

        if (( ${#GENERATION_LABELS[@]} == count )); then
            label="${GENERATION_LABELS[$((i - 1))]}"
        else
            # CLI-режим сохраняет прежнее поведение: одна --label при пакетной
            # генерации становится "Метка #1", "Метка #2" и т.д.
            label="$base_label"
            if (( count > 1 )) && [[ -n "$label" ]]; then
                label="${label} #${i}"
            fi
        fi

        info "[${i}/${count}] Регистрирую новый WARP-клиент..."

        local payload
        payload="$(
            jq -n \
                --arg tos "$created_at" \
                --arg key "$public_key" \
                '{
                    install_id: "",
                    tos: $tos,
                    key: $key,
                    fcm_token: "",
                    type: "ios",
                    locale: "en_US"
                }'
        )"

        if ! api_request POST "reg" "" "$payload"; then
            error "Не удалось создать WARP-регистрацию."
            [[ -n "$API_HTTP" ]] && error "HTTP: $API_HTTP"
            [[ -n "$API_BODY" ]] && error "Ответ (первые 500 символов): ${API_BODY:0:500}"
            print_partial_result
            return 1
        fi

        require_json_api_body "POST /reg" || {
            print_partial_result
            return 1
        }

        local id token
        id="$(jq -r '.result.id // empty' <<< "$API_BODY")"
        token="$(jq -r '.result.token // empty' <<< "$API_BODY")"

        if [[ -z "$id" || -z "$token" ]]; then
            error "Cloudflare не вернул registration id/token."
            error "Ответ (первые 500 символов): ${API_BODY:0:500}"
            print_partial_result
            return 1
        fi

        # Сохраняем id/token сразу. Если следующий этап завершится ошибкой,
        # регистрацией всё равно можно будет управлять и отозвать её через локальный реестр.
        local save_rc=0
        save_registration "$id" "$token" "$public_key" "$label" "$created_at" "$expires_at" || save_rc=$?
        if (( save_rc != 0 )); then
            if (( save_rc == 3 )); then
                error "Регистрация создана, но этот client public key уже появился в локальном реестре."
                error "Обнаружена параллельная операция или конфликт ключей."
            else
                error "Регистрация создана, но управляющие данные не удалось сохранить."
            fi
            warn "Пытаюсь немедленно отозвать новую регистрацию, чтобы не оставить её без управления."

            if revoke_api_registration "$id" "$token"; then
                error "Новая регистрация удалена с сервера. Генерация остановлена безопасно."
            else
                error "ВАЖНО: автоматический откат тоже не удался."
                local recovery_file=""
                if recovery_file="$(save_emergency_registration_recovery \
                    "$id" "$token" "$public_key" "$label" "$created_at" "$expires_at")"; then
                    error "Управляющие данные сохранены в аварийный файл с правами 600:"
                    error "$recovery_file"
                    error "Не удаляйте этот файл, пока регистрация не будет отозвана или возвращена в реестр."
                else
                    error "Не удалось сохранить даже аварийный recovery-файл."
                    error "Registration ID: ${id}"
                    error "Management token: ${token}"
                    error "Скопируйте эти две строки в безопасное место: без token регистрацию нельзя будет отозвать этим менеджером."
                fi
            fi
            return 1
        fi

        CREATED_IDS+=("$id")

        if ! api_request PATCH "reg/${id}" "$token" '{"warp_enabled":true}'; then
            error "Регистрация ${id} сохранена в реестре, но её настройка не завершилась."
            error "Её можно отозвать через меню или --revoke-id."
            [[ -n "$API_HTTP" ]] && error "HTTP: $API_HTTP"
            print_partial_result
            return 1
        fi

        require_json_api_body "PATCH /reg/{id}" || {
            error "Регистрация ${id} сохранена в реестре и доступна для ручного отзыва."
            print_partial_result
            return 1
        }

        local peer_public_key client_ipv4 client_ipv6
        peer_public_key="$(jq -r '.result.config.peers[0].public_key // empty' <<< "$API_BODY")"
        client_ipv4="$(jq -r '.result.config.interface.addresses.v4 // empty' <<< "$API_BODY")"
        client_ipv6="$(jq -r '.result.config.interface.addresses.v6 // empty' <<< "$API_BODY")"

        if [[ -z "$peer_public_key" || -z "$client_ipv4" || -z "$client_ipv6" ]]; then
            error "Cloudflare вернул неполную конфигурацию."
            error "Регистрация ${id} сохранена в реестре и доступна для ручного отзыва."
            print_partial_result
            return 1
        fi

        local conf relative_path vpn_key
        conf="$(build_config "$private_key" "$client_ipv4" "$client_ipv6" "$peer_public_key")"
        relative_path="$(next_config_path)"

        if ! write_config_file "$relative_path" "$conf"; then
            error "Регистрация ${id} создана, но файл конфигурации записать не удалось."
            error "Запись сохранена в реестре без пути к конфигу."
            print_partial_result
            return 1
        fi

        if ! update_registration_config "$id" "$relative_path"; then
            error "Конфиг создан: ${relative_path}"
            error "Но не удалось привязать его путь к записи ${id} в реестре."
            return 1
        fi

        CREATED_FILES+=("$relative_path")

        if (( count == 1 )); then
            vpn_key="$(build_vpn_key "$private_key" "$client_ipv4" "$client_ipv6" "$peer_public_key" "$conf")"
            last_conf="$conf"
            last_vpn_key="$vpn_key"
        fi

        ok "[${i}/${count}] Создан ${relative_path}"
    done

    printf '\n%sГотово.%s Создано конфигов: %s\n' "$C_BOLD" "$C_RESET" "$count"

    local f
    for f in "${CREATED_FILES[@]}"; do
        printf '  - %s\n' "$f"
    done

    if (( count == 1 && hide_secrets == 0 )); then
        printf '\n%sСтрока для AmneziaVPN:%s\n%s\n' "$C_BOLD" "$C_RESET" "$last_vpn_key"
        printf '\n%sКонфигурация:%s\n%s\n' "$C_BOLD" "$C_RESET" "$last_conf"
    fi

    if [[ -n "$absolute_expiry" || -n "$ttl" ]]; then
        printf '\nСрок действия сохранён в локальном реестре.\n'
        printf 'Для автоматического отзыва запускайте: bash warp_expiry.sh\n'
    fi
}

on_interrupt() {
    printf '\n' >&2
    warn "Операция прервана пользователем."
    print_partial_result
    exit 130
}

trap on_interrupt INT TERM

# -----------------------------------------------------------------------------
# Список и отзыв регистраций
# -----------------------------------------------------------------------------

print_registration_list() {
    ensure_dependencies list || return 1
    init_registry || return 1

    local total
    total="$(jq '.registrations | length' "$REGISTRY_FILE")"

    if [[ "$total" -eq 0 ]]; then
        printf '  Регистраций пока нет.\n'
        return 0
    fi

    local index=0 registration status label expires public_key
    while IFS= read -r registration; do
        index=$((index + 1))
        status="$(registration_status "$registration")"
        label="$(jq -r '.label // empty' <<< "$registration")"
        expires="$(jq -r '.expires_at // empty' <<< "$registration")"
        public_key="$(jq -r '.public_key // empty' <<< "$registration")"

        [[ -n "$label" ]] || label="${C_DIM}(без метки)${C_RESET}"

        printf '  %s[%s]%s %s\n' "$C_CYAN" "$index" "$C_RESET" "$label"
        printf '      Public key: %s  ·  Истекает: %s  ·  Статус: ' \
            "$(mask_optional_value "$public_key")" "$(format_date_local "$expires")"
        status_display "$status"
        printf '\n'

        if (( index < total )); then
            printf '      %s────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"
        fi
    done < <(jq -c '.registrations[]' "$REGISTRY_FILE")
}

confirm_revoke() {
    local registration="$1"
    local status expires raw_label public_key created

    raw_label="$(jq -r '.label // empty' <<< "$registration")"
    status="$(registration_status "$registration")"
    expires="$(jq -r '.expires_at // empty' <<< "$registration")"
    created="$(jq -r '.created_at // empty' <<< "$registration")"
    public_key="$(jq -r '.public_key // empty' <<< "$registration")"

    printf '\n%sНайдена регистрация:%s\n' "$C_BOLD" "$C_RESET"
    print_field "Метка" "${raw_label:-—}"
    print_field "Public key" "$(mask_optional_value "$public_key")"
    print_field "Создана" "$(format_date_local "$created")"
    print_field "Истекает" "$(format_date_local "$expires")"
    print_field_prefix "Статус"
    status_display "$status"
    printf '\n'

    if [[ "${YES:-0}" -eq 1 ]]; then
        return 0
    fi

    [[ -t 0 ]] || {
        error "Для неинтерактивного отзыва добавьте --yes."
        return 1
    }

    while true; do
        printf '\n'
        print_danger_item "1" "Отозвать эту регистрацию"
        print_menu_item "0" "Отмена"
        local answer
        read_menu_choice answer
        case "$answer" in
            1) return 0 ;;
            0) return 1 ;;
            *) warn "Выберите 1 или 0." ;;
        esac
    done
}

revoke_registration_record() {
    local registration="$1"
    local reason="${2:-manual}"
    local require_confirmation="${3:-1}"

    local id token revoked_at name
    id="$(jq -r '.id // empty' <<< "$registration")"
    token="$(jq -r '.token // empty' <<< "$registration")"
    revoked_at="$(jq -r '.revoked_at // empty' <<< "$registration")"
    name="$(display_name_for_registration "$registration")"

    if [[ -n "$revoked_at" ]]; then
        info "${name}: регистрация уже отмечена как отозванная ($(format_date_local "$revoked_at"))."
        return 0
    fi

    if [[ -z "$id" || -z "$token" ]]; then
        error "${name}: в реестре отсутствует id или token."
        return 1
    fi

    if (( require_confirmation == 1 )); then
        confirm_revoke "$registration" || {
            info "Отзыв отменён."
            return 0
        }
    fi

    info "Отзываю регистрацию: ${name}..."

    if ! revoke_api_registration "$id" "$token"; then
        error "Локальная запись не изменена. Отзыв можно повторить позже."
        return 1
    fi

    local now
    now="$(date -u +%FT%TZ)"

    if ! mark_registration_revoked "$id" "$reason" "$now"; then
        error "Регистрация удалена на сервере, но registrations.json обновить не удалось."
        error "Нужно вручную отметить id=${id} как отозванный."
        return 1
    fi

    ok "${name}: регистрация успешно отозвана."
    info "Локальный конфиг не удалялся."
}

interactive_revoke_by_index() {
    [[ -t 0 ]] || {
        error "Интерактивный отзыв требует терминал."
        return 1
    }

    print_registration_list

    local index registration
    while true; do
        printf '\nНомер регистрации для отзыва [0 — отмена]: '
        read -r index

        [[ -n "$index" ]] || continue
        [[ "$index" == "0" ]] && return 0

        if [[ ! "$index" =~ ^[1-9][0-9]*$ ]]; then
            warn "Введите номер регистрации из списка или 0 для отмены."
            continue
        fi

        registration="$(get_registration_by_index "$index")"
        if [[ -z "$registration" ]]; then
            warn "Регистрации с номером ${index} нет."
            continue
        fi

        break
    done

    revoke_registration_record "$registration" manual 1
}

report_config_lookup_error() {
    local file="$1"
    local rc="$2"
    error "Не удалось определить регистрацию по файлу: $file"
    error "Причина: $(config_lookup_error_text "$rc")."
}

offer_delete_queue_file() {
    local file="$1"
    local expected_public_key="$2"

    [[ -t 0 ]] || return 0

    printf '\n'
    print_danger_item "1" "Удалить этот файл из revoke/"
    print_menu_item "0" "Оставить файл"

    local answer
    while true; do
        read_menu_choice answer
        case "$answer" in
            1)
                local current_public_key rc
                current_public_key="$(public_key_from_config_file "$file")" || {
                    rc=$?
                    warn "Файл изменился или больше не читается; удаление отменено ($(config_lookup_error_text "$rc"))."
                    return 0
                }
                if [[ "$current_public_key" != "$expected_public_key" ]]; then
                    warn "Содержимое файла изменилось после проверки; удаление отменено."
                    return 0
                fi
                rm -- "$file"
                ok "Файл удалён из revoke/: $(basename -- "$file")"
                return 0
                ;;
            0)
                info "Файл оставлен в revoke/."
                return 0
                ;;
            *)
                warn "Выберите 1 или 0."
                ;;
        esac
    done
}

revoke_config_file() {
    local input_path="$1"
    local queue_cleanup="${2:-0}"

    ensure_dependencies revoke-file || return 1
    init_registry || return 1

    local file
    file="$(normalize_input_path "$input_path")"

    local public_key registration rc
    public_key="$(public_key_from_config_file "$file")" || {
        rc=$?
        report_config_lookup_error "$file" "$rc"
        return 1
    }

    registration="$(find_registration_by_public_key "$public_key")" || {
        rc=$?
        report_config_lookup_error "$file" "$rc"
        return 1
    }

    local revoked_at id index
    revoked_at="$(jq -r '.revoked_at // empty' <<< "$registration")"
    id="$(jq -r '.id // empty' <<< "$registration")"
    index="$(registration_index_by_id "$id")"

    printf '\n%sФайл:%s %s\n' "$C_BOLD" "$C_RESET" "$file"
    [[ -n "$index" ]] && printf '  Запись реестра:           #%s\n' "$index"

    if [[ -n "$revoked_at" ]]; then
        info "Эта регистрация уже отозвана ($(format_date_local "$revoked_at"))."
        if (( queue_cleanup == 1 )); then
            offer_delete_queue_file "$file" "$public_key"
        fi
        return 0
    fi

    if ! revoke_registration_record "$registration" manual 1; then
        return 1
    fi

    # При отмене revoke_registration_record возвращает 0, поэтому перед удалением
    # подтверждаем, что запись действительно получила revoked_at.
    registration="$(get_registration_by_id "$id")"
    revoked_at="$(jq -r '.revoked_at // empty' <<< "$registration")"
    if [[ -n "$revoked_at" && "$queue_cleanup" -eq 1 ]]; then
        offer_delete_queue_file "$file" "$public_key"
    fi
}

REVOKE_SCAN_FILES=()
REVOKE_SCAN_STATUSES=()
REVOKE_SCAN_DETAILS=()
REVOKE_SCAN_PUBLIC_KEYS=()

scan_revoke_directory() {
    local input_dir="$1"
    local directory
    directory="$(normalize_input_path "$input_dir")"

    [[ -d "$directory" ]] || {
        error "Директория не найдена: $directory"
        return 1
    }
    [[ -r "$directory" && -x "$directory" ]] || {
        error "Нет доступа к директории: $directory"
        return 1
    }

    REVOKE_SCAN_FILES=()
    REVOKE_SCAN_STATUSES=()
    REVOKE_SCAN_DETAILS=()
    REVOKE_SCAN_PUBLIC_KEYS=()

    local nullglob_was=0 nocaseglob_was=0 dotglob_was=0
    shopt -q nullglob && nullglob_was=1
    shopt -q nocaseglob && nocaseglob_was=1
    shopt -q dotglob && dotglob_was=1
    shopt -s nullglob nocaseglob dotglob
    local candidates=("$directory"/*.conf)
    (( nullglob_was == 1 )) || shopt -u nullglob
    (( nocaseglob_was == 1 )) || shopt -u nocaseglob
    (( dotglob_was == 1 )) || shopt -u dotglob

    local -A seen=()
    local file public_key registration rc status detail primary revoked_at name

    for file in "${candidates[@]}"; do
        [[ -f "$file" ]] || continue

        REVOKE_SCAN_FILES+=("$file")
        public_key=""
        registration=""
        primary=""

        public_key="$(public_key_from_config_file "$file")" || {
            rc=$?
            REVOKE_SCAN_STATUSES+=("invalid")
            REVOKE_SCAN_DETAILS+=("$(config_lookup_error_text "$rc")")
            REVOKE_SCAN_PUBLIC_KEYS+=("")
            continue
        }

        if [[ -n "${seen[$public_key]:-}" ]]; then
            primary="${seen[$public_key]}"
            REVOKE_SCAN_STATUSES+=("duplicate")
            REVOKE_SCAN_DETAILS+=("дубликат файла #${primary}")
            REVOKE_SCAN_PUBLIC_KEYS+=("$public_key")
            continue
        fi
        seen["$public_key"]="${#REVOKE_SCAN_FILES[@]}"

        registration="$(find_registration_by_public_key "$public_key")" || {
            rc=$?
            if [[ "$rc" -eq 20 ]]; then
                status="unknown"
                detail="регистрация не найдена в реестре"
            elif [[ "$rc" -eq 21 ]]; then
                status="conflict"
                detail="конфликт: public_key встречается в реестре несколько раз"
            else
                status="invalid"
                detail="$(config_lookup_error_text "$rc")"
            fi
            REVOKE_SCAN_STATUSES+=("$status")
            REVOKE_SCAN_DETAILS+=("$detail")
            REVOKE_SCAN_PUBLIC_KEYS+=("$public_key")
            continue
        }

        revoked_at="$(jq -r '.revoked_at // empty' <<< "$registration")"
        name="$(display_name_for_registration "$registration")"
        if [[ -n "$revoked_at" ]]; then
            status="revoked"
            detail="${name} — уже отозвана"
        else
            status="ready"
            detail="$name"
        fi

        REVOKE_SCAN_STATUSES+=("$status")
        REVOKE_SCAN_DETAILS+=("$detail")
        REVOKE_SCAN_PUBLIC_KEYS+=("$public_key")
    done
}

revoke_scan_status_text() {
    case "$1" in
        ready) printf 'ГОТОВ К ОТЗЫВУ' ;;
        revoked) printf 'УЖЕ ОТОЗВАН' ;;
        unknown) printf 'НЕ НАЙДЕН В РЕЕСТРЕ' ;;
        invalid) printf 'НЕКОРРЕКТНЫЙ КОНФИГ' ;;
        duplicate) printf 'ДУБЛИКАТ' ;;
        conflict) printf 'КОНФЛИКТ РЕЕСТРА' ;;
        *) printf '%s' "$1" ;;
    esac
}

revoke_scan_status_display() {
    local status="$1"
    local text padded
    text="$(revoke_scan_status_text "$status")"
    printf -v padded '%-24s' "$text"

    case "$status" in
        ready) printf '%s%s%s' "$C_GREEN" "$padded" "$C_RESET" ;;
        revoked|duplicate) printf '%s%s%s' "$C_DIM" "$padded" "$C_RESET" ;;
        unknown) printf '%s%s%s' "$C_YELLOW" "$padded" "$C_RESET" ;;
        invalid|conflict) printf '%s%s%s' "$C_RED" "$padded" "$C_RESET" ;;
        *) printf '%s' "$padded" ;;
    esac
}

print_revoke_scan() {
    local i status

    if (( ${#REVOKE_SCAN_FILES[@]} == 0 )); then
        printf '  Подходящих *.conf не найдено.\n'
        return 0
    fi

    for ((i = 0; i < ${#REVOKE_SCAN_FILES[@]}; i++)); do
        status="${REVOKE_SCAN_STATUSES[$i]}"
        printf '  %s[%d]%s %s\n' "$C_CYAN" "$((i + 1))" "$C_RESET" \
            "$(basename -- "${REVOKE_SCAN_FILES[$i]}")"
        printf '      '
        revoke_scan_status_display "$status"
        printf ' · %s\n' "${REVOKE_SCAN_DETAILS[$i]}"
    done
}

queue_config_count() {
    ensure_dependencies list >/dev/null 2>&1 || return 1
    init_registry >/dev/null 2>&1 || return 1

    local nullglob_was=0 nocaseglob_was=0 dotglob_was=0
    shopt -q nullglob && nullglob_was=1
    shopt -q nocaseglob && nocaseglob_was=1
    shopt -q dotglob && dotglob_was=1
    shopt -s nullglob nocaseglob dotglob
    local files=("$REVOKE_DIR"/*.conf)
    (( nullglob_was == 1 )) || shopt -u nullglob
    (( nocaseglob_was == 1 )) || shopt -u nocaseglob
    (( dotglob_was == 1 )) || shopt -u dotglob

    local count=0 file
    for file in "${files[@]}"; do
        [[ -f "$file" ]] && count=$((count + 1))
    done
    printf '%s' "$count"
}

interactive_revoke_queue_file() {
    ensure_dependencies revoke-file || return 1
    init_registry || return 1
    scan_revoke_directory "$REVOKE_DIR" || return 1

    if (( ${#REVOKE_SCAN_FILES[@]} == 0 )); then
        info "В revoke/ нет *.conf для обработки."
        return 0
    fi

    print_revoke_scan

    local choice
    while true; do
        printf '\nНомер файла [0 — назад]: '
        read -r choice
        [[ -n "$choice" ]] || continue
        [[ "$choice" == "0" ]] && return 0
        if [[ ! "$choice" =~ ^[1-9][0-9]*$ ]] || (( choice > ${#REVOKE_SCAN_FILES[@]} )); then
            warn "Введите номер файла из списка или 0."
            continue
        fi
        break
    done

    revoke_config_file "${REVOKE_SCAN_FILES[$((choice - 1))]}" 1
}

interactive_revoke_path() {
    ensure_dependencies revoke-file || return 1
    init_registry || return 1

    local path
    printf 'Путь к .conf [0 — назад]: '
    IFS= read -r path
    [[ -n "$path" ]] || return 0
    [[ "$path" == "0" ]] && return 0

    revoke_config_file "$path" 0
}

confirm_batch_revoke() {
    local ready_count="$1"

    if [[ "${YES:-0}" -eq 1 ]]; then
        return 0
    fi

    [[ -t 0 ]] || {
        error "Для неинтерактивного массового отзыва добавьте --yes."
        return 1
    }

    printf '\n'
    print_danger_item "1" "Подтвердить массовый отзыв (${ready_count})"
    print_menu_item "0" "Отмена"

    local answer
    while true; do
        read_menu_choice answer
        case "$answer" in
            1) return 0 ;;
            0) return 1 ;;
            *) warn "Выберите 1 или 0." ;;
        esac
    done
}

remove_batch_queue_files() {
    local -n files_ref="$1"
    local -n keys_ref="$2"
    local removed=0 kept=0 i current_public_key rc

    for ((i = 0; i < ${#files_ref[@]}; i++)); do
        current_public_key="$(public_key_from_config_file "${files_ref[$i]}")" || {
            rc=$?
            warn "Не удаляю $(basename -- "${files_ref[$i]}"): файл изменён или не читается ($(config_lookup_error_text "$rc"))."
            kept=$((kept + 1))
            continue
        }
        if [[ "$current_public_key" != "${keys_ref[$i]}" ]]; then
            warn "Не удаляю $(basename -- "${files_ref[$i]}"): содержимое изменилось после отзыва."
            kept=$((kept + 1))
            continue
        fi
        if rm -- "${files_ref[$i]}"; then
            removed=$((removed + 1))
        else
            warn "Не удалось удалить: ${files_ref[$i]}"
            kept=$((kept + 1))
        fi
    done

    ok "Удалено из revoke/: ${removed}. Оставлено: ${kept}."
}

revoke_directory() {
    local input_dir="$1"
    local allow_queue_cleanup="${2:-0}"

    ensure_dependencies revoke-file || return 1
    init_registry || return 1

    local directory
    directory="$(normalize_input_path "$input_dir")"
    scan_revoke_directory "$directory" || return 1

    printf '\n%sПроверка директории:%s %s\n\n' "$C_BOLD" "$C_RESET" "$directory"
    print_revoke_scan

    local ready=0 already=0 unknown=0 invalid=0 duplicate=0 conflict=0 i
    for ((i = 0; i < ${#REVOKE_SCAN_FILES[@]}; i++)); do
        case "${REVOKE_SCAN_STATUSES[$i]}" in
            ready) ready=$((ready + 1)) ;;
            revoked) already=$((already + 1)) ;;
            unknown) unknown=$((unknown + 1)) ;;
            invalid) invalid=$((invalid + 1)) ;;
            duplicate) duplicate=$((duplicate + 1)) ;;
            conflict) conflict=$((conflict + 1)) ;;
        esac
    done

    printf '\n%sСводка проверки:%s\n' "$C_BOLD" "$C_RESET"
    print_field "Готовы к отзыву" "$ready"
    print_field "Уже отозваны" "$already"
    print_field "Не найдены" "$unknown"
    print_field "Некорректные" "$invalid"
    print_field "Дубликаты" "$duplicate"
    print_field "Конфликты реестра" "$conflict"

    if (( ready == 0 )); then
        info "Нет регистраций, готовых к отзыву. Никаких API-запросов не выполнено."
        if (( unknown > 0 || invalid > 0 || conflict > 0 )); then
            return 1
        fi
        return 0
    fi

    if ! confirm_batch_revoke "$ready"; then
        info "Массовый отзыв отменён."
        return 0
    fi

    local success=0 failed=0 changed=0 skipped=$((already + unknown + invalid + duplicate + conflict))
    local file expected_key current_key registration rc revoked_at
    local successful_files=()
    local successful_keys=()

    for ((i = 0; i < ${#REVOKE_SCAN_FILES[@]}; i++)); do
        [[ "${REVOKE_SCAN_STATUSES[$i]}" == "ready" ]] || continue

        file="${REVOKE_SCAN_FILES[$i]}"
        expected_key="${REVOKE_SCAN_PUBLIC_KEYS[$i]}"

        current_key="$(public_key_from_config_file "$file")" || {
            rc=$?
            error "$(basename -- "$file"): файл изменился после проверки ($(config_lookup_error_text "$rc"))."
            failed=$((failed + 1))
            changed=$((changed + 1))
            continue
        }
        if [[ "$current_key" != "$expected_key" ]]; then
            error "$(basename -- "$file"): содержимое изменилось после проверки; пропускаю."
            failed=$((failed + 1))
            changed=$((changed + 1))
            continue
        fi

        registration="$(find_registration_by_public_key "$expected_key")" || {
            rc=$?
            error "$(basename -- "$file"): состояние реестра изменилось ($(config_lookup_error_text "$rc"))."
            failed=$((failed + 1))
            continue
        }

        revoked_at="$(jq -r '.revoked_at // empty' <<< "$registration")"
        if [[ -n "$revoked_at" ]]; then
            info "$(display_name_for_registration "$registration"): уже отозвана; пропускаю."
            skipped=$((skipped + 1))
            continue
        fi

        if revoke_registration_record "$registration" manual-batch 0; then
            success=$((success + 1))
            successful_files+=("$file")
            successful_keys+=("$expected_key")
        else
            failed=$((failed + 1))
        fi
    done

    printf '\n%sИтог массового отзыва:%s\n' "$C_BOLD" "$C_RESET"
    print_field "Успешно отозвано" "$success"
    print_field "Ошибок" "$failed"
    print_field "Пропущено" "$skipped"
    (( changed > 0 )) && print_field "Изменились после проверки" "$changed"

    if (( allow_queue_cleanup == 1 && success > 0 )); then
        if [[ "${YES:-0}" -eq 1 || ! -t 0 ]]; then
            info "Успешно обработанные файлы оставлены в revoke/. --yes никогда не удаляет файлы."
        else
            printf '\n'
            print_danger_item "1" "Удалить успешно отозванные файлы из revoke/ (${success})"
            print_menu_item "0" "Оставить файлы"
            local cleanup_choice
            while true; do
                read_menu_choice cleanup_choice
                case "$cleanup_choice" in
                    1)
                        remove_batch_queue_files successful_files successful_keys
                        break
                        ;;
                    0)
                        info "Файлы оставлены в revoke/."
                        break
                        ;;
                    *) warn "Выберите 1 или 0." ;;
                esac
            done
        fi
    fi

    (( failed == 0 && unknown == 0 && invalid == 0 && conflict == 0 ))
}

revoke_menu_ui() {
    [[ -t 0 ]] || {
        error "Интерактивное меню отзыва требует терминал."
        return 1
    }

    ensure_dependencies list || return 1
    init_registry || return 1

    while true; do
        clear_ui
        print_title "WARP Amnezia Manager › Регистрации › Отзыв"
        printf '\n'
        print_field "Файлов в revoke/" "$(queue_config_count)"
        print_divider
        printf '\n'
        print_menu_item "1" "Отозвать по номеру регистрации"
        print_menu_item "2" "Отозвать один конфиг из revoke/"
        print_menu_item "3" "Отозвать конфиг по указанному пути"
        print_menu_item "4" "Отозвать все подходящие конфиги из revoke/"
        print_menu_item "0" "Назад"

        local choice
        read_menu_choice choice
        case "$choice" in
            1)
                clear_ui
                print_title "Отзыв › По номеру регистрации"
                printf '\n'
                interactive_revoke_by_index || true
                pause_ui
                ;;
            2)
                clear_ui
                print_title "Отзыв › Один конфиг из revoke/"
                printf '\n'
                interactive_revoke_queue_file || true
                pause_ui
                ;;
            3)
                clear_ui
                print_title "Отзыв › Файл по указанному пути"
                printf '\n'
                interactive_revoke_path || true
                pause_ui
                ;;
            4)
                clear_ui
                print_title "Отзыв › Все конфиги из revoke/"
                revoke_directory "$REVOKE_DIR" 1 || true
                pause_ui
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–4."
                pause_ui
                ;;
        esac
    done
}

interactive_revoke() {
    revoke_menu_ui
}

revoke_target() {
    local target="$1"

    if [[ "$target" =~ ^[1-9][0-9]*$ ]]; then
        ensure_dependencies manage || return 1
        init_registry || return 1
        local registration
        registration="$(get_registration_by_index "$target")"
        [[ -n "$registration" ]] || {
            error "Регистрации с номером ${target} нет."
            return 1
        }
        revoke_registration_record "$registration" manual 1
        return
    fi

    revoke_config_file "$target" 0
}

revoke_by_id() {
    local id="$1"

    ensure_dependencies manage || return 1
    init_registry || return 1

    local registration
    registration="$(get_registration_by_id "$id")"
    [[ -n "$registration" ]] || {
        error "Registration ID '$id' не найден в локальном реестре."
        return 1
    }

    revoke_registration_record "$registration" manual 1
}

revoke_expired() {
    local dry_run="$1"
    local quiet="$2"

    local QUIET="$quiet"
    ensure_dependencies manage || return 1
    init_registry || return 1

    local now_epoch
    now_epoch="$(date -u +%s)"

    local expired_count=0 revoked_count=0 failed_count=0
    local registration

    info "Проверяю сроки действия регистраций..."

    # Работаем со снимком списка. Каждый успешный отзыв атомарно обновляет реальный JSON.
    while IFS= read -r registration; do
        local revoked_at expires_at expires_epoch id token name
        revoked_at="$(jq -r '.revoked_at // empty' <<< "$registration")"
        expires_at="$(jq -r '.expires_at // empty' <<< "$registration")"

        [[ -n "$revoked_at" || -z "$expires_at" ]] && continue

        if ! expires_epoch="$(date -u -d "$expires_at" +%s 2>/dev/null)"; then
            warn "Некорректный expires_at у регистрации $(jq -r '.id // "<без id>"' <<< "$registration"): $expires_at"
            failed_count=$((failed_count + 1))
            continue
        fi

        (( expires_epoch <= now_epoch )) || continue

        expired_count=$((expired_count + 1))
        name="$(display_name_for_registration "$registration")"

        if (( dry_run == 1 )); then
            printf '[EXPIRED] %s — срок истёк %s\n' "$name" "$(format_date_local "$expires_at")"
            continue
        fi

        if revoke_registration_record "$registration" expired 0; then
            revoked_count=$((revoked_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done < <(jq -c '.registrations[]' "$REGISTRY_FILE")

    if (( dry_run == 1 )); then
        if (( expired_count == 0 )); then
            ok "Истёкших активных регистраций нет."
        else
            info "Истёкших регистраций: ${expired_count}. Никаких изменений не выполнено."
        fi
        return 0
    fi

    if (( expired_count == 0 )); then
        ok "Истёкших активных регистраций нет."
    else
        info "Итог: истекло ${expired_count}, отозвано ${revoked_count}, ошибок ${failed_count}."
    fi

    (( failed_count == 0 ))
}

# -----------------------------------------------------------------------------
# Интерактивный интерфейс
# -----------------------------------------------------------------------------

UI_LABELS=()
UI_LABEL_MODE_NAME="Без меток"
UI_TTL=""
UI_EXPIRES=""
GENERATION_LABELS=()

init_ui_labels() {
    local count="$1"
    UI_LABELS=()
    local i
    for ((i = 0; i < count; i++)); do
        UI_LABELS+=("")
    done
    UI_LABEL_MODE_NAME="Без меток"
}

count_ui_labels() {
    local count=0 label
    for label in "${UI_LABELS[@]}"; do
        [[ -n "$label" ]] && count=$((count + 1))
    done
    printf '%s' "$count"
}

review_labels_ui() {
    local count="$1"
    clear_ui
    print_title "Создание › Метки / комментарии"
    printf '\n'

    local i label
    for ((i = 0; i < count; i++)); do
        label="${UI_LABELS[$i]:-}"
        printf '  '
        fit_text "$((i + 1))." 5
        printf '%s\n' "${label:-—}"
    done

    printf '\n'
    print_field "Заполнено" "$(count_ui_labels) из $count"
    pause_ui
}

parse_index_spec() {
    local spec="$1"
    local count="$2"
    local compact="${spec//[[:space:]]/}"

    [[ -n "$compact" ]] || return 1

    local -A seen=()
    local -a parts=()
    IFS=',' read -r -a parts <<< "$compact"

    local part start end i
    for part in "${parts[@]}"; do
        if [[ "$part" =~ ^([1-9][0-9]*)-([1-9][0-9]*)$ ]]; then
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"
            (( start <= end && end <= count )) || return 1
            for ((i = start; i <= end; i++)); do
                seen[$i]=1
            done
        elif [[ "$part" =~ ^[1-9][0-9]*$ ]]; then
            (( part <= count )) || return 1
            seen[$part]=1
        else
            return 1
        fi
    done

    for ((i = 1; i <= count; i++)); do
        [[ -n "${seen[$i]:-}" ]] && printf '%s\n' "$i"
    done
}

configure_labels_selective_ui() {
    local count="$1"
    local original_mode="$UI_LABEL_MODE_NAME"
    local -a original_labels=("${UI_LABELS[@]}")

    init_ui_labels "$count"
    UI_LABEL_MODE_NAME="Выборочно"

    while true; do
        clear_ui
        print_title "Создание › Выборочные метки"
        printf '\n  Можно указывать номера и диапазоны: 1,3,5-7\n'
        printf '  Неуказанные конфиги останутся без метки.\n\n'
        print_field "Сейчас заполнено" "$(count_ui_labels) из $count"
        print_divider
        print_menu_item "1" "Задать / изменить метку выбранным конфигам"
        print_menu_item "2" "Просмотреть текущие метки"
        print_menu_item "3" "Очистить все метки"
        print_menu_item "4" "Готово"
        print_menu_item "0" "Отменить изменения"
        local choice
        read_menu_choice choice

        case "$choice" in
            1)
                printf 'Номера конфигов: '
                local spec
                read -r spec

                local -a indexes=()
                mapfile -t indexes < <(parse_index_spec "$spec" "$count" || true)
                if [[ ${#indexes[@]} -eq 0 ]]; then
                    warn "Не удалось разобрать номера. Пример: 1,3,5-7"
                    pause_ui
                    continue
                fi

                printf 'Метка/комментарий (Enter — очистить у выбранных): '
                local label
                read -r label
                label="$(sanitize_label "$label")"

                local index
                for index in "${indexes[@]}"; do
                    UI_LABELS[$((index - 1))]="$label"
                done
                ok "Обновлено конфигов: ${#indexes[@]}."
                pause_ui
                ;;
            2)
                review_labels_ui "$count"
                ;;
            3)
                init_ui_labels "$count"
                UI_LABEL_MODE_NAME="Выборочно"
                ok "Все метки очищены."
                pause_ui
                ;;
            4)
                return 0
                ;;
            0)
                UI_LABELS=("${original_labels[@]}")
                UI_LABEL_MODE_NAME="$original_mode"
                return 1
                ;;
            *)
                warn "Выберите пункт 0–4."
                pause_ui
                ;;
        esac
    done
}

configure_labels_ui() {
    local count="$1"

    if (( count == 1 )); then
        while true; do
            clear_ui
            print_title "Создание › Метка / комментарий"
            printf '\n  Текущая метка: %s\n\n' "${UI_LABELS[0]:-—}"
            print_menu_item "1" "Оставить без метки"
            print_menu_item "2" "Задать метку / комментарий"
            print_menu_item "3" "Просмотреть текущую метку"
            print_menu_item "0" "Назад"
            local single_choice
            read_menu_choice single_choice
            case "$single_choice" in
                1)
                    init_ui_labels 1
                    UI_LABEL_MODE_NAME="Без меток"
                    return 0
                    ;;
                2)
                    printf 'Метка/комментарий: '
                    local single_label
                    read -r single_label
                    single_label="$(sanitize_label "$single_label")"
                    if [[ -z "$single_label" ]]; then
                        warn "Метка пустая. Используйте пункт 1, если метка не нужна."
                        pause_ui
                        continue
                    fi
                    UI_LABELS=("$single_label")
                    UI_LABEL_MODE_NAME="Индивидуальная"
                    return 0
                    ;;
                3)
                    review_labels_ui 1
                    ;;
                0)
                    return 0
                    ;;
                *)
                    warn "Выберите пункт 0–3."
                    pause_ui
                    ;;
            esac
        done
    fi

    while true; do
        clear_ui
        print_title "Создание › Метки / комментарии"
        printf '\n'
        print_field "Текущий режим" "$UI_LABEL_MODE_NAME"
        print_field "Заполнено" "$(count_ui_labels) из $count"
        printf '\n'
        print_menu_item "1" "Без меток"
        print_menu_item "2" "Одна одинаковая метка для всех"
        print_menu_item "3" "Общая метка + номер (например USER #1, #2...)"
        print_menu_item "4" "Задать каждому конфигу отдельно"
        print_menu_item "5" "Задать метки только выбранным конфигам"
        print_menu_item "6" "Просмотреть текущие метки"
        print_menu_item "0" "Назад"
        local choice
        read_menu_choice choice

        case "$choice" in
            1)
                init_ui_labels "$count"
                ok "Метки отключены."
                pause_ui
                return 0
                ;;
            2)
                printf 'Общая метка/комментарий: '
                local common_label
                read -r common_label
                common_label="$(sanitize_label "$common_label")"
                if [[ -z "$common_label" ]]; then
                    warn "Метка не должна быть пустой. Для пустых меток используйте пункт 1."
                    pause_ui
                    continue
                fi
                UI_LABELS=()
                local i
                for ((i = 0; i < count; i++)); do
                    UI_LABELS+=("$common_label")
                done
                UI_LABEL_MODE_NAME="Одинаковая для всех"
                return 0
                ;;
            3)
                printf 'Основа метки (например USER): '
                local base_label
                read -r base_label
                base_label="$(sanitize_label "$base_label")"
                if [[ -z "$base_label" ]]; then
                    warn "Основа метки не должна быть пустой."
                    pause_ui
                    continue
                fi
                UI_LABELS=()
                local i
                for ((i = 1; i <= count; i++)); do
                    UI_LABELS+=("${base_label} #${i}")
                done
                UI_LABEL_MODE_NAME="Общая + номер"
                return 0
                ;;
            4)
                UI_LABELS=()
                local i label
                printf '\nEnter оставляет конкретный конфиг без метки.\n\n'
                for ((i = 1; i <= count; i++)); do
                    printf 'Конфиг %s/%s — метка: ' "$i" "$count"
                    read -r label
                    UI_LABELS+=("$(sanitize_label "$label")")
                done
                UI_LABEL_MODE_NAME="Индивидуально"
                return 0
                ;;
            5)
                if configure_labels_selective_ui "$count"; then
                    return 0
                fi
                ;;
            6)
                review_labels_ui "$count"
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–6."
                pause_ui
                ;;
        esac
    done
}

choose_expiry_ui() {
    local title="${1:-Срок действия}"
    local previous_ttl="${UI_TTL:-}"
    local previous_expires="${UI_EXPIRES:-}"

    while true; do
        clear_ui
        print_title "$title"
        printf '\n'
        print_menu_item "1" "Бессрочно"
        print_menu_item "2" "1 день"
        print_menu_item "3" "7 дней"
        print_menu_item "4" "30 дней"
        print_menu_item "5" "Указать свой срок (например 12h, 90d, 4w)"
        print_menu_item "6" "Указать конкретную дату окончания"
        print_menu_item "0" "Назад без изменений"
        local choice
        read_menu_choice choice

        case "$choice" in
            1)
                UI_TTL=""
                UI_EXPIRES=""
                return 0
                ;;
            2)
                UI_TTL="1d"
                UI_EXPIRES=""
                return 0
                ;;
            3)
                UI_TTL="7d"
                UI_EXPIRES=""
                return 0
                ;;
            4)
                UI_TTL="30d"
                UI_EXPIRES=""
                return 0
                ;;
            5)
                printf 'Срок: '
                local custom_ttl
                read -r custom_ttl
                if duration_to_seconds "$custom_ttl" >/dev/null; then
                    UI_TTL="$custom_ttl"
                    UI_EXPIRES=""
                    return 0
                fi
                warn "Формат: число + m/h/d/w, например 30m, 12h, 7d, 4w."
                pause_ui
                ;;
            6)
                printf 'Дата окончания (например 2026-12-31 23:59): '
                local input normalized
                read -r input
                if normalized="$(normalize_expiry_date "$input")"; then
                    UI_TTL=""
                    UI_EXPIRES="$normalized"
                    return 0
                fi
                warn "Не удалось разобрать будущую дату."
                pause_ui
                ;;
            0)
                UI_TTL="$previous_ttl"
                UI_EXPIRES="$previous_expires"
                return 1
                ;;
            *)
                warn "Выберите пункт 0–6."
                pause_ui
                ;;
        esac
    done
}

expiry_summary() {
    if [[ -n "${UI_TTL:-}" ]]; then
        printf '%s' "$UI_TTL"
    elif [[ -n "${UI_EXPIRES:-}" ]]; then
        printf 'до %s' "$(format_date_local "$UI_EXPIRES")"
    else
        printf 'бессрочно'
    fi
}

preview_creation_ui() {
    local count="$1"
    clear_ui
    print_title "Создание › Предпросмотр"

    printf '\n'
    print_field "Количество" "$count"
    print_field "Срок" "$(expiry_summary)"
    print_field "Метки" "$UI_LABEL_MODE_NAME ($(count_ui_labels)/$count заполнено)"
    print_divider

    local i label
    for ((i = 0; i < count; i++)); do
        label="${UI_LABELS[$i]:-}"
        printf '  '
        fit_text "$((i + 1))." 5
        printf '%s\n' "${label:-—}"
    done

    pause_ui
}


create_wizard() {
    local count=1
    init_ui_labels "$count"
    UI_TTL=""
    UI_EXPIRES=""

    while true; do
        clear_ui
        print_title "WARP Amnezia Manager › Создание"

        printf '\n  Параметры новой партии:\n'
        print_divider
        print_field "Количество" "$count"
        print_field "Метки" "$UI_LABEL_MODE_NAME — заполнено $(count_ui_labels)/$count"
        print_field "Срок" "$(expiry_summary)"
        print_divider
        printf '\n'
        print_menu_item "1" "Изменить количество конфигов"
        print_menu_item "2" "Настроить метки / комментарии"
        print_menu_item "3" "Настроить срок действия"
        print_menu_item "4" "Предпросмотр партии"
        print_menu_item "5" "Создать конфигурации"
        print_menu_item "0" "Отмена и возврат в главное меню"
        local choice
        read_menu_choice choice

        case "$choice" in
            1)
                printf 'Количество конфигов: '
                local new_count
                read -r new_count
                if [[ ! "$new_count" =~ ^[1-9][0-9]*$ ]]; then
                    warn "Количество должно быть положительным целым числом."
                    pause_ui
                    continue
                fi

                if [[ "$new_count" != "$count" ]]; then
                    count="$new_count"
                    init_ui_labels "$count"
                    info "Количество изменено. Метки сброшены, чтобы не перепутать назначения."
                    pause_ui
                fi
                ;;
            2)
                configure_labels_ui "$count"
                ;;
            3)
                choose_expiry_ui "Создание › Срок действия" || true
                ;;
            4)
                preview_creation_ui "$count"
                ;;
            5)
                clear_ui
                print_title "Создание › Подтверждение"
                printf '\n'
                print_field "Будет создано конфигов" "$count"
                print_field "Метки" "$UI_LABEL_MODE_NAME ($(count_ui_labels)/$count)"
                print_field "Срок" "$(expiry_summary)"
                printf '\n'
                print_menu_item "1" "Создать"
                print_menu_item "0" "Вернуться к настройке"
                local confirm
                read_menu_choice confirm
                if [[ "$confirm" != "1" ]]; then
                    [[ "$confirm" == "0" ]] || {
                        warn "Выберите 1 или 0."
                        pause_ui
                    }
                    continue
                fi

                GENERATION_LABELS=("${UI_LABELS[@]}")
                printf '\n'
                if generate_configs "$count" "" "$UI_TTL" "$UI_EXPIRES" 1; then
                    ok "Все данные регистрации сохранены в .data/registrations.json."
                    GENERATION_LABELS=()

                    while true; do
                        printf '\n'
                        print_menu_item "1" "Перейти к управлению регистрациями"
                        print_menu_item "0" "Вернуться в главное меню"
                        local after_choice
                        read_menu_choice after_choice
                        case "$after_choice" in
                            1)
                                registrations_menu
                                return 0
                                ;;
                            0)
                                return 0
                                ;;
                            *)
                                warn "Выберите 1 или 0."
                                ;;
                        esac
                    done
                fi
                GENERATION_LABELS=()
                pause_ui
                return 0
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–5."
                pause_ui
                ;;
        esac
    done
}

show_technical_info() {
    local registration="$1"
    local id token public_key config created expires revoked reason

    id="$(jq -r '.id // empty' <<< "$registration")"
    token="$(jq -r '.token // empty' <<< "$registration")"
    public_key="$(jq -r '.public_key // empty' <<< "$registration")"
    config="$(jq -r '.config // empty' <<< "$registration")"
    created="$(jq -r '.created_at // empty' <<< "$registration")"
    expires="$(jq -r '.expires_at // empty' <<< "$registration")"
    revoked="$(jq -r '.revoked_at // empty' <<< "$registration")"
    reason="$(jq -r '.revoke_reason // empty' <<< "$registration")"

    printf '\n'
    print_field "Registration ID" "$id"
    print_field "Client public key" "$(mask_optional_value "$public_key")"
    print_field "Token" "$(mask_optional_value "$token")"
    print_field "Первоначальный путь" "${config:-—}"
    print_field "Создан" "$(format_date_local "$created")"
    print_field "Истекает" "$(format_date_local "$expires")"
    print_field "Отозван" "$(format_date_local "$revoked")"
    print_field "Причина отзыва" "${reason:-—}"
}

extend_registration_ui() {
    local registration="$1"
    local id expires_at
    id="$(jq -r '.id // empty' <<< "$registration")"
    expires_at="$(jq -r '.expires_at // empty' <<< "$registration")"

    local ttl=""
    while true; do
        clear_ui
        print_title "Регистрация › Продление"
        printf '\n'
        print_menu_item "1" "Продлить на 1 день"
        print_menu_item "2" "Продлить на 7 дней"
        print_menu_item "3" "Продлить на 30 дней"
        print_menu_item "4" "Указать свой срок (например 12h, 90d, 4w)"
        print_menu_item "0" "Назад"
        local choice
        read_menu_choice choice
        case "$choice" in
            1) ttl="1d"; break ;;
            2) ttl="7d"; break ;;
            3) ttl="30d"; break ;;
            4)
                printf 'Срок: '
                read -r ttl
                if duration_to_seconds "$ttl" >/dev/null; then
                    break
                fi
                warn "Некорректный срок. Формат: 30m, 12h, 7d, 4w."
                pause_ui
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–4."
                pause_ui
                ;;
        esac
    done

    local seconds
    seconds="$(duration_to_seconds "$ttl")" || return 1

    local now_epoch base_epoch
    now_epoch="$(date -u +%s)"
    base_epoch="$now_epoch"

    if [[ -n "$expires_at" ]]; then
        local current_epoch
        if current_epoch="$(date -u -d "$expires_at" +%s 2>/dev/null)" && (( current_epoch > now_epoch )); then
            base_epoch="$current_epoch"
        fi
    fi

    local new_expiry
    new_expiry="$(date -u -d "@$((base_epoch + seconds))" +%FT%TZ)"

    update_registration_expiry "$id" "$new_expiry"
    ok "Новый срок: $(format_date_local "$new_expiry")"
}

set_registration_expiry_ui() {
    local registration="$1"
    local id
    id="$(jq -r '.id // empty' <<< "$registration")"

    local saved_ttl="${UI_TTL:-}"
    local saved_expires="${UI_EXPIRES:-}"
    UI_TTL=""
    UI_EXPIRES=""

    if ! choose_expiry_ui "Регистрация › Срок действия"; then
        UI_TTL="$saved_ttl"
        UI_EXPIRES="$saved_expires"
        return 0
    fi

    local expiry=""
    if [[ -n "$UI_TTL" ]]; then
        expiry="$(expiry_from_ttl "$(date -u +%FT%TZ)" "$UI_TTL")"
    elif [[ -n "$UI_EXPIRES" ]]; then
        expiry="$UI_EXPIRES"
    fi

    update_registration_expiry "$id" "$expiry"
    if [[ -n "$expiry" ]]; then
        ok "Срок изменён: $(format_date_local "$expiry")"
    else
        ok "Регистрация теперь бессрочная."
    fi

    UI_TTL="$saved_ttl"
    UI_EXPIRES="$saved_expires"
}

bulk_update_labels_ui() {
    local total
    total="$(jq '.registrations | length' "$REGISTRY_FILE")"

    if (( total == 0 )); then
        warn "Регистраций пока нет."
        pause_ui
        return 0
    fi

    while true; do
        clear_ui
        print_title "Регистрации › Массовые метки"
        printf '\n'
        print_registration_list
        printf '\n'
        print_divider
        printf '\n'
        print_menu_item "1" "Выбрать регистрации по номерам / диапазонам"
        print_menu_item "2" "Выбрать все регистрации"
        print_menu_item "0" "Назад"
        local mode
        read_menu_choice mode

        local -a indexes=()
        case "$mode" in
            1)
                printf 'Номера (например 1,3,5-7): '
                local spec
                read -r spec
                mapfile -t indexes < <(parse_index_spec "$spec" "$total" || true)
                if [[ ${#indexes[@]} -eq 0 ]]; then
                    warn "Не удалось разобрать номера."
                    pause_ui
                    continue
                fi
                ;;
            2)
                local i
                for ((i = 1; i <= total; i++)); do
                    indexes+=("$i")
                done
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–2."
                pause_ui
                continue
                ;;
        esac

        printf 'Новая общая метка/комментарий (Enter — очистить): '
        local label
        read -r label
        label="$(sanitize_label "$label")"

        printf '\n'
        print_field "Выбрано регистраций" "${#indexes[@]}"
        print_field "Новая метка" "${label:-—}"

        local confirm
        while true; do
            printf '\n'
            print_menu_item "1" "Применить"
            print_menu_item "0" "Отмена"
            read_menu_choice confirm
            case "$confirm" in
                1) break ;;
                0)
                    info "Изменения отменены."
                    pause_ui
                    return 0
                    ;;
                *) warn "Выберите 1 или 0." ;;
            esac
        done

        local index registration id updated=0
        for index in "${indexes[@]}"; do
            registration="$(get_registration_by_index "$index")"
            [[ -n "$registration" ]] || continue
            id="$(jq -r '.id // empty' <<< "$registration")"
            [[ -n "$id" ]] || continue
            if update_registration_label "$id" "$label"; then
                updated=$((updated + 1))
            fi
        done

        ok "Метка обновлена у регистраций: ${updated}."
        pause_ui
        return 0
    done
}

registration_details_ui() {
    local index="$1"

    while true; do
        local registration
        registration="$(get_registration_by_index "$index")"
        [[ -n "$registration" ]] || return 0

        local config created expires status raw_label public_key
        raw_label="$(jq -r '.label // empty' <<< "$registration")"
        public_key="$(jq -r '.public_key // empty' <<< "$registration")"
        config="$(jq -r '.config // empty' <<< "$registration")"
        created="$(jq -r '.created_at // empty' <<< "$registration")"
        expires="$(jq -r '.expires_at // empty' <<< "$registration")"
        status="$(registration_status "$registration")"

        clear_ui
        print_title "Регистрация #${index}"
        printf '\n'
        print_field "Метка" "${raw_label:-—}"
        print_field "Public key" "$(mask_optional_value "$public_key")"
        print_field "Первоначальный путь" "${config:-—}"
        print_field "Создан" "$(format_date_local "$created")"
        print_field "Истекает" "$(format_date_local "$expires")"
        print_field_prefix "Статус"
        status_display "$status"
        printf '\n'

        if [[ -n "$config" ]]; then
            if [[ -e "${SCRIPT_DIR}/${config}" ]]; then
                print_field "Исходный файл" "существует"
            else
                print_field "Исходный файл" "удалён или перемещён"
            fi
        else
            print_field "Исходный файл" "не был создан / не привязан"
        fi

        print_divider
        printf '\n'
        print_menu_item "1" "Изменить метку / комментарий"

        if [[ "$status" != "revoked" ]]; then
            print_menu_item "2" "Изменить срок действия"
            print_menu_item "3" "Продлить срок"
            print_menu_item "4" "Сделать бессрочным"
            print_menu_item "5" "Отозвать регистрацию"
            print_menu_item "6" "Техническая информация"
        else
            print_menu_item "2" "Техническая информация"
        fi

        print_menu_item "0" "Назад"
        local choice
        read_menu_choice choice

        if [[ "$status" == "revoked" ]]; then
            case "$choice" in
                1)
                    printf 'Новая метка/комментарий (Enter — очистить): '
                    local new_label
                    read -r new_label
                    new_label="$(sanitize_label "$new_label")"
                    update_registration_label "$(jq -r '.id' <<< "$registration")" "$new_label"
                    ok "Метка обновлена."
                    pause_ui
                    ;;
                2)
                    show_technical_info "$registration"
                    pause_ui
                    ;;
                0)
                    return 0
                    ;;
                *)
                    warn "Выберите пункт 0–2."
                    pause_ui
                    ;;
            esac
            continue
        fi

        case "$choice" in
            1)
                printf 'Новая метка/комментарий (Enter — очистить): '
                local new_label
                read -r new_label
                new_label="$(sanitize_label "$new_label")"
                update_registration_label "$(jq -r '.id' <<< "$registration")" "$new_label"
                ok "Метка обновлена."
                pause_ui
                ;;
            2)
                set_registration_expiry_ui "$registration"
                pause_ui
                ;;
            3)
                extend_registration_ui "$registration" || true
                pause_ui
                ;;
            4)
                update_registration_expiry "$(jq -r '.id' <<< "$registration")" ""
                ok "Регистрация теперь бессрочная."
                pause_ui
                ;;
            5)
                revoke_registration_record "$registration" manual 1 || true
                pause_ui
                ;;
            6)
                show_technical_info "$registration"
                pause_ui
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–6."
                pause_ui
                ;;
        esac
    done
}

registrations_menu() {
    while true; do
        clear_ui
        print_title "WARP Amnezia Manager › Регистрации"
        printf '\n'
        print_registration_list
        printf '\n'
        print_divider
        printf '\n'
        print_menu_item "1" "Открыть регистрацию по номеру"
        print_menu_item "2" "Изменить метки у нескольких регистраций"
        print_menu_item "3" "Отозвать регистрацию"
        print_menu_item "4" "Проверить сроки действия"
        print_menu_item "0" "Назад"
        local choice
        read_menu_choice choice

        case "$choice" in
            1)
                printf 'Номер регистрации [0 — отмена]: '
                local index
                read -r index
                if [[ -z "$index" ]]; then
                    continue
                fi
                if [[ "$index" == "0" ]]; then
                    continue
                fi
                if [[ ! "$index" =~ ^[1-9][0-9]*$ ]]; then
                    warn "Введите номер регистрации из списка."
                    pause_ui
                    continue
                fi

                local registration
                registration="$(get_registration_by_index "$index")"
                if [[ -n "$registration" ]]; then
                    registration_details_ui "$index"
                else
                    warn "Регистрации с номером ${index} нет."
                    pause_ui
                fi
                ;;
            2)
                bulk_update_labels_ui
                ;;
            3)
                revoke_menu_ui
                ;;
            4)
                expiry_check_ui
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–4."
                pause_ui
                ;;
        esac
    done
}

expiry_check_ui() {
    clear_ui
    print_title "WARP Amnezia Manager › Проверка сроков"

    printf '\n  Выполняю безопасную проверку. На этом этапе ничего не отзывается.\n\n'
    revoke_expired 1 0 || true

    local expired
    read -r _active _soon expired _revoked _orphan <<< "$(registry_stats)"

    if (( expired == 0 )); then
        pause_ui
        return 0
    fi

    local answer
    while true; do
        printf '\n'
        print_danger_item "1" "Отозвать все истёкшие регистрации"
        print_menu_item "0" "Назад без изменений"
        read_menu_choice answer

        case "$answer" in
            1)
                printf '\n'
                revoke_expired 0 0 || true
                break
                ;;
            0)
                info "Ничего не изменено."
                break
                ;;
            *)
                warn "Выберите 1 или 0."
                ;;
        esac
    done

    pause_ui
}

main_menu() {
    ensure_dependencies list || return 1
    init_registry || return 1

    while true; do
        clear_ui

        local active soon expired revoked orphan
        read -r active soon expired revoked orphan <<< "$(registry_stats)"

        print_title "WARP Amnezia Manager"
        printf '\n  Состояние локального реестра:\n'
        print_divider
        print_field "Активных" "${C_GREEN}${active}${C_RESET}"
        print_field "Скоро истекают" "${C_YELLOW}${soon}${C_RESET}"
        print_field "Просрочено" "${C_RED}${expired}${C_RESET}"
        print_field "Отозвано" "$revoked"
        print_field "Без конфига" "$orphan"
        print_divider
        printf '\n'
        print_menu_item "1" "Создать конфигурации"
        print_menu_item "2" "Управление регистрациями"
        print_menu_item "3" "Проверить и отключить истёкшие"
        print_menu_item "4" "Справка"
        print_menu_item "0" "Выход"
        local choice
        read_menu_choice choice

        case "$choice" in
            1)
                create_wizard
                ;;
            2)
                registrations_menu
                ;;
            3)
                expiry_check_ui
                ;;
            4)
                clear_ui
                print_title "WARP Amnezia Manager › Справка"
                printf '\n'
                print_help
                pause_ui
                ;;
            0)
                return 0
                ;;
            *)
                warn "Выберите пункт 0–4."
                pause_ui
                ;;
        esac
    done
}


# -----------------------------------------------------------------------------
# Разбор CLI-аргументов
# -----------------------------------------------------------------------------

MODE=""

set_mode() {
    local new_mode="$1"
    if [[ -n "$MODE" && "$MODE" != "$new_mode" ]]; then
        error "Нельзя одновременно использовать режимы '$MODE' и '$new_mode'."
        exit 2
    fi
    MODE="$new_mode"
}

COUNT=1
QUIET=0
YES=0
DRY_RUN=0
LABEL=""
TTL=""
EXPIRES_INPUT=""
REVOKE_TARGET=""
REVOKE_DIR_TARGET=""
REVOKE_ID=""
POSITIONAL=()
GENERATION_OPTION_SEEN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --menu)
            set_mode "menu"
            shift
            ;;
        --generate)
            set_mode "generate"
            shift
            ;;
        -n|--count)
            [[ $# -ge 2 ]] || {
                error "Опции $1 требуется значение."
                exit 2
            }
            COUNT="$2"
            GENERATION_OPTION_SEEN=1
            shift 2
            ;;
        --count=*)
            COUNT="${1#*=}"
            GENERATION_OPTION_SEEN=1
            shift
            ;;
        --label)
            [[ $# -ge 2 ]] || {
                error "Опции --label требуется значение."
                exit 2
            }
            LABEL="$2"
            GENERATION_OPTION_SEEN=1
            shift 2
            ;;
        --label=*)
            LABEL="${1#*=}"
            GENERATION_OPTION_SEEN=1
            shift
            ;;
        --ttl)
            [[ $# -ge 2 ]] || {
                error "Опции --ttl требуется значение."
                exit 2
            }
            TTL="$2"
            GENERATION_OPTION_SEEN=1
            shift 2
            ;;
        --ttl=*)
            TTL="${1#*=}"
            GENERATION_OPTION_SEEN=1
            shift
            ;;
        --expires)
            [[ $# -ge 2 ]] || {
                error "Опции --expires требуется значение."
                exit 2
            }
            EXPIRES_INPUT="$2"
            GENERATION_OPTION_SEEN=1
            shift 2
            ;;
        --expires=*)
            EXPIRES_INPUT="${1#*=}"
            GENERATION_OPTION_SEEN=1
            shift
            ;;
        --list)
            set_mode "list"
            shift
            ;;
        --revoke)
            set_mode "revoke"
            if [[ $# -ge 2 && "$2" != -* ]]; then
                REVOKE_TARGET="$2"
                shift 2
            else
                shift
            fi
            ;;
        --revoke=*)
            set_mode "revoke"
            REVOKE_TARGET="${1#*=}"
            [[ -n "$REVOKE_TARGET" ]] || {
                error "Опции --revoke= требуется непустая цель."
                exit 2
            }
            shift
            ;;
        --revoke-dir)
            set_mode "revoke-dir"
            if [[ $# -ge 2 && "$2" != -* ]]; then
                REVOKE_DIR_TARGET="$2"
                shift 2
            else
                REVOKE_DIR_TARGET="$REVOKE_DIR"
                shift
            fi
            ;;
        --revoke-dir=*)
            set_mode "revoke-dir"
            REVOKE_DIR_TARGET="${1#*=}"
            [[ -n "$REVOKE_DIR_TARGET" ]] || {
                error "Опции --revoke-dir требуется непустой путь."
                exit 2
            }
            shift
            ;;
        --revoke-id)
            [[ $# -ge 2 ]] || {
                error "Опции --revoke-id требуется registration ID."
                exit 2
            }
            set_mode "revoke-id"
            REVOKE_ID="$2"
            shift 2
            ;;
        --revoke-id=*)
            set_mode "revoke-id"
            REVOKE_ID="${1#*=}"
            shift
            ;;
        --revoke-expired)
            set_mode "revoke-expired"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --yes)
            YES=1
            shift
            ;;
        -q|--quiet)
            QUIET=1
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                POSITIONAL+=("$1")
                shift
            done
            ;;
        -*)
            error "Неизвестная опция: $1"
            error "Запустите с --help для справки."
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            GENERATION_OPTION_SEEN=1
            shift
            ;;
    esac
done

LABEL="$(sanitize_label "$LABEL")"

if [[ -z "$MODE" ]]; then
    if (( GENERATION_OPTION_SEEN == 1 )); then
        set_mode "generate"
    elif [[ -t 0 && -t 1 ]]; then
        set_mode "menu"
    else
        set_mode "generate"
    fi
fi

if (( GENERATION_OPTION_SEEN == 1 )) && [[ "$MODE" != "generate" ]]; then
    error "Параметры генерации можно использовать только в режиме --generate."
    exit 2
fi

if (( DRY_RUN == 1 )) && [[ "$MODE" != "revoke-expired" ]]; then
    error "--dry-run используется только вместе с --revoke-expired."
    exit 2
fi

if (( YES == 1 )) && [[ "$MODE" != "revoke" && "$MODE" != "revoke-id" && "$MODE" != "revoke-dir" ]]; then
    error "--yes используется только с --revoke, --revoke-dir или --revoke-id."
    exit 2
fi

if (( YES == 1 )) && [[ "$MODE" == "revoke" && -z "$REVOKE_TARGET" ]]; then
    error "--revoke --yes без конкретного номера или файла запрещён."
    error "Укажите цель отзыва либо откройте интерактивное меню без --yes."
    exit 2
fi

case "$MODE" in
    menu)
        [[ -t 0 ]] || die "Интерактивное меню требует терминал."
        main_menu
        ;;
    generate)
        if [[ ! "$COUNT" =~ ^[1-9][0-9]*$ ]]; then
            error "--count должен быть положительным целым числом: $COUNT"
            exit 2
        fi

        if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
            error "Допустимо не более двух позиционных аргументов: PRIVATE_KEY [PUBLIC_KEY]."
            exit 2
        fi

        if (( COUNT > 1 )) && [[ ${#POSITIONAL[@]} -gt 0 ]]; then
            error "Позиционные ключи нельзя использовать вместе с --count > 1."
            exit 2
        fi

        if [[ -n "$TTL" && -n "$EXPIRES_INPUT" ]]; then
            error "--ttl и --expires нельзя использовать одновременно."
            exit 2
        fi

        if [[ -n "$TTL" ]] && ! duration_to_seconds "$TTL" >/dev/null; then
            error "Некорректный --ttl: $TTL"
            error "Используйте, например: 30m, 12h, 7d, 4w."
            exit 2
        fi

        NORMALIZED_EXPIRES=""
        if [[ -n "$EXPIRES_INPUT" ]]; then
            if ! NORMALIZED_EXPIRES="$(normalize_expiry_date "$EXPIRES_INPUT")"; then
                error "Некорректная или уже прошедшая дата --expires: $EXPIRES_INPUT"
                exit 2
            fi
        fi

        generate_configs \
            "$COUNT" \
            "$LABEL" \
            "$TTL" \
            "$NORMALIZED_EXPIRES" \
            "$QUIET" \
            "${POSITIONAL[0]:-}" \
            "${POSITIONAL[1]:-}"
        ;;
    list)
        print_registration_list
        ;;
    revoke)
        if [[ -z "$REVOKE_TARGET" ]]; then
            interactive_revoke
        else
            revoke_target "$REVOKE_TARGET"
        fi
        ;;
    revoke-dir)
        [[ -n "$REVOKE_DIR_TARGET" ]] || REVOKE_DIR_TARGET="$REVOKE_DIR"
        if [[ "$(normalize_input_path "$REVOKE_DIR_TARGET")" == "$REVOKE_DIR" ]]; then
            revoke_directory "$REVOKE_DIR_TARGET" 1
        else
            revoke_directory "$REVOKE_DIR_TARGET" 0
        fi
        ;;
    revoke-id)
        revoke_by_id "$REVOKE_ID"
        ;;
    revoke-expired)
        revoke_expired "$DRY_RUN" "$QUIET"
        ;;
    *)
        die "Внутренняя ошибка: неизвестный режим '$MODE'."
        ;;
esac
