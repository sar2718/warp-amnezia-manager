#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR/project" "$WORK_DIR/bin" "$WORK_DIR/home/Downloads"
cp "$PROJECT_DIR/warp_manager.sh" "$WORK_DIR/project/"
cp "$PROJECT_DIR/warp_expiry.sh" "$WORK_DIR/project/"

export HOME="$WORK_DIR/home"
export PATH="$WORK_DIR/bin:$PATH"
export MOCK_CURL_LOG="$WORK_DIR/curl.log"
: > "$MOCK_CURL_LOG"

cat > "$WORK_DIR/bin/wg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    genkey)
        printf 'privGenerated\n'
        ;;
    pubkey)
        IFS= read -r key || true
        case "$key" in
            privA) printf 'pubA\n' ;;
            privB) printf 'pubB\n' ;;
            privC) printf 'pubC\n' ;;
            privD) printf 'pubD\n' ;;
            privFail) printf 'pubFail\n' ;;
            privGenerated) printf 'pubGenerated\n' ;;
            invalid|'') exit 1 ;;
            *) printf 'pub_%s\n' "$key" ;;
        esac
        ;;
    *)
        exit 2
        ;;
esac
EOF
chmod +x "$WORK_DIR/bin/wg"

cat > "$WORK_DIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=""
method="GET"
url=""
args=("$@")

for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[$i]}" in
        --output)
            output="${args[$((i + 1))]}"
            i=$((i + 1))
            ;;
        --request)
            method="${args[$((i + 1))]}"
            i=$((i + 1))
            ;;
        http://*|https://*)
            url="${args[$i]}"
            ;;
    esac
done

printf '%s %s\n' "$method" "$url" >> "${MOCK_CURL_LOG:?}"

body='{}'
code=200
if [[ "$method" == "POST" ]]; then
    if [[ -n "${MOCK_RACE_PUBLIC_KEY:-}" ]]; then
        jq --arg public_key "$MOCK_RACE_PUBLIC_KEY" '
            .registrations += [{
                id: "race-id",
                token: "race-token",
                public_key: $public_key,
                config: null,
                label: "Race",
                created_at: "2026-01-01T00:00:00Z",
                expires_at: null,
                revoked_at: null,
                revoke_reason: null
            }]
        ' .data/registrations.json > .data/race.json
        mv .data/race.json .data/registrations.json
    fi
    body='{"result":{"id":"new-id","token":"new-token"}}'
elif [[ "$method" == "PATCH" ]]; then
    body='{"result":{"config":{"peers":[{"public_key":"peer-key"}],"interface":{"addresses":{"v4":"172.16.0.2/32","v6":"2606:4700::1/128"}}}}}'
elif [[ "$method" == "DELETE" && "$url" == *'/reg/fail-id' ]]; then
    body='{"error":"simulated"}'
    code=503
elif [[ "$method" == "DELETE" && "$url" == *'/reg/new-id' && "${MOCK_FAIL_NEW_DELETE:-0}" == "1" ]]; then
    body='{"error":"simulated rollback failure"}'
    code=503
fi

[[ -n "$output" ]] && printf '%s' "$body" > "$output"
printf '%s' "$code"
EOF
chmod +x "$WORK_DIR/bin/curl"

cd "$WORK_DIR/project"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    printf 'PASS: %s\n' "$*"
}

bash -n warp_manager.sh
bash -n warp_expiry.sh
pass "синтаксис Bash"

help_text="$(bash warp_manager.sh --help)"
grep -q -- '--revoke-dir' <<< "$help_text" || fail "в справке нет --revoke-dir"
grep -q 'PrivateKey -> wg pubkey' <<< "$help_text" || fail "в справке нет описания сопоставления"
pass "справка CLI"

# Опасным цветом помечаются только финальные необратимые действия.
# Переход в массовый отзыв и переход к подтверждению одиночного отзыва
# остаются обычными пунктами меню.
grep -Fq 'print_menu_item "4" "Отозвать все подходящие конфиги из revoke/"' warp_manager.sh \
    || fail "переход к массовому отзыву ошибочно помечен как опасное действие"
