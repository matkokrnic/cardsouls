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

31.8.
2 kamera gleda preko mog ramena prema protivniku 3  cjelo vrijeme gledamo protivnika sto je zeljeno ponasnje, ali kad idem ljevo ili desno animacija je cudnoa hodamo unaprijed a micemo se kao da lebdimo u densno odk hodamo u rpazno ako ima smislsa 4 kretanj je okej stick prema naprjed idemo napred orbitiramo ljevo desno, osim sto kazem animaicja izgleda sada lose tj krivo 5   roll bez icega je odskok koji cudno izgleda animacijski usmjereni roll ide kud gurnem uz cundu animaciu i genralno pre kratko traje animacija mu je prebrza i premau udaljnost pokrije al to smo cini mi se i nekad ranije ustanovili 6 flick radi ali cini mi se da je pre grub/nagaoa trenutno trebalo bi ga svakako smoothati to se vlajda postize akceleracijom ili ne znam ti bolej zans svakako, svakako bi dodao marker tockicu na neprijatleju koji je trenutno targetan kako i je u elden ringu/ dark soulsu / sekiru 7 r3 dosita vraca target instantno na neprijatlejskog heroja 8 leš odmah vraća na heroja lock on targeting 9 nemogu cut nikakve telgerafe jos jer nema unblockable napada ako na to mislsi ako mislsi na obican napad cuje se da 10 pri smrti keran se zamrzne 11 ne znam kako vidit ali cinilo se okej sto se fps tice ovako od oka zna se desit da kad su 4 miniona na hrpi i hodaju zabijajuci se jedni u druge da onako malo blinkaju u priakzu DDOATNO kad ima vise meta primjetio sam da shuffle lock ona na meta nije samo "ljevo desno" vec doslovn odabire metu koja najbolje odgovra filcku sa analgoa nisam siguran da je tako u souls igrama nego da doslovno vrtis ljevo desno kako su trenuo orjenitrani u prikazu sto bi mi proetpostalvjam i vise pasalo ali n mogu biti siguran, sto ti mislis i pitaj ako sam negdje bio nejasan


1.9.
1 tokica je sad na boljoj visini iako opet kako se model gega ona zna mrvicu isapdati iz kontuire mionona ali to je sad nebitno zasda je ovo dovoljno dobro idemo dalje 2 totem i heroj idelj uredu 4 round ouver = markeri nestaju

projektili lete, krene titrat dio ekreana pa mi je tekos rec tjela koja stoje i nemicu se jer su zapela(minoni ne zanju reagirati akd se prepreka nade ispred nih nego se ukipe dok se nesto ne pomjerni) i hodajuci/napdajuci titraju sigurno a cini mi se i lesevi da znaju iako nisam savami siguran al nebi to dodatno ispitiva, svakako nije cesta pojava i  desi se kad je ionako ne situacij koju ne vidim realno u igri

1.9. (4-5 pooling / 60 fps smoke)
1 mjerni harness (perf_20_units_live): oko 20 jedinica na ploci, obje polovice ekrana, totemi pucaju - projektili lete prema herojima na sredini; minioni se medusobno napadaju i napadaju toteme (standard prioritet iz 4-2, prvi put vidjeno u ovolikoj guzvi)
2 flags off (minions i totems na false): karte se odigraju, nista se ne spawna, nista ne pukne, run sam zavrsi nakon par sekundi - ok; flagovi vraceni na true, git status prazan
3 titranje: rijetko, kad je puno miniona na hrpi krene titrati dio ekrana i kamera malo zatrza; titraju sigurno tijela koja hodaju/napadaju i ona koja stoje ukipljena, lesevi mozda, nisam siguran i ne bih to dalje ispitivao - nije cesto i situacija realno nije iz igre
4 minioni ne znaju reagirati kad im je prepreka ispred, ukipe se dok se nesto ne pomakne (poznato iz 4-3) - za playtest blok


2.9.
ljevi I densi strafe I ostatak lokmocje rade
## 2026-09-02 — 5-0a live smoke (Matko, pad, flip [0,3])
- Lock-on + sideways: strafe clips play; FIRST run had left/right visually
  swapped (Mixamo preview mirror) — fixed by swapping the two source files,
  re-verified correct in-game.
- Backpedal correct while locked; diagonal boundary flicker not noticeable.
- Locomotion transitions crossfaded; attack/block/roll still instant.
- Attacks land normally (bone-following hitbox); chained swings restart.
- FPS stable.

## 2026-09-02 — 5-0b pad card input (živi smoke, pad, flip [0,3])
Sve 1-9 PASS: held-L3 cast mode, slotovi L2/L1/R1/R2 = HUD red, Basic cast + odbijanje bez slota,
supresija attack/block/roll pod L3, roll escape na puštanje, held-through-exit ne okida, trigger
ne spama, lock-on netaknut, fps stabilan.

3.9.
## 2026-09-02 — 5-0c totem + projektil modeli (živi smoke + re-smoke, pad, flip [0,3])
Tri tinta razlučiva na pogled. Crvena na combat totemu prigušena crveno-smeđa (tint*teal maska,
MULTIPLY) — jarkija bi bila bolja, nije esencijalno, odgođeni polish. Model sjeda u prostor, ne
lebdi/tone. Projektil žuta kugla — mami i bratu uočljivija od stare, meni stara djelovala
trodimenzionalnije; ostaje žuta, dubina = odgođeni polish. NALAZ: totem se rotirao za metom —
presudio da totemi NIKAD ne rotiraju (obara 4-4 "prihvaćena kozmetika", suđeno na sivoj kutiji);
fixano, re-smoke 3/3: totem miran, puca 360 i iza leđa, minioni se normalno okreću. Gameplay netaknut.


1 klizanje radi dobro na sva cetri tzida 2 kutevi su isto nepopusni ali ni ne zpainjem, dobro je  3 summon iza leda u kutu recimo stvori heroiju iza leda sto ga malo pogurne unaprijed heroja jel, ne summona se vani 4 kamera je malo probelmaticna inace mi se znalo desavati da malo preipsitam odluku o tome da se kamerom ne moze slobodno urpavljati i ne znam kolko je to dobra odluka, ali o tom cemo kasnije nekada, zasad je doboljno zpamatiti da forsirani lock on ima svoje uocene manjakvosti a dodavanje zidova sprjevava da osoba vidi svog heroja kad je blizu zida, mozda bi bilo blje da su zidovi porzirini 5 projektili su ok 6 vanjsk rub zida ne smeta 7 djeuluje ok jedino malo ruzno izgleda redneranje gornje strane zidova i kad se kruzi nekako je pre pravokutno prezentirano ako ima smisla al to nije bitno

