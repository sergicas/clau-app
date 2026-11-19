#!/bin/bash
# Fa córrer una lliçó amb el LessonRunner de l'app, al Mac, tocant cada nota al seu cop.
# Ús: proves/llico.sh 21        (o: proves/llico.sh 21 0.15 per tocar 0,15 s tard)
set -e
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -parse-as-library -o build/prova-llico Clau/Music.swift Clau/Course.swift Clau/Rhythm.swift Clau/LessonRunner.swift proves/llico.swift 2>&1 | grep -E "error" || true
./build/prova-llico "$@"
