#!/usr/bin/env bash
# deepeco_fds_test.sh — suíte de CENÁRIO para a regra de FIM DE SEMANA do deepeco.
#
#   A partir de 2026-08-23 00:00 de Pequim (= 2026-08-22T16:00:00Z UTC), fins de
#   semana do fuso de Pequim (UTC+8, sáb/dom) são ECONOMIA o DIA TODO (picos não
#   valem). Dias úteis seguem o regime antigo (PICO 01:00–04:00 e 06:00–10:00
#   UTC). Pré-vigência segue a regra antiga.
#
#   Todo caso usa DEEPECO_NOW="YYYY-MM-DD HH:MM" (UTC) — o hook de teste do
#   script — para substituir o relógio. Nunca usa `date` real. Nenhuma chamada
#   de rede. Apenas bash + coreutils + grep + python3 (opcional, só para o
#   check de alinhamento da tabela — SKIP se ausente) + od (BOM).
#
#   Exit 0 quando FAIL==0 (independente de SKIP). O case11 pode "SKIP" quando
#   python3 está ausente (Git Bash no Windows comum) — SKIP não é falha; com
#   python3 presente, case11 roda e deve PASSAR. São 15 resultados no total:
#   14 regulares que precisam passar + case14 (com 2 asserts no mesmo caso);
#   sem python3 são 14 pass + 1 skip — exit 0.
set -uo pipefail

# ── Localização do deepeco (relativo a este script) ─────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
D="$SCRIPT_DIR/../payload/deepeco"

# ── Contadores ──────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

say()  { printf '%s\n' "$*"; }

# Executa o deepeco já com o relógio sintonizado e coleta a saída e o exit code.
#   run_now "<NOW>" [ARG...]  →  executa "$D" [ARG...]
#   define OUT (saída completa) e HEAD (1ª linha)
run_now() {
  local now="$1"; shift
  OUT="$(DEEPECO_NOW="$now" "$D" "$@" 2>&1)"
  HEAD="$(printf '%s\n' "$OUT" | head -n1)"
}

# Registra o resultado de um caso.
#   result <nome> <ok(0|1|2)> <mensagem>
#   0 = PASS · 1 = FAIL · 2 = SKIP (não conta como falha; exit final só olha FAIL)
result() {
  local nome="$1" ok="$2" msg="$3"
  if [ "$ok" = "0" ]; then
    PASS=$((PASS + 1)); say "PASS  $nome"
  elif [ "$ok" = "2" ]; then
    SKIP=$((SKIP + 1)); say "SKIP  $nome"
    say "      $msg"
  else
    FAIL=$((FAIL + 1)); say "FAIL  $nome"
    say "      $msg"
  fi
}

# Verifica se a saída contém determinada substring (ere). Último argumento é o
# timestamp; usa grep -q. Retorna 0 se achou.
#   has_substr <saída> <padrão>
has_substr() { printf '%s' "$1" | grep -q -- "$2"; }

# ─────────────────────────────────────────────────────────────────────────────
# CASO 1 — sáb 2026-08-22 15:00 Pequim (PRÉ-vigência): regra antiga, janela
# 06:00–10:00 UTC ativa → pico.
# ─────────────────────────────────────────────────────────────────────────────
run_now "2026-08-22 07:00" --short
if has_substr "$OUT" "HORÁRIO DE PICO"; then
  result "case1_previg_sab15h_pico" 0 ""
else
  result "case1_previg_sab15h_pico" 1 "esperava 'HORÁRIO DE PICO' no sáb pré-vig (15:00 Pequim); obtido: $HEAD"
fi

# CASO 2 — sáb 2026-08-22 23:59 Pequim (PRÉ-vig), fora de qualquer janela → economia.
run_now "2026-08-22 15:59" --short
if has_substr "$OUT" "ECONOMIA ATIVA"; then
  result "case2_previg_sab2359_economia" 0 ""
else
  result "case2_previg_sab2359_economia" 1 "esperava 'ECONOMIA ATIVA' (sáb 23:59 Pequim pré-vig); obtido: $HEAD"