## 2026-09-03 — Story 5-0d arena-edge — live smoke (pad flip [0,3])

1. Wall sliding: smooth on all four walls, no bounce, no pass-through. PASS.
2. Corners: solid, unyielding, no snagging or catching. PASS.
3. Near-wall/corner summon (F1 containment fix): unit spawns INSIDE the arena behind the hero;
   depenetration nudges the casting hero slightly forward — accepted as cosmetic (the clamp can
   place the spawn within body-overlap distance of a wall-pinned hero), not a defect. PASS.
4. Camera under lock-on at a wall (SMOKE-WATCH → RESOLVED in-story, `5-0d/R5`): confirmed — the
   forced-lock camera ends up outside the ring sighting the hero through an opaque wall; the hero
   is occluded. Operator ruled transparent walls the right fix on the spot; applied in-story and
   verified live (see item 8 below). Separately noted, NOT resolved here: the forced lock-on
   itself (no free camera control) has observed shortcomings, deferred to the post-E5+E6
   playtest/retune block.
5. Projectiles pass through the wall visually: accepted by design (AC 7). PASS.
6. Outer wall overhang above the void: visible from the edge, does not bother. Accepted.
7. Performance feels fine. Cosmetics: the walls' top-face rendering looks rough and circling the
   arena reads "too rectangular" — AC 2 untuned territory, noted for a later art pass. Not
   blocking.

Verdict: SMOKE PASS.
4. Camera under lock-on at a wall (SMOKE-WATCH → RESOLVED in-story): confirmed — the forced-lock
   camera ends up outside the ring and an opaque wall occluded the hero. Operator ruled on the
   spot that transparent walls are the right call; applied in a cosmetic pass (shared
   StandardMaterial3D, grey-blue, alpha 0.35, four wall meshes; collision untouched, golden
   unmoved) and verified live — the wall still reads as a boundary from inside, the hero stays
   visible through it from an outside-the-ring camera. Separately noted, NOT resolved here: the
   forced lock-on itself (no free camera control) has observed shortcomings; that question is
   deferred to the post-E5+E6 playtest/retune block.

8. Transparent walls verified live after the cosmetic pass: boundary still legible from inside,
   hero visible through the wall under near-wall lock-on, alpha 0.35 judged right, wall top-face
   rendering acceptable. PASS.


4.9.
5-1 accelerator stacking — smoke na padu, 6/6 PASS. Prvi mana totem kao i dosad; drugi osjetno brži, bar skače više po tiku. Isto za staminu. Ubijanjem jednog od dva efekt se vraća na razinu jednog, ne na nulu. Protivnikovi totemi ne diraju moje barove. fps stabilan. Bez nalaza.

5-1a: regresijski smoke na padu, lock/flick/smrt mete/marker/fps sve kao prije, ništa vidljivo se nije promijenilo

## 2026-09-04 — 5-2 unblockable initiation — REGRESSION smoke, 5/5 PASS

This is a REGRESSION smoke, per `5-2/R15`: mode 2 was NOT observed in motion, because no input
path can emit it — both controllers hardcode BASIC. The first real playtest of the unblockable is
at `5-7`.

1. Mode 1 summon casts, card leaves hand, vacated slot refills after the draw delay. PASS.
2. Melee chain of three, chain window intact, stamina drains and regenerates. PASS.
3. Roll and block behave as before; movement normal. PASS.
4. A cast succeeds mid-block and during/immediately after a roll — S6 ratified as correct by
   `5-2/R11`, and this confirms the gate did not over-reach into BASIC. PASS.
   Operator observation: casting while holding block DROPS the block on the cast tick. The cast
   itself succeeded, which is what this check tests. Recorded, not ruled, at `5-2/R17`.
5. Minions, totems, projectile all behave as before. PASS.

Verdict: SMOKE PASS, 5/5, regression-only.


5-3 smoke:
5.9.
smoke prolazi sve usporkos ovim opazanjima koja vrejdim imati zapisano:
1 cast proalzi 2 tri boje tri poze 3 zvukovi su ne prerazliciti ali tu sad nebi radio razlike puno, ruzni ionak cem ih mejnjat 4 vremenski se steta  iudarac prklapaju samo sto je ragne ogroman i neporirodno jako djeluje da igrac ubode zrak ispred sebe a da 8 m dalje portivnik najebe 5 domet sam maloprije komentirao, domat bi svakako trebao bit velik ili bar relativno veci u dnsou na bicne zamahe, tjoest takav da uz pravilno pozicinoiranje i ako protivnik nema previse stanie za pobjec vrlo vejrovatno tjera na roll za kojeg isto moznda nema stamine odnosno na obranu unblockalbe mdoeom 3 sto i je cilje, ali tu ima i do manjkoavosti animacija, a i do toga sto bi trebali mozda genralnu brzinu likova suporiti i napraviti hodanje standradrom a trcanje koje trenutno koristimo necime sto guta staminu ali  tome cemo kasnije isto, ovaj dio bi treba biti doslovnoo 1/1 kopja sekiro mehanike(eventualno malo velikodusniji range) fali taj chageup moment i amicaijiski i imeplentirano toga da se taj napad charrgperupa igrc drzi gumb za to vrijeme to daje dodatan kratak porstor da drugi igrac vidi da se sprema nesto eliko i opasno 6 model osaje u svojoj kutiji-to isto nije zeljeno ponasnje ali mozda to nije dio ovog storya 7 orb o okojem pricas je ovaj telgraf jel to se vidi da iako se ne generiraju orbovi kao resurs koji je posljedica unblcablea uspjesnog ali to vlajda nije jos iplementirano 8 uspio sam ga ubiti tkoom chargeupa prie nego je njegoa steta sletjela i orb se odma ugasio i nema nakon r pogotka niotkud 9 sve ostalo radi noramlno 10 stabilno


6.9.

5-4:
smoke proalzi sve, prikazuju se pikupljeni orbovi igracu, orbovi se zarade uspjesnim unblockalbeom u rangeu van toga ne donosi zaradu, usmrcujuci unblockable takoder donosi zaradu, kad kliknemo r broj orbova se resetira, boje se poklapaju, jedino bi trebalo I karte u ruci obojati jos

