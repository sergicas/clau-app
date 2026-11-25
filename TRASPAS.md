# Traspàs: on som amb Clau (2026-11-24)

## Estat
- Últim commit de codi: vegeu `git log` (sisena revisió, 2026-11-24). Tot està desat a git i pujat a GitHub. No hi ha canvis pendents.
- La darrera versió està instal·lada a l'iPhone (Release) i al Mac (`./mac.sh` → /Applications/Clau.app).
- `proves/prova.sh` diu «Tot bé.»

## Què s'ha fet en aquesta tanda (commits 85268c8 → d16f481)
- **Quarta i cinquena revisió del provador** (informes a `revisions/2026-11-22.md` i `revisions/2026-11-23.md`):
  - El jutge del ritme detecta quan l'alumne toca amb la mà desplaçada una tecla amunt o avall. El missatge diu quina tecla anava i quina ha tocat.
  - Una blanca escurçada té prioritat sobre «vas una nota per davant» i sobre «vas una nota endarrerit». La regla és `shortened()` a `Clau/Rhythm.swift`.
  - La L21, pas 3, té un text més curt.
- **Passos intermedis** abans dels salts de les blanques:
  - L10: «un do llarg i dos de curts».
  - L11: «un do de dos cops i dos mis».
  - L15: els trossos de la cançó es toquen de dos en dos.
  - L28: «només un do i un sol de dos cops».
- **Partitures amb compassos** (`Clau/StaffView.swift`): les notes i les barres de compàs tenen més aire. Les plicas ja no toquen les barres i el punt ja no toca la corxera.
- **Test d'interfície**: `launch()` fa `app.activate()` i comprova que Clau quedi al davant.

## Tanda del 2026-11-24 (commits 428093b i 33b2632)
- L32 vista a l'iPhone: el recorregut d'interfície ha passat.
- L24: pas 6 nou, «on es torna a començar» (el final i el principi, amb punts de pols), abans de tocar-la dues vegades (ara pas 7). La prova del «qui corre» de `proves/main.swift` agafa l'últim pas de la L24.
- Punts de pols (`StaffView.drawPips`): es reparteixen cap a la nota següent, amb un buit entre notes i una ratlleta que uneix els punts d'una mateixa nota.
- Sisena revisió del provador (`revisions/2026-11-24.md`): arreglats els punts sense compassos (L21, L28), la ratlla doble i el text del pas 6 de la L24. Després, també s'encenen els punts als passos d'escoltar (`playExample` publica `rhythmBeat`).

