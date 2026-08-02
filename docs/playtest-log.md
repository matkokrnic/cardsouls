# Playtest log

Dnevnik osjecaja. Pise se rukom, odmah nakon testa, na hrvatskom.
Ne daj nijednom agentu da ovo pise umjesto tebe.

Za svaki test zapisi: koji su flagovi bili ukljuceni, sto je bilo zabavno,
gdje je bilo previse toga za pratiti, i sto te iznerviralo.

---

2-1 split-screen smoke — stabilnih 60 fps kroz puni melee exchange s dva igrača, bez jittera kamere, framing na pola širine drži bez izmjene configa; opažanja: mrtvi hero se i dalje kreće (poznati DEAD-slot residuals, fix na 2-3), parry trenutno bez posljedice za napadača

## 2026-07-28 — 2-2 gamepad controller (smoke)

Hardver: Logitech F310, prekidac na X (XInput). Pad ukopcan PRIJE pokretanja igre.
Build: HEAD 8947be4 + necommitane dev pass promjene.

Flip 1 — Array[int]([3, 2]), pad na slot 0 vs NULL dummy:
- napad, blok i roll rade s pada, nema ispadanja inputa
- facing kontinuiran, nije 8 smjerova
- shema RB napad / LB blok / B roll mi odgovara, ne mijenjam je

Flip 2 — Array[int]([2, 3]), NULL dummy na slot 0, pad na slot 1:
- isti pad vozi P2
- konzola pri pokretanju: [gamepad] slot ordinal 0 -> device 0 (XInput Controller)
  — pad je na slotu 1 a dobio je ordinal 0, znaci device se izvodi iz spojenih
  joypadova, ne iz slot indeksa
- chain od 2-3 udarca linka isto kao na tipkovnici
- iskopcavanje pada usred meca: slot ide u neutral, bez pada i bez pauze;
  ukopcavanje vraca kontrolu

Nije provjereno:
- simultana dva-pad izolacija (imam jedan pad)
- fps/perf mjerenje nije radeno
- jitter na rubu deadzonea nisam posebno gledao

Zakljucak: PASS za pokriveno.

28.7.

split screen radi kako spada, kada igrac biva ubijen ne moze se micati za razliku od ranije

28.7.

jepo je vidjeti ovoliko novih stvari i motivirajuce, hud je svaki u svojoj polovici, nista ne strsi van vlastiitog okvira, ejdino mi je pitch zona nezgrapno poizcioniorana nasred obe polovice ekrana(mozda bi j smjestio ljevo od hp/stam/mana barova/karata iako nisam isguran jos za ui to bi dosminavao kasnije ako nije problem, daj me sjeti jeli pitch zone zajednicki ili svako ima svoj to je jedna od stvari koje be volio reicmo isprobati obe u nekom trenu pa onda odlucivati, mozda i usporedivai u raznim fazama razvoja), na prvu mi se ikone za karte cine mrvu malo za jasnu citljivost ali to cemo bilje znati kada dode stvarni art, osim toga vidim da attak ne pije staminu 2 hp i stam jesu puni mana jest prazna, 4 mana raste pogodcima doista, ranije mi se i cinilo da su mozda samo udarci bre brzi generalno i tome u korsit ide relativna brzina u odnosu na rol ali vjerujem da ce se to dodatno iskrislizirati kada dodamo konkretne modele i animacije, vidim da se pravilo ispijeu you win/lose natpis, vidim da kad kliknem R ubijeni ozivi ali idalje ostanu lose win natpisi, osim toga vise ne vidim debug log koji je prije govorio koje se akcije desavaju ne znam je li to namjerno, fps kako treba biti, odlicno

zakljucci; nema debuga I da napad ne pije  staminu je intentional


28.7 2-5

sav ui na svom mjestu I ne smeta si,
poledinilica su prikazani kako je zamisljeno
nema nezeljenih preklapanja
sve je na svom mejstu od ranije
natpis idalje stoji nakon R
fps stablian

29.7.

