# Contributing

## Writing rules

Write all text in ASD-STE100 Simplified Technical English. This includes documents, code comments, names, log text, and commit messages.

Text that the player reads in the game is the exception. It uses normal, friendly English with Vietnamese terms.

The main STE rules:

- Use short sentences. A procedure sentence has 20 words or fewer. A description sentence has 25 words or fewer.
- Write one instruction in each sentence.
- Use the active voice.
- Use the imperative in procedures ("Run the tests.").
- Use one word for one meaning. Do not use synonyms for the same thing.
- Use "must" for a requirement. Do not use "should" for a requirement.
- Do not use "-ing" words as nouns or adjectives when a simple word is possible.

Use the Vietnamese words with all diacritics: "phở", not "pho".

## Commit rules

- Commit with the identity of the owner:

  ```sh
  git -c user.name="Sơn Trần-Nguyễn" -c user.email=github@sntran.com -c commit.gpgsign=false commit
  ```

- Do not add a `Co-Authored-By` trailer or any other note to a commit.
- Do not put references to the tools that wrote the code in files or commits.
- Write the commit subject in STE, in the imperative ("Add the clock sheet").

## Branch rules

Use a branch prefix for the type of task:

| Prefix | Task |
|---|---|
| `feat/` | New game behavior |
| `fix/` | Defect correction |
| `docs/` | Documents only |
| `test/` | Tests only |
| `ci/` | Build and CI changes |

Put the plan number in the branch name when there is a plan: `feat/0001-foundation`.

Do not open a pull request unless the owner asks for one.

## Assets

- Use only assets with a CC0, CC-BY, or SIL Open Font License.
- Record the source and the license of each asset in `assets/CREDITS.md`.
- Do not use logos, brands, or the names of real shops.