fi

# CASO 3 — exatamente na virada da vigência: 2026-08-22 16:00 UTC = dom 00:00 Pequim.
run_now "2026-08-22 16:00" --short
if has_substr "$OUT" "ECONOMIA o DIA TODO"; then
  result "case3_vigencia_domingo0000" 0 ""
else
  result "case3_vigencia_domingo0000" 1 "esperava 'ECONOMIA o DIA TODO' (dom 00:00 Pequim = virada); obtido: $HEAD"
fi

# CASO 4 — dom 2026-08-23 15:00 Pequim (pós-vig), dentro da janela 06:00–10:00 UTC
# que seria pico em dia útil → mas FDS: economia o dia todo.
run_now "2026-08-23 07:00" --short
if has_substr "$OUT" "ECONOMIA o DIA TODO"; then
  result "case4_fds_dom15h_economia_todo_dia" 0 ""
else
  result "case4_fds_dom15h_economia_todo_dia" 1 "esperava 'ECONOMIA o DIA TODO' (dom 15:00 Pequim); obtido: $HEAD"
fi

# CASO 5 — seg 2026-08-24 15:00 Pequim (dia útil), janela 06:00–10:00 UTC ativa → pico.
# Regressão zero: FDS não vaza para segunda.
run_now "2026-08-24 07:00" --short
if has_substr "$OUT" "HORÁRIO DE PICO"; then
  result "case5_diautil_seg15h_pico" 0 ""
else
  result "case5_diautil_seg15h_pico" 1 "esperava 'HORÁRIO DE PICO' (seg 15:00 Pequim, dia útil); obtido: $HEAD"
fi

# CASO 6 — seg 2026-08-24 13:00 Pequim, fora de janela → economia.
run_now "2026-08-24 05:00" --short
if has_substr "$OUT" "ECONOMIA ATIVA"; then
  result "case6_diautil_seg13h_economia" 0 ""
else
  result "case6_diautil_seg13h_economia" 1 "esperava 'ECONOMIA ATIVA' (seg 13:00 Pequim); obtido: $HEAD"
fi

# CASO 7 — 2026-08-23 16:00 UTC = seg 00:00 Pequim: já não é mais fim de semana →
# dia útil, economia (fora de janela).
run_now "2026-08-23 16:00" --short
if has_substr "$OUT" "ECONOMIA ATIVA"; then
  result "case7_seg0000_pequim_economia" 0 ""
else
  result "case7_seg0000_pequim_economia" 1 "esperava 'ECONOMIA ATIVA' (seg 00:00 Pequim); obtido: $HEAD"
fi

# CASO 8 — dom 2026-08-30 15:00 Pequim (pós-vig): status completo deve informar
# o novo rótulo do primeiro pico da próxima semana.
run_now "2026-08-30 07:00"
ok=0; msg=""
if ! has_substr "$OUT" "ECONOMIA o DIA TODO"; then ok=1; msg="sem 'ECONOMIA o DIA TODO'"; fi
if ! has_substr "$OUT" "01:00 UTC";  then ok=1; msg="$msg | falta rótulo '01:00 UTC'"; fi
if ! has_substr "$OUT" "09:00 Pequim"; then ok=1; msg="$msg | falta rótulo '09:00 Pequim'"; fi
if ! has_substr "$OUT" "próxima semana"; then ok=1; msg="$msg | falta 'próxima semana'"; fi
[ "$ok" = "1" ] && msg="${msg} | head: $HEAD"
result "case8_fds_status_proxima_semana" "$ok" "$msg"

# CASO 9 — conf antigo (sem chaves ECO_FDS_*): default ON aplica a regra nova.
# ECO_ATIVO=1 garante variação de preço + a janela padrão.
tmpold="$(mktemp -d)"
printf 'ECO_ATIVO="1"\nECO_PICOS_UTC="01:00-04:00 06:00-10:00"\n' > "$tmpold/conf"
OUT="$(DEEPECO_CONF="$tmpold/conf" DEEPECO_NOW="2026-08-23 07:00" "$D" --short 2>&1)"
rm -rf "$tmpold"
if printf '%s' "$OUT" | grep -q "ECONOMIA o DIA TODO"; then
  result "case9_conf_antigo_default_on" 0 ""
