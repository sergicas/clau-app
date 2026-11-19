# Clau — definició i pla del curs

Esborrany del 17 de novembre de 2026. **Pendent del vistiplau d'en Sergi.** No s'ha escrit cap codi.

## Què és Clau, en una frase

Clau és una app per aprendre a tocar el piano des de zero, amb un piano o teclat de debò al davant: el telèfon es posa al faristol, ensenya una sola cosa cada vegada, la toca perquè la sentis i t'escolta mentre la toques tu.

## Decisions preses (17-11-2026)

| Pregunta | Decisió d'en Sergi |
|---|---|
| Per a qui és | Per a qui comença de zero |
| Com són les primeres lliçons | Breus, perquè el que s'hi explica és molt elemental |
| On toca l'alumne | En un piano o teclat real. Des del 18-11, també al teclat de la pantalla, perquè no calgui tenir piano |
| Com sap l'app si ho fa bé | Amb piano de debò, escolta amb el micròfon. A la pantalla, sap quina tecla s'ha tocat |
| Fins on arriba | Un curs llarg, fins a llegir partitura i tocar acords |

## Què promet i què no

- **Promet:** que en acabar cada etapa toques una peça sencera que abans no sabies tocar.
- **No promet:** substituir un professor. L'app sent quina nota toques i quan; no veu la mà ni l'esquena, i no pot corregir la postura.

## Com és una lliçó

Totes tenen la mateixa forma, perquè l'alumne no hagi d'aprendre l'app a cada pas:

1. **Mira** — una sola idea, amb un dibuix del teclat o de la mà. Una o dues frases.
2. **Escolta** — l'app ho toca.
3. **Toca** — ho toques tu al piano. L'app escolta i marca cada nota encertada.
4. **Ja està** — quan surt bé tres vegades, la lliçó s'acaba.

Les lliçons de la primera etapa duren **dos o tres minuts**. Més endavant, quan hi ha peces, poden arribar a cinc o deu.

## El curs: set etapes

Cada etapa acaba amb una peça. Unes 60 lliçons en total.

### Etapa 1 · El teclat (8 lliçons, 2 minuts cadascuna)

1. Seure davant del piano i deixar caure la mà
2. Les tecles negres van de dues en dues i de tres en tres
3. On és el do: a l'esquerra de les dues negres
4. Tots els dos del piano, i el do del mig
5. Els dits tenen número: de l'1 al 5
6. Do, re, mi amb els dits 1, 2 i 3
7. Els cinc dits: de do a sol, pujant i baixant
8. **Peça:** l'Oda a l'alegria amb la mà dreta

### Etapa 2 · El pols (7 lliçons)

9. La pulsació: tocar un do seguint el pols de l'app
10. Notes llargues i notes curtes
11. Comptar fins a quatre
12. El silenci també compta
13. Dues notes per pulsació
14. La mateixa melodia, lenta i de pressa
15. **Peça:** Jingle Bells, amb el seu ritme

> Canvi del 19-11-2026, pendent del vistiplau d'en Sergi: el pla deia Germà Jaume, però no es pot tocar sense moure la mà (baixa fins a un sol greu i puja fins al la, nou notes; l'alumne només en té cinc, de do a sol). Jingle Bells hi cap sencera i fa servir tot el que s'ha après a l'etapa: notes d'un cop, de dos, de quatre i de mig cop. Canviar de peça és tocar una sola lliçó a `Course.swift`.
>
> A l'etapa 2 no es fan servir els noms «negra» i «blanca» per a les notes, perquè a l'etapa 1 volen dir tecles. Es diu «un cop», «dos cops», «mig cop»; els noms arriben a l'etapa 3, quan es veuen escrites.
>
> Com es comprova el ritme: l'app compta quatre cops i després mira que cada nota caigui al seu cop, amb marge ample. Amb el teclat de la pantalla el pols sona tota l'estona. Amb un piano de debò el pols només sona als quatre cops d'entrada i després es veu a la pantalla, sense so, perquè el micròfon no el confongui amb una nota. No es comprova quanta estona s'aguanta una nota, només quan comença.

### Etapa 3 · Llegir (9 lliçons)

16. Les cinc ratlles
17. La clau de sol i on s'escriu el sol
18. Do, re i mi escrits
19. Fa i sol escrits
20. Pujar, baixar i repetir: llegir el dibuix, no els noms
21. Com s'escriu una nota llarga i una de curta
22. El compàs
23. Llegir una melodia que no has sentit mai
24. **Peça:** Au clair de la lune, llegida

