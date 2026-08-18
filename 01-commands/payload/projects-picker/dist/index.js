#!/usr/bin/env node

// src/index.jsx
import React, { useEffect, useMemo, useState } from "react";
import { Box, Text, render, useInput } from "ink";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
// A pasta de projetos e CONFIGURACAO do usuario, nunca um palpite: nao existe
// fallback para ~/Projects (criar/listar pasta na home de quem instalou e o
// bug que isso corrige). Precedencia: $PROJECTS_DIR > projects.conf.
// O conf e lido por regex, nao por eval: e arquivo do usuario, nao script.
function readConfDir() {
  const conf = process.env.PROJECTS_CONF ||
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
var ROOT = process.env.PROJECTS_DIR || readConfDir();
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
    console.error(`projects-picker: n\xE3o consegui ler ${dir}: ${err.message}`);
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
if (process.argv.includes("--list")) {
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
  return /* @__PURE__ */ React.createElement(Box, { flexDirection: "column" }, /* @__PURE__ */ React.createElement(Text, { bold: true }, "Escolha um projeto \u2014 ", HOME_NAME, " (", projects.length, ")"), filter ? /* @__PURE__ */ React.createElement(Text, null, "filtro: ", /* @__PURE__ */ React.createElement(Text, { color: "cyan" }, filter), /* @__PURE__ */ React.createElement(Text, { dimColor: true }, " \xB7 ", filtered.length, "/", projects.length)) : /* @__PURE__ */ React.createElement(Text, { dimColor: true }, "mais recente primeiro"), /* @__PURE__ */ React.createElement(Box, { marginTop: 1, flexDirection: "column" }, visible.length === 0 ? /* @__PURE__ */ React.createElement(Text, { dimColor: true }, "nenhum projeto corresponde \u2014 Enter abre ", HOME_NAME) : visible.map((p, i) => {
    const selected = i === cursor - start;
    return /* @__PURE__ */ React.createElement(Text, { key: p.name, color: selected ? "green" : void 0, bold: selected }, selected ? "\u276F " : "  ", p.name, /* @__PURE__ */ React.createElement(Text, { dimColor: true }, "  (", relativeTime(p.mtimeMs), ")"));
  })), /* @__PURE__ */ React.createElement(Text, { dimColor: true, marginTop: 1 }, "\u2191\u2193 navegar \xB7 digitar = filtrar \xB7 \u232B apagar \xB7 Enter = abrir \xB7 Esc = cancelar"));
}
render(/* @__PURE__ */ React.createElement(App, null), { stdout: process.stderr });