5-5:
2 spark tintan samo kada tocnom bojom odgovorim na unblockable napad, porblem je sto trenutno treb znat napamet koja karta je koaj boja, trebalo bi ih primvermo obojtai u boje njhiove, dok nekad kasnije ui ne smislim bolji(dalko)  3 kirva boja prposta potpuno unblockable napad 4 obican parry idalje zut da 6 ne razumijem sto hoces 7 pormesena obrana tiho istnkne, tako je 8 l normalno rolla p1 9 feeling je deifnitvno los i unblockable napada i obrane, ali birna stvar koju sam naucio: prvo napravi stvari onda napravi da ljepo izgldaju tako da to su porblemi zakasnije, iako da feel je ni manje ni vise nego gorzan, brambeni igrac izgleda ko da ne radi nista (a svaka ta akcija bi trebala imat svoju kontra akciju - swwep-skok na glavu, jump atack, presrtanje gadanjem projektilom doj je napad airborne i thrust mikiro ocunter nekakav, rangevi, auto aim svasta nesto, cahrgaup se nikako ne ccita, prozor napada i brane i kada sljeec sto je nejasan, ali radi osnova i to je tneutno bitno) 10 fps okej
5 blok pada momentalnno 6 animacije ne prestane ali se odmah cuje zvu obrane od unblockablea

5-6:
1 obrana bojom stuna napadaca 2 kriva boja ili ne odgvoreno proupsut da slete amiljsne posljedice 3 dodge moze potpuno izbjeci pirmanje teti i zaradu orba portoivniku cak i u arngeu ako je dobro tajmiran 4 deflect kaznjaava, ali mi se mrvicu prekrakto mozda cini duljina sutna nisam siguran 5 stunan igc ne moze nista 6 chargeup odbacija igarti kartice u modu 1 7 minioni se ne zamrzavaju na deflect 8 fps stabilan

5-7:
## 2026-09-07 — 5-7 pad modovi 2/3 (živi smoke, pad, flip [0,3])
Sve jezgrene stavke PASS: L3+B = unblockable chargeup s pada (prvi put), L3+X = defense cast
(karta/stamina/cue), Y ne radi ništa, supresija attack/block/roll pod L3 i sve živo na release,
F i ; mrtvi, fps stabilan.
Dvopadna razmjena nije odrađena (nema drugog pada) — zapisano kao izostanak.


6-0:
8.9.
1 svaka karta ima jednu od tri boje 2 prazna stanja nemaju boju 3 okvir koji pokazuje koja je karta armirana ne remeti vidljivost kojoj boji pripada karta 4 imena karata ostala su citljiva i nakon promjena koje smo uveli

6-1:
9.9.
hm pa sve tocke ti mogu reci da prolaze osim 5 jer ne razumiem bas, zna se desit da se animacija npr napada koskom odvije cijela ali steta slece dovoljno nakandno da idalje stignem psutit gumb izmedu dovresene animacije i stete da se steta ne desi, ali osim toga svakako trenutno stnaje naimacija nije finalano dapac u e6 cem puno raditit na tome, tako da ne znamo sto zakljuciti

## 2026-09-09 — 6-1b chargeup presentation (live smoke, 2 kruga + rucni feel tuning)

- Krug 1 (dijeljeni knobs, strike frame = max reach): FAIL na feel — RED freeze na krivom
  mjestu (kasno u vrtnji), BLUE bez vidljive promjene (thrust vizualno stur), GREEN hover na
  apexu pa animacija NESTANE — nikad ne landa (strike frame bio airborne apex, mjerni
  artefakt, ne feel problem). Feint iz kasne hold poze citao kao "napad koji je fiznuo".
- Fix pass: strike frame kriterij korigiran (impact nakon peak speeda; GREEN 1.2375 -> 2.1542 s),
  knobs per-boja umjesto dijeljenih.
- Krug 2 + rucno vrtenje (Matko, notepad + relaunch, bez suite runa): konvergencija na ranu
  stanku + dug vidljiv udarac za sve tri boje. Konacne trojke (hold_start/hold_end/hold_fraction):
  RED 0.30/0.45/0.15, BLUE 0.40/0.55/0.17, GREEN 0.40/0.55/0.5744 (hover ostao na apexu).
  Lekcija: mali hold_fraction trazi nizi hold_end (velik ostatak klipa treba sirok rep prozora
  ili je blur).
- Presude: stavke 1-7 PASS (hold-through sve tri boje cita se do isteka, udarac vidljiv; coil/
  hover/prijetnja OK s ranim stankama; feint i tap cisti; regresija cista), 8 fps stabilan.
- Watch (bez presude): trenutni rez na landingu (bez follow-througha) — postojeci gameplay,
  nije zasmetao ovaj krug. Telegraf sad dug i mek (stanka zavrsava na pola prozora) — sud na
  playtestu s protivnikom, retune blok. Polish biljeska: tap zvuk ruzan.
- Feel tuning se PONOVNO otvara kad cijeli gameplay loop bude ziv (Matkova odluka, retune blok).

6-1c:
11.9.
prije nego pocnemo izgleda vec bolje nego sto sam ocekivao ajmo sada po tockama 1 kada srafam oko lika koji puni unblocakbel on ga prati i steta pada u svim slucajevima osim spike sto ima i smisla, cak mi manjak animacije i samo slide n smeta djeluje kao kada nameless king poleti i zajuri se ubodnim napadom, a i druga dva napada nekad registriraju stetu za portivnika iako ne conectaju vizualno, to cemo promjeniti(znaci taj dio mora biti preciaz, a homing mzoe nadokad s malo brzine recimo) 2 pravo vermeni dodge radi, tj negira dmg unblockable svakako, osim toga mozda se prerano ugasi homing idalje u tom slucaju imam dojam kao da cim klinkm dodge homing prestane a mozda sam u krivu, prije mi se dodge cinio pre malo mejsta da pokriva tj roll, a sada mi se cini puno i mislim da bi dodge svakoo morao bit skuplji po staminu od incijiacije unblcokable napada 3 sve boje prevaljuju put, jos cu se kasnije kad imamo gameplay loop ili vude li potrebe ranije ustimavat borjek iz porslog storya ali recimo neka opomena i finesa koja se tice ovog storya je recimo u zelenom da bi imalo smisla da vecinu hominga model obavlja u fazi do freeza mid airborn, a kad sljece da ne putuje toliko, prirodnije izgleda tj izgledat ce. 4 hodanje unazad ako krene kada i commit pobjegne iz range, ali to mislim da je djelom da je zato sto ubiti trenuto hodanje je trcanje i zato izmedusotalog i uvodimo hodanje, iako bi digao jos malo doseg i brzinu hominga, kako sam i ranije rekao ovo je samo dodatan razlog, 5 ako pod pogodak na rubu mislis na to da ima razmaka izmedu maca i playera a da se steta registrira, tako je to se desava, to sam ranije vec napisao u ovoj prouci, i to svakako zleimmo ispraviti, steta jedino smije biti ako se modeli conectaju nikako drugacije, inace igra ne izgleda fer 6 ostatak radi prospisno 7 ostrica i steta se ne poklapaju savrseno, steta kasni malo i registrira se iako nije stvarno vizualno konektano 8 fps stablina, ako imas pitanja i nedoumica pitaj, svakako nam ide dobro


