// src/index.jsx — seletor TUI (Ink/React) de uma pasta de projetos/agent-skills.
// A pasta é CONFIGURAÇÃO do usuário, nunca um palpite: não existe fallback para
// ~/Projects (criar/listar pasta na home de quem instalou é o bug que isso
// corrige). Precedência: --root > $PROJECTS_DIR > projects.conf.
// O conf é lido por regex, não por eval: é arquivo do usuário, não script.
//
// Este arquivo é a FONTE; o build roda esbuild e grava dist/index.js:
//   npm run build
//   (esbuild src/index.jsx --bundle --platform=node --format=esm
//    --packages=external --banner:js="#!/usr/bin/env node"
//    --outfile=dist/index.js)
import React, { useEffect, useMemo, useState } from "react";
import { Box, Text, render, useInput } from "ink";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

// Lê o diretório do conf por regex (linha PROJECTS_DIR="..."), sem `source`.
function readConfDir() {
  const conf =
    process.env.PROJECTS_CONF ||
    path.join(process.env.HOME, ".config", "aula-dev", "projects.conf");
  let txt;
  try {
    txt = fs.readFileSync(conf, "utf8");
  } catch {
    return null;
  }
  let found = null;
  for (const line of txt.split(/\r?\n/)) {
    const m = line.match(/^\s*PROJECTS_DIR\s*=\s*(.*)$/);
    if (m) found = m[1].trim().replace(/^["']|["']$/g, "");
  }
  return found || null;
}

// Flags de linha de comando. Forma canônica com espaço: --root <dir> e
// --title <texto>; a forma --root=<dir> / --title=<texto> também é aceita.
// Flags desconhecidas são ignoradas (comportamento atual).
function parseArgv(argv) {
  const out = { root: null, title: "Escolha um projeto", list: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--list") {
      out.list = true;
    } else if (a === "--root") {
      if (i + 1 >= argv.length) {
        console.error("projects-picker: --root exige um caminho (--root <dir>)");
        process.exit(2);
      }
      out.root = argv[++i];
    } else if (a.startsWith("--root=")) {
      out.root = a.slice("--root=".length);
    } else if (a === "--title") {
      if (i + 1 >= argv.length) {
        console.error("projects-picker: --title exige um texto (--title <texto>)");
        process.exit(2);
      }
      out.title = argv[++i];
    } else if (a.startsWith("--title=")) {
      out.title = a.slice("--title=".length);
    }
    // demais flags: ignoradas
  }
  if (out.root !== null && out.root.length === 0) out.root = null;
  return out;
}

const opts = parseArgv(process.argv.slice(2));
// Precedência final: --root > $PROJECTS_DIR > projects.conf.
var ROOT = opts.root || process.env.PROJECTS_DIR || readConfDir();
if (!ROOT) {
  console.error(
    "projects-picker: nenhuma pasta de projetos configurada.\n" +
    "  Rode:  projects --setup     (ou: PROJECTS_DIR=/caminho projects-picker)"
  );
  process.exit(2);
}
var WINDOW = 10;
function listProjects(dir) {
  let entries;
  try {
    entries = fs.readdirSync(dir);
  } catch (err) {
    console.error(`projects-picker: não consegui ler ${dir}: ${err.message}`);
    process.exit(1);
  }
  const out = [];
  for (const name of entries) {
    if (name.startsWith(".")) continue;
    const p = path.join(dir, name);
    let st;
    try {
      st = fs.statSync(p);
    } catch {
      continue;
    }
    if (!st.isDirectory()) continue;
    out.push({ name, mtimeMs: st.mtimeMs });
  }
  out.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return out;
}
function relativeTime(ms) {
  const diff = Date.now() - ms;
  const min = 6e4;
  const h = 36e5;
  const d = 864e5;
  if (diff < min) return "agora";
  if (diff < h) return `${Math.floor(diff / min)} min`;
  if (diff < d) return `${Math.floor(diff / h)} h`;
  if (diff < 30 * d) return `${Math.floor(diff / d)} dias`;
  return new Date(ms).toISOString().slice(0, 10);
}
function clamp(v, lo, hi) {
  return Math.min(Math.max(v, lo), hi);
}
var projects = listProjects(ROOT);
var HOME_NAME = process.env.HOME && ROOT.startsWith(process.env.HOME + path.sep)
  ? "~" + ROOT.slice(process.env.HOME.length)
  : ROOT;
if (opts.list) {
  for (const p of projects) console.log(p.name);
  process.exit(0);
}
function App() {
  const [filter, setFilter] = useState("");
  const [cursor, setCursor] = useState(0);
  const filtered = useMemo(() => {
    const f = filter.trim().toLowerCase();
    return f ? projects.filter((p) => p.name.toLowerCase().includes(f)) : projects;
  }, [filter]);
  const start = clamp(cursor - 4, 0, Math.max(0, filtered.length - WINDOW));
  const visible = filtered.slice(start, start + WINDOW);
  useEffect(() => {
    setCursor(0);
  }, [filter]);
  useInput((input, key) => {
    if (key.upArrow) {
      setCursor((c) => c <= 0 ? 0 : c - 1);
      return;
    }
    if (key.downArrow) {
      setCursor((c) => c >= filtered.length - 1 ? c : c + 1);
      return;
    }
    if (key.return) {
      const chosen = filtered[cursor];
      const target = chosen ? path.join(ROOT, chosen.name) : ROOT;
      fs.writeSync(1, target + "\n");
      process.exit(0);
      return;
    }
    if (key.backspace) {
      setFilter((f) => f.slice(0, -1));
      return;
    }
    if (key.escape) {
      process.exit(1);
      return;
    }
    if (input && !key.ctrl && !key.meta && !key.alt) {
      setFilter((f) => f + input);
    }
  });
  return (
    <Box flexDirection="column">
      <Text bold>
        {opts.title} — {HOME_NAME} ({projects.length})
      </Text>
      {filter ? (
        <Text>
          filtro: <Text color="cyan">{filter}</Text>
          <Text dimColor> · {filtered.length}/{projects.length}</Text>
        </Text>
      ) : (
        <Text dimColor>mais recente primeiro</Text>
      )}
      <Box marginTop={1} flexDirection="column">
        {visible.length === 0 ? (
          <Text dimColor>nenhum projeto corresponde — Enter abre {HOME_NAME}</Text>
        ) : (
          visible.map((p, i) => {
            const selected = i === cursor - start;
            return (
              <Text key={p.name} color={selected ? "green" : undefined} bold={selected}>
                {selected ? "❯ " : "  "}
                {p.name}
                <Text dimColor>  ({relativeTime(p.mtimeMs)})</Text>
              </Text>
            );
          })
        )}
      </Box>
      <Text dimColor marginTop={1}>
        ↑↓ navegar · digitar = filtrar · ⌫ apagar · Enter = abrir · Esc = cancelar
      </Text>
    </Box>
  );
}
render(<App />, { stdout: process.stderr });