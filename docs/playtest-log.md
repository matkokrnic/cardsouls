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

2.8
1 oba mana bara se polako pasivno pune, iako nemogu sa sigurnoscu reci dok nebu visse mehanika implenetirano, cini se mozda malo prebrzo, kao sto mi se cini i da svaki udrac generira previse mane 10% je puno sigurno bi smanjo na 5% a mozda cak i manje te blokirani udarci nebi trebali davati jednako mane kao oni koji ne pordu mozda umjesto 5% onako 2%, ali to su stvarikoje cu bolje zanti reci ka da vise stvari bude implementirano 2 pogodat daje vildjiv skok ,mozdaprevise kako sam ranije komentirao, 3 blkirani pogodak daje manu to ne znam kako sam ranije naveo jeli dobro ili da barrem ne daje mane kao i nebolkirani, buduci da se mana brzo puni a napad je snizen kako smo htjli nisam uspio ubiti lika prije nego se napunio skorz pa nemogu reci, fps nez kako da vidim ako mislim na isto

fps uredan, a sada kazem ti buduci da se mana prebtzo puni vec je skroz puna kad umre p2 pa ne vidm puni li se dok je mrtvac ali kad kllilknem r se respawna s punom manom

4.8.
1 opisano ponasanje je istovjetno testiranom 2 ne znam kako bi ustanovio smanjuje li se špil a vidm da si to opisao kao inteded ponasanje 3 dok nije armiran slot e nista ne radi ali to znam jer se mana en skini i to mogu vjdeti kazes da je "tiho" ali ni kad castam se ne cuje nista bili trebalo? 5vidim da se moze castati tokom rolla i tokom blokiranja bez porblema 4 kad je poritnvik mortav vidim da mogu armirati ali ne i castati, fps stabilan cijelo vrijeme


## 2026-08-04 — Story 3-5a live smoke (two-human)

First run where a card can actually be played. Keyboard only:
P1 holds Q, picks 1-4, confirms with E; P2 holds O, picks 6-9, confirms with P.

Confirmed in play: the selection indicator lights the right slot and clears the
instant the modifier is released; a confirm with nothing armed does nothing; a
cast with too little mana does nothing; while the opponent is dead a card can
still be armed but not cast; fps steady throughout.

Not observable: whether the deck shrinks. Nothing on screen shows a deck count
yet (that is 3-6), so I could only infer the cast landed from the mana dropping.

S5 — there is no feedback on a cast at all. No sound, nothing on screen, for
either a successful cast or a rejection. I noticed the silence before I noticed
anything else; without the mana bar moving I would not know a cast had happened.

S6 — I can cast in the middle of a roll and while holding block, with no
resistance at all. Recording the observation; I am not yet sure whether it reads
as a bug or as the card layer simply being parallel to melee.

6.8.
1 ruka se čita 2 nema gorenje reda protivnice ruke  izgleda uredno 3 elemti se ne sudaraju 4 mana i deck count rade, sada jeli odma vidljivo iz perfiernog vida ha moglo bi biti bolje ali u sadasnjem razvoju nebi to dodatno razraadivao dok nemamo sve implementirano 5 naoruzanje se vidi i bez citanja izbornika NAPOMENA: volio bi da karte ne padaju u slotove ljevo kako im se karte s ljeva konzummiraju vec da povlacenj nove akrte zamjeni slot one igrane

7.8. sada karte nakon sto su igrane ostavljaju prazan slot od 1s te se u njega povlaci nova karta, ne pomicu se sve ulijevo da se popuni praznina

8.8. revela hand toggle premejten u terminal ispisom, neka tkao to ostane, idalje ne vidmi svrhu te funkcionalnosti, idmeo dalje

10.8.
summoni se pojavljuju kad se odigrava karta koja ima summon i ne pojavlju kad se odigra karte bez summona, ostaju na ploci kad ubijem drugog igraca, nestaju kad resetriam n R, fps je stabilan

10.8.
1 cast summona sivi box koji je okrenut prema neprijatljeu 2 porate ga boxevi ako se krece neprijaelj 3 ubijanje radi porpiseno, r mice sumone 4 vidjlivo je solidno 5 DODATAK vidim da heroij mogu poralziti kroz te rpavokutnike ne znam jel to namjerno tako zasad

