# TODO

-   `NamesList.txt` in the Unicode Database lists entries like this:

    ```
    00B7    MIDDLE DOT
            = midpoint (in typography)
            = Georgian comma
            = Greek middle dot (ano teleia)
            * also used as a raised decimal point or to denote multiplication; for multiplication 22C5 is preferred
            x (greek ano teleia - 0387)
            x (runic single punctuation - 16EB)
            x (bullet - 2022)
            x (one dot leader - 2024)
            x (hyphenation point - 2027)
            x (bullet operator - 2219)
            x (dot operator - 22C5)
            x (word separator middle dot - 2E31)
            x (raised dot - 2E33)
            x (katakana middle dot - 30FB)
            x (latin letter sinological dot - A78F)
    ```

    Specifically, I'm interested in the similar-looking characters
    listed above, from U+0387 GREEK ANO TELEIA to U+A78F LATIN LETTER
    SINOLOGICAL DOT.  However, `unicoder` should be able to
    automatically find and print all of this stuff.

    According to `NamesList.txt`:

    > This file is semi-automatically derived from UnicodeData.txt and
    > a set of manually created annotations using a script to select
    > or suppress information from the data file. The rules used for
    > this process are aimed at readability for the human reader, at
    > the expense of some details; therefore, this file should not be
    > parsed for machine-readable information.

    So, what's in here are entries found in the character names list:

    -   Unicode name
    -   Version 1.0 name (=) [= (1.0)]
    -   Alternative names (=) [=]
    -   Character name aliases (※) [%]
    -   Informative notes (•) [*]
        -   includes samples of language use
    -   Cross references (→) [x]
    -   Compatibility decomposition mappings (≈) [#]
    -   Canonical decomposition mappings (≡) [:]
    -   Standardized variation sequences (~) [~]

    -   () symbology in code charts
    -   [] symbology in NamesList.txt

    See:
    -   [Key to the Code Charts](https://unicode.org/charts/About.html#Key)
    -   [About the Code Charts](https://www.unicode.org/versions/latest/ch24.pdf), section 24.1
