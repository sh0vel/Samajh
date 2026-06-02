# Translation Quality — Ideas & Problems

## Current Problems

### 1. Romanization Inconsistency
The same word can appear spelled differently across songs or even within a song.
- मैं → "main", "mein", "mai" used interchangeably
- है → "hai", "he", "hain" mixing singular/plural forms
- आ → "aa", "a", "aao" depending on context
- No canonical standard being enforced by the prompt

### 2. Word Translations Are Song-Context Locked
The gloss shown in the token popup ("pyaar = love") is the right meaning *for this song*, but that's not how language learning works. The word "pyaar" has a life outside this lyric — its register, its spectrum of use, what it contrasts with. Right now the popup feels more like a footnote than a lesson.

### 3. Popup Window Is Too Thin
Currently shows: native script · roman · single gloss. That's it. A learner gets no sense of the word as a living thing — how it sounds in other contexts, where it came from, what its root is, what feels similar.

---

## Ideas

### Romanization

- **Enforce a single standard** — Pick one system (IAST, ALA-LC, or a simplified phonetic system for Hindi/Urdu) and instruct the model to apply it consistently. A glossary of the 200 most common Hindi/Urdu words with their canonical romanization could be included in the system prompt as a reference table. The model matches against this before inventing its own spelling.
- **Romanization consistency pass** — After the main generation, run a second cheap pass that scans all `roman` fields and normalizes them against the glossary. Could be done client-side with a lookup table for common words, or server-side as a post-processing step.
- **Dialect tagging** — Some variation is real (Hindi vs Urdu register of the same word). Worth tagging which romanization dialect the song is in so the model stays consistent within that register.

---

### The Token Popup — Make It a Real Lesson

Currently: `surface · roman · gloss`

Proposed structure:

```
मोहब्बत
mohabbat

love, deep affection — closer to longing than everyday love

───────────────────────────────
Roots
  Arabic: محبّة (mahabbah) — love, fondness
  Entered Hindi/Urdu via Persian

───────────────────────────────
Register
  Urdu-heavy · poetic · formal
  Compare: pyaar (everyday), ishq (obsessive longing), prem (Sanskrit, pure)

───────────────────────────────
In this line
  "mohabbat ki hai" → "has fallen in love"
  Verb form: mohabbat karna = to love (as an action)

───────────────────────────────
Hear it used
  [future: example sentences from corpus]
```

New fields needed on `LyricToken`:
- `etymology: String?` — origin language, root word, entry route
- `register: String?` — formal/colloquial/poetic/Urdu-heavy/Sanskrit-heavy
- `spectrum: [String]?` — nearby words in meaning with how they differ
- `verbForm: String?` — if the token is a conjugated verb, what the root form is and what it means
- `grammaticalNote: String?` — gender, case, tense if relevant
- `contextNote: String?` — what specifically is happening with this word in the song (currently what `gloss` partly does)

This doubles the AI cost per song but massively increases the educational value per tap.

---

### Evaluation Framework

Without a way to measure quality, there's no signal for improvement. Ideas:

**Automated checks (cheap, run every generation):**
- Romanization consistency score — count unique spellings of the same native word across a song; flag if >1
- Coverage — what % of tokens have etymology / register filled vs null
- Length sanity — gloss that is longer than the line itself is probably hallucinated
- Round-trip check — translate `natural` back to the target language and compute rough similarity to original (expensive, probably not worth it)

**Human eval rubric (for manual review sessions):**
- Romanization: correct pronunciation guide? (1–5)
- Gloss: accurate to this line's meaning? (1–5)
- Etymology: correct origin? verifiable? (1–5)
- Register note: useful and accurate? (1–5)
- Natural translation: reads like real English? captures the feel? (1–5)
- Overall: would a Hindi learner find this useful? (1–5)

**In-app feedback signal (future):**
- "Was this helpful?" on the popup (👍/👎)
- User edits to translations → natural signal of what was wrong
- Retranslation requests with feedback text → mine for common complaints

**Test set:**
- Curate ~20 lines from well-known songs with known-good translations (from published sources, academic translators)
- Run each generation against this set and score manually
- Use as a regression baseline when changing prompts

---

### Other Translation Gaps

- **Verb conjugation is opaque** — "jaana" vs "jaaye" vs "jaata" all appear but the popup doesn't explain why. Adding a grammatical note ("conditional form of 'jaana' — to go") would make Hindi grammar learnable from songs.
- **Compound verbs** — Hindi uses a lot of `V + lena/dena/jaana` constructions ("kha liya", "de diya") that have aspectual meaning. Currently they're glossed as one chunk without explaining the helper verb.
- **Honorifics and register shifts** — A song might shift from `tu` (intimate) to `tum` (respectful) to `aap` (formal) across verses. This is emotionally meaningful and currently invisible.
- **Sandhi and elision** — Written Devanagari sometimes fuses words. The token split can be wrong, causing misalignment between roman and native. Needs a smarter tokenizer or a correction pass.
- **Transliteration vs translation in natural** — Sometimes the natural translation is too literal ("my heart goes toward you") when the actual feeling is more idiomatic. A "feel" pass that makes the English sound like something a poet would write, not a dictionary.

---

## Priority Order (rough)

1. Romanization standardization — highest ROI, affects every single line, cheapest fix
2. Richer token popup fields (etymology, register, spectrum) — biggest UX leap
3. In-app user feedback signal — needed to know if anything is working
4. Automated consistency checks — catch regressions as prompts evolve
5. Verb conjugation + compound verb notes — deep value for actual language learners
6. Human eval rubric + test set — serious but slow to build
