#!/usr/bin/env python3
"""Build the blind human review: for each invariant, the chosen formulations
under shuffled letter codes.  Writes human/blind-review.md and human/KEY.md.
The key maps letters back to variants; it is not for reading until the
answers are written down."""
import os, random, re, sys
sys.path.insert(0, os.path.dirname(__file__)); from preserve import blocks, NAMES
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
VARIANTS = ['A-equiv', 'A-short', 'B-short', 'C-short', 'D-short', 'E-short', 'F-short']
LETTERS = 'PQRSTUV'
def main(seed=7):
    out = ['# Blind review: the foundation in several formulations', '',
           'Seven formulations of each foundation invariant follow, under letters that change from one invariant to the next. One of them is the current text. Do not look at `KEY.md` until your answers are written down.', '',
           'For each invariant, note the start and end time, then answer:', '',
           '1. Which formulation did you understand fastest? Rank your top two.',
           '2. In one sentence, what does your top choice mean?',
           '3. Who does it protect, and who carries the obligation?',
           '4. Name one thing that would violate it.',
           '5. Is anything confusing or ambiguous in any of the seven? Which letters?',
           '6. How confident are you in your reading of your top choice (low / medium / high)?', '',
           'Write answers in `human/answers-<your-name>.md`, one section per invariant. Reading time and perceived clarity are the measures; there is no right ranking.', '']
    key = ['# Key to the blind review (open after answering)', '', '| invariant | letter | variant |', '|---|---|---|']
    texts = {v: blocks(open(f'{ROOT}/variants/{v}.txt').read()) for v in VARIANTS}
    for i, n in enumerate(NAMES):
        rng = random.Random(f'{seed}:{n}'); order = VARIANTS[:]; rng.shuffle(order)
        out += [f'## Invariant {i}: `{n}`', '']
        for letter, v in zip(LETTERS, order):
            body = texts[v][n].split('\n', 1)[1]   # drop the name line; it is the same everywhere
            out += [f'### {letter}', '', '```text', body, '```', '']
            key.append(f'| {n} | {letter} | {v} |')
    open(f'{ROOT}/human/blind-review.md', 'w').write('\n'.join(out))
    open(f'{ROOT}/human/KEY.md', 'w').write('\n'.join(key) + '\n')
    print(f'{len(out)} lines; words to read:', len(re.findall(r"\S+", '\n'.join(out))))
if __name__ == '__main__': main()
