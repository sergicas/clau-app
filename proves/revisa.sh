#!/bin/bash
# Revisió completa de Clau al Mac, sense telèfon ni simulador. Tot va a build/revisio/.
#   resum.txt      què ha passat a cada prova
#   alumne.txt     quantes vegades passa cada ritme un alumne simulat
#   llicons.txt    cada lliçó feta amb el LessonRunner de l'app, tocant bé
#   registre.txt   els ritmes que ha tocat de debò algú a l'app del Mac (últims 7 dies)
#   llico-NN.png   totes les partitures de cada lliçó, amb l'amplada d'un iPhone
set -u
cd "$(dirname "$0")/.."
OUT=build/revisio
rm -rf "$OUT"; mkdir -p "$OUT"
RESUM="$OUT/resum.txt"
echo "Revisió de Clau, $(date '+%Y-%m-%d %H:%M'), $(git log --oneline -1)" > "$RESUM"

pas() { echo "== $1" | tee -a "$RESUM"; }

pas "Compilar l'app (iPhone, per al Mac)"
if xcodebuild -project Clau.xcodeproj -scheme Clau -configuration Debug \
     -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
     -derivedDataPath build/ddrevisio build > "$OUT/compilar.txt" 2>&1; then
  echo "  bé" | tee -a "$RESUM"
else
  echo "  FALLA: mira $OUT/compilar.txt" | tee -a "$RESUM"
  grep -E "error:" "$OUT/compilar.txt" | head -20 | tee -a "$RESUM"
fi
grep -c "warning:" "$OUT/compilar.txt" | sed 's/^/  avisos del compilador: /' | tee -a "$RESUM"

pas "Motor i curs (proves/prova.sh)"
./proves/prova.sh > "$OUT/motor.txt" 2>&1
grep -E "MAL|FALLA|error" "$OUT/motor.txt" | tee -a "$RESUM"
tail -1 "$OUT/motor.txt" | sed 's/^/  /' | tee -a "$RESUM"

pas "Alumne simulat (proves/alumne.sh)"
./proves/alumne.sh > "$OUT/alumne.txt" 2>&1
sed -n '/^Avisos:/,$p' "$OUT/alumne.txt" | tee -a "$RESUM"

pas "Cada lliçó amb el LessonRunner, tocant just al cop"
swiftc -O -parse-as-library -o build/prova-llico Clau/Music.swift Clau/Course.swift Clau/Rhythm.swift Clau/LessonRunner.swift proves/llico.swift 2>&1 | grep -E "error" | tee -a "$RESUM"
TOTAL=$(grep -c "number: [0-9]" Clau/Course.swift)
: > "$OUT/llicons.txt"
for n in $(seq 1 "$TOTAL"); do ./build/prova-llico "$n" >> "$OUT/llicons.txt" 2>&1; done
grep -B3 "MAL" "$OUT/llicons.txt" | tee -a "$RESUM"
echo "  $(grep -c '^Tot bé' "$OUT/llicons.txt") lliçons acabades sense errors de $TOTAL; $(grep -c 'MAL' "$OUT/llicons.txt") voltes dolentes" | tee -a "$RESUM"

pas "Partitures (build/revisio/llico-NN.png)"
./proves/pentagrama.sh --curs > "$OUT/partitures.txt" 2>&1
echo "  $(ls "$OUT"/llico-*.png 2>/dev/null | wc -l | tr -d ' ') imatges" | tee -a "$RESUM"

pas "Ritmes tocats de debò a l'app del Mac (últims 7 dies)"
/usr/bin/log show --last 7d --predicate 'subsystem == "cat.sergicastillo.clau" AND category == "ritme"' 2>/dev/null \
  | grep -v "^Timestamp" | sed -E 's/^([0-9-]+ [0-9:]+).*\] /\1 /' > "$OUT/registre.txt"
echo "  $(grep -c 'lliçó' "$OUT/registre.txt") intents; $(grep -c 'BÉ' "$OUT/registre.txt") bé, $(grep -c 'MAL' "$OUT/registre.txt") malament" | tee -a "$RESUM"

pas "iPhone connectat"
if xcrun xctrace list devices 2>/dev/null | sed -n '/== Devices ==/,/== Simulators ==/p' | grep -q "00008140-001154DA2EE3001C"; then
  echo "  sí" | tee -a "$RESUM"
else
  echo "  no (o no disponible): les proves d'interfície al telèfon no es poden passar" | tee -a "$RESUM"
fi
echo "Fet. Resum a $RESUM"