13.9.
1 i 2mac sad radi stetu samo kada dira protivnika(napomena za kasnije je da mi se range hominga cini mozda malen, mmjenjanjem doega trebati ce i namjestit brzinu hominga), zasad super 3dodge poslje komita ne znam sto pitas ali lagano se pobjegne, tako da bi digao cijenu dodgea sto se stamine tice i dodao malo dometa kasnije nekada unblockable napadima 4 green let uopce ne radi homing u djelu animacije prije nego je skakac u najvisoj toci dakle prvo skoci u vis iznad tocke u kojoj se nalazi a onda odleti do neprijatlje a trebao bi barem dvije trecine leta prema nerpijatleju odraditi do najvise tocke a ostatak nakon 5 ne znam o kakvom gumbu pricamo i koja bi mu tebala biti namjena? 6 ostalo radi 7 fps stabilan
nema nikakvog efekta to opet animacija do svog zenita putuje samo vertikalno, iskreno psuito bi to zasad i isao bi dalje implementirati stvari za gameplay loop, pa kad sve imamo krenuo došmikavat ovakve stvari

14.9. 
nakon pocinjanja impemetacije pitcha ikao ga jos nevidmo ostatak postojecih stvari radi kako spada

2026-09-14 — 6-3a pitch aktivacija, smoke

Flip [0, 3], ja na padu kao P2. Prošlo šest od sedam stavki.

Stageanje kartom kroz L3 + Y radi, mana padne, slot ostane prazan bez natpisa.
Sva četiri odbijanja rade i razlozi se razlikuju u inspectoru — zona zauzeta,
prazan slot, prazna zona, nije spremna. Ništa se ne troši ni na jednom.

Aktivacija: zaradio dva orba pa stageao kartu koja košta jedan. Y je odigrao
kartu, brojač pao za točno jedan, drugi orb ostao — to je ono što sam htio
vidjeti. Zvuk uspjeha se jasno razlikuje od odbijanja. Tek tad se u ruci
pojavio natpis da karta dolazi.

Aktivacija dok nabijam prolazi, probao.

NISAM provjerio: odbijanje dok sam stunan. Za to mi treba drugi pad ili drugi
igrač, nisam imao ni jedno. Vjerujem da radi jer je pokriveno testom, ali
okom nije viđeno — ostaje za playtest s bratom.

fps uredan.

### 2026-09-15 — 6-3b-pitch-hud (live smoke, 7/7 PASS)

P1 keyboard, P2 gamepad, split screen, one operator. All seven steps passed; no named
deviation (6-3a closed six-of-seven).

What is now visible that was not before:
- Two pitch zones per half — own left of the vitals bars (anchor B), opponent's right.
  The 2-6 dead-centre placeholder and its A/B switch are gone.
- A staged card shows id, a draining countdown bar and a READY state in both zones.
- NO orb number appears in either zone. Shortfall is read by eye from the 5-4 orb
  counters against the card's price.
- The staged card's hand slot shows a dimmed ghost of that card, not a blank slot, and
  becomes "..." when the window expires.

Observed behaviour worth carrying into the playtest block:
- READY flips on both halves on the same tick the landing grants the orb — the
  match-level seam means both players learn it simultaneously. Confirmed by eye.
- The countdown bar moves twice a second (30-tick push). Legible under F2 stepping;
  looked smooth at full speed.
- Anchor B ratified (6-3b/R3, closing finding S4 open since the 2-6 smoke): the zone
  left of the bars reads without pulling the eye off the fight.

Open for the playtest block, NOT for this story:
- Whether the opponent zone's READY state alone is enough information, or whether the
  missing shortfall number makes your own zone harder to plan against. Own-slot
  shortfall is a named deferral with no owner (6-3b/R1).
- Whether the 20-second fizzle window is the right length once pitches are being used
  for real rather than demonstrated.

## 2026-09-16 — Story 6-7 locomotion gaits, live smoke (config [0, 3]: P1 keyboard, P2 pad)

Deviation from 6-7/R19's two-pad procedure, named: single operator; every pad step coverable on
one pad; the keyboard half gave p1_run (Space) a live check a two-pad run would not have.

1. Walk default — PASS. No button: visibly slower, minion closes distance.
1a. Keyboard split — PASS. Space+direction runs, without it walks; same drain, same threshold.
2. Run on held A — PASS. Old speed, bar drains ~5 s full-to-empty, regen suppressed while running.
3. Empty + threshold — PASS. Drops to walk at zero; holding A does NOT resume until ~20%, then
   resumes by itself, no re-press.
4. Release — PASS. Regen starts only after ~0.8 s.
5. Actions out of run — PASS. Attack (RB) rooted and normal, run self-resumes on exit with A
   still held; same for roll (B).
6. Block — PASS. LB+stick+A: walk speed, bar does NOT drain.
7. L3 chord — PASS. L3+A confirms BASIC, no running; release L3, hold A: runs.
8. Task 10 — REPRODUCES, wider than predicted: the last-clicked debug-panel button keeps keyboard
   focus and re-fires on Space, whichever it was (not only ReloadBalance). Fix per 6-7/R20:
   FOCUS_NONE on all three panel buttons.
9. FPS — stable ~60 throughout.

FEEL VERDICT (operator, retune candidate, NOT this story): walk is too fast and run is too slow —
the gap between the gaits should widen. Both are authored balance fields (walk_speed 2.5,
move_speed 5.0 in data/balance/balance_config.tres), so this is a one-line-per-field .tres tweak
foldable into the NEXT story's dev pass as a minor item. NOTE for whoever does it:
test/integration/test_hero_movement.gd pins MOVE_SPEED := 5.0 as a local constant and reads the
authored .tres, so a run-speed change must update that constant in the same pass;
test_unit_approach_live.gd reads walk_speed live and follows automatically.

## 16.9.2026 — 6-7b locomotion presentation (smoke, dva pada)

- Hod sporiji nego prije, ne klizi. Trk brži, noge prate tlo.
- Strafe i hod unatrag pod lockom, u hodu i u trku: animacija na pravu stranu.
- Okret u mjestu: prvo su se koraci palili samo kad meta kruži blizu ili brzo; kad je daleko, lik se okretao klizeći u idle pozi. Fix: koraci za svaki okret, brzina koraka prati brzinu okretanja. Onda je radilo stalno, ali čudno izgledalo. Nakon štimanja (min brzina koraka 0.6, prag ~3°/s) bolje. Nije idealno, ali prihvatljivo.
- Prijelazi hod/trk znali su biti grubi; blend 0.12 -> 0.25 pomogao. Ostatak je nagla promjena brzine, za retune.
- Tempo: probao hod 2.5 / trk 5.5, ostaje hod 2.2 / trk 5.5.
- Hod u bloku klizi. Radije bi da ne klizi, ali nema animacije; kasnije.
- fps uredan.

## 2026-09-17 -- 6-8-camera-freedom live smoke (Tier A)

Operator: Matko. Two configurations, one operator:
- Config A: `slot_controller_kinds = [0, 3]` in `src/main/main.tscn` (P1 keyboard, P2 pad). Pad-driven camera items played on P2's pad. Flip reverted after the session.
- Config B: shipped default (both slots keyboard), for keyboard parity and the unlocked block check.

Deviation from the story's "two pads" Live Smoke wording: single operator; keyboard parity needed both keyboard slots anyway.

| # | Item | Result |
|---|------|--------|
| 1 | R3 click: hero lock -> unlock (marker hides); unlocked -> locks hero; minion/totem lock -> back to hero | PASS |
| 2 | Unlocked hero: faces movement; neutral roll goes forward; no turn on stick release; camera rotation alone does not turn the hero | PASS |
| 3 | Unlocked camera: stick right turns view right; unlock keeps heading; no recenter; relock eases back; rate 3.0 deg/tick (180 deg/s) accepted as shipped | PASS |
| 4 | Flick direction while locked: first right flick = nearest target on the right, first left flick = nearest on the left | PASS |
| 5 | 360 cycling: target behind the hero reachable; order wraps; one full sweep visits every target exactly once, no ping-pong | PASS |
| 6 | Unlocked camera near the arena wall | Finding, not a blocker: the camera ignores the wall. Accepted as the intended behaviour, no follow-up. |
| 7 | Keyboard parity, both slots, all five actions (P1 T / F G / Z C, P2 Numpad 5 / Numpad 4 6 / Numpad 1 3), P2 numpad with NumLock on and off | PASS |
| 8 | Block while unlocked: turned away -> hit lands; facing the attacker -> blocked | PASS |

Verdict: smoke PASS 8/8, no retune from this session.

## 2026-09-19 — 6-6a defense reactions (živi smoke s bratom, dva pada, flip [3,3])
Hurt reaction: trzaj samo na idle, akcije se ne prekidaju, napadačev zamah netaknut. Knockdown:
neodgovoreni unblockable obara, dok ležiš sve odbijeno, get_up jednom s i-frameovima; kontrirani/
dodgani ne obaraju. Trade ručno potrefljen — oba padnu. Floor hit: šteta ide, ležanje se ne
produžuje. Deflect/obrana stunovi drže vlastitu pozu, različitu od knockdowna. Blok/parry štima.
Nalazi: (1) čim get_up krene sve akcije dostupne — "teleport na noge", ide fix (get_up zaključan,
i-frameovi ostaju); (2) knockdown + get_up trajanja oboje pomalo predugo — retune blok; (3)
klizanje u hit_react pozi kad se krećem — polish, defer. Kontra s poda željeno nemoguća (mode 3).

6-6b:
20.9.
1 sad su mu cudnije nego inace vremenski rozor kad mogu obraniti unblockable, svakako nije vizualno intuitivan, osim toga animacije se i ne poklapaju bas jedne s drugim kao par unblockable anpad i obrana, npr nas lik skici u mejsti i napravi beck lfip umejsto da homea pream napadacu skicu mu na glavu nogmaa i odande se odrazi nazad, isto ide i za slide, ne konaketa s likom osim ako nisu iznimno blizu, kod degera to nije problem, iako se on iznimno slabo vidi povecao bi ga da gase nagalsi i skuzio sam da di god gleda onaj koji brai animaciju bacanja izvodi u smjeru di gleda a noz leti prema protivniku jako cudno to izgleda 2 da prerano karta porpadne i bude pun pogodak, samo nije bas jasno to, osim toga kazem vizualno se stvari trebaju poklapati s radnjama nemoze se odviti jedno a vidjeti drugo 3 prekasno da obrane trebju biti brze generlanoo, ikao nije intuitvan taj prozor, ja bi radije da neam fainte i da nema cahrgeupa na drzanju za unblocakble nad t osam vec rekao 4 kriva boja napad porlazi 5 prolazi da iako kazem vec sto mislim o feintanju,  a to je da ga nebi tebalo biti 6 mislim da bi malo krace trebali trajati tj bit brzi osim 7 kad je netko na podu kontra ne porlazi 8 da 9nemoze se kontra iz drzanog bolka jer kad drzimo l3 l2 prestane bit blok, osim toga razisljam da za armiranje naij potrebno drzati l2 nego kao lock on klik za takav mod klik za obicne bindove 10 kontra usred zamaham nakon dovrsneog zamaha ide 11nemogu oba kontrirarat ako oba chargaju valjda zaboga 12 to je sve oej 13 ha okej je generalno bi mozda malo podigao range za homing tih napada, i ctiljivost samih napada i korisaciju tih dvoje animacija
2 prozor pa dokle god stignes preteci to da te napad takne tj landa bi trebao moci obraniti a samo abrana bi trebala biti realitvno brza, ubiti dakle ako iniciras obranu prije nego li te napad takne jel 3 idalje ne znam o cem se rade tj sto opisuju navedene trojke

jos neki nalazi: 
Pauza na glavi prije odskoka — prezentacijski gumb (hold na spoju skok→backflip, ista mehanika kao 6-1b stanke) → retune blok.
Pogađanje nožem — polish (dagger je čista prezentacija; "pogodak" je trenutak rušenja, može se poravnati s dolaskom noža).
Kontra premalo nagrađuje — balans; poluge su duljina napadačevog knockdowna i eventualna nagrada branitelju (orb/mana) → retune blok, sud na playtestu s prijateljima.

Re-smoke sam, 20.9. navecer, [0,3] s 6-D1 tipkama (X/V/B na tipkovnici kastaju unblockable po boji, ja na padu kontriram). Sve manje-vise dobro: crveni sad stvarno skoci do napadaca, sleti mu na glavu i backflipom se vrati; plavi slide dode do njega; lik gleda u napadaca cijelu kontru pa bacanje ide u istom smjeru kao i noz; prozor je sad cijela kontra - pritisnem bilo kad prije nego me takne i obrani. Trajanja 1.0/0.8/0.5 ostaju za sad. Vidio sam par sumnjivih hitboxeva, to cemo detaljnije na pravom playtestu s prijateljima. Jos: usporiti trenutak izmedu doskoka na glavu i odskoka, profinit pogadanje nozem, i obrana od unblockablea mi se cini da mozda ne nagraduje dovoljno - vidjet cemo na playtestu.

## 6-D1 solo smoke keys (20.9.2026)

Tipke X/V/B za P1 rade: jedan pritisak kasta unblockable prvom kartom te boje i sam drzi chargeup, pa mogu sam smokeati kontre bez brata.

## 2026-09-21 — 6-9 click-to-commit (solo smoke [0,3], X/V/B + pad)

Unblockable je sad klik i commit, bez držanja i bez feinta. Solo smoke, tipkovnica P1 kasta preko X/V/B, pad P2 brani.

- Tap i pusti: napad ide do kraja i sleti, nijednom se nije prekinuo.
- Poslije tapa sam hodao, blokirao, napadao i rolao na tipkovnici — napad je i dalje letio isto, ništa ga nije otkazalo.
- Animacija punjenja svaki put dođe do udarca, 6-1b tempo izgleda isto kao prije.
- Kontra bojom na padu i dalje obori napadača.
- Regresija OK: običan melee, roll i blok rade kao prije.
- fps stabilan.

Presuda: PASS. Klik i commit se osjeća kako sam htio — odluka pada na pritisak, a protivnik mora pogoditi boju.
Otvoreno za playtest: je li unblockable bez feinta preslab, i nagrađuje li kontra dovoljno.

## 22.9.2026 — 6-10 card mode toggle, solo smoke [0,3]

Smoke 6-10 na padu (P2), P1 tipkovnica s X/V/B za unblockable. Oba nacina provjerena:
- HOLD (default): drzanje L3 digne ruku, armirana karta ide vise, pustanje vraca sve dolje; izvan moda napad/blok/roll normalni.
- TOGGLE (card_mode_toggle = true u gamepad_profile.tres): klik L3 pali i gasi mod, odigrana karta brise armiranje a mod ostaje, knockdown i reset/kraj runde gase mod, klik dok lezim radi.
- Armirana karta i mana bar: nista odrezano nije mi zapelo za oko.
- Slucajni klik L3 dok trcim: nije problem na smokeu.
- fps stabilan.
Sve prolazi. Koji je nacin bolji (hold ili toggle) odlucujem na playtestu.

6-5a spell framework + Deck 1 buffovi, smoke na dva pada, flip [3,3] — PASS 7/7.
Vanguard summona, Bloodhound roll ide dalje i cijeli je neranjiv, Frostbite vidljivo uspori
protivnika (i na blokiranom pogotku), Bloodlust duplira štetu na obje strane, Vampiric Aura
vraca HP dok udaram. Svih devet neimplementiranih efekata se odigra bez greške i bez pada.
Regresija OK, fps stabilan.

Nalazi (nisu regresija, prezentacijski dug):
- karte ne pokazuju cijene — treba i cijena normalnog casta i cijena pitcha (mana + orbovi);
- ruka bi vjerojatno trebala biti ikone umjesto kartica s tekstom, HUD treba redizajn;
- nema nikakvog vizualnog odjeka kad se karta odigra.

1 les doista defaultno stoji 20 s pa nestane, totema nema sada, ai nisu ostajali odma nestanu 2 ako ne minoina karta se odbija naplatiti i girati, ako ih imavise umire onaj kojeg gledam, dobivam hp ali ne prealzi maximum 3 les dobije adekvatno porduljenej ali ne pormjni se vizualno nimalo, ako nema lesa karta odvia biti igrana 4 lrdrv ustaju ako ih ima ak ih nema karta ostaje u pitch zoni dok ne istekne i orbovi se ne trose na pokusaj igranja bez leseva 5 totema nema pa nemogu pradt iako sam uvjeren da ih to nece efektirati culling ubija moje minione i daje +2 mane za svakoga do max 10 i odbija igranje ako nema miniona 7 tudi lesevi se ne dizu 8 ovo je uredu 9 vidljivost je uzanadoljnitkest prekirva boja karte, morat cemo skoro hud neki diajrnirat i uvset, generlno trebat ce i svaki efekt o karata obuc u nesto vizulano jer ovako djeluje kao da se nista ne desava iako mehanike rade 10 nakon smrti runda zavrav noramlno 11 fps stabilan

## 2026-09-25 -- 6-5c hero cast + Honed Bolt, live smoke (dva pada, [3,3])

PASS, sve provjereno:
- Bacanje: mac gore, munja u nebo pa pada na metu; bacac stoji i nista ne moze (blok, roll, karte, kontra).
- Upozorenje na meti (stozac + alarm) cijelo bacanje, i kad je bacac izvan kadra.
- Precizan roll izbjegava munju; blok i deflect ne pomazu.
- Pogodak: 4 stete, dizzy stun, pa root ~2.5 s (nema trka ni rolla, roll tih); hod, blok, deflect, napad i karte rade.
- Dizzy (munja) i stunned (deflect) se razlikuju.
- Obican udarac ne prekida bacanje; stun i neodgovoren unblockable ga prekidaju i munja ne padne; blok se spusti kad bacanje krene.
- Druga munja u rootu opet stuna i produzuje root; ustajanje poslije knockdowna izbjegava munju.
- Bloodlust duplira stetu munje, Vampiric Aura lijeci bacaca.
- Regresija OK, runda normalno zavrsi smrcu heroja (R-D6), fps stabilan.

Vizual (munja, stozac, krug, alarm) je placeholder -> Tier B prezentacijska storyja iza 6-5f.

## 2026-09-28 -- 6-5d Fireball and spell targeting (two pads)

- Smoke on two pads: 14/15 PASS.
- Fireball: staging takes all mana (min 3), waits for the red orb, visible cast, then a homing shot. Roll dodges it and it flies on straight; block does not help; deflect negates it. Damage is about 1.5 x the mana spent.
- Spell targeting: Fireball and Honed Bolt go to the locked target (hero or minion). A bolt on a minion is damage only. Re-locking mid-cast keeps the original target; an unlocked caster hits the enemy hero.
- An enemy Honed Bolt landing mid-cast stuns the caster and cancels the Fireball; card and mana are lost. A fizzled Fireball refunds nothing. The round ends normally on a spell kill.
- Item 10 (target dies before impact) could not be tested by hand: the caster is locked for the whole 0.8 s cast. Covered by tests.
- Found: the Honed Bolt lightning also played before every Fireball. Fixed in the smoke-fix pass; re-checked on pads: gone for Fireball, still there for the bolt.
- All new visuals (fireball, target cone, lightning, alarm) are placeholders for the presentation story after 6-5f.

## 2026-09-29 -- 6-5e Rocksling, Boom, Corpse Bomb (smoke, dva pada [3,3])

Rezultat: 14/14 PASS, R-D6 prošao (runda normalno završi i nova krene).

- Rocksling: animacija bacanja, pa 3 kamena jedan za drugim iz nogu, homing radi.
- Pogodak na heroja: 3 štete + sivi Boulder na nasumičnom slotu; protivnik ga ne vidi.
- Blok ne pomaže (puna šteta + Boulder), deflect poništi kamen, roll skida homing.
- Nakon bacanja rafal ide dalje dok se bacač slobodno kreće i napada.
- Boulder usporava hod i trk, svaki sljedeći jače; čišćenje odmah vraća brzinu. S Frostbiteom još sporije.
- Čišćenje: mod 1 za 2 mane, karta ispod se odmah vrati u isti slot; bez mane i u ostalim modovima odbijeno.
- Boom: trenutno 6 po Boulderu, bez animacije; bez Bouldera aktivacija odbijena, karta ostaje u zoni.
- Corpse Bomb: minioni odmah umiru i ostaju leševi, lubanja iz svakog tijela; Raise Dead ih diže. Bez miniona odbijeno.
- Lock-on na miniona: kamenje radi samo štetu, bez Bouldera.
- Debug reset usred rafala: preostalo kamenje otkazano, Boulderi nestaju, karte na mjestu.
- Placeholderi (kamen, lubanja, Boulder) međusobno prepoznatljivi, fps stabilan.

Otvoreno za Tier B prezentaciju iza 6-5f: svi vizuali su placeholderi; na Boulder karti se modovi i dalje vrte (pritisak se ispravno odbije).

## 2026-09-29 — 6-5f Counterspell (okvir + šest trenutnih karata), smoke na dva pada

Flip [3,3], P1 igra karte, P2 kontrira. Sve točke prošle:
- Vanguard poništen: minion nestao bez leša.
- Culling poništen: oba miniona natrag živa s HP-om od prije smrti, P1 mana pala za dobiveno.
- Rocksling + Boom pa Counterspell: HP vraćen, Boulderi natrag na iste slotove.
- Drain poništen: minion natrag, P1 HP dolje.
- Counterspell bez mete: odbijen tiho, karta ostala u zoni i dalje odbrojava, orb netaknut.
- Druga kopija na već poništenu kartu: odbijena.
- Honed Bolt kao meta (jedna od sedam 6-5g karata): odbijen — privremeno pravilo do 6-5g.
- Cue (znak + zvuk) na oba heroja pri svakom stvarnom poništenju, nikad pri odbijanju.
- Runda normalno završila ubojstvom poslije Counterspella (R-D6 prošao), fps stabilan.

Dojam / za kasnije:
- Rez 6-5f/6-5g nisam registrirao dok nisam vidio točku 7 — sedam karata s trajanjem/letom (Aura, Bloodhound, Frostbite, Honed Bolt, Rocksling, Fireball, Corpse Bomb) čeka 6-5g.
- Htio bih da i Counterspell može biti meta Counterspella: stanje se vrati kao da prvi Counterspell nije odigran. Kandidat za 6-5g scope talk, ne sad.
- Vizuali i dalje placeholder → Tier B prezentacijska story iza 6-5g.

## 2026-09-30 — 6-5g Counterspell na timed / in-flight karte (smoke)

Dva pada, flip [3,3]. 13/13 PASS. Kontra = Honed Bolt u pitch zoni + 4 mane + plavi orb, kao i na 6-5f.

- Vampiric Aura: kontra ugasi auru, HP koji je već vraćen ostaje. OK.
- Bloodhound: kontra prije rolla → roll običan. OK.
- Frostbite armed: kontra odmah → sljedeći udarac ne usporava. OK.
- Frostbite slow: kontra dok sam usporen → usporenje odmah prestane. OK.
- Munja usred bacanja: prekinuta, protivnik odmah slobodan (nije ošamućen), karta i mana mu propale. OK.
- Munja sletjela: kontra u rootu → HP natrag, root odmah prestane. OK.
- Fireball u letu: kugla nestane, bez štete. OK.
- Rocksling: kamen u letu nestane, treći se ne ispali, Boulder nestane iz ruke (karta ispod se vrati, usporenje ode), HP za pogodak vraćen. OK.
- Corpse Bomb: kontrirao sam prekasno — leš je već istekao (20 s). HP od lubanje vraćen, minion se NIJE digao. Po presudi (leš nestao = nema vraćanja), nije bug. Isti restore put provjeren na sljedećoj točki.
- Minion ubijen munjom: kontra → digne se iz leša s HP-om od prije smrti. OK.
- Whiff: izbjegnem munju rollom, pokušam kontrirati → tiho odbijeno, karta ostane, orb ostane, sljedeća karta se može kontrirati. OK.
- Istekao buff: Bloodhound istekne, pokušam kontrirati → tiho odbijeno, karta ostane. OK.
- R-D6: runda normalno završila killom. fps stabilan. Cue na oba heroja pri svakoj pravoj kontri, nikad pri odbijanju.

Napomene za playtest:
- Rok leša (20 s) efektivno ograničava vraćanje miniona, a prozor za kontru je neograničen — vidjeti na playtestu treba li to uskladiti (knob u .tres).
- Sve kontre i dalje bez vizuala osim placeholder cuea — ide u prezentacijsku story.


## 2026-10-04 — 7-1 live smoke (Matko, dva pada, flip [3,3])

Prvi smoke:
- Vanguard: izgleda i zvuči dobro, među boljima.
- Culling: vizualno ok, moglo bi biti naglašenije; šašav zvuk. Drain mi je bolji, a slična je stvar.
- Grave Ward: leš zasvijetli zeleno, iznad lebde mali duhovi — mogli bi biti veći; par puta glow i duhovi nisu bili poravnati s lešom.
- Raise Dead: okej, moglo bi biti efektnije, npr. zelena munja na leš prije nego se digne.
- Vampiric Aura: vidljivo, ali moglo bi više; nije intuitivno što se događa; zvuk bezveze.
- Rocksling: uz Honed Bolt najbolji efekt, i zvuk i vizual. Prvi kamen na zamahu, druga dva bez — točno. Krhotine kul, ali kamenje na meti nije poravnato s modelom, lebdi oko njega.
- Boom: dobar. BUG: Drain/Boom efekt se ponovo izvrti na iniciranju unblockablea, bez promjene u igri.
- Bloodhound Step: užasan zvuk, efekt okej.
- Fireball: ima svoju animaciju; s najviše mane kugla barem duplo premalena; eksplozija može biti impozantnija.
- Honed Bolt: vizualno super.
- Counterspell: runski krug nisam ni primijetio, samo plavo bljeskanje — mora biti istaknutije.
- Frostbite: među najslabijima, plave zvjezdice iz oružja jedva se vide.
- Corpse Bomb: lubanja se jedva vidi, neka bude 2-3x veća; Fireball i lubanje bi trebali flare iza sebe.
- Stun/root: root izgleda kao plava haljina, ali je čitljiv; stun od bolta kratko traje i jedva se vidi; prijelaz poze riga neugodan.
- Općenito: zadovoljan, imao sam niža očekivanja. Zvukove ću kasnije sam ručno podesiti. HUD hitno fali.