10.8.
1 summon se krece prema neprijatleju kad je sumonan 2 ne mogu porci kroz njega niti odgurnuti 3kad je vise summona ne trzaju se i ne guraju, rkecu se noralno i medusobno ne mogu porci jedni kroz druge i prate narepatjea 4 pa brizna prilaska i razmak na koje mostaju djeluju okej, iako finalno sama zamiljao minone vise kao eldenr ing mobove nego homing porjektile ovov je za sad a vsie kao homing fireball haha, al sve sto si rekao da provjerim je na mjestu

10.8.
1 ubijanje radi tocno kako si opisao 2  heroij ne dobivaju manu od lupanja neprijatlejivh minoina 3 nema nevidljivg zida 4 udaranje vlastitog minoina ne snizava njegov hp 5 dva unita se ponasaju zeljeno, ne uovde jedan drugom smetnje a oba mogu zeljeno pirmiti dmg iz istog swinga 6 ako se heroja nade izmedu svog minoina i nepreijtlejskog heroja blokira ga, ne znam je li to zeljeno, 7 vec smo ranije rekli da jedanzamah ostti sve neprijatljske minone koje takne ne samo jednoga. 8 3 zamha do smirti se cini kao dobar standard

12.8.
1 summonani minoin krene prem meni i stane kadme krene mlatit samo ne vidim telegraph pa nemogu tocno reci kad krene zamah 2 zamah nema citljivu najavu ili je ja nevdim3 ne znam kako bi izmjegao izmicanjem kada ne vidim tu najavu 4 roll kroz udarac ne prima stetu, block negira dio, a deflect sktoz kako je i zmalsijeno 5 kada me pogodi crveni telegraf oko mene se pojavi 6 minoni se ne ozljeduju medusobno ako su od istog igraca 7 umiru od 3 udarca8 pustiosam da me ubije isve radi okej, e sad to sto nema telgraph ne znam treba li ispravljati jer preppotvlajam da mozemo skoro dodati neke placehodler modle i anmiacije pa ce one same po sebi davati vizualni telegraf sto se desava zar ne

17.8.
zamah ukorijenjuje, kretanje je normalno, porblem otkloinjen ali sada uoceavam da su trenutak lupanja i animaicja nepotavanti pa je onda parry na jako losem mjestu, osim toga super provbitni problem zatvoren adekvatno

26.8.
1 parry je sada mnogo bolji, obrana taman di treba biti 2 najava iako je zamah brzi da se sasvim solidno regirati pravovremneo na njega  4 lesina sotji 10 sekundi pa nestane ne znamo sto ti znaci debug pauza i resrt, primjetio sam jos neka cudna ponasanja u edgecaseovima minoiona ali to bi svako ostavio za nakon implemtnacije e4 e5 i e6

28.8.
1 vidim da rub map zaprao ne postoji jer da i ja i inion letimo iznad kad prestane ploca na kojoj svi stojimo, osim toga minion se spawna kako kazes iza heroija u ondosnu na neprijatleju, i uvje se posjavi isti porblem ako se ni heroj ni neprijatlje ne pomaknu minoinu ce semtati vlastiti heroij i nece ga znati zoabici 2 minoni se dobro sapwna u trku 3 da minon se uvjek spawna iza heroja u odnosu na neprijtleja odnosno da je heroj tocno izmedu vlastitog minona i neprijatelja4 kad dotrcim u lice nepritaljeu minon s eopet klasicno spawna iza mene 5 imam dojam da stoje na tlu ali to nemogu provjeriti jer nemogu micati kaeru slobodno  6 lesine se ne mici i ne spawna se preko nje

30.8.
1 nakon sumonanja totem se pojavi iza igraca koji ga priziva putem karte, visi je od minoina ne mice se, jedino se rotoira oko vlatite osi da prati protivnika 2 blokira kretanje dok je ziv 3  totem puca po portivnickom heroju kada dode u range inace ne puca 4 nakon sto je projektil izbjegnut rollom vise nije prijetnja urpavo kako smo i zmiaslitli, aklcelerija poretkitla mi se jako svida, nalaz za nekad kasnije je, da sam roll mozda ima premalo iframeova, da mu je aniamicije prebrza, sto se oboje rijesva istom stvari i premalo prostora prpode mi se cini, ali nebi to dirao jos neko vrijeme 5 blok i deflect trose zrno tako je, razmilsajm za kasnije mozda napravtit da obicnom totemu vec na sami block ne prolazi nikakva steta da nije deflect potreban al jos cemo vidjeti to 6 vidim samo jednu vrstu totema hellforge totem, koji totemi ako su to neki drugi sluze kao akceleratori mane i stamine ne doalze kroz karte
6 tidal i verdant totemi radi kako je zamisljeno regenracija mane i stamine doista jest ubrzana