else
  result "case9_conf_antigo_default_on" 1 "esperava 'ECONOMIA o DIA TODO' com conf antigo (sem chaves FDS); obtido: $(printf '%s\n' "$OUT" | head -n1)"
fi

# CASO 10 — opt-out: ECO_FDS_ECO_DIA_INTEIRO="0" reverte para a regra antiga →
# dom continua com pico na janela 06:00–10:00 UTC.
tmpout="$(mktemp -d)"
printf 'ECO_ATIVO="1"\nECO_PICOS_UTC="01:00-04:00 06:00-10:00"\nECO_FDS_ECO_DIA_INTEIRO="0"\n' > "$tmpout/conf"
OUT="$(DEEPECO_CONF="$tmpout/conf" DEEPECO_NOW="2026-08-23 07:00" "$D" --short 2>&1)"
rm -rf "$tmpout"
if printf '%s' "$OUT" | grep -q "HORÁRIO DE PICO"; then
  result "case10_optout_desligar_fds" 0 ""
else
  result "case10_optout_desligar_fds" 1 "esperava 'HORÁRIO DE PICO' com ECO_FDS_ECO_DIA_INTEIRO=0; obtido: $(printf '%s\n' "$OUT" | head -n1)"
fi

# CASO 11 — alinhamento da tabela no modo FDS: as 3 linhas de célula (contêm '│')
# devem ter o MESMO padrão de offsets de '│' — nenhuma coluna pode estar
# deslocada. Método robusto: python3 (byte offset por linha), com fallback SKIP.
# A célula de rótulo de FDS é multibyte, então comparamos OFFSET EM BYTES (é o
# que garante que o printf do bash alinhou as colunas na mesma largura).
run_now "2026-08-30 07:00" --short
CASE11=skip
if command -v python3 >/dev/null 2>&1; then
  ALIGN=$(printf '%s\n' "$OUT" | python3 -c '
import sys
offsets=[]
for line in sys.stdin:
    line=line.rstrip("\n")
    if "│" not in line: continue
    offs=[i for i,c in enumerate(line) if c=="│"]
    offsets.append(tuple(offs))
if not offsets:
    print("NO_CELL_ROWS"); raise SystemExit(0)
print("PATTERNS=" + ";".join(",".join(hex(x) for x in o) for o in sorted(set(offsets))))
if len(set(offsets)) == 1:
    print("ALIGN_OK")
else:
    print("MISALIGN_DETECTED")
' 2>/dev/null)
  if printf '%s\n' "$ALIGN" | grep -qx "ALIGN_OK"; then
    result "case11_tabela_fds_alinhada" 0 ""
    CASE11=pass
  elif printf '%s\n' "$ALIGN" | grep -q "NO_CELL_ROWS"; then
    result "case11_tabela_fds_alinhada" 1 "nenhuma linha de célula com '│' na saída; head: $HEAD"
    CASE11=fail
  else
    result "case11_tabela_fds_alinhada" 1 "colunas da tabela FDS deslocadas (3 linhas de célula devem ter o MESMO padrão de offsets '│'); padrões: $(printf '%s\n' "$ALIGN" | sed -n 's/^PATTERNS=//p')"
    CASE11=fail
  fi
else
  say "SKIP: case11 (python3 ausente)"
  result "case11_tabela_fds_alinhada" 2 "python3 ausente — case11 não rodou (SKIP não é falha)"
fi

# CASO 12 — BOM do .ps1 espelho (deepeco.ps1): garante PS 5.1 UTF-8.
PS1="$SCRIPT_DIR/../payload/deepeco.ps1"
if [ -f "$PS1" ]; then
  BOM="$(head -c 3 "$PS1" | od -An -tx1 | tr -d ' ')"
  if [ "$BOM" = "efbbbf" ]; then
    result "case12_bom_ps1" 0 ""
  else
    result "case12_bom_ps1" 1 "deepeco.ps1 sem BOM UTF-8 (obtido: '$BOM', esperava 'ef b bf'/efbbbf)"
  fi
else
  result "case12_bom_ps1" 1 "arquivo deepeco.ps1 não encontrado em $PS1"
fi

# CASO 13 — --help responde (0) e flag desconhecida sai != 0 (2).
if "$D" --help >/dev/null 2>&1; then
  result "case13_help_responde" 0 ""
else
  result "case13_help_responde" 1 "--help não respondeu com exit 0 (obtido exit $?)"
fi
"$D" --helpp >/dev/null 2>&1
ec=$?
if [ "$ec" -ne 0 ]; then
  result "case13_flag_desconhecida_erro" 0 ""
else
  result "case13_flag_desconhecida_erro" 1 "flag desconhecida saiu 0 (esperava != 0)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CASO 14 — janelas customizadas sob FDS. Conf com ECO_ATIVO=1 e uma janela de
# pico custom (02:00-05:00 07:00-11:00 UTC), em que p_ini[0]=02:00 UTC = 10:00
# Pequim. No FDS, o rótulo do "próximo pico" e o HORÁRIO DE PICO do dia útil
# devem seguir o conf custom — não o default hardcoded 01:00/09:00.
# ─────────────────────────────────────────────────────────────────────────────
tmpwin="$(mktemp -d)"
printf 'ECO_ATIVO="1"\nECO_PICOS_UTC="02:00-05:00 07:00-11:00"\n' > "$tmpwin/conf"
# Assert 1 — dom 2026-08-30 07:00 UTC (pós-vig, FDS): status deve derivar o
# primeiro pico da próxima semana de p_ini[0] do conf custom (02:00 UTC).
OUT="$(DEEPECO_CONF="$tmpwin/conf" DEEPECO_NOW="2026-08-30 07:00" "$D" --short 2>&1)"
ok=0; msg=""
if ! printf '%s' "$OUT" | grep -q "ECONOMIA o DIA TODO"; then ok=1; msg="sem 'ECONOMIA o DIA TODO'"; fi
if ! printf '%s' "$OUT" | grep -q "10:00 Pequim (= 02:00 UTC"; then ok=1; msg="$msg | falta '10:00 Pequim (= 02:00 UTC' (próximo-pico deve vir de p_ini[0] do conf custom)"; fi
[ "$ok" = "1" ] && msg="$msg | head: $(printf '%s\n' "$OUT" | head -n1)"
result "case14_fds_custom_windows" "$ok" "$msg"
# Assert 2 — seg 2026-08-31 07:00 UTC (dia útil Pequim 15:00): dentro da janela
# custom 07:00-11:00 UTC → pico (prova que o pico do dia útil segue o conf
# custom também e o FDS não vazou).
if [ "$ok" = "0" ]; then
  OUT="$(DEEPECO_CONF="$tmpwin/conf" DEEPECO_NOW="2026-08-31 07:00" "$D" --short 2>&1)"
  if printf '%s' "$OUT" | grep -q "HORÁRIO DE PICO"; then
    say "      + assert2: dia útil segue conf custom (HORÁRIO DE PICO em 07:00-11:00 UTC)"
  else
    FAIL=$((FAIL + 1)); say "FAIL  case14_fds_custom_windows"
    say "      + assert2: esperava 'HORÁRIO DE PICO' (seg, janela custom 07:00-11:00 UTC); obtido: $(printf '%s\n' "$OUT" | head -n1)"
  fi
fi
rm -rf "$tmpwin"

# ── Resumo ───────────────────────────────────────────────────────────────────
say
say "══════════════════════════════════════════"
say "RESULTADO: $PASS passou, $FAIL falhou, $SKIP ignorado (case11=$CASE11)"
say "══════════════════════════════════════════"
[ "$FAIL" -eq 0 ]