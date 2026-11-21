#!/bin/bash
# Alumne simulat: quantes vegades passa cada ritme del curs tocant amb errors de persona.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -o build/prova-alumne Clau/Music.swift Clau/Course.swift Clau/Rhythm.swift proves/alumne/main.swift 2>&1 | grep -E "error" || true
./build/prova-alumne