if grep -Fq 'print_danger_item "4" "Отозвать все подходящие конфиги из revoke/"' warp_manager.sh; then
    fail "массовый отзыв подсвечивается до экрана подтверждения"
fi
grep -Fq 'print_menu_item "5" "Отозвать регистрацию"' warp_manager.sh \
    || fail "переход к подтверждению одиночного отзыва ошибочно помечен как опасное действие"
pass "логика подсветки опасных действий"

bash warp_manager.sh --list >/dev/null
[[ -d revoke ]] || fail "revoke/ не создана"
pass "инициализация revoke/"

cat > .data/registrations.json <<'EOF'
{"version":1,"registrations":[
  {"id":"id-a","token":"tok-a","public_key":"pubA","config":"configs/WARP.conf","label":"A","created_at":"2026-01-01T00:00:00Z","expires_at":null,"revoked_at":null,"revoke_reason":null},
  {"id":"id-b","token":"tok-b","public_key":"pubB","config":"configs/WARP.conf","label":"B","created_at":"2026-01-01T00:00:00Z","expires_at":null,"revoked_at":"2026-01-02T00:00:00Z","revoke_reason":"manual"},
  {"id":"fail-id","token":"tok-f","public_key":"pubFail","config":"configs/WARP.conf","label":"Fail","created_at":"2026-01-01T00:00:00Z","expires_at":null,"revoked_at":null,"revoke_reason":null}
]}
EOF
chmod 600 .data/registrations.json

cat > "$HOME/Downloads/with space.conf" <<'EOF'
[Peer]
PublicKey = pubB
[Interface]
PrivateKey = privA
Address = 1.2.3.4
EOF

bash warp_manager.sh --revoke "$HOME/Downloads/with space.conf" --yes >/dev/null
[[ "$(jq -r '.registrations[0].revoked_at // empty' .data/registrations.json)" != "" ]] \
    || fail "регистрация A не отозвана"
grep -q 'DELETE .*reg/id-a' "$MOCK_CURL_LOG" || fail "отозвана не та регистрация"
pass "поиск по содержимому и путь с пробелом"

if bash warp_manager.sh --revoke WARP.conf --yes >/dev/null 2>"$WORK_DIR/error"; then
    fail "сохранился поиск по имени/старому пути"
fi
grep -q 'обычным файлом' "$WORK_DIR/error" || fail "нет понятной ошибки отсутствующего файла"
pass "нет fallback по имени файла"

printf '[Interface]\r\nPrivateKey = privB\r\n[Peer]\r\nPublicKey = peer\r\n' \
    > "$HOME/Downloads/crlf.conf"
before="$(wc -l < "$MOCK_CURL_LOG")"
bash warp_manager.sh --revoke "$HOME/Downloads/crlf.conf" --yes >/dev/null
after="$(wc -l < "$MOCK_CURL_LOG")"
[[ "$before" == "$after" ]] || fail "уже отозванная запись вызвала DELETE"
pass "CRLF и уже отозванная регистрация"

cat > "$HOME/Downloads/multiple.conf" <<'EOF'
[Interface]
PrivateKey = privA
PrivateKey = privC
EOF
if bash warp_manager.sh --revoke "$HOME/Downloads/multiple.conf" --yes >/dev/null 2>"$WORK_DIR/error"; then
    fail "принято несколько PrivateKey"
fi
grep -q 'несколько PrivateKey' "$WORK_DIR/error" || fail "нет диагностики нескольких PrivateKey"
pass "защита от неоднозначного PrivateKey"

cat > "$HOME/Downloads/unknown.conf" <<'EOF'
[Interface]
PrivateKey = privC
EOF
if bash warp_manager.sh --revoke "$HOME/Downloads/unknown.conf" --yes >/dev/null 2>"$WORK_DIR/error"; then
    fail "неизвестный конфиг принят"
fi
grep -q 'не найдена' "$WORK_DIR/error" || fail "нет диагностики неизвестного конфига"
pass "неизвестный конфиг"