> Nota del 19-11-2026: d'Au clair de la lune es toca només la primera part (quatre compassos, que es repeteixen). La segona part baixa fins a un sol greu i no hi cap amb cinc dits. Pendent del vistiplau d'en Sergi.
>
> Els noms «negra», «blanca», «rodona» i «corxera» apareixen a la lliçó 21, quan es veuen escrites. La clau de sol surt de la lletra «Apple Symbols» del sistema; la resta del pentagrama (notes, pals, silencis, compassos) es dibuixa a mà. `proves/pentagrama.sh` en fa una mostra al Mac.

### Etapa 4 · La mà esquerra (8 lliçons)

25. La mà esquerra també té cinc dits, però al revés
26. Do a sol amb la mà esquerra
27. La clau de fa
28. Notes llargues a l'esquerra
29. Una melodia amb l'esquerra
30. Canviar de mà sense aturar-se
31. Llegir les dues claus
32. **Peça:** una melodia que passa d'una mà a l'altra

### Etapa 5 · Les dues mans (10 lliçons)

33. Una nota llarga a sota i la melodia a sobre
34. Canviar la nota de sota a temps
35. Les dues mans alhora, la mateixa nota
36. Moviment contrari: les mans s'obren i es tanquen
37. La mà esquerra marca el pols
38. Llegir dues ratlles alhora
39–41. Tres peces curtes, cada una una mica més difícil
42. **Peça:** l'Oda a l'alegria amb les dues mans

### Etapa 6 · Sortir dels cinc dits (8 lliçons)

43. Estirar la mà: la sisena nota
44. Passar el polze per sota
45. L'escala de do, pujant
46. L'escala de do, baixant
47. Les tecles negres: sostinguts i bemolls
48. Sol major i el seu fa sostingut
49. Fort i fluix
50. **Peça:** el Minuet en sol

### Etapa 7 · Acords (10 lliçons)

51. Tres notes alhora: l'acord de do
52. Fa i sol
53. L'acord trencat: les mateixes notes, d'una en una
54. Canviar d'acord sense mirar
55. Acords menors
56. Inversions: el mateix acord en una altra posició
57. Acompanyar una melodia amb acords
58. Do, fa, sol i do: la cadència
59. Acompanyar-se una cançó
60. **Peça:** una cançó amb melodia i acords

Aquí s'aprofiten els textos de les cinc sessions d'acords de la web claudefa.com.

## El límit del micròfon, dit clar

El micròfon només sent bé **una nota cada vegada**. Això marca el curs:

- **Etapes 1 a 4** (una mà): l'app ho pot comprovar tot.
- **Etapa 5** (dues mans): pot seguir la melodia, però no la mà esquerra quan sonen alhora.
- **Etapa 7** (acords): pot comprovar un acord trencat, nota a nota, però no un acord ple.

On el micròfon no arriba hi ha dues sortides, i caldrà triar-ne una quan s'hi arribi:

- que l'alumne s'escolti i decideixi ell si ha sortit bé, comparant amb l'exemple;
- connectar un piano digital amb un cable, que sí que diu a l'app totes les notes que es toquen.

## Com es publica

La decisió és un curs llarg. La recomanació de Claude és **fer-lo sencer però publicar-lo per etapes**: la primera versió amb les etapes 1 i 2 (15 lliçons, fins a tocar dues cançons amb una mà) i una actualització per cada etapa nova.

Motiu: el curs llarg és el que es va intentar el juny i no es va acabar. Per etapes, cada tros queda acabat, provat amb un piano de debò i a la botiga, i el que s'aprèn d'una etapa serveix per fer millor la següent. La decisió és d'en Sergi.

## Què s'aprofita dels esbossos

- El so de piano i el detector de notes amb micròfon (`~/Projects/_arxiu/clau-vella`).
- El dibuix de la partitura i del teclat.
- Tres peces ja escrites nota a nota: Oda a l'alegria, Germà Jaume i el Minuet en sol.
- Els textos d'acords de la web (`~/Projects/clau`).
- L'aspecte: paper crema, lletra amb serifa, to sobri.

## Què queda per decidir

1. Si es publica per etapes o tot de cop.
2. El to: sobri, com la web (sense premis ni felicitacions), o amb alguna recompensa suau per a qui comença.
3. Si l'app és també per a nens o només per a adults (canvia el llenguatge i la fitxa de la botiga).
4. De pagament, gratuïta, o primera etapa gratis i la resta de pagament.
5. Només en català o també en altres llengües.