Polish round: bug Drain/Boom i nevidljivi runski krug popravljeni, veličine i vidljivost pojačane, nove geste za Auru/Frostbite i Counterspell (zamah mačem, krug iz vrha zamaha).

Re-smoke: sve dovoljno dobro.

## 2026-10-05/06 -- 7-6 HUD i karte (pet smokeova, dva pada)

Smoke 1 (5.10.): Boulder, pitch zona s artom i traka povijesti odlicni od prve. Karte premale: artove ne pamtim i ne razlikujem brzo, kruzice za pitch tesko brojim, cijene nisu dovoljno istaknute. Podizanje za "mogu platiti" me zbunjivalo jer sam navikao da armiranje dize karte; armiranje je bilo preneuocljivo (glavna zamjerka). Bljesak nisam primijetio. Orbovi oko heroja ruzni i zbunjujuci. Honed Bolt treba biti grom, ne strela. Udarac, blok, deflect, roll, unblockable, obrana bojom i pitch rade; runda zavrsi na kill, fps stabilan.

Smoke 2 (6.10.): velicina karata odlicna, art osjetno prepoznatljiviji. Svijetle polovice karata super, ali boja karte pati kad su tamne. Armiranje pogodeno, bljesak sad primjetan. Ruka odlicna, ali pitch zone i trake na krivom mjestu; traka povijesti mi je bila bolja prije. Orbovi puno bolji, malo preveliki. Kamera predaleko, lik treba biti duplo veci. Debug panel nasred ekrana smeta.

Smoke 3 (6.10.): fullscreen radi. Kruzici (puni/supiji) napokon citljivi. Luk s trakama ispod srednjih karata super. Kamera pogodena, orbovi dobre velicine, F3 za panel odlican, slot reel odlican, fps stabilan. Jos: deblji okvir, pitch zone velicine karte s jednakim razmakom, Boulder se ne armira dok nije odigran, trake malo tanje i brojevi necitljivi. Rijetko mi se cini da lik fizicki udari u orbove (kratki trzaj), nije strasno.

Smoke 4 (6.10.): okvir, pitch zone, orbovi koji obilaze lik i armiranje Bouldera sve odlicno. Tanje trake super, ali tamna plocica pod brojem ruzna; maknuta (P19).

Smoke 5 (6.10.): F3 sad pali/gasi cijeli debug sloj (panel, inspektori, brojaci orbova, telegrafi). Honed Bolt se s blizom kamerom puno citljivije izbjegava, boje unblockablea razlikujem po animaciji, deflect se vidi po stunu napadaca. Kad su s telegrafima nestali i njihovi zvukovi osjecao sam se kao slijepac; zvukovi vraceni (P22), F3 skriva samo simbole, sad je bolje. Neka ostane privremeno; kasnije trebaju suptilniji, uklopljeniji vizualni znakovi i zvukovi.

## 2026-10-08 -- 7-8 unblockable honest contact (solo smoke, flip [0,3])

- Prosao sve tocke cekliste, ne najtemeljitije, ali sve sto sam vidio je puno bolje nego sto sam ocekivao.
- Rusenje tocno na dodir, roll kroz ostricu, okrznuti zrak ne pogada, ritam punjenja (Genichiro), zeleni skok, prijelazi, regresija i fps: u redu.
- Opazanja za dalje:
  - mozda je prelako pobjeci napadu (doseg/homing?)
  - usporiti opcenito brzinu kretanja i napada
  - orbovi kad ih je puno i dalje smetaju, kao da se guraju medusobno kad ih lik odgurne; htio bih da budu duhovi bez ikakvog otpora
  - telegraf: oci napadaca ubrzano trepcu u boji unblockablea (kao bomba) i jako bljesnu kad krene napad
  - kako sprijeciti besplatno mijenjanje ruke igranjem obrana u prazno
  - crvena kontra: cudan brz skok, ne vidi se sto se dogodilo, fali tezine i dramaticnosti (referenca: Sekiro kontra unblockablea)
  - zelena kontra: baceni noz nema tezinu kad pogodi i slabo se vidi

## 2026-10-08 -- 7-9 unblockable tempo (solo smoke [0,3])

P1 na tipkovnici kasta (X/V/B), ja branim na padu. Svih 13 stavki PASS.
- Unblockable kosta 1 manu; bez mane je cast odbijen. Povrata nema.
- Obrana bojom bez napada je odbijena i nista se ne trosi.
- Kontra: prerano = karta potrosena i pojedem udarac. Pravi trenutak radi u sve tri boje i daje +1 manu. Radi i pritisak u letu (zeleni).
- Roll kroz udarac spasava i napad me poslije ne prati.
- Skretanje: rani korak ili roll prati i pogodi, kasni korak izbliza izbjegne.
- Imunitet 1.5 s nakon ustajanja radi, i za kontriranog napadaca; melee u tom razdoblju pogada.
- Trk sporiji (4.6), hod i roll isti.
- Regresija OK, fps stabilan. R-D6: heroj pogine, runda normalno zavrsi.

## 2026-10-09 -- 7-10 unblockable presentation (solo smoke [0,3], P1 kasta s X/V/B, ja na padu)

- Oči napadača: svijetle u boji unblockablea, trepću sve brže, bljesnu na polasku, gase se na dodiru -- radi za sve tri boje.
- Kontra na očekivani bljesak prolazi pouzdano.
- Crvena kontra: skok na glavu pa odskok sad imaju smisleniji ritam; zamrzavanje, bljesak, udarac i trzaj kamere rade. Tempo mi se čini malo spor -- sitnica za kasnije.
- Neuspjela crvena: nema skoka na glavu, pojedem udarac.
- Zelena kontra: nož se vidi s tragom, pogodak se osjeti, napadač pada na pogotku.
- Imunitet nakon ustajanja: srebrni sjaj se vidi i blijedi, unblockable prolazi kroz mene.
- Kugle iznad glave nema već neko vrijeme (maknuta ranije), nije tema.
- Regresija i fps OK.
- Za kasnije: zvuk otkucaja je loš, zvuči kao balončići; bljesak iz očiju bi mogao biti efektniji -- nije nužno sad.
- Sve u svemu super.