jq '.registrations += [{"id":"id-a2","token":"tok","public_key":"pubA","config":null,"label":"A2","created_at":"2026-01-01T00:00:00Z","expires_at":null,"revoked_at":null,"revoke_reason":null}]' \
    .data/registrations.json > .data/tmp.json
mv .data/tmp.json .data/registrations.json
if bash warp_manager.sh --revoke "$HOME/Downloads/with space.conf" --yes >/dev/null 2>"$WORK_DIR/error"; then
    fail "конфликт public_key в реестре не заблокирован"
fi
grep -q 'несколько записей' "$WORK_DIR/error" || fail "нет диагностики конфликта реестра"
jq 'del(.registrations[-1]) | .registrations[0].revoked_at=null | .registrations[0].revoke_reason=null' \
    .data/registrations.json > .data/tmp.json
mv .data/tmp.json .data/registrations.json
pass "конфликт реестра"

rm -f revoke/*.conf
cat > revoke/01-a.conf <<'EOF'
[Interface]
PrivateKey = privA
EOF
cp revoke/01-a.conf revoke/02-a-copy.conf
cat > revoke/03-b.conf <<'EOF'
[Interface]
PrivateKey = privB
EOF
cat > revoke/04-unknown.conf <<'EOF'
[Interface]
PrivateKey = privC
EOF
cat > revoke/05-invalid.conf <<'EOF'
[Interface]
Address = 1.2.3.4
EOF
cat > revoke/06-fail.conf <<'EOF'
[Interface]
PrivateKey = privFail
EOF

if bash warp_manager.sh --revoke-dir --yes >"$WORK_DIR/batch.out" 2>"$WORK_DIR/batch.err"; then
    fail "массовый тест должен вернуть ошибку из-за смоделированного API 503"
fi
grep -q 'Готовы к отзыву' "$WORK_DIR/batch.out" || fail "нет плана массового отзыва"
grep -q 'Дубликаты' "$WORK_DIR/batch.out" || fail "не показаны дубликаты"
grep -q 'Успешно отозвано' "$WORK_DIR/batch.out" || fail "нет итоговой сводки"
[[ -f revoke/01-a.conf ]] || fail "--yes удалил файл из revoke/"
[[ "$(jq -r '.registrations[] | select(.id=="id-a") | .revoked_at // empty' .data/registrations.json)" != "" ]] \
    || fail "A не отозвана в пачке"
[[ "$(jq -r '.registrations[] | select(.id=="fail-id") | .revoked_at // empty' .data/registrations.json)" == "" ]] \
    || fail "неуспешный DELETE ошибочно отмечен как успешный"
pass "массовый отзыв, дубликаты, продолжение после ошибки, --yes без удаления"

: > "$MOCK_CURL_LOG"
if bash warp_manager.sh --generate privA pubA --quiet >/dev/null 2>"$WORK_DIR/error"; then
    fail "повторный client public key принят"
fi
[[ ! -s "$MOCK_CURL_LOG" ]] || fail "при повторном ключе выполнен запрос к API"
grep -q 'уже присутствует' "$WORK_DIR/error" || fail "нет сообщения о повторном ключе"
pass "запрет повторного client public key до API"

: > "$MOCK_CURL_LOG"
if bash warp_manager.sh --generate privC WRONG --quiet >/dev/null 2>"$WORK_DIR/error"; then
    fail "несогласованная пара PRIVATE_KEY/PUBLIC_KEY принята"
fi
[[ ! -s "$MOCK_CURL_LOG" ]] || fail "при несогласованной паре выполнен запрос к API"
grep -q 'не соответствует' "$WORK_DIR/error" || fail "нет сообщения о несогласованной паре"
pass "проверка PRIVATE_KEY/PUBLIC_KEY"

: > "$MOCK_CURL_LOG"
bash warp_manager.sh --generate privD pubD --quiet >/dev/null
[[ "$(jq -r '.registrations[] | select(.id=="new-id") | .public_key' .data/registrations.json)" == "pubD" ]] \
    || fail "новый public_key не сохранён"
if grep -q 'privD' .data/registrations.json; then
    fail "PrivateKey попал в registrations.json"
fi
pass "успешная генерация и отсутствие PrivateKey в реестре"


# --revoke= поддерживает literal ~/... и по-прежнему сопоставляет только содержимое.
before="$(wc -l < "$MOCK_CURL_LOG")"
bash warp_manager.sh --revoke='~/Downloads/crlf.conf' --yes >/dev/null
after="$(wc -l < "$MOCK_CURL_LOG")"
[[ "$before" == "$after" ]] || fail "--revoke= для уже отозванной записи вызвал DELETE"
pass "--revoke= и безопасное раскрытие ~/"

mkdir -p "$HOME/custom-revoke"
cp "$HOME/Downloads/crlf.conf" "$HOME/custom-revoke/arbitrary-name.conf"
bash warp_manager.sh --revoke-dir='~/custom-revoke' --yes >/dev/null
pass "произвольная директория --revoke-dir"

mkdir -p "$HOME/invalid-only"
cat > "$HOME/invalid-only/broken.conf" <<'EOF'
[Interface]
Address = 1.2.3.4
EOF
if bash warp_manager.sh --revoke-dir="$HOME/invalid-only" --yes >/dev/null 2>"$WORK_DIR/error"; then
    fail "директория только с некорректным конфигом вернула успех"
fi
pass "ненулевой код для проблемной пачки без готовых регистраций"

jq '.registrations += [{"id":"expired-id","token":"expired-token","public_key":"pubExpired","config":"configs/old.conf","label":"Expired","created_at":"2020-01-01T00:00:00Z","expires_at":"2020-01-02T00:00:00Z","revoked_at":null,"revoke_reason":null}]' \
    .data/registrations.json > .data/tmp.json
mv .data/tmp.json .data/registrations.json
: > "$MOCK_CURL_LOG"
bash warp_expiry.sh --dry-run >/dev/null
[[ ! -s "$MOCK_CURL_LOG" ]] || fail "warp_expiry.sh --dry-run выполнил API-запрос"
bash warp_expiry.sh >/dev/null
grep -q 'DELETE .*reg/expired-id' "$MOCK_CURL_LOG" || fail "warp_expiry.sh не отозвал истёкшую регистрацию"
pass "регрессия warp_expiry.sh"

# Имитируем редкую гонку: после POST другой процесс записал тот же public_key,
# основной реестр отклонил новую запись, а DELETE-откат тоже не сработал.
rm -f .data/recovery-*.json
: > "$MOCK_CURL_LOG"
if MOCK_RACE_PUBLIC_KEY=pubC MOCK_FAIL_NEW_DELETE=1 \
    bash warp_manager.sh --generate privC pubC --quiet >/dev/null 2>"$WORK_DIR/recovery.err"; then
    fail "гонка public_key неожиданно завершилась успешно"
fi
recovery_files=(.data/recovery-*.json)
[[ ${#recovery_files[@]} -eq 1 && -f "${recovery_files[0]}" ]] \
    || fail "после неудачного отката не создан ровно один recovery-файл"
[[ "$(stat -c '%a' "${recovery_files[0]}")" == "600" ]] \
    || fail "recovery-файл имеет небезопасные права"
[[ "$(jq -r '.id' "${recovery_files[0]}")" == "new-id" ]] \
    || fail "recovery-файл содержит неверный registration id"
[[ "$(jq -r '.token' "${recovery_files[0]}")" == "new-token" ]] \
    || fail "recovery-файл не сохранил management token"
[[ "$(jq -r '.public_key' "${recovery_files[0]}")" == "pubC" ]] \
    || fail "recovery-файл содержит неверный public key"
if grep -q 'privC' "${recovery_files[0]}"; then
    fail "PrivateKey попал в recovery-файл"
fi
grep -q 'аварийный файл' "$WORK_DIR/recovery.err" || fail "нет сообщения о recovery-файле"
pass "аварийное сохранение управления при неудачном rollback"

printf 'ALL TESTS PASSED\n'