## L33, la primera de l'etapa 5 (2026-11-24)
- Etapa 5 «Les dues mans» oberta amb la L33 «Una nota llarga a sota» (`Course.notaDeSota`). Tres compassos: a cada un, l'esquerra toca una rodona (do, sol, do) sola al primer cop i l'aguanta; la dreta toca tres negres als cops 2, 3 i 4.
- Nou `Tone.hold`: la nota sona i s'escriu així de llarga, però la següent comença al cap de `beats`. El jutge del ritme no canvia, perquè només mira quan comença cada nota. El pentagrama de les dues mans posa un silenci a l'altra mà mentre la nota de sota sona sola.
- Alumne simulat (corregit el 2026-11-25: la xifra d'abans era la columna del «ritme propi», no la del principiant): el principiant passa un 84–90 % els passos d'un compàs i un 89–96 % els de tres; qui porta el seu propi tempo sense escoltar el pols, un 74 % i un 27 %.
- No s'ha vist a l'iPhone ni amb un piano de debò. No se sap si el micròfon reconeix bé la melodia mentre la nota de sota encara sona.

## L34, canviar la nota de sota (2026-11-24)
- L34 «Canviar la nota de sota» (`Course.canviarSota`). La nota de sota és una blanca (`hold: 2`): l'esquerra toca als cops 1 i 3 i la dreta, als cops 2 i 4. Tres compassos: do–sol i mi–re a sota, i per acabar el compàs del do llarg de la L33. Les mans continuen sense començar mai alhora.
- Alumne simulat (corregit el 2026-11-25, mateixa confusió de columnes): el principiant passa un 85–91 % els passos d'un compàs i un 91–98 % la resta; el «ritme propi», un 74 %, un 45 % i un 28 %.
- Com la L33, no s'ha vist a l'iPhone ni amb un piano de debò.

## L35, les dues mans alhora, i el piano per cable (2026-11-25)
- **Decisió d'en Sergi:** les dues coses. Amb un piano digital connectat per cable l'app ho corregeix tot; sense cable, als passos amb dues notes alhora l'alumne s'escolta i diu ell si ha sortit bé.
- `Tone.also`: una segona nota que comença alhora amb l'altra mà. El pentagrama la dibuixa al seu lloc, el teclat marca les dues tecles i l'exemple les fa sonar totes dues.
- `RhythmJudge` accepta dues notes al mateix moment (proves noves a `proves/main.swift`, «Dues notes alhora»). L'alumne simulat també toca la segona mà, amb un desajust de 25 ms.
- `Clau/MIDIInput.swift` (CoreMIDI, només escolta): detecta un piano endollat, descarta la sessió de xarxa i els busos interns, i passa cada tecla amb el seu instant. Quan hi ha cable, el micròfon no s'engega i el pols sona també mentre es toca. A la tria «Un piano» ho diu: «Piano connectat per cable».
- Sense cable (`LessonRunner.selfChecked`): l'app compta, marca el pols i al final pregunta «Ha sonat com l'exemple?», amb «Sí, ha sortit bé», «Encara no» i «Escolta l'exemple».
- A la pantalla (teclat dibuixat) les dues notes es comproven com amb el cable, perquè la pantalla sap totes les tecles.
- L35 «Les dues mans alhora» (`Course.mansAlhora`): la mateixa nota amb les dues mans, de quatre dos fins a pujar i baixar de do a sol. Principiant simulat: 90–100 %; «ritme propi», 34–89 %.
- **Provat al Mac** amb `proves/piano-virtual.swift` (un piano MIDI de mentida; es compila amb `swiftc -O -o build/piano-virtual proves/piano-virtual.swift`): Clau detecta el cable, rep les tecles (L1 acabada amb tres dos), jutja les dues mans a temps (L35 pas 4, «BÉ» al registre) i torna al mode d'escoltar-se quan es desendolla. El mode sense cable també s'ha recorregut al Mac.
- **No provat:** amb un piano digital de debò i un cable de debò, ni a l'iPhone (només s'hi ha instal·lat). Tampoc dos dits alhora a la pantalla del telèfon. El cable és USB; per Bluetooth no s'ha fet res.
- El projecte es regenera amb `xcodegen generate` quan s'afegeix un fitxer a Clau/.

## Auditoria de ChatGPT (2026-11-25)
- 17 punts sobre el commit 44eb4ba (abans de la L35). Gairebé tots són certs; en Sergi ha dit de començar pels arreglos petits.
- **Fets:**
  - 3: el jutge dona una nota per perduda amb el mateix rellotge que els tocs (`LessonRunner.inputDelay`), i el final espera aquest retard.
  - 9: `rhythmBeat` va de mig cop en mig cop (Double), també als exemples: les corxeres a mig cop encenen el seu punt.
  - 10: «Has tocat durant un silenci» només si el toc cau dins d'un silenci (`RhythmJudge.rests`); prova nova a `proves/main.swift`.
  - 11: els passos saltats es compten (`LessonRunner.skip()`); el final diu «Lliçó recorreguda» i quants n'has saltat, i no «Has tocat la peça sencera». La lliçó continua quedant com a feta.
  - 17: textos de les L11, L20, L22 (els dos quatres) i L25 (què és una octava).
- **Fets després (mateix dia):**
  - 1: amb micròfon, els passos on la nota de sota encara sona quan entra la melodia (`hold`) van al mode d'escoltar-se (`LessonRunner.selfChecked`): L33 passos 5, 7, 9 i 10; L34 passos 4, 6, 7, 9 i 10. El text diu «Mentre la nota de sota encara sona, el micròfon no et pot corregir».
  - 2: amb la pantalla o el cable, quan el pas té notes de la mà esquerra el jutge demana la tecla exacta (`RhythmJudge.exact`). Si el nom és bo i l'octava no, diu «Aquí anava un do més avall». Amb micròfon n'hi ha prou amb el nom.
  - 4: amb la pantalla o el cable, una nota de dos cops o més s'ha d'aguantar fins a mig cop abans del final (`RhythmJudge.released`). Si no, la marca surt malament i diu «Mantén la tecla apretada». El cable també passa quan s'aixeca la tecla (`MIDIInput.onRelease`).
  - `proves/llico.sh <lliçó> [desplaçament] [bé|solta|octava]`: fa córrer el LessonRunner de debò i ara també aixeca els dits. L'alumne simulat no aixeca els dits ni s'equivoca d'octava: les seves xifres no canvien.
