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
