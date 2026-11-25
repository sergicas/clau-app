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
- Alumne simulat: el principiant passa un 74 % els passos d'un compàs i un 27 % els de tres compassos, com a la resta del curs.
- No s'ha vist a l'iPhone ni amb un piano de debò. No se sap si el micròfon reconeix bé la melodia mentre la nota de sota encara sona.

## L34, canviar la nota de sota (2026-11-24)
- L34 «Canviar la nota de sota» (`Course.canviarSota`). La nota de sota és una blanca (`hold: 2`): l'esquerra toca als cops 1 i 3 i la dreta, als cops 2 i 4. Tres compassos: do–sol i mi–re a sota, i per acabar el compàs del do llarg de la L33. Les mans continuen sense començar mai alhora.
- Alumne simulat: el principiant passa un 74 % els passos d'un compàs, un 45 % els dos compassos i un 28 % els tres.
- Com la L33, no s'ha vist a l'iPhone ni amb un piano de debò.

## Decisions d'en Sergi
- En els ritmes curts no es perdona una blanca escurçada. Per això el principiant simulat es queda a uns 30 % als passos difícils, i en Sergi ho vol així.
- Mai simuladors d'iOS: les proves es fan a l'iPhone per cable.
- El provador no toca Clau/, ClauUITests/ ni el projecte, i no fa commits.
- Des del 2026-11-25 es pot pujar tot a internet (abans no es pujava res). El codi és a https://github.com/sergicas/clau-app, repositori privat. Enviar res a Apple continua demanant el seu sí.
- A l'etapa 5, de moment, les dues mans mai comencen alhora (2026-11-24). Què fer quan hagin de començar juntes (L35) està per decidir.

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
   - La L35 (les dues mans alhora): cal triar com es comprova amb piano de debò, perquè el micròfon no sent dues notes que comencen alhora.
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