- **Pendents, per ordre:** micròfon: errors, permisos, fils i filtre d'octaves (5, 6, 8), millor amb un piano de debò; L24 per graons (12, ho ha de decidir en Sergi); teclat en pantalles petites (13); compàs 3/4, alteracions i acords abans de les etapes 6–7 (14); publicar: política de privacitat dins l'app, Mac, fitxa (7, 15, 16).

## Decisions d'en Sergi
- En els ritmes curts no es perdona una blanca escurçada. Per això el principiant simulat es queda a uns 30 % als passos difícils, i en Sergi ho vol així.
- Mai simuladors d'iOS: les proves es fan a l'iPhone per cable.
- El provador no toca Clau/, ClauUITests/ ni el projecte, i no fa commits.
- Des del 2026-11-25 es pot pujar tot a internet (abans no es pujava res). El codi és a https://github.com/sergicas/clau-app, repositori públic des del 2026-11-25. Aquell dia es va demanar una auditoria a ChatGPT (xat «Fes una auditoria de l'app Clau…»); falta llegir-ne el resultat. Enviar res a Apple continua demanant el seu sí.
- A les L33 i L34 les dues mans mai comencen alhora (2026-11-24). Des de la L35 sí: amb cable ho comprova l'app i sense cable l'alumne s'escolta (2026-11-25).

## Pendent
1. ~~Veure la L32 a l'iPhone.~~ **Fet el 2026-11-24:** testLlegir i testEsquerra han passat (el telèfon anava per xarxa local, no per cable). Les captures e08, e09, g12 i g13 són correctes. Abans, dues proves d'interfície havien fallat amb «Timed out while enabling automation mode». Abans de provar-ho, cal:
   - que el telèfon estigui desbloquejat i amb la pantalla encesa;
   - que el Mode de desenvolupador estigui activat;
   - acceptar qualsevol avís que surti al telèfon.

   Ordre de prova:
   ```
   xcodebuild -project Clau.xcodeproj -scheme Clau -destination 'id=00008140-001154DA2EE3001C' \
     -derivedDataPath build/ddtest -resultBundlePath build/proves-iphone.xcresult test \
     -only-testing:ClauUITests/Recorregut/testLlegir -only-testing:ClauUITests/Recorregut/testEsquerra
   ```
   Després:
   - exportar les captures amb xcresulttool;
   - mirar e08-l32-peca, e09-l32-primer-tros, g12 i g13;
   - desinstal·lar el runner `cat.sergicastillo.clau.uitests.xctrunner`.
2. Coses obertes que en Sergi no ha demanat:
   - Ningú ha provat l'app amb un piano de debò.
   - ~~La L24, pas 6, és al 22 %.~~ 2026-11-24: nou pas 6 «on es torna a començar» (el final i el principi, 62 %) abans de les dues vegades (ara pas 7, 22–30 %). L'últim no pot pujar sense perdonar blanques: té sis notes llargues.
   - ~~La L35: cal triar com es comprova.~~ Triat i fet el 2026-11-25 (cable i escoltar-se). Falta provar-ho amb un piano digital de debò.
   - L'auditoria demanada a ChatGPT el 2026-11-25: falta llegir-ne el resultat.
   - ~~Els punts de pols de les notes llargues queden amuntegats.~~ 2026-11-24: es reparteixen des del cap de la nota fins al de la següent (`StaffView.drawPips`).

## Eines útils
- Proves del motor: `proves/prova.sh`
- Alumne simulat: `proves/alumne.sh`
- Partitures dibuixades: `proves/pentagrama.sh --curs` → `build/revisio/llico-NN.png`
- Instal·lar a l'iPhone (Release):
  ```
  xcodebuild -project Clau.xcodeproj -scheme Clau -configuration Release -destination 'id=00008140-001154DA2EE3001C' -derivedDataPath build/ddiphone -allowProvisioningUpdates build
  xcrun devicectl device install app --device 00008140-001154DA2EE3001C build/ddiphone/Build/Products/Release-iphoneos/Clau.app
  ```
- Agent `provador-clau`: fa una revisió completa i n'escriu l'informe a `revisions/`.