mislim da se ubijanje kretajucih igrace odvija propisno s tim da je tekso porcjeniti jer napaddac koji lovi stane svaki put kad azmahuje, ono sto svakako mogu reci 100% sigurno je to da nakon R nestaje win/lose poruka, nije mi jasno sto je ovo magnitude i ovo drugo, primjetio sam da kad toglam to drugo(a ne vidim procitati jer malo strsi van ekrana ljevo i poklapa se sa drugim elemetom, slika priakzuje to, sotale svati su unutar svojih gabarita sto se tice priakza), reci mi zasto priakzjemo statuse igraca dvaput u ui-u i kao state przore zasebne, aha to je instepctor, pa kad p1 nešto radi tipa napada p2, mejnja se inspector od p2 tj pada mu hp, jesi ti htio mozda prikazati tudi hp i statuse? instument zaklanje hud kao sto sam ranije rekao, pitch zona na novom mejstu je po meni mnogo bolje pozincinoirana nego na sred ekrana, kako da ac7 odradim, fps je uredan

sad je dovedne  u red I razjasnjeno dosta toga
1 leš ne nastavlja klizati kada ga ubijem u prketu, panel je sada na sredini, citljivo je ali ruzno izgleda, osim toga sad uiocama da se oba igraca prraliziraju kada jedan umre

## 2-6-legibility-feel-instrumentation — live smoke (2026-07-29)

Config: shipped default, two live humans, no .tscn edit. fps ~145.

PASS. Block 1 confirmed live:
- round ends -> BOTH heroes freeze (intended: step 1b skips resolution for both)
- a hero killed while MOVING does not slide; the corpse halts
- R clears the win/lose label and the match continues; repeatable
- inspector present in both halves, primed from the start, per-slot correct
- pitch zone A/B moves both halves together

Findings (non-blocking):
- S4: pitch zone at anchor B (left of the vitals bars) reads BETTER than dead
  centre. FIRST A/B reading only -- the verdict stays open for E6.
- S6: the instrument panel is readable and clear of the HUD after the fix, but
  centred and visually ugly. Cosmetic, no owner.
- S8: the attack sting and the block sting are more similar to each other than
  either is to the roll sting. All three cues still read correctly and in time,
  but SHAPE carried the read -- by ear alone attack vs block is weak, and the
  protocol requires the set to be distinguishable by ear as well. Owner: the
  DEBT E "legibility under 0.5s" member on the rig story, where the definitive
  run with a naive observer also lives. NOT fixed in 2-6.

AC 4 (variable analog magnitude): NOT verifiable in this smoke -- keyboard slots,
no pad, .tscn flip forbidden. Switch present and toggles; effect unverified.

### AC 7 -- telegraph legibility protocol, rehearsal run
naive observer: NO -- DRY RUN of the procedure, not a verdict on the cues.
Definitive legibility judgement stays animation-gated (rig story).

| Action | Cue | Identified before resolve? | Correct? | Carried by | Note |
|--------|-----|---------------------------|----------|------------|------|
| Attack | AttackCone + StingAttack | Y | Y | both | sting close to block's |
| Block  | BlockShield + StingBlock | Y | Y | both | sting close to attack's |
| Roll   | RollDisc + StingRoll     | Y | Y | both | clearly distinct by ear |



31.7. 
konfiguracija (isporučeni default, dvije tipkovnice, bez flipa) i da ste bili dvojica
što je prošlo: šest animacija na prave akcije, leš ostaje ležati, deflect bez trzaja, fps stabilan
žuti roll krug pokraj lika — najvrednija stavka; zapiši da si vidio tijelo odvojeno od mjesta gdje hero stvarno jest
roll klip se prekine puno prije kraja
blok nema međukadrova, pop u pozu i iz nje
da ništa od toga ne blokira adoption i da sve tri stavke idu 3-0b



2.8.
1  taman ili mozda samo mrvicu pre brzo ali zasad vise nego dovoljno dobro 2 cini se taman za reagirati 3 sve 3 anicmacije su prisutne 4 od oka mi je tesko tvrditi sa isgurnoscu ali djeuje kao da registracija udasraca se poklapa sa stizanjem maca to mi se cini dobro 5 za sada vise nego dovoljno dobro mozda bi jos malo posporio nekad kasnije 6 osjecas ses neranjivost a li misli mda bi bila jos dodatna da mrvu dulje traje, al kazem zasasd to vise nebi dirao dovjno dobro je za sada
zvuk tkoader telegrafira dovoljno dobro