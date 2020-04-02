# Unicoder

A quick-and-dirty command-line Unicode utility.

-   `unicoder blocks`

```
U+0000      U+007F      128     Basic Latin
U+0080      U+00FF      128     Latin-1 Supplement
U+0100      U+017F      128     Latin Extended-A
U+0180      U+024F      208     Latin Extended-B
U+0250      U+02AF      96      IPA Extensions
...
```

-   `unicoder scripts`

```
U+0000      U+0040      65      Common
U+005B      U+0060      6
U+007B      U+00A9      47
...
U+1FA90     U+1FA95     6
U+E0001     U+E0001     1
U+E0020     U+E007F     96
U+0041      U+005A      26      Latin
U+0061      U+007A      26
U+00AA      U+00AA      1
...
```

-   `unicoder block 'Basic Latin'`
-   `unicoder block '!'` (any character in the block)
-   `unicoder block U+0021`
-   `unicoder block 33` (decimal codepoint)
-   `unicoder block 'EXCLAMATION MARK'`

```
# Basic Latin
U+0000      ???     <control> (NULL)
U+0001      ???     <control> (START OF HEADING)
U+0002      ???     <control> (START OF TEXT)
...
U+001D      ???     <control> (INFORMATION SEPARATOR THREE)
U+001E      ???     <control> (INFORMATION SEPARATOR TWO)
U+001F      ???     <control> (INFORMATION SEPARATOR ONE)
U+0020              SPACE
U+0021      !       EXCLAMATION MARK
U+0022      "       QUOTATION MARK
...
```

-   `unicoder table 'Basic Latin'`

```
# Basic Latin
             0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
            --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
U+0000      ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ???
U+0010      ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ??? ???
U+0020           !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /
U+0030       0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?
U+0040       @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O
U+0050       P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _
U+0060       `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o
U+0070       p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~  ???
```

-   `unicoder charinfo 'INTERROBANG'`
-   `unicoder charinfo U+203D`
-   `unicoder charinfo '‽'`
-   `unicoder charinfo 8253`

```
bidi                            ON
block                           General Punctuation
category                        Po
code                            203D
combining                       0
comment
decimal
decomposition
digit
lower
mirrored                        N
name                            INTERROBANG
numeric
script                          Common
title
unicode10
upper
```

-   `unicoder charprops 'INTERROBANG'`

```
Age                             V1_1
Alphabetic                      No
ASCII_Hex_Digit                 No
Bidi_Class                      Other_Neutral
Bidi_Control                    No
...
```
