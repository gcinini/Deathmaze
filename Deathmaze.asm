********************************************************************************
* Deathmaze 5000 for the Apple II                                              *
* By Frank Corr, Jr.                                                           *
* (some sources also credit William F. Denman, Jr.)                            *
* Copyright 1980 by Med Systems Software                                       *
********************************************************************************
* Disassembly by Andy McFadden, using 6502bench SourceGen v1.7.5               *
* Last updated 2021/08/14                                                      *
********************************************************************************
FN_DESTROY_OBJ  .eq     $00    {const}    ;destroy an item
FN_DESTROY_OBJ1 .eq     $01    {const}    ;destroy an item
FN_GET_BOX_OBJ  .eq     $02    {const}    ;get object, still in box
FN_ACTIVATE_OBJ .eq     $03    {const}    ;activate object (e.g. light torch)
FN_GET_OBJ      .eq     $04    {const}    ;pick up object (not in box)
FN_DROP_OBJ     .eq     $05    {const}    ;drop an object (becomes a box)
FN_GET_OBJ_INFO .eq     $06    {const}    ;get object info
FN_DRAW_INV     .eq     $07    {const}    ;draw player inventory on screen
FN_COUNT_INV    .eq     $08    {const}    ;count inventory items; result in $19
FN_RESET_STATE  .eq     $09    {const}    ;reset all player state
FN_FIND_BOXES   .eq     $0a    {const}    ;find 1-4 boxes in view on floor
FN_OBJ_HERE     .eq     $0b    {const}    ;find item on floor at current posn
FN_FIND_FOOD    .eq     $0c    {const}    ;find food obj in inventory
FN_FIND_LIT_T   .eq     $0d    {const}    ;find lit torch
FN_FIND_UNLIT_T .eq     $0e    {const}    ;find unlit torch
FIRST_NOUN      .eq     $1d    {const}    ;index of first noun in word list
VERB_FWD        .eq     $5b    {const}    ;verb value for "move forward"
VERB_LEFT       .eq     $5c    {const}    ;verb value for "turn left"
VERB_RIGHT      .eq     $5d    {const}    ;verb value for "turn right"
VERB_180        .eq     $5e    {const}    ;verb value for "turn around"
char_horiz      .eq     $06               ;text output horizontal position (0-39)
char_vert       .eq     $07               ;text output vertical position (0-23)
char_row_ptr    .eq     $08    {addr/2}   ;hi-res address for top line of text
string_ptr      .eq     $0c    {addr/2}   ;pointer to text string
blink_timer     .eq     $17    {addr/2}   ;timer for blinking apple cursor
MON_A1L         .eq     $3c               ;general purpose
MON_A1H         .eq     $3d               ;general purpose
MON_A2L         .eq     $3e               ;general purpose
MON_A2H         .eq     $3f               ;general purpose
DOS_RWTS        .eq     $03d9             ;RWTS entry point
MON_USRADDR     .eq     $03f8  {addr/3}   ;jump to function that handles monitor Ctrl-Y
TEXT_PAGE_1     .eq     $0400  {addr/1024} ;text screen, page 1
HIRES_PAGE_2    .eq     $4000  {addr/8192} ;hi-res graphics, page 2
KBD             .eq     $c000             ;R last key pressed + 128
KBDSTRB         .eq     $c010             ;RW keyboard strobe
TXTCLR          .eq     $c050             ;RW display graphics
TXTSET          .eq     $c051             ;RW display text
MIXCLR          .eq     $c052             ;RW display full screen
TXTPAGE1        .eq     $c054             ;RW display page 1
TXTPAGE2        .eq     $c055             ;RW display page 2 (or read/write aux mem)
LORES           .eq     $c056             ;RW display lo-res graphics
HIRES           .eq     $c057             ;RW display hi-res graphics
MON_WRITE       .eq     $fecd             ;write data to cassette
MON_READ        .eq     $fefd             ;read data from cassette
MON_MONZ        .eq     $ff69             ;reset and enter monitor

                .org    $0805
0805: 58           Start           cli                       ;enable interrupts (why?)
0806: a2 00                        ldx     #$00
0808: 86 17                        stx     blink_timer       ;init cursor blink timer to zero
080a: 86 18                        stx     blink_timer+1
080c: 20 00 3f     Restart         jsr     Setup             ;relocate last part of program above hi-res page 2
080f: 86 06                        stx     char_horiz        ;set horizontal position to zero
0811: 2c 55 c0                     bit     TXTPAGE2          ;set page 2
0814: 2c 52 c0                     bit     MIXCLR            ;full screen
0817: 2c 57 c0                     bit     HIRES             ;hi-res mode
081a: 2c 50 c0                     bit     TXTCLR            ;enable graphics
081d: 20 55 08                     jsr     ClearScreen       ;clear screen
0820: ea                           nop
0821: 20 ef 11                     jsr     SetRowPtr         ;set hi-res address for text output
0824: a9 94                        lda     #$94              ;"do you wish to continue a game?"
0826: 20 e2 08                     jsr     DrawMsgN          ;draw the message
0829: 20 f7 0f                     jsr     GetYesNo          ;get answer
082c: c9 59                        cmp     #‘Y’              ;affirmative?
082e: d0 13                        bne     :NoLoad           ;no, skip load
0830: 20 3f 7c                     jsr     LoadDiskOrTape
0833: a9 96                        lda     #$96              ;"when ready, press any key"
0835: ea                           nop
0836: ea                           nop
0837: 20 a4 08                     jsr     DrawMsgN_Row23
083a: 20 e9 0f                     jsr     WaitKeyCursor     ;wait for key
083d: 20 72 08                     jsr     LoadFromTape      ;do tape load
0840: 4c 4a 08                     jmp     GetStarted

                   ]func_cmd       .var    $0f    {addr/1}

0843: a2 09        :NoLoad         ldx     #FN_RESET_STATE
0845: 86 0f                        stx     ]func_cmd
0847: 20 34 1a                     jsr     ObjMgmtFunc       ;init player state
                   ; Start the game, first showing the instruction page.
084a: a2 1b        GetStarted      ldx     #$1b
084c: 8e 9c 61                     stx     parsed_verb       ;pretend the user typed "instructions"
084f: 20 40 26                     jsr     ExecParsedInput   ;execute command
0852: 4c 2b 09                     jmp     MainLoop

                   ; 
                   ; Clears hi-res page 2 to black.
                   ; 
                   ]ptr            .var    $0e    {addr/2}

0855: a2 00        ClearScreen     ldx     #<HIRES_PAGE_2    ;init pointer
0857: 86 0e                        stx     ]ptr
0859: a2 40                        ldx     #>HIRES_PAGE_2
085b: 86 0f                        stx     ]ptr+1
085d: a0 00                        ldy     #$00
085f: 98           :ClearLoop1     tya
0860: 91 0e        :ClearLoop      sta     (]ptr),y
0862: e6 0e                        inc     ]ptr              ;advance pointer
0864: d0 fa                        bne     :ClearLoop
0866: e6 0f                        inc     ]ptr+1
0868: a5 0f                        lda     ]ptr+1
086a: c9 60                        cmp     #>HIRES_PAGE_2+$2000 ;done yet?
086c: d0 f1                        bne     :ClearLoop1       ;no, keep going
086e: 60                           rts

086f: ea ea ea                     .junk   3

                   ; 
                   ; Loads a saved game from tape.
                   ; 
0872: a2 93        LoadFromTape    ldx     #<plyr_facing     ;set load address to $6193
0874: 86 3c                        stx     MON_A1L
0876: a2 61                        ldx     #>plyr_facing
0878: 86 3d                        stx     MON_A1H
087a: a2 62                        ldx     #$62              ;set end to $6292 (start + 255)
087c: 86 3f                        stx     MON_A2H
087e: a2 92                        ldx     #$92
0880: 86 3e                        stx     MON_A2L
0882: 20 fd fe                     jsr     MON_READ          ;read data from cassette
0885: 20 55 08                     jsr     ClearScreen
0888: 20 15 10                     jsr     DrawMaze          ;redraw maze
088b: 20 1c 7d                     jsr     VerifySave        ;pops return addr
                   ; (can't actually get here?)
088e: ea                           nop
088f: 4c 34 1a                     jmp     ObjMgmtFunc

                   ; 
                   ; Draws message N at the second-to-last line.  The message text is also copied
                   ; into a buffer.
                   ; 
                   ; On entry:
                   ;   A-reg: message index
                   ; 
                   ]save_ptr       .var    $0a    {addr/2}

0892: a2 00        DrawMsgN_Row22  ldx     #$00
0894: 86 06                        stx     char_horiz        ;set horizontal position to zero
0896: a2 16                        ldx     #22
0898: 86 07                        stx     char_vert         ;set vertical position to row 22 (one up from bottom)
089a: a2 7a                        ldx     #<text_row22
089c: 86 0a                        stx     ]save_ptr
089e: a2 0c                        ldx     #>text_row22
08a0: 86 0b                        stx     ]save_ptr+1
08a2: d0 10                        bne     :DrawMsg

08a4: a2 00        DrawMsgN_Row23  ldx     #$00
08a6: 86 06                        stx     char_horiz        ;set horizontal position to zero
08a8: a2 17                        ldx     #23
08aa: 86 07                        stx     char_vert         ;set vertical position to row 23 (last line)
08ac: a2 a2                        ldx     #<text_row23
08ae: 86 0a                        stx     ]save_ptr
08b0: a2 0c                        ldx     #>text_row23
08b2: 86 0b                        stx     ]save_ptr+1
                   ; 
08b4: 20 00 09     :DrawMsg        jsr     FindMsgN          ;set pointer to Nth message
08b7: 20 ef 11                     jsr     SetRowPtr         ;configure the hi-res screen pointer
08ba: 20 21 09                     jsr     ClearToSpaces     ;clear text buffer to spaces
08bd: a0 00                        ldy     #$00
08bf: b1 0c                        lda     (string_ptr),y    ;get byte from message
08c1: 29 7f                        and     #%01111111        ;strip high bit
08c3: 91 0a        :DrawLoop       sta     (]save_ptr),y     ;save in buffer
08c5: 20 a4 11                     jsr     DrawGlyph         ;draw on screen
08c8: ee 0c 00                     inc:    string_ptr        ;advance text pointer
08cb: d0 03                        bne     :NoInc
08cd: ee 0d 00                     inc:    string_ptr+1
08d0: e6 0a        :NoInc          inc     ]save_ptr         ;advance save buffer pointer
08d2: d0 02                        bne     :NoInc
08d4: e6 0b                        inc     ]save_ptr+1
08d6: a0 00        :NoInc          ldy     #$00
08d8: b1 0c                        lda     (string_ptr),y    ;get next byte from message
08da: 10 e7                        bpl     :DrawLoop         ;if we haven't hit the start of next message, branch
08dc: a9 1e                        lda     #$1e
08de: 20 92 11                     jsr     PrintSpecialChar
08e1: 60                           rts

                   ; 
                   ; Draws message #N, at the current text position.
                   ; 
                   ; On entry:
                   ;   A-reg: message index
                   ; 
                   • Clear variables
                   ]msg_ptr        .var    $0c    {addr/2}

08e2: 20 00 09     DrawMsgN        jsr     FindMsgN          ;get pointer to the Nth message
                   ; 
                   ; Draws the pointed-to message, at the current text position.
                   ; 
                   ; On entry:
                   ;   $0c-0d: pointer to text
                   ; 
08e5: 20 ef 11     DrawMsg         jsr     SetRowPtr         ;set hi-res row pointer
08e8: a0 00                        ldy     #$00
08ea: b1 0c                        lda     (]msg_ptr),y      ;get first char
08ec: 29 7f                        and     #$7f              ;clear the high bit
08ee: 20 a4 11     :DrawLoop       jsr     DrawGlyph         ;draw it
08f1: ee 0c 00                     inc:    string_ptr        ;advance pointer
08f4: d0 03                        bne     :NoInc
08f6: ee 0d 00                     inc:    string_ptr+1
08f9: a0 00        :NoInc          ldy     #$00
08fb: b1 0c                        lda     (]msg_ptr),y      ;get next char
08fd: 10 ef                        bpl     :DrawLoop         ;if we haven't hit next string, branch
08ff: 60                           rts

                   ; 
                   ; Finds the Nth string in the message table.
                   ; 
                   ; The first character in each string has its high bit set.
                   ; 
                   ; On entry:
                   ;   $11: string index (0-?)
                   ; 
                   ; On exit:
                   ;   $0c-0d: pointer to string
                   ;   $11: zero
                   ; 
                   ]ptr            .var    $0c    {addr/2}
                   ]string_num     .var    $11    {addr/1}

0900: 85 11        FindMsgN        sta     ]string_num
0902: a2 29                        ldx     #<msg_strings     ;init to start of list
0904: 8e 0c 00                     stx:    string_ptr
0907: a2 68                        ldx     #>msg_strings
0909: 8e 0d 00                     stx:    string_ptr+1
090c: a0 00                        ldy     #$00
090e: b1 0c        :Find1          lda     (]ptr),y          ;get a character
0910: 30 0a                        bmi     :FoundStart       ;hi bit set at start of string, branch
0912: ee 0c 00     :Find2          inc:    string_ptr        ;advance pointer
0915: d0 f7                        bne     :Find1            ;didn't roll, branch
0917: ee 0d 00                     inc:    string_ptr+1      ;increment high byte
091a: d0 f2                        bne     :Find1            ;(always)

091c: c6 11        :FoundStart     dec     ]string_num       ;decrement count
091e: d0 f2                        bne     :Find2            ;not there yet
0920: 60                           rts

                   ; 
                   ; Sets 40 spaces ($20) at the target address.
                   ; 
                   ; On entry:
                   ;   $0a-0b: pointer
                   ; 
                   ]ptr            .var    $0a    {addr/2}

0921: a0 27        ClearToSpaces   ldy     #39
0923: a9 20                        lda     #‘ ’
0925: 91 0a        :Loop           sta     (]ptr),y
0927: 88                           dey
0928: 10 fb                        bpl     :Loop
092a: 60                           rts

                   ; 
                   ; Main game loop.
                   ; 
092b: 20 ca 0c     MainLoop        jsr     GetInput
092e: ad 9c 61                     lda     parsed_verb
0931: c9 5a                        cmp     #$5a              ;written verb (not movement key)?
0933: 30 0e                        bmi     :WrittenVerb      ;yes, branch
0935: 20 49 09                     jsr     HandleImmCmd      ;no, handle key immediately
0938: ad a5 61     MainLoop2       lda     special_zone      ;something special here?
093b: f0 ee                        beq     MainLoop          ;no, loop
093d: 20 47 33                     jsr     HandleSpecialZone ;do the special thing
0940: 4c 2b 09                     jmp     MainLoop          ;back to the grind

0943: 20 40 26     :WrittenVerb    jsr     ExecParsedInput
0946: 4c 38 09                     jmp     MainLoop2

                   ; 
                   ; Handles "immediate" actions: move forward or change direction.
                   ; 
                   ; On entry:
                   ;   A-reg: verb
                   ; 
                   ]tmp_facing     .var    $1a    {addr/1}

0949: ae 93 61     HandleImmCmd    ldx     plyr_facing       ;copy the player's current facing direction
094c: 86 1a                        stx     ]tmp_facing
094e: c9 5b                        cmp     #VERB_FWD         ;did they try to move forward?
0950: f0 4b                        beq     HndMoveFwd        ;yes, handle it
0952: 20 56 09                     jsr     DirectionChange   ;no, try the other stuff
0955: 60                           rts

0956: c9 5c        DirectionChange cmp     #VERB_LEFT        ;turn left?
0958: f0 1b                        beq     HndTurnLeft       ;yes, branch
095a: c9 5e                        cmp     #VERB_180         ;turn around?
095c: f0 29                        beq     HndTurn180        ;yes, branch
                   ; Must be "turn right".
095e: a5 1a                        lda     ]tmp_facing       ;get facing
0960: c9 04                        cmp     #$04              ;currently at 4?
0962: f0 05                        beq     :RollOver         ;yes, branch
0964: ee 93 61                     inc     plyr_facing       ;update facing
0967: d0 05                        bne     :Finish           ;(always)

0969: a2 01        :RollOver       ldx     #$01              ;reset to 1
096b: 8e 93 61                     stx     plyr_facing
                   ; Finish up by redrawing the maze and reporting low resources.
096e: 20 15 10     :Finish         jsr     DrawMaze          ;redraw maze
0971: 20 77 0b                     jsr     ReportLowRsrc     ;report hunger / torch issues
0974: 60                           rts

0975: a5 1a        HndTurnLeft     lda     ]tmp_facing       ;get facing
0977: c9 01                        cmp     #$01              ;currently at 1?
0979: f0 05                        beq     :RollUnder        ;yes, branch
097b: ce 93 61                     dec     plyr_facing       ;update facing
097e: 10 ee                        bpl     :Finish           ;(always)

0980: a2 04        :RollUnder      ldx     #$04              ;reset to 4
0982: 8e 93 61                     stx     plyr_facing
0985: d0 e7                        bne     :Finish           ;(always)

0987: a5 1a        HndTurn180      lda     ]tmp_facing
0989: c9 03                        cmp     #$03              ;< 3?
098b: 30 08                        bmi     L0995             ;yes, inc twice
098d: ce 93 61                     dec     plyr_facing       ;no, dec twice
0990: ce 93 61                     dec     plyr_facing
0993: 10 d9                        bpl     :Finish           ;(always)

0995: ee 93 61     L0995           inc     plyr_facing
0998: ee 93 61                     inc     plyr_facing
099b: 10 d1                        bpl     :Finish
                   ; 
                   ; Handles forward movement, including travel into special areas.
                   ; 
099d: ad 94 61     HndMoveFwd      lda     plyr_floor        ;get current floor
09a0: c9 03                        cmp     #$03              ;3rd floor?
09a2: d0 25                        bne     :NotPerfSq        ;not the Perfect Square special, branch
09a4: ad 95 61                     lda     plyr_xpos
09a7: c9 07                        cmp     #$07              ;X pos = 7?
09a9: d0 1e                        bne     :NotPerfSq        ;not special, branch
09ab: ad 96 61                     lda     plyr_ypos
09ae: ae 93 61                     ldx     plyr_facing       ;copy facing to ZP
09b1: 86 1a                        stx     ]tmp_facing
09b3: c9 08                        cmp     #$08              ;Y pos = 8?
09b5: f0 0c                        beq     :ChkPQNorth       ;yes, branch
09b7: c9 09                        cmp     #$09              ;Y pos = 9?
09b9: d0 0e                        bne     :NotPerfSq        ;not special, branch
09bb: a5 1a                        lda     ]tmp_facing       ;check facing
09bd: c9 04                        cmp     #$04              ;looking south?
09bf: d0 08                        bne     :NotPerfSq        ;no, not special
09c1: f0 1c                        beq     :MoveForward      ;yes, allow movement through wall

09c3: a5 1a        :ChkPQNorth     lda     ]tmp_facing
09c5: c9 02                        cmp     #$02              ;facing north?
09c7: f0 16                        beq     :MoveForward      ;yes, allow movement through wall
                   ; Player is not facing the perfect square wall.  Test to see if there is a wall
                   ; right in front of us.
09c9: ad 9a 61     :NotPerfSq      lda     maze_walls_rt
09cc: 29 e0                        and     #%11100000        ;strip low bits, keeping only distance
09ce: d0 0f                        bne     :MoveForward      ;nonzero, allow movement
09d0: 20 7e 12                     jsr     EraseMaze         ;facing a wall, splat the player
09d3: a9 09                        lda     #9
09d5: 85 06                        sta     char_horiz
09d7: 85 07                        sta     char_vert
09d9: a9 7c                        lda     #$7c              ;"splat"
09db: 20 e2 08                     jsr     DrawMsgN
09de: 60                           rts

09df: ae 93 61     :MoveForward    ldx     plyr_facing       ;get facing
09e2: ca                           dex
09e3: f0 15                        beq     :MoveWest
09e5: ca                           dex
09e6: f0 0d                        beq     :MoveNorth
09e8: ca                           dex
09e9: f0 05                        beq     :MoveEast
09eb: ce 96 61                     dec     plyr_ypos         ;move south (-Y)
09ee: 10 0d                        bpl     :MoveCommon       ;(always)

09f0: ee 95 61     :MoveEast       inc     plyr_xpos         ;move east (+X)
09f3: 10 08                        bpl     :MoveCommon       ;(always)

09f5: ee 96 61     :MoveNorth      inc     plyr_ypos         ;move north (+Y)
09f8: 10 03                        bpl     :MoveCommon       ;(always)

09fa: ce 95 61     :MoveWest       dec     plyr_xpos         ;move west (-X)
09fd: 20 10 0a     :MoveCommon     jsr     CheckSpecialCell  ;check to see if the new cell is special
0a00: ad a5 61                     lda     special_zone      ;find anything?
0a03: f0 01                        beq     :NoSpecial        ;no, do the usual
0a05: 60                           rts

0a06: 20 19 0b     :NoSpecial      jsr     ReduceResources   ;reduce torch and satiation levels
0a09: 20 15 10                     jsr     DrawMaze          ;redraw maze at new position
0a0c: 20 77 0b                     jsr     ReportLowRsrc     ;report hunger / torch issues
0a0f: 60                           rts

                   ; 
                   ; Checks to see if we're now standing in a cell with special properties.
                   ; 
                   ]ypos_copy      .var    $19    {addr/1}
                   ]xpos_copy      .var    $1a    {addr/1}

                   CheckSpecialCell
0a10: ad 96 61                     lda     plyr_ypos         ;copy X/Y position to ZP
0a13: 85 19                        sta     ]ypos_copy
0a15: ad 95 61                     lda     plyr_xpos
0a18: 85 1a                        sta     ]xpos_copy
0a1a: ad 94 61                     lda     plyr_floor
0a1d: c9 03                        cmp     #$03              ;on 3rd floor?
0a1f: d0 01                        bne     :Not3rd           ;no, branch
0a21: 60                           rts                       ;yes, nothing further here

0a22: 30 03        :Not3rd         bmi     :OneOrTwo
0a24: 4c bc 0a                     jmp     :FourOrFive

0a27: c9 02        :OneOrTwo       cmp     #$02              ;2nd floor?
0a29: f0 32                        beq     :FloorTwo         ;yes, branch
0a2b: a5 1a                        lda     ]xpos_copy
0a2d: c9 03                        cmp     #$03              ;X pos = 3?
0a2f: f0 05                        beq     :CheckCalcY       ;yes, check for calc
0a31: c9 06                        cmp     #$06              ;X pos = 6?
0a33: f0 0e                        beq     :ChkGuillotine    ;yes, check for guillotine
0a35: 60                           rts

0a36: a5 19        :CheckCalcY     lda     ]ypos_copy
0a38: c9 03                        cmp     #$03              ;Y pos = 3?
0a3a: f0 01                        beq     :IsCalcRoom       ;yes, in the calculator room
0a3c: 60           :Return         rts

0a3d: a2 02        :IsCalcRoom     ldx     #$02              ;calculator special
0a3f: 8e a5 61                     stx     special_zone
0a42: 60                           rts

0a43: a5 19        :ChkGuillotine  lda     ]ypos_copy
0a45: c9 0a                        cmp     #$0a              ;Y pos = 10?
0a47: f0 01                        beq     ReportGuillotine  ;yes, off with his head
0a49: 60                           rts

                   ReportGuillotine
0a4a: 20 55 08                     jsr     ClearScreen       ;clear hi-res screen
0a4d: a9 00                        lda     #0                ;column 0
0a4f: 85 06                        sta     char_horiz
0a51: a9 09                        lda     #9                ;row 9
0a53: 85 07                        sta     char_vert
0a55: a9 29                        lda     #$29              ;"the invisible guillotine beheads you"
0a57: 20 e2 08                     jsr     DrawMsgN
0a5a: 4c b9 10                     jmp     HandleDeath

0a5d: a5 19        :FloorTwo       lda     ]ypos_copy
0a5f: c9 05                        cmp     #$05              ;Y pos = 5?
0a61: f0 24                        beq     :Check2Y5
0a63: ad a4 61     :CheckDog1      lda     floor_move_lo     ;check number of moves made
0a66: c9 3c                        cmp     #60               ;at least 60?
0a68: b0 05                        bcs     :GtEq60           ;yes, branch
0a6a: ad a3 61                     lda     floor_move_hi
0a6d: f0 cd                        beq     :Return
0a6f: ad ae 61     :GtEq60         lda     dog1_alive        ;is dog #1 alive?
0a72: 29 01                        and     #$01              ;(?)
0a74: f0 c6                        beq     :Return           ;no, bail
0a76: ad a5 61                     lda     special_zone      ;already in a special zone (e.g. no light)?
0a79: d0 06                        bne     :InsertDogSpec    ;yes, branch
0a7b: a2 06                        ldx     #$06              ;encounter with dog #1
0a7d: 8e a5 61                     stx     special_zone      ;set special zone
0a80: 60                           rts

0a81: a2 06        :InsertDogSpec  ldx     #$06
0a83: 8e a6 61                     stx     special_zone1     ;add to special zone stack
0a86: 60                           rts

0a87: a5 1a        :Check2Y5       lda     ]xpos_copy
0a89: c9 05                        cmp     #$05              ;X pos = 5?
0a8b: f0 22                        beq     :Dog2
0a8d: c9 08                        cmp     #$08              ;X pos = 8?
0a8f: d0 d2                        bne     :CheckDog1        ;no, do other dog thing
                   ; Stepped into pit on 2nd floor.  Move to 3rd.
0a91: a2 03                        ldx     #$03
0a93: 8e 93 61                     stx     plyr_facing       ;rotate to face east
0a96: 8e 94 61                     stx     plyr_floor        ;3rd floor
0a99: a2 08                        ldx     #8                ;set X=8 Y=5
0a9b: 8e 95 61                     stx     plyr_xpos
0a9e: a2 05                        ldx     #5
0aa0: 8e 96 61                     stx     plyr_ypos
0aa3: a2 00                        ldx     #$00
0aa5: 8e a3 61                     stx     floor_move_hi     ;reset step counter
0aa8: 8e a4 61                     stx     floor_move_lo
0aab: 20 7c 10                     jsr     FallIntoPit       ;down we go
0aae: 60                           rts

                   ; Set up dog #2 (the one near the middle of the 2nd floor, which you can skip).
0aaf: ad af 61     :Dog2           lda     dog2_alive        ;is dog #2 alive?
0ab2: 29 01                        and     #$01
0ab4: f0 05                        beq     :Return           ;no, bail
0ab6: a2 07                        ldx     #$07              ;encounter with dog #2
0ab8: 8e a5 61                     stx     special_zone
0abb: 60           :Return         rts

0abc: c9 04        :FourOrFive     cmp     #$04              ;4th floor?
0abe: f0 40                        beq     :Floor4
                   ; Special areas on 5th floor.
0ac0: a5 1a                        lda     ]xpos_copy
0ac2: c9 04                        cmp     #$04              ;X pos = 4?
0ac4: f0 24                        beq     :CheckFiveX4
0ac6: ad a4 61     :Not5_44        lda     floor_move_lo
0ac9: c9 32                        cmp     #50               ;made at least 50 moves?
0acb: b0 05                        bcs     :CheckMother      ;yes, check on mom
0acd: ad a3 61                     lda     floor_move_hi
0ad0: f0 e9                        beq     :Return
0ad2: ad ac 61     :CheckMother    lda     monster2_alive    ;is monster's mother alive?
0ad5: 29 04                        and     #$04
0ad7: f0 e2                        beq     :Return           ;no, bail
0ad9: ad a5 61                     lda     special_zone      ;currently in a special zone?
0adc: d0 06                        bne     :InSpec           ;yes, branch
0ade: a2 09                        ldx     #$09              ;monster's mother lair
0ae0: 8e a5 61                     stx     special_zone
0ae3: 60                           rts

0ae4: a2 09        :InSpec         ldx     #$09              ;monster's mother lair
0ae6: 8e a6 61                     stx     special_zone1
0ae9: 60                           rts

0aea: a5 19        :CheckFiveX4    lda     ]ypos_copy
0aec: c9 04                        cmp     #$04              ;Y pos = 4?
0aee: d0 d6                        bne     :Not5_44          ;no, branch
                   ; Found the bat cell.
0af0: ad ab 61                     lda     bat_alive         ;is bat alive?
0af3: 29 02                        and     #$02
0af5: f0 cf                        beq     :Not5_44          ;no, no bat for you
0af7: 20 dc 10                     jsr     PushSpecialZone1
0afa: a2 04                        ldx     #$04
0afc: 8e a5 61                     stx     special_zone      ;into the bat zone
0aff: 60                           rts

                   ; In the monster's lair area on floor 4.  Monster shows up after 80 moves.
0b00: ad a4 61     :Floor4         lda     floor_move_lo
0b03: c9 50                        cmp     #80               ;has player taken 80+ forward steps?
0b05: b0 05                        bcs     :EnoughSteps      ;yes, branch
0b07: ad a3 61                     lda     floor_move_hi
0b0a: f0 af                        beq     :Return
0b0c: ad ad 61     :EnoughSteps    lda     monster1_alive    ;is monster alive?
0b0f: 29 02                        and     #$02
0b11: f0 05                        beq     :Return           ;no, bail
0b13: a2 08                        ldx     #$08              ;encounter with monster in lair
0b15: 8e a5 61                     stx     special_zone
0b18: 60           :Return         rts

                   ; 
                   ; Updates number of moves left on torches and hunger level.  This is called
                   ; after every forward movement (but not on turns or commands).
                   ; 
                   ; Also, increases the movement counter.
                   ; 
0b19: ad a4 61     ReduceResources lda     floor_move_lo     ;increment 16-bit move counter
0b1c: c9 ff                        cmp     #$ff              ;(in a really awkward way)
0b1e: f0 06                        beq     :LowFull
0b20: ee a4 61                     inc     floor_move_lo
0b23: 4c 2e 0b                     jmp     :DoTorch

0b26: a2 00        :LowFull        ldx     #$00
0b28: 8e a4 61                     stx     floor_move_lo
0b2b: ee a3 61                     inc     floor_move_hi
0b2e: ad 94 61     :DoTorch        lda     plyr_floor
0b31: c9 05                        cmp     #$05              ;5th floor?
0b33: f0 1a                        beq     :NoDecTorch       ;must be using ring, skip torch check
0b35: ad a1 61                     lda     torch_level       ;is a torch lit?
0b38: f0 15                        beq     :NoDecTorch       ;no, don't reduce torch level
0b3a: ce a1 61                     dec     torch_level
0b3d: d0 10                        bne     :NoDecTorch       ;still more to burn, branch
0b3f: ce 97 61                     dec     num_lit_torches   ;decrement lit torch count
0b42: a2 00                        ldx     #$00
0b44: 8e 9e 61                     stx     illumination_flag ;disable illumination
0b47: 20 dc 10                     jsr     PushSpecialZone1
0b4a: a2 0a                        ldx     #$0a              ;encounter monster in the darkness
0b4c: 8e a5 61                     stx     special_zone
                   ; Check food level.
0b4f: ce a0 61     :NoDecTorch     dec     food_level_lo     ;reduce food level
0b52: ad a0 61                     lda     food_level_lo     ;check food level
0b55: c9 ff                        cmp     #$ff              ;low byte dropped below zero?
0b57: d0 03                        bne     :NoDec            ;no, branch
0b59: ce 9f 61                     dec     food_level_hi     ;yes, decrement high byte
0b5c: ad 9f 61     :NoDec          lda     food_level_hi     ;see if we're out of food
0b5f: 0d a0 61                     ora     food_level_lo
0b62: d0 b4                        bne     :Return           ;have food, branch
                   ; Out of energy.
0b64: 20 55 08     StarvedToDeath  jsr     ClearScreen       ;erase hi-res screen
0b67: a9 35                        lda     #$35              ;"you have died of starvation"
0b69: a2 07                        ldx     #7
0b6b: 86 06                        stx     char_horiz        ;horizontal offset 7
0b6d: a2 02                        ldx     #2
0b6f: 86 07                        stx     char_vert         ;vertical offset 2
0b71: 20 e2 08                     jsr     DrawMsgN          ;give them the bad news
0b74: 4c b9 10                     jmp     HandleDeath       ;jump to general death handling

                   ; 
                   ; Displays a message when resources are running low.
                   ; 
0b77: ad 9f 61     ReportLowRsrc   lda     food_level_hi     ;got energy?
0b7a: d0 0c                        bne     :NotHungry        ;yes, no message
0b7c: ad a0 61                     lda     food_level_lo
0b7f: c9 0a                        cmp     #10               ;10 or more units left?
0b81: b0 05                        bcs     :NotHungry        ;yes, no message
0b83: a9 32                        lda     #$32              ;"your stomach is growling"
0b85: 20 92 08                     jsr     DrawMsgN_Row22
0b88: ad a1 61     :NotHungry      lda     torch_level       ;check torch level
0b8b: f0 25                        beq     :Return           ;already out, no message
0b8d: c9 0a                        cmp     #10               ;10 or more moves left?
0b8f: b0 21                        bcs     :Return           ;no message
0b91: a9 33                        lda     #$33              ;"your torch is dying"
0b93: 20 a4 08                     jsr     DrawMsgN_Row23
0b96: 60                           rts

                   ; 
                   ; Checks to see if an item is in the player's inventory and unboxed.
                   ; 
                   ; NOTE: if the item is not found, this prints a "check your inventory" message
                   ; and then pops the caller off the stack and returns to the caller's caller.
                   ; 
                   ; On entry:
                   ;   $0e: noun
                   ; 
                   ; On return:
                   ;   A-reg: object index for consumables (torches/food), object state ($07/$08)
                   ; for others
                   ;   $19/$1a: results from inventory query
                   ; 
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]ret_state      .var    $1a    {addr/1}

0b97: ad 9d 61     CheckInventory  lda     parsed_noun
0b9a: c9 12                        cmp     #$12              ;food, torch, ... ?
0b9c: 10 15                        bpl     :ChkConsumable    ;yes, branch
0b9e: a2 06                        ldx     #FN_GET_OBJ_INFO
0ba0: 86 0f                        stx     ]func_cmd
0ba2: 20 34 1a                     jsr     ObjMgmtFunc       ;get object info
0ba5: a5 1a                        lda     ]ret_state        ;check state
0ba7: c9 07                        cmp     #$07              ;is it in inventory and unboxed (active or not)?
0ba9: 10 07                        bpl     :Return           ;yes, bail
0bab: 68           :PopAndMsg      pla                       ;pop return address off stack
0bac: 68                           pla
0bad: a9 7b        CheckInvDolt    lda     #$7b              ;"check your inventory, dolt"
0baf: 20 a4 08     :MsgAndRet      jsr     DrawMsgN_Row23
0bb2: 60           :Return         rts

0bb3: c9 12        :ChkConsumable  cmp     #$12              ;food?
0bb5: f0 10                        beq     :HandleFood       ;yes, branch
0bb7: c9 13                        cmp     #$13              ;torch?
0bb9: f0 18                        beq     :HandleTorch      ;yes, branch
0bbb: a2 0b                        ldx     #FN_OBJ_HERE
0bbd: 86 0f                        stx     ]func_cmd
0bbf: 20 34 1a                     jsr     ObjMgmtFunc
0bc2: c9 00                        cmp     #$00
0bc4: f0 e5                        beq     :PopAndMsg
0bc6: 60                           rts

0bc7: a2 0c        :HandleFood     ldx     #FN_FIND_FOOD
0bc9: 86 0f                        stx     ]func_cmd
0bcb: 20 34 1a                     jsr     ObjMgmtFunc       ;object index in A-reg
0bce: c9 00                        cmp     #$00              ;did we find some?
0bd0: f0 d9                        beq     :PopAndMsg        ;no, snark
0bd2: 60                           rts

0bd3: a2 0e        :HandleTorch    ldx     #FN_FIND_UNLIT_T  ;look for unlit torch
0bd5: 86 0f                        stx     ]func_cmd
0bd7: 20 34 1a                     jsr     ObjMgmtFunc
0bda: c9 00                        cmp     #$00              ;find anything?
0bdc: d0 d4                        bne     :Return           ;yes, we're done
0bde: ad 94 61                     lda     plyr_floor
0be1: c9 05                        cmp     #$05              ;are we on the 5th floor?
0be3: f0 c6                        beq     :PopAndMsg        ;yes, complain and bail
0be5: ad 9e 61                     lda     illumination_flag ;lights off?
0be8: f0 c1                        beq     :PopAndMsg        ;yes, complain and bail
0bea: a2 0d                        ldx     #FN_FIND_LIT_T
0bec: 86 0f                        stx     ]func_cmd
0bee: 20 34 1a                     jsr     ObjMgmtFunc       ;look for lit torch
0bf1: c9 00                        cmp     #$00              ;find anything?
0bf3: d0 bd                        bne     :Return           ;no, bail
0bf5: ad 97 61                     lda     num_lit_torches   ;check lit torch count
0bf8: c9 01                        cmp     #$01              ;is one lit?
0bfa: d0 af                        bne     :PopAndMsg        ;no, complain and bail
0bfc: 68                           pla                       ;pop return address
0bfd: 68                           pla
0bfe: a9 98                        lda     #$98              ;"you will do no such thing"
0c00: d0 ad                        bne     :MsgAndRet        ;print msg and bail

                   ; 
                   ; Copy a block of data.
                   ; 
                   ; On entry:
                   ;   $0e-0f: src pointer
                   ;   $10-11: dst pointer
                   ;   $19-1a: length
                   ; 
                   ]src_ptr        .var    $0e    {addr/2}
                   ]dst_ptr        .var    $10    {addr/2}
                   ]length         .var    $19    {addr/2}

0c02: a0 00        CopyData        ldy     #$00              ;indirect load requires Y-reg, so set to zero
0c04: b1 0e        :CopyLoop       lda     (]src_ptr),y
0c06: 91 10                        sta     (]dst_ptr),y
0c08: e6 0e                        inc     ]src_ptr          ;increment low byte of src pointer
0c0a: d0 02                        bne     :SrcLowNZ
0c0c: e6 0f                        inc     ]src_ptr+1        ;hit zero, increment high byte
0c0e: e6 10        :SrcLowNZ       inc     ]dst_ptr          ;increment low byte of dst pointer
0c10: d0 02                        bne     :DstLowNZ
0c12: e6 11                        inc     ]dst_ptr+1
0c14: c6 19        :DstLowNZ       dec     ]length           ;decrement the length
0c16: f0 0b                        beq     LenLowZ           ;hit zero, see if we're done
0c18: a5 19                        lda     ]length           ;get the low byte
0c1a: c9 ff                        cmp     #$ff              ;did we just decrement below zero?
0c1c: d0 e6                        bne     :CopyLoop         ;no, branch
0c1e: c6 1a                        dec     ]length+1         ;yes, decrement the high byte
0c20: 4c 04 0c                     jmp     :CopyLoop

0c23: a5 1a        LenLowZ         lda     ]length+1         ;is 16-bit length zero?
0c25: 05 19                        ora     ]length
0c27: d0 db                        bne     :CopyLoop         ;not yet, keep going
0c29: 60                           rts

                   ; 
                   ; Saved copy of messages in rows 22/23.
0c2a: c9 50 90 03+ saved_msgs      .bulk   $c9,$50,$90,$03,$20,$15,$10,$ad,$9e,$61,$f0,$08,$a2,$00,$8e,$b3
                                    +      $61,$4c,$93,$34,$a2,$00,$8e,$a4,$61,$ad,$b3,$61,$d0,$29,$ad,$94
                                    +      $61,$c9,$05,$f0,$0a,$ad,$ad,$61
0c52: 29 02 d0 08+                 .bulk   $29,$02,$d0,$08,$4c,$93,$34,$ad,$ac,$61,$f0,$f8,$20,$26,$36,$a9
                                    +      $43,$20,$92,$08,$a9,$44,$20,$a4,$08,$ee,$b3,$61,$4c,$08,$36,$c9
                                    +      $01,$d0,$13,$20,$26,$36,$ee,$b3
                   ; 
                   ; Message shown in row 22.  This row is also used for input.
0c7a: 61 a9 45 20+ text_row22      .bulk   $61,$a9,$45,$20,$92,$08,$a9,$47,$20,$a4,$08,$4c,$08,$36,$20,$26
                                    +      $36,$ad,$94,$61,$c9,$05,$f0,$0d,$a9,$36,$20,$92,$08,$a9,$37,$20
                                    +      $a4,$08,$4c,$b9,$10,$a9,$48,$20
                   ; 
                   ; Message shown in row 23.
0ca2: 92 08 a9 4b+ text_row23      .bulk   $92,$08,$a9,$4b,$20,$a4,$08,$4c,$b9,$10,$ca,$d0,$6f,$ad,$9d,$61
                                    +      $c9,$11,$f0,$07,$20,$5f,$10,$a9,$20,$d0,$e9,$ad,$9c,$61,$c9,$0e
                                    +      $f0,$52,$c9,$13,$d0,$ee,$a2,$04

                   ; 
                   ; Get and parse a character or a line of input.
                   ; 
                   ; The first character is handled specially, because movement keys react
                   ; immediately.  Once we get a non-movement key, we switch to line-input mode
                   ; with a blinking apple cursor.
                   ; 
                   ; The input is parsed into $619c/619d before returning.
                   ; 
0cca: 2c 10 c0     GetInput        bit     KBDSTRB           ;clear keyboard strobe
0ccd: 2c 00 c0     :WaitForKey     bit     KBD               ;key ready?
0cd0: 10 fb                        bpl     :WaitForKey       ;not yet
0cd2: ad 00 c0                     lda     KBD               ;get key
0cd5: 29 7f                        and     #$7f              ;strip high bit
0cd7: c9 40                        cmp     #‘@’              ;< '@' ?
0cd9: 30 02                        bmi     :NoConv           ;yes
0cdb: 29 5f                        and     #$5f              ;convert to upper case
0cdd: 48           :NoConv         pha                       ;save key value
                   ; Save previous messages into buffer (can recall with ESC key).
0cde: a9 0c                        lda     #>text_row22
0ce0: 85 0f                        sta     ]src_ptr+1
0ce2: a9 7a                        lda     #<text_row22
0ce4: 85 0e                        sta     ]src_ptr
0ce6: a9 0c                        lda     #>saved_msgs
0ce8: 85 11                        sta     ]dst_ptr+1
0cea: a9 2a                        lda     #<saved_msgs
0cec: 85 10                        sta     ]dst_ptr
0cee: a9 00                        lda     #$00
0cf0: 85 1a                        sta     ]length+1
0cf2: a9 50                        lda     #80               ;copy 80 bytes
0cf4: 85 19                        sta     ]length
0cf6: 20 02 0c                     jsr     CopyData
0cf9: 20 5f 10                     jsr     ClearMessages     ;clear bottom two rows
0cfc: ea                           nop
0cfd: ea                           nop
0cfe: ea                           nop
0cff: ea                           nop
0d00: ea                           nop
0d01: ea                           nop
0d02: ea                           nop
0d03: ea                           nop
0d04: ea                           nop
0d05: ea                           nop
0d06: ea                           nop
0d07: ea                           nop
0d08: ea                           nop
0d09: ea                           nop
0d0a: ea                           nop
0d0b: ea                           nop
0d0c: ea                           nop
0d0d: ea                           nop
0d0e: ea                           nop
0d0f: c6 07                        dec     char_vert         ;back up to row 22
0d11: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
                   ; Clear message area to $80.
                   ; 
                   • Clear variables
                   ]word_count     .var    $10    {addr/1}
                   ]input_count    .var    $11    {addr/1}
                   ]in_buf_ptr     .var    $19    {addr/2}

0d14: a9 0c                        lda     #>text_row22
0d16: 8d 0d 00                     sta:    string_ptr+1
0d19: a9 79                        lda     #<text_row22-1
0d1b: 8d 0c 00                     sta:    string_ptr
0d1e: a9 80                        lda     #$80
0d20: a0 50                        ldy     #80
0d22: 91 0c        :Set80Loop      sta     (string_ptr),y
0d24: 88                           dey
0d25: d0 fb                        bne     :Set80Loop
                   ; 
0d27: a9 00                        lda     #$00
0d29: 85 11                        sta     ]input_count      ;no input yet
0d2b: 85 10                        sta     ]word_count
0d2d: a9 0c                        lda     #>text_row22      ;use row 22 message buffer to hold input
0d2f: 85 1a                        sta     ]in_buf_ptr+1
0d31: a9 79                        lda     #<text_row22-1
0d33: 85 19                        sta     ]in_buf_ptr
0d35: 68                           pla                       ;restore key value
0d36: 4c 4f 0d                     jmp     GotInputKey

                   ; Wait for a key to be hit as part of entering a line of input.
0d39: 2c 10 c0     GetNextKey      bit     KBDSTRB           ;clear keyboard strobe
0d3c: 20 43 12     :WaitLoop       jsr     DrawBlinkingApple ;draw the cursor, if appropriate
0d3f: 2c 00 c0                     bit     KBD
0d42: 10 f8                        bpl     :WaitLoop
0d44: ad 00 c0                     lda     KBD
0d47: 29 7f                        and     #%01111111        ;clear high bit
0d49: c9 40                        cmp     #$40              ;< '@'?
0d4b: 30 02                        bmi     GotInputKey       ;yes, branch
0d4d: 29 5f                        and     #%01011111        ;convert to upper case
                   ; 
                   ; Handle key.  Key value in A-reg (high bit cleared, converted to upper case).
                   ; 
0d4f: 48           GotInputKey     pha                       ;save key value
0d50: a5 11                        lda     ]input_count      ;do we have one or more chars in buffer?
0d52: d0 27                        bne     :ChkBS            ;yes, skip command-key checks
                   ; Check for immediate command keys.
0d54: 68                           pla                       ;restore key value
0d55: c9 5a                        cmp     #‘Z’              ;is it 'Z' (move forward)?
0d57: d0 03                        bne     :ChkX
0d59: 4c d1 0d                     jmp     MoveForward

0d5c: c9 58        :ChkX           cmp     #‘X’              ;is it 'X' (turn around)?
0d5e: d0 03                        bne     :ChkLeft
0d60: 4c dd 0d                     jmp     TurnAround

0d63: c9 08        :ChkLeft        cmp     #$08              ;is it left arrow (turn left)?
0d65: d0 03                        bne     :ChkRight
0d67: 4c d9 0d                     jmp     TurnLeft

0d6a: c9 15        :ChkRight       cmp     #$15              ;is it right arrow (turn right)?
0d6c: d0 03                        bne     :ChkIgnorable
0d6e: 4c d5 0d                     jmp     TurnRight

0d71: c9 20        :ChkIgnorable   cmp     #$20              ;is it ' '?
0d73: f0 c4                        beq     GetNextKey        ;yes, branch (no effect at start of line)
0d75: c9 0d                        cmp     #$0d              ;is it "Return"?
0d77: f0 c0                        beq     GetNextKey        ;yes, branch (no effect at start of line)
0d79: d0 08                        bne     :ChkReturn

0d7b: 68           :ChkBS          pla                       ;restore char
0d7c: c9 08                        cmp     #$08              ;is it left arrow (backspace)?
0d7e: d0 03                        bne     :ChkReturn        ;no, branch
0d80: 4c e8 0d                     jmp     Backspace

0d83: c9 0d        :ChkReturn      cmp     #$0d              ;is it "Return" (execute input)?
0d85: d0 03                        bne     :ChkEsc           ;no, branch
0d87: 4c e5 0d                     jmp     JmpParseInput     ;yes, go parse and execute

0d8a: c9 1b        :ChkEsc         cmp     #$1b              ;is it "Esc" (restore msgs)?
0d8c: d0 3a                        bne     :NotEsc
                   ; ESC hit, clear input and show previous messages.
                   ]src_ptr        .var    $0e    {addr/2}

0d8e: a9 00                        lda     #0                ;move to left column
0d90: 85 06                        sta     char_horiz
0d92: a9 16                        lda     #22               ;row 22
0d94: 85 07                        sta     char_vert
0d96: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
0d99: a9 0c                        lda     #>saved_msgs      ;copy from saved-message buffer
0d9b: 85 0f                        sta     ]src_ptr+1
0d9d: a9 29                        lda     #<saved_msgs-1
0d9f: 85 0e                        sta     ]src_ptr
0da1: a0 50                        ldy     #80               ;80 bytes (both lines)
0da3: b1 0e        :Loop           lda     (]src_ptr),y
0da5: 91 19                        sta     (]in_buf_ptr),y
0da7: 88                           dey
0da8: d0 f9                        bne     :Loop
                   ; 
                   ]count          .var    $0e    {addr/1}
                   ]index          .var    $0f    {addr/1}

0daa: a0 50                        ldy     #80               ;print 80 characters
0dac: 84 0e                        sty     ]count
0dae: a0 01                        ldy     #$01              ;start the count at 1
0db0: 84 0f                        sty     ]index            ;(we set the pointer to buffer-1)
0db2: b1 19        :Loop           lda     (]in_buf_ptr),y   ;get char from buffer
0db4: c9 80                        cmp     #$80              ;high bit set?
0db6: 30 02                        bmi     :ValidChar        ;no, valid char; branch
0db8: a9 20                        lda     #$20              ;yes, use ' ' instead
0dba: 20 92 11     :ValidChar      jsr     PrintSpecialChar
0dbd: e6 0f                        inc     ]index            ;increment index
0dbf: a4 0f                        ldy     ]index            ;load back into Y-reg
0dc1: c6 0e                        dec     ]count            ;have we done all 80?
0dc3: d0 ed                        bne     :Loop             ;not yet, loop
0dc5: 4c ca 0c                     jmp     GetInput          ;done, restart input loop

0dc8: c9 20        :NotEsc         cmp     #$20              ;is it ' ' (separates verb/noun)?
0dca: f0 6b                        beq     HandleSpace
0dcc: b0 3f                        bcs     HandleValidChar   ;non-control char, handle it
0dce: 4c 39 0d                     jmp     GetNextKey        ;control char, ignore it

0dd1: a9 5b        MoveForward     lda     #VERB_FWD
0dd3: d0 0a                        bne     DoImmVerb

0dd5: a9 5d        TurnRight       lda     #VERB_RIGHT
0dd7: d0 06                        bne     DoImmVerb

0dd9: a9 5c        TurnLeft        lda     #VERB_LEFT
0ddb: d0 02                        bne     DoImmVerb

0ddd: a9 5e        TurnAround      lda     #VERB_180
0ddf: 8d 9c 61     DoImmVerb       sta     parsed_verb
0de2: 4c 6e 12                     jmp     DrawSpace         ;erase char (?) and return

0de5: 4c 4d 0e     JmpParseInput   jmp     ParseInput

                   ; 
                   ; Ctrl+H hit after typing letters.  This makes it a backspace rather than a
                   ; turn-left command.
                   ; 
0de8: 20 6e 12     Backspace       jsr     DrawSpace         ;erase apple
0deb: c6 06                        dec     char_horiz        ;back up one
0ded: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
0df0: a9 20                        lda     #$20
0df2: 20 92 11                     jsr     PrintSpecialChar  ;erase char by printing space
0df5: c6 06                        dec     char_horiz        ;back up another
0df7: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
0dfa: a4 11                        ldy     ]input_count
0dfc: b1 19                        lda     (]in_buf_ptr),y   ;get char we backed up over?
0dfe: c9 20                        cmp     #‘ ’              ;was it a space?
0e00: d0 02                        bne     :NotSpc           ;no, branch
0e02: c6 10                        dec     ]word_count       ;yes, decrement word count (back in the verb)
0e04: a9 80        :NotSpc         lda     #$80
0e06: 91 19                        sta     (]in_buf_ptr),y   ;replace char in buffer with 0x80
0e08: c6 11                        dec     ]input_count
0e0a: 4c 39 0d                     jmp     GetNextKey

                   ; Store the character in the input buffer and echo it to the screen.  Letters
                   ; have been converted to upper case, but we convert to mixed-case on the screen.
                   ]tmp            .var    $13    {addr/1}

0e0d: 85 13        HandleValidChar sta     ]tmp              ;save key (which was converted to upper case)
0e0f: c9 41                        cmp     #‘A’              ;was it a letter?
0e11: 90 10                        bcc     :Regular          ;no, branch
0e13: a4 11                        ldy     ]input_count      ;are we at the start of the buffer?
0e15: f0 0c                        beq     :Regular          ;yes, branch
0e17: b1 19                        lda     (]in_buf_ptr),y   ;get previous char
0e19: c9 20                        cmp     #‘ ’              ;was it a space?
0e1b: f0 06                        beq     :Regular          ;yes, we're at start of word; branch
0e1d: a5 13                        lda     ]tmp              ;get value
0e1f: 09 20                        ora     #%00100000        ;convert to lower case
0e21: d0 02                        bne     :DrawKey          ;(always)

0e23: a5 13        :Regular        lda     ]tmp              ;get key value
0e25: 48           :DrawKey        pha                       ;save it
0e26: 20 92 11                     jsr     PrintSpecialChar  ;print it
0e29: 68                           pla                       ;restore it
0e2a: e6 11                        inc     ]input_count      ;advance to next spot in buffer
0e2c: a4 11                        ldy     ]input_count
0e2e: 91 19                        sta     (]in_buf_ptr),y   ;store char
0e30: c0 1e                        cpy     #30               ;reached max input length?
0e32: f0 19                        beq     ParseInput        ;yes, go parse it
0e34: 4c 39 0d                     jmp     GetNextKey        ;no, get another key

                   ; 
                   ; Handles entry of ' ' anywhere other than the start of the line.
                   ; 
0e37: a4 11        HandleSpace     ldy     ]input_count
0e39: 88                           dey
0e3a: b1 19                        lda     (]in_buf_ptr),y   ;get previous character
0e3c: c9 20                        cmp     #‘ ’              ;was it also a space?
0e3e: d0 03                        bne     :NotSpc           ;no, branch
0e40: 4c 39 0d                     jmp     GetNextKey        ;yes, ignore this one

0e43: a5 10        :NotSpc         lda     ]word_count       ;get word count
0e45: d0 06                        bne     ParseInput        ;nonzero, this terminates noun; branch to parser
0e47: e6 10                        inc     ]word_count       ;was zero, this terminates verb; increment
0e49: a9 20                        lda     #‘ ’              ;go handle like any other input char
0e4b: d0 c0                        bne     HandleValidChar   ;(always)

                   ; Parse the line of input.
                   ; 
                   ; At this point:
                   ;   $11: number of bytes in input buffer
                   ;   $19-1a: input buffer pointer
0e4d: 20 6e 12     ParseInput      jsr     DrawSpace         ;erase the blinking cursor char
0e50: a9 20                        lda     #‘ ’
0e52: e6 11                        inc     ]input_count
0e54: a4 11                        ldy     ]input_count      ;we want to terminate the input line by
0e56: 91 19                        sta     (]in_buf_ptr),y   ; sticking a space character on the end
0e58: e6 19                        inc     ]in_buf_ptr       ;advance buffer pointer
0e5a: d0 02                        bne     :NoInc
0e5c: e6 1a                        inc     ]in_buf_ptr+1
                   ; Parse the verb.
                   ]word_index     .var    $10    {addr/1}

0e5e: 20 6b 0f     :NoInc          jsr     ParseWord         ;parse the first word; result in $10
0e61: a5 10                        lda     ]word_index
0e63: 8d 9c 61                     sta     parsed_verb       ;save it off
                   ; Find the next ' ' in the buffer.
0e66: a0 00                        ldy     #$00
0e68: e6 19        :FindSpcLoop    inc     ]in_buf_ptr       ;advance buffer pointer
0e6a: d0 02                        bne     :NoInc1
0e6c: e6 1a                        inc     ]in_buf_ptr+1
0e6e: b1 19        :NoInc1         lda     (]in_buf_ptr),y   ;get char
0e70: c9 20                        cmp     #‘ ’              ;space?
0e72: d0 f4                        bne     :FindSpcLoop      ;no, branch
0e74: e6 19                        inc     ]in_buf_ptr       ;advance pointer past space
0e76: d0 02                        bne     :NoInc2
0e78: e6 1a                        inc     ]in_buf_ptr+1
0e7a: b1 19        :NoInc2         lda     (]in_buf_ptr),y
0e7c: c9 80                        cmp     #$80              ;did we run off the end?
0e7e: f0 04                        beq     :NoNoun           ;yes, no noun follows
0e80: c9 20                        cmp     #‘ ’              ;is it another space?
0e82: d0 07                        bne     :ParseNoun        ;no, go parse noun
0e84: a9 00        :NoNoun         lda     #$00
0e86: 8d 9d 61                     sta     parsed_noun
0e89: f0 08                        beq     :GotWords         ;(always)

0e8b: 20 6b 0f     :ParseNoun      jsr     ParseWord         ;parse the second word; result in $10
0e8e: a5 10                        lda     ]word_index
0e90: 8d 9d 61                     sta     parsed_noun       ;save it off
                   ; We've got the words.  See if they make basic sense.
0e93: ad 9c 61     :GotWords       lda     parsed_verb       ;get verb
0e96: c9 1d                        cmp     #FIRST_NOUN       ;is it from the noun list?
0e98: 90 28                        bcc     :IsVerb           ;no, it's a verb; branch
                   ; Complain about verbing a noun.
0e9a: a9 8d                        lda     #$8d              ;"I'm sorry, but I can't"
0e9c: 20 a4 08                     jsr     DrawMsgN_Row23
0e9f: a9 7a                        lda     #<text_row22      ;reset input pointer
0ea1: 85 19                        sta     ]in_buf_ptr
0ea3: a9 0c                        lda     #>text_row22
0ea5: 85 1a                        sta     ]in_buf_ptr+1
0ea7: a0 00                        ldy     #$00
0ea9: 98           :Loop           tya
0eaa: 48                           pha
0eab: b1 19                        lda     (]in_buf_ptr),y   ;print characters
0ead: c9 20                        cmp     #‘ ’              ; up to the first space
0eaf: f0 08                        beq     :NounEnd
0eb1: 20 92 11                     jsr     PrintSpecialChar
0eb4: 68                           pla
0eb5: a8                           tay
0eb6: c8                           iny
0eb7: d0 f0                        bne     :Loop
0eb9: 68           :NounEnd        pla
0eba: a9 2e                        lda     #‘.’              ;finish sentence with punctuation
0ebc: 20 a4 11                     jsr     DrawGlyph
0ebf: 4c ca 0c                     jmp     GetInput          ;try again

0ec2: c9 14        :IsVerb         cmp     #$14              ;does this verb need a noun?
0ec4: b0 50                        bcs     :NoNoun           ;no, branch
                   ; Check the noun.
0ec6: ad 9d 61                     lda     parsed_noun       ;get noun index
0ec9: f0 4b                        beq     :NoNoun           ;none provided, branch
0ecb: c9 40                        cmp     #$40              ;is noun an invalid word?
0ecd: f0 0b                        beq     :InvalidNoun      ;yes, branch
0ecf: c9 1d                        cmp     #FIRST_NOUN       ;was the noun a verb word?
0ed1: 90 07                        bcc     :InvalidNoun      ;yes, branch
0ed3: 38                           sec
0ed4: e9 1c                        sbc     #FIRST_NOUN-1     ;change $1d-3f to $01-23
0ed6: 8d 9d 61                     sta     parsed_noun
0ed9: 60           :Return         rts

0eda: a9 8f        :InvalidNoun    lda     #$8f              ;"what in tarnation is a"
0edc: 20 a4 08                     jsr     DrawMsgN_Row23
0edf: a9 7a                        lda     #<text_row22      ;get pointer to input buffer
0ee1: 85 19                        sta     ]in_buf_ptr
0ee3: a9 0c                        lda     #>text_row22
0ee5: 85 1a                        sta     ]in_buf_ptr+1
0ee7: a0 00                        ldy     #$00              ;search for the first space
0ee9: b1 19        :Loop           lda     (]in_buf_ptr),y
0eeb: c9 20                        cmp     #‘ ’
0eed: f0 08                        beq     :GotSpace
0eef: e6 19                        inc     ]in_buf_ptr       ;advance pointer
0ef1: d0 f6                        bne     :Loop
0ef3: e6 1a                        inc     ]in_buf_ptr+1
0ef5: d0 f2                        bne     :Loop             ;(always)

0ef7: e6 19        :GotSpace       inc     ]in_buf_ptr       ;advance pointer past the space
0ef9: d0 02                        bne     :PrintNoun        ; which is guaranteed to be non-space
0efb: e6 1a                        inc     ]in_buf_ptr+1
0efd: 98           :PrintNoun      tya                       ;preserve Y-reg
0efe: 48                           pha
0eff: b1 19                        lda     (]in_buf_ptr),y   ;get character
0f01: c9 20                        cmp     #‘ ’              ;is it a space?
0f03: f0 08                        beq     :PrintQ           ;yes, branch
0f05: 20 92 11                     jsr     PrintSpecialChar  ;output character
0f08: 68                           pla
0f09: a8                           tay                       ;restore Y-reg
0f0a: c8                           iny
0f0b: d0 f0                        bne     :PrintNoun        ;loop
0f0d: a9 3f        :PrintQ         lda     #‘?’
0f0f: 20 92 11                     jsr     PrintSpecialChar  ;print a question mark
0f12: 68                           pla                       ;remove saved Y-reg from stack
0f13: 4c ca 0c                     jmp     GetInput          ;go get more input

                   ; 
                   ; Player entered a verb without a noun.  Check it.
0f16: ad 9c 61     :NoNoun         lda     parsed_verb
0f19: c9 14                        cmp     #$14              ;is verb in set that doesn't require a noun?
0f1b: b0 bc                        bcs     :Return           ;yes, input is valid
0f1d: c9 0e                        cmp     #$0e              ;"exam"?
0f1f: f0 39                        beq     :HndExamNoN       ;yes, handle that specially
                   ; Verb has no noun but needs one.  We want to print the verb they used, followed
                   ; by "what" (as in "Eat what?").
0f21: a9 0c                        lda     #>text_row22      ;set pointer to text input
0f23: 85 1a                        sta     ]in_buf_ptr+1
0f25: a9 7a                        lda     #<text_row22
0f27: 85 19                        sta     ]in_buf_ptr
0f29: a9 00                        lda     #0                ;set position to start of bottom line
0f2b: 85 06                        sta     char_horiz
0f2d: a9 17                        lda     #23
0f2f: 85 07                        sta     char_vert
0f31: 20 ef 11                     jsr     SetRowPtr         ;set hi-res row addr
0f34: a9 1e                        lda     #$1e              ;clear to end of line
0f36: 20 92 11                     jsr     PrintSpecialChar
                   ; 
0f39: a0 00                        ldy     #$00
0f3b: 84 11                        sty     ]input_count
0f3d: b1 19                        lda     (]in_buf_ptr),y   ;get first char
0f3f: 29 5f                        and     #%01011111        ;convert to upper case
0f41: d0 06                        bne     :CharOk
0f43: b1 19        :Loop           lda     (]in_buf_ptr),y   ;get next char
0f45: c9 20                        cmp     #‘ ’
0f47: f0 09                        beq     :WeirdChar        ;not space, weird
0f49: 20 92 11     :CharOk         jsr     PrintSpecialChar  ;print char
0f4c: e6 11                        inc     ]input_count
0f4e: a4 11                        ldy     ]input_count
0f50: d0 f1                        bne     :Loop
                   ; 
0f52: a9 56        :WeirdChar      lda     #$56              ;"what?"
0f54: 20 e2 08                     jsr     DrawMsgN
0f57: 4c ca 0c                     jmp     GetInput          ;back to input loop

0f5a: ad 9e 61     :HndExamNoN     lda     illumination_flag
0f5d: f0 04                        beq     :NoLight
0f5f: a9 8b                        lda     #$8b              ;"look at your monitor"
0f61: d0 02                        bne     :PrintMsg

0f63: a9 8a        :NoLight        lda     #$8a              ;"it's awfully dark"
0f65: 20 a4 08     :PrintMsg       jsr     DrawMsgN_Row23
0f68: 4c ca 0c                     jmp     GetInput

                   ; 
                   ; Parses a verb or noun.
                   ; 
                   ; On exit:
                   ;   $10: word index ($00-3f)
                   ; 
                   • Clear variables
                   ]table_ptr      .var    $0e    {addr/2}
                   ]word_index     .var    $10    {addr/1}
                   ]cmd_len_ctr    .var    $11    {addr/1}
                   ]tmp_char       .var    $13    {addr/1}
                   ]input_ptr      .var    $19    {addr/2}

0f6b: a5 1a        ParseWord       lda     ]input_ptr+1      ;preserve input pointer
0f6d: 48                           pha
0f6e: a5 19                        lda     ]input_ptr
0f70: 48                           pha
0f71: a9 66                        lda     #>verb_list       ;set pointer to start of word list
0f73: 85 0f                        sta     ]table_ptr+1
0f75: a9 94                        lda     #<verb_list
0f77: 85 0e                        sta     ]table_ptr
0f79: a9 00                        lda     #$00
0f7b: 85 10                        sta     ]word_index       ;init word index to zero
0f7d: a0 01        :CompareStr     ldy     #$01              ;start at +1 so we can look back to check for alias
0f7f: b1 0e        :ScanLoop       lda     (]table_ptr),y    ;get value from table
0f81: 29 80                        and     #$80              ;check high bit
0f83: d0 08                        bne     :HiSet            ;set, we're at the start of a word
0f85: e6 0e                        inc     ]table_ptr        ;not set, scan forward to find start
0f87: d0 f6                        bne     :ScanLoop         ; (we might have stopped early on previous mismatch)
0f89: e6 0f                        inc     ]table_ptr+1
0f8b: d0 f2                        bne     :ScanLoop
                   ; 
0f8d: 88           :HiSet          dey
0f8e: b1 0e                        lda     (]table_ptr),y
0f90: c9 2a                        cmp     #‘*’              ;is this an alias for previous entry?
0f92: f0 02                        beq     :IsAlias          ;yes, don't increment index
0f94: e6 10                        inc     ]word_index       ;not alias
0f96: e6 0e        :IsAlias        inc     ]table_ptr        ;advance pointer (counteracts DEY)
0f98: d0 02                        bne     :NoInc
0f9a: e6 0f                        inc     ]table_ptr+1
                   ; 
0f9c: a9 04        :NoInc          lda     #$04              ;test first 4 letters of word
0f9e: 85 11                        sta     ]cmd_len_ctr
0fa0: b1 0e        :CmpLoop        lda     (]table_ptr),y    ;get value from table
0fa2: 29 5f                        and     #%01011111        ;convert to upper case
0fa4: 85 13                        sta     ]tmp_char
0fa6: b1 19                        lda     (]input_ptr),y    ;get value from input line
0fa8: 29 5f                        and     #%01011111        ;convert to upper case
0faa: c5 13                        cmp     ]tmp_char         ;does it match?
0fac: d0 17                        bne     :NotMatch         ;no, move on
0fae: e6 19                        inc     ]input_ptr        ;match, advance to next char
0fb0: d0 02                        bne     :NoInc1
0fb2: e6 1a                        inc     ]input_ptr+1
0fb4: e6 0e        :NoInc1         inc     ]table_ptr        ;advance table pointer
0fb6: d0 02                        bne     :NoInc2
0fb8: e6 0f                        inc     ]table_ptr+1
0fba: c6 11        :NoInc2         dec     ]cmd_len_ctr      ;have we checked 4 chars?
0fbc: d0 e2                        bne     :CmpLoop          ;not yet, keep going
                   ; Matched, return with word index in $10.
0fbe: 68           :Return         pla                       ;restore input pointer
0fbf: 85 19                        sta     ]input_ptr
0fc1: 68                           pla
0fc2: 85 1a                        sta     ]input_ptr+1
0fc4: 60                           rts

0fc5: a5 10        :NotMatch       lda     ]word_index       ;check the index
0fc7: c9 3f                        cmp     #$3f              ;reached end of cmd/obj list?
0fc9: f0 0d                        beq     :NoMatches        ;yes, give up
0fcb: 68                           pla                       ;reset input pointer
0fcc: 85 19                        sta     ]input_ptr
0fce: 68                           pla
0fcf: 85 1a                        sta     ]input_ptr+1
0fd1: 48                           pha                       ;and save it again
0fd2: a5 19                        lda     ]input_ptr
0fd4: 48                           pha
0fd5: 4c 7d 0f                     jmp     :CompareStr

0fd8: e6 10        :NoMatches      inc     ]word_index       ;increment to $40 to indicate failure
0fda: d0 e2                        bne     :Return           ;(always)

                   ; 
                   ; Pauses for a moderate amount of time.
                   ; 
                   ]counter        .var    $0e    {addr/2}

0fdc: a2 90        MediumPause     ldx     #$90
0fde: 86 0f                        stx     ]counter+1
0fe0: c6 0e        :Loop           dec     ]counter
0fe2: d0 fc                        bne     :Loop
0fe4: c6 0f                        dec     ]counter+1
0fe6: d0 f8                        bne     :Loop
0fe8: 60                           rts

                   ; 
                   ; Wait for a key to be hit.  Draws a blinking cursor.  (Caller is expected to
                   ; get the key from KBD.)
                   ; 
0fe9: 2c 10 c0     WaitKeyCursor   bit     KBDSTRB           ;clear keyboard strobe
0fec: 20 43 12     :WaitLoop       jsr     DrawBlinkingApple
0fef: 2c 00 c0                     bit     KBD
0ff2: 10 f8                        bpl     :WaitLoop
0ff4: 4c 6e 12                     jmp     DrawSpace         ;erase apple

                   ; 
                   ; Waits for 'Y' or 'N' to be hit.  Draws a blinking cursor.
                   ; 
                   ; On exit:
                   ;   A-reg: key hit
                   ; 
0ff7: 2c 10 c0     GetYesNo        bit     KBDSTRB
0ffa: 20 43 12     :WaitLoop       jsr     DrawBlinkingApple
0ffd: 2c 00 c0                     bit     KBD
1000: 10 f8                        bpl     :WaitLoop
1002: ad 00 c0                     lda     KBD
1005: 29 7f                        and     #$7f
1007: c9 59                        cmp     #‘Y’
1009: f0 04                        beq     :IsY
100b: c9 4e                        cmp     #‘N’
100d: d0 e8                        bne     GetYesNo
100f: 48           :IsY            pha
1010: 20 6e 12                     jsr     DrawSpace
1013: 68                           pla
1014: 60                           rts

                   ; 
                   ; Draws the maze portion of the screen.
                   ; 
                   • Clear variables
                   ]feature_dist   .var    $0e    {addr/1}
                   ]feature_index  .var    $0f    {addr/1}

1015: 20 7e 12     DrawMaze        jsr     EraseMaze
1018: 20 bf 17                     jsr     ProcessMazeWalls
101b: ad 9e 61                     lda     illumination_flag ;is there light?
101e: f0 24                        beq     :Return           ;no, draw nothing
1020: 20 a6 12                     jsr     DrawVisWalls
1023: 20 df 1d                     jsr     FindFeature       ;see if there are interesting features ahead
1026: a5 0f                        lda     ]feature_index
1028: 05 0e                        ora     ]feature_dist
102a: f0 03                        beq     :NoFeature
102c: 20 5a 1e                     jsr     DrawFeature       ;found one, draw it
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

102f: a2 0a        :NoFeature      ldx     #FN_FIND_BOXES
1031: 86 0f                        stx     ]func_cmd
1033: 20 34 1a                     jsr     ObjMgmtFunc       ;find boxes on floor
1036: ad 9b 61                     lda     vis_box_flags     ;find any?
1039: f0 09                        beq     :Return           ;no, done
103b: 85 0e                        sta     ]func_arg         ;yes, set up call
103d: a2 06                        ldx     #$06
103f: 86 0f                        stx     ]func_cmd
1041: 20 5a 1e                     jsr     DrawFeature       ;draw all boxes
1044: 60           :Return         rts

                   ; 
                   ; Pause longishly.
                   ; 
                   ]counter3       .var    $0e    {addr/1}
                   ]counter2       .var    $0f    {addr/1}
                   ]counter1       .var    $10    {addr/1}

1045: a2 05        LongDelay       ldx     #$05
1047: 86 10                        stx     ]counter1
1049: a2 00        :Delay1         ldx     #$00
104b: 86 0f                        stx     ]counter2
104d: c6 0e        :Delay2         dec     ]counter3
104f: d0 fc                        bne     :Delay2
1051: c6 0f                        dec     ]counter2
1053: d0 f8                        bne     :Delay2
1055: c6 10                        dec     ]counter1
1057: d0 f0                        bne     :Delay1
1059: 60                           rts

                   PrintLittleSense
105a: a9 55                        lda     #$55              ;"you are making little sense"
105c: 4c a4 08                     jmp     DrawMsgN_Row23

                   ; 
                   ; Erases the message area (text rows 22 and 23) to spaces.
                   ; 
                   ; On exit:
                   ;   A-reg: preserved
                   ;   text row set to 23 (bottom row)
                   ; 
105f: 48           ClearMessages   pha                       ;preserve A-reg
1060: a2 00                        ldx     #0                ;set column to zero
1062: 86 06                        stx     char_horiz
1064: a2 16                        ldx     #22               ;set row to 22
1066: 86 07                        stx     char_vert
1068: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
106b: a9 1e                        lda     #$1e              ;output clear-to-EOL char
106d: 20 92 11                     jsr     PrintSpecialChar
1070: e6 07                        inc     char_vert         ;set to row 23
1072: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
1075: a9 1e                        lda     #$1e              ;output clear-to-EOL char
1077: 20 92 11                     jsr     PrintSpecialChar
107a: 68                           pla                       ;restore A-reg
107b: 60                           rts

                   ; 
                   ; Informs the player that they have fallen into a pit.
                   ; 
107c: 20 7e 12     FallIntoPit     jsr     EraseMaze
107f: a2 05                        ldx     #5
1081: 86 06                        stx     char_horiz
1083: a2 08                        ldx     #8
1085: 86 07                        stx     char_vert
1087: 20 ef 11                     jsr     SetRowPtr
108a: a9 a7                        lda     #$a7              ;"oh no! a pit"
108c: 20 e2 08                     jsr     DrawMsgN
108f: 20 dc 0f                     jsr     MediumPause
1092: a2 05                        ldx     #5
1094: 86 06                        stx     char_horiz
1096: e6 07                        inc     char_vert
1098: 20 ef 11                     jsr     SetRowPtr
109b: a9 2c                        lda     #$2c              ;"aaaaaaaaaaahhhhh"
109d: 20 e2 08                     jsr     DrawMsgN
10a0: 20 45 10                     jsr     LongDelay
10a3: 20 7e 12                     jsr     EraseMaze
10a6: a2 09                        ldx     #9
10a8: 86 06                        stx     char_horiz
10aa: a2 08                        ldx     #8
10ac: 86 07                        stx     char_vert
10ae: 20 ef 11                     jsr     SetRowPtr
10b1: a9 2d                        lda     #$2d              ;"wham"
10b3: 20 e2 08                     jsr     DrawMsgN
10b6: 4c 45 10                     jmp     LongDelay

10b9: 20 45 10     HandleDeath     jsr     LongDelay         ;pause so they can read cause of death
10bc: 20 5f 10                     jsr     ClearMessages     ;clear message area
10bf: a9 34                        lda     #$34              ;"you are another victim of the maze"
10c1: 20 92 08                     jsr     DrawMsgN_Row22
10c4: a9 39        AskPlayAgain    lda     #$39              ;"do you want to play again?"
10c6: 20 a4 08                     jsr     DrawMsgN_Row23
10c9: 20 f7 0f                     jsr     GetYesNo
10cc: c9 59                        cmp     #‘Y’
10ce: d0 03                        bne     ExitToMon         ;no, exit
10d0: 4c 0c 08                     jmp     Restart           ;yes, restart game

10d3: 2c 54 c0     ExitToMon       bit     TXTPAGE1
10d6: 2c 51 c0                     bit     TXTSET
10d9: 4c 69 ff                     jmp     MON_MONZ

                   ; 
                   ; Push the special zone stack to make room for a new item.  Does not alter the
                   ; current zone.
                   ; 
                   PushSpecialZone1
10dc: ad a6 61                     lda     special_zone1
10df: 8d a7 61                     sta     special_zone2
10e2: ad a5 61                     lda     special_zone
10e5: 8d a6 61                     sta     special_zone1
10e8: 60                           rts

10e9: 95 61 20 7c+                 .junk   121
                   ; Hi-res line addresses for 24 lines of text.
1162: 40 00        line_addr       .dbd2   $4000             ;line 0
1164: 40 80                        .dbd2   $4080             ;line 8
1166: 41 00                        .dbd2   $4100
1168: 41 80                        .dbd2   $4180
116a: 42 00                        .dbd2   $4200
116c: 42 80                        .dbd2   $4280
116e: 43 00                        .dbd2   $4300
1170: 43 80                        .dbd2   $4380
1172: 40 28                        .dbd2   $4028
1174: 40 a8                        .dbd2   $40a8
1176: 41 28                        .dbd2   $4128
1178: 41 a8                        .dbd2   $41a8
117a: 42 28                        .dbd2   $4228
117c: 42 a8                        .dbd2   $42a8
117e: 43 28                        .dbd2   $4328
1180: 43 a8                        .dbd2   $43a8
1182: 40 50                        .dbd2   $4050
1184: 40 d0                        .dbd2   $40d0
1186: 41 50                        .dbd2   $4150
1188: 41 d0                        .dbd2   $41d0
118a: 42 50                        .dbd2   $4250
118c: 42 d0                        .dbd2   $42d0
118e: 43 50                        .dbd2   $4350
1190: 43 d0                        .dbd2   $43d0             ;line 184

                   ; 
                   ; Prints a character on the screen, with special handling for a few:
                   ;   $0a: perform newline + carriage return
                   ;   $1e: clear to end of line
                   ;   $c0-ff: emit (N-$c0) spaces
                   ; 
                   ; On entry:
                   ;   A-reg: character to print
                   ; 
                   PrintSpecialChar
1192: c9 0a                        cmp     #$0a              ;newline / carriage return?
1194: f0 76                        beq     NewLineCR         ;yes, branch
1196: c9 1e                        cmp     #$1e              ;clear to EOL?
1198: d0 03                        bne     :NotClear         ;no, branch
119a: 4c 1e 12                     jmp     ClearToEol

119d: c9 c0        :NotClear       cmp     #$c0              ;>= $c0?
119f: 90 03                        bcc     DrawGlyph         ;no, draw as glyph
11a1: 4c 26 12                     jmp     DrawSpaces        ;yes, output N-$c0 spaces

                   ; 
                   ; Draws a glyph on the hi-res screen.
                   ; 
                   ; On entry:
                   ;   A-reg: glyph index (0-127)
                   ;   $08-09: pointer to first row on hi-res screen
                   ; 
                   ; On exit:
                   ;   horiz/vert position advanced by 1; $08-09 updated
                   ; 
                   • Clear variables
                   ]glyph_ptr      .var    $13    {addr/2}
                   ]line_ctr       .var    $15    {addr/1}

11a4: 85 13        DrawGlyph       sta     ]glyph_ptr        ;store index
11a6: a9 00                        lda     #$00
11a8: 85 14                        sta     ]glyph_ptr+1      ;make it a 16-bit value
11aa: 06 13                        asl     ]glyph_ptr        ;multiply by 8
11ac: 26 14                        rol     ]glyph_ptr+1
11ae: 06 13                        asl     ]glyph_ptr
11b0: 26 14                        rol     ]glyph_ptr+1
11b2: 06 13                        asl     ]glyph_ptr
11b4: 26 14                        rol     ]glyph_ptr+1
11b6: 18                           clc
11b7: a9 94                        lda     #<font_glyphs     ;add to font base address
11b9: 65 13                        adc     ]glyph_ptr
11bb: 85 13                        sta     ]glyph_ptr        ;save as pointer
11bd: a9 62                        lda     #>font_glyphs
11bf: 65 14                        adc     ]glyph_ptr+1
11c1: 85 14                        sta     ]glyph_ptr+1
                   ; Draw it.
11c3: a2 00                        ldx     #$00
11c5: a0 00                        ldy     #$00
11c7: a9 08                        lda     #$08              ;glyphs are 8 lines high
11c9: 85 15                        sta     ]line_ctr
11cb: 18                           clc
11cc: b1 13        :DrawLoop       lda     (]glyph_ptr),y    ;get glyph data
11ce: 81 08                        sta     (char_row_ptr,x)  ;store on hi-res screen
11d0: a9 04                        lda     #$04              ;next row is +$0400
11d2: 65 09                        adc     char_row_ptr+1
11d4: 85 09                        sta     char_row_ptr+1
11d6: c8                           iny                       ;advance to next byte in glyph data
11d7: c6 15                        dec     ]line_ctr         ;copied all 8?
11d9: d0 f1                        bne     :DrawLoop         ;not yet
                   ; Advance horizontal / vertical position.
11db: e6 06                        inc     char_horiz        ;advance horizontal position
11dd: a9 28                        lda     #40
11df: c5 06                        cmp     char_horiz        ;at end of line?
11e1: d0 0c                        bne     SetRowPtr         ;no, don't update
11e3: a9 00                        lda     #$00
11e5: 85 06                        sta     char_horiz        ;yes, set horiz posn to zero
11e7: a9 17                        lda     #23
11e9: c5 07                        cmp     char_vert         ;at bottom of screen?
11eb: f0 02                        beq     SetRowPtr         ;yes, don't advance
11ed: e6 07                        inc     char_vert         ;no, move to next line
                   ; 
                   ; Sets the hi-res row pointer for the current vertical text position.
                   ; 
                   ; On entry:
                   ;   $07: vertical position (0-23)
                   ; 
                   ; On exit:
                   ;   $08-09: address of top row on hi-res page 2
                   ; 
                   ]ind_ptr        .var    $13    {addr/2}

11ef: a5 07        SetRowPtr       lda     char_vert
11f1: 0a                           asl     A
11f2: 18                           clc
11f3: 69 62                        adc     #<line_addr
11f5: 85 13                        sta     ]ind_ptr
11f7: a9 00                        lda     #$00
11f9: 69 11                        adc     #>line_addr
11fb: 85 14                        sta     ]ind_ptr+1
11fd: a0 01                        ldy     #$01
11ff: 18                           clc
1200: b1 13                        lda     (]ind_ptr),y
1202: 65 06                        adc     char_horiz
1204: 85 08                        sta     char_row_ptr
1206: 88                           dey
1207: b1 13                        lda     (]ind_ptr),y
1209: 85 09                        sta     char_row_ptr+1
120b: 60                           rts

120c: 20 6e 12     NewLineCR       jsr     DrawSpace
120f: a9 17                        lda     #23
1211: c5 07                        cmp     char_vert
1213: f0 02                        beq     :NoInc
1215: e6 07                        inc     char_vert
1217: a9 00        :NoInc          lda     #$00
1219: 85 06                        sta     char_horiz
121b: 4c ef 11                     jmp     SetRowPtr

                   ; 
                   ; Clear the screen to the end of the current line by drawing spaces.
                   ; 
121e: a9 28        ClearToEol      lda     #40               ;compute 40 - horiz posn
1220: 38                           sec
1221: e5 06                        sbc     char_horiz
1223: 4c 29 12                     jmp     DrawSpaces1       ;draw that many spaces

                   ; 
                   ; Output (N - $c0) spaces.
                   ; 
                   ; On entry:
                   ;   A-reg: number of spaces to draw, +$C0
                   ; 
                   ]count          .var    $16    {addr/1}

1226: 38           DrawSpaces      sec
1227: e9 c0                        sbc     #$c0
1229: 85 16        DrawSpaces1     sta     ]count
122b: a5 06                        lda     char_horiz        ;save text position
122d: 48                           pha
122e: a5 07                        lda     char_vert
1230: 48                           pha
1231: a9 20        :Loop           lda     #‘ ’
1233: 20 a4 11                     jsr     DrawGlyph         ;draw space
1236: c6 16                        dec     ]count
1238: d0 f7                        bne     :Loop             ;not done, branch
123a: 68                           pla                       ;restore text position
123b: 85 07                        sta     char_vert
123d: 68                           pla
123e: 85 06                        sta     char_horiz
1240: 4c ef 11                     jmp     SetRowPtr         ;reset text pointer

                   ; 
                   ; Draws a blinking apple glyph for the input cursor.  Only updates the screen
                   ; when the state changes.
                   ; 
                   DrawBlinkingApple
1243: e6 17                        inc     blink_timer
1245: d0 02                        bne     :NoInc
1247: e6 18                        inc     blink_timer+1
1249: a5 18        :NoInc          lda     blink_timer+1
124b: c9 18                        cmp     #$18
124d: f0 05                        beq     :DrawApple
124f: c9 30                        cmp     #$30
1251: f0 1b                        beq     DrawSpace
1253: 60           :Return         rts

1254: a9 00        :DrawApple      lda     #$00
1256: c5 17                        cmp     blink_timer
1258: d0 f9                        bne     :Return
125a: a5 06                        lda     char_horiz
125c: 48                           pha
125d: a5 07                        lda     char_vert
125f: 48                           pha
1260: a9 00                        lda     #$00              ;solid apple glyph
1262: 20 a4 11     DoDrawGlyph     jsr     DrawGlyph
1265: 68                           pla                       ;restore previous position
1266: 85 07                        sta     char_vert
1268: 68                           pla
1269: 85 06                        sta     char_horiz
126b: 4c ef 11                     jmp     SetRowPtr

126e: a5 06        DrawSpace       lda     char_horiz        ;save position
1270: 48                           pha
1271: a5 07                        lda     char_vert
1273: 48                           pha
1274: a9 00                        lda     #$00              ;reset blink timer
1276: 85 17                        sta     blink_timer
1278: 85 18                        sta     blink_timer+1
127a: a9 20                        lda     #‘ ’              ;space character
127c: d0 e4                        bne     DoDrawGlyph       ;(always)

                   ; 
                   ; Clears the part of the screen covered by the maze (rows 0-20, columns 0-22).
                   ; 
                   ; Same effect as printing lots of spaces, but much faster.
                   ; 
                   • Clear variables
                   ]counter        .var    $19    {addr/1}

127e: a9 00        EraseMaze       lda     #0
1280: 85 06                        sta     char_horiz
1282: a9 14                        lda     #20
1284: 85 07                        sta     char_vert         ;start on row 20 (1 blank + 2 msg lines below)
1286: 20 ef 11     :ChunkLoop      jsr     SetRowPtr
1289: 18                           clc
128a: a9 08                        lda     #$08
128c: 85 19                        sta     ]counter
128e: a9 00        :Loop8          lda     #$00
1290: a0 16                        ldy     #22               ;start in column 22
1292: 91 08        :RowLoop        sta     (char_row_ptr),y  ;set to zero
1294: 88                           dey
1295: 10 fb                        bpl     :RowLoop
1297: a9 04                        lda     #$04              ;for each set of 8, we can incr high ptr by 4
1299: 65 09                        adc     char_row_ptr+1
129b: 85 09                        sta     char_row_ptr+1
129d: c6 19                        dec     ]counter          ;have we done 8 rows?
129f: d0 ed                        bne     :Loop8            ;not yet, loop
12a1: c6 07                        dec     char_vert         ;decrement vertical position
12a3: 10 e1                        bpl     :ChunkLoop        ;branch if >= 0
12a5: 60                           rts

                   ; 
                   ; Draws the visible maze walls with glyphs and horizontal lines, using the bit
                   ; flags in $6199/619a.
                   ; 
                   vis vis vis vis vis vis vis vis vis vis vis vis vis vis

                   vis vis vis vis vis vis vis vis vis vis vis vis vis vis

                   vis vis vis vis vis vis vis vis vis vis vis vis
12a6: ad 9a 61     DrawVisWalls    lda     maze_walls_rt
12a9: 4a                           lsr     A                 ;right-shift 5x to get distance to facing wall
12aa: 4a                           lsr     A
12ab: 4a                           lsr     A
12ac: 4a                           lsr     A
12ad: 4a                           lsr     A
12ae: 48                           pha                       ;push distance on stack
                   ; Start by drawing the horizontal lines at the top and bottom of the facing
                   ; wall, or just the "infinity" glyph.
12af: c9 05                        cmp     #$05              ;at "infinity"?
12b1: 90 10                        bcc     :ChkDst4          ;no, branch
12b3: a9 33                        lda     #$33              ;$4133 = row 80 col 11
12b5: 85 08                        sta     char_row_ptr
12b7: a9 41                        lda     #$41
12b9: 85 09                        sta     char_row_ptr+1
12bb: a9 05                        lda     #$05              ;'X' glyph, for "infinite" distance
12bd: 20 92 11                     jsr     PrintSpecialChar
12c0: 4c 5c 13                     jmp     :DrawLeft4

12c3: c9 04        :ChkDst4        cmp     #$04              ;4 squares away?
12c5: d0 19                        bne     :ChkDst3          ;no, branch
12c7: a9 32                        lda     #$32              ;$4132+1 = row 80 col 11
12c9: 85 08                        sta     char_row_ptr
12cb: a9 41                        lda     #$41
12cd: 85 09                        sta     char_row_ptr+1
12cf: a0 01                        ldy     #1                ;len=1
12d1: 20 77 17                     jsr     DrawLineHorizontal
12d4: a9 5d                        lda     #$5d              ;$5d32+1 = row 87 col 11
12d6: 85 09                        sta     char_row_ptr+1
12d8: a0 01                        ldy     #1
12da: 20 77 17                     jsr     DrawLineHorizontal
12dd: 4c 5c 13                     jmp     :DrawLeft4

12e0: c9 03        :ChkDst3        cmp     #$03              ;3 squares away?
12e2: d0 19                        bne     :ChkDst2          ;no, branch
12e4: a9 40                        lda     #$40              ;$40b1+1 = row 72 col 10
12e6: 85 09                        sta     char_row_ptr+1
12e8: a9 b1                        lda     #$b1
12ea: 85 08                        sta     char_row_ptr
12ec: a0 03                        ldy     #3                ;len=3
12ee: 20 77 17                     jsr     DrawLineHorizontal
12f1: a9 5d                        lda     #$5d              ;$5db1+1 = row 95 col 10
12f3: 85 09                        sta     char_row_ptr+1
12f5: a0 03                        ldy     #3
12f7: 20 77 17                     jsr     DrawLineHorizontal
12fa: 4c 30 14                     jmp     :DrawLeft3

12fd: c9 02        :ChkDst2        cmp     #$02              ;2 squares away?
12ff: d0 1d                        bne     :ChkDst1          ;no, branch
1301: a9 43                        lda     #$43              ;$4387+1 = row 56 col 8
1303: 85 09                        sta     char_row_ptr+1
1305: a9 87                        lda     #$87
1307: 85 08                        sta     char_row_ptr
1309: a0 07                        ldy     #7                ;len=7
130b: 20 77 17                     jsr     DrawLineHorizontal
130e: a9 5e                        lda     #$5e              ;$5eaf+1 = row 111 col 8
1310: 85 09                        sta     char_row_ptr+1
1312: a9 af                        lda     #$af
1314: 85 08                        sta     char_row_ptr
1316: a0 07                        ldy     #7
1318: 20 77 17                     jsr     DrawLineHorizontal
131b: 4c 18 15                     jmp     :DrawLeft2

131e: c9 01        :ChkDst1        cmp     #$01              ;1 square away?
1320: d0 1d                        bne     :CloseWall        ;no, branch
1322: a9 42                        lda     #$42              ;$4204+1 = row 32 col 5
1324: 85 09                        sta     char_row_ptr+1
1326: a9 04                        lda     #$04
1328: 85 08                        sta     char_row_ptr
132a: a0 0d                        ldy     #13               ;len=13
132c: 20 77 17                     jsr     DrawLineHorizontal
132f: a9 5c                        lda     #$5c              ;$5c54+1 = row 135 col 5
1331: 85 09                        sta     char_row_ptr+1
1333: a9 54                        lda     #$54
1335: 85 08                        sta     char_row_ptr
1337: a0 0d                        ldy     #13
1339: 20 77 17                     jsr     DrawLineHorizontal
133c: 4c 00 16                     jmp     :DrawLeft1

133f: a9 40        :CloseWall      lda     #$40              ;$4000+1 = row 0 col 1
1341: 85 09                        sta     char_row_ptr+1
1343: a9 00                        lda     #$00
1345: 85 08                        sta     char_row_ptr
1347: a0 15                        ldy     #21               ;len=21
1349: 20 77 17                     jsr     DrawLineHorizontal
134c: a9 5e                        lda     #$5e              ;$5e50+1 = row 167 col 1 (just above 3-line msg area)
134e: 85 09                        sta     char_row_ptr+1
1350: a9 50                        lda     #$50
1352: 85 08                        sta     char_row_ptr
1354: a0 15                        ldy     #21
1356: 20 77 17                     jsr     DrawLineHorizontal
1359: 4c e8 16                     jmp     :DrawCloseWalls

135c: ad 99 61     :DrawLeft4      lda     maze_walls_lf     ;check left wall
135f: 29 10                        and     #$10
1361: d0 39                        bne     :LeftWall4        ;left side is a wall, branch
                   ; Left side of cell at dist=4 is open, draw side hallway.
1363: 68                           pla                       ;get max view dist
1364: 48                           pha
1365: c9 04                        cmp     #$04              ;is there a facing wall at dist=4?
1367: f0 0d                        beq     :NotAtEnd4lo      ;no, branch
1369: a9 41                        lda     #$41              ;$4132 = row 80 col 10
136b: 85 09                        sta     char_row_ptr+1
136d: a9 32                        lda     #$32
136f: 85 08                        sta     char_row_ptr
1371: a9 04                        lda     #$04              ;vertical line, right edge
1373: 20 92 11                     jsr     PrintSpecialChar
1376: a9 41        :NotAtEnd4lo    lda     #$41              ;$4131+1 = row 80 col 10
1378: 85 09                        sta     char_row_ptr+1
137a: a9 31                        lda     #$31
137c: 85 08                        sta     char_row_ptr
137e: a0 01                        ldy     #1                ;len=1
1380: 20 77 17                     jsr     DrawLineHorizontal
1383: a9 5d                        lda     #$5d              ;$5d32 = row 87 col 10
1385: 85 09                        sta     char_row_ptr+1
1387: a0 01                        ldy     #1                ;len = 1
1389: 20 77 17                     jsr     DrawLineHorizontal
138c: a9 09                        lda     #9
138e: 85 06                        sta     char_horiz
1390: 85 07                        sta     char_vert
1392: a9 04                        lda     #$04              ;vertical line, right edge
1394: a0 03                        ldy     #3                ;len=3
1396: 20 a7 17                     jsr     DrawGlyphsDown
1399: 4c c5 13                     jmp     :DrawRight4

                   ; Left side of cell at dist=4 is wall, draw wall.
139c: 68           :LeftWall4      pla                       ;get max view dist
139d: 48                           pha
139e: c9 04                        cmp     #$04              ;is there a facing wall at dist=4?
13a0: d0 0d                        bne     :NotAtEnd4lw      ;no, branch
13a2: a9 41                        lda     #$41              ;$4132 = row 80 col 10
13a4: 85 09                        sta     char_row_ptr+1
13a6: a9 32                        lda     #$32
13a8: 85 08                        sta     char_row_ptr
13aa: a9 04                        lda     #$04              ;vertical line, right edge
13ac: 20 92 11                     jsr     PrintSpecialChar
13af: a9 0a        :NotAtEnd4lw    lda     #10
13b1: 85 06                        sta     char_horiz
13b3: a9 09                        lda     #9
13b5: 85 07                        sta     char_vert
13b7: a0 01                        ldy     #1                ;len=1
13b9: 20 95 17                     jsr     DrawDiagDownRight ;draw diagonal lines
13bc: c6 06                        dec     char_horiz
13be: e6 07                        inc     char_vert
13c0: a0 01                        ldy     #$01
13c2: 20 7f 17                     jsr     DrawDiagDownLeft
                   ; 
13c5: ad 9a 61     :DrawRight4     lda     maze_walls_rt     ;check right wall
13c8: 29 10                        and     #$10
13ca: d0 3b                        bne     :RightWall4       ;right side is a wall, branch
                   ; Right side of cell at dist=4 is open, draw side hallway.
13cc: 68                           pla                       ;get max view dist
13cd: 48                           pha
13ce: c9 04                        cmp     #$04              ;is there a facing wall at dist=4?
13d0: f0 0d                        beq     :NotAtEnd4ro      ;no, branch
13d2: a9 41                        lda     #$41              ;$4134 = row 80 col 12
13d4: 85 09                        sta     char_row_ptr+1
13d6: a9 34                        lda     #$34
13d8: 85 08                        sta     char_row_ptr
13da: a9 03                        lda     #$03              ;vertical line, left edge
13dc: 20 92 11                     jsr     PrintSpecialChar
13df: a9 41        :NotAtEnd4ro    lda     #$41              ;$4133+1 = row 80 col 12
13e1: 85 09                        sta     char_row_ptr+1
13e3: a9 33                        lda     #$33
13e5: 85 08                        sta     char_row_ptr
13e7: a0 01                        ldy     #1                ;len=1
13e9: 20 77 17                     jsr     DrawLineHorizontal
13ec: a9 5d                        lda     #$5d              ;$5d33+1 = row 87 col 12
13ee: 85 09                        sta     char_row_ptr+1
13f0: a0 01                        ldy     #1                ;len = 1
13f2: 20 77 17                     jsr     DrawLineHorizontal
13f5: a9 0d                        lda     #13
13f7: 85 06                        sta     char_horiz
13f9: a9 09                        lda     #9
13fb: 85 07                        sta     char_vert
13fd: a9 03                        lda     #$03              ;vertical line, left edge
13ff: a0 03                        ldy     #3
1401: 20 a7 17                     jsr     DrawGlyphsDown
1404: 4c 30 14                     jmp     :DrawLeft3

                   ; Left side of cell at dist=4 is wall, draw wall.
1407: 68           :RightWall4     pla                       ;get max view dist
1408: 48                           pha
1409: c9 04                        cmp     #$04              ;is there a facing wall at dist=4?
140b: d0 0d                        bne     :NotAtEnd4rw      ;no, branch
140d: a9 41                        lda     #$41              ;$4134 = row 80 col 12
140f: 85 09                        sta     char_row_ptr+1
1411: a9 34                        lda     #$34
1413: 85 08                        sta     char_row_ptr
1415: a9 03                        lda     #$03              ;vertical line, left edge
1417: 20 92 11                     jsr     PrintSpecialChar
141a: a9 0c        :NotAtEnd4rw    lda     #12
141c: 85 06                        sta     char_horiz
141e: a9 09                        lda     #9
1420: 85 07                        sta     char_vert
1422: a0 01                        ldy     #1
1424: 20 7f 17                     jsr     DrawDiagDownLeft  ;draw diagonal lines
1427: e6 06                        inc     char_horiz
1429: e6 07                        inc     char_vert
142b: a0 01                        ldy     #1
142d: 20 95 17                     jsr     DrawDiagDownRight
                   ; 
                   ; Repeat the process for the cell at dist=3.
                   ; 
1430: ad 99 61     :DrawLeft3      lda     maze_walls_lf
1433: 29 08                        and     #$08
1435: d0 3d                        bne     L1474
1437: 68                           pla
1438: 48                           pha
1439: c9 03                        cmp     #$03
143b: f0 0d                        beq     L144A
143d: a9 09                        lda     #$09
143f: 85 06                        sta     char_horiz
1441: 85 07                        sta     char_vert
1443: a9 04                        lda     #$04
1445: a0 03                        ldy     #$03
1447: 20 a7 17                     jsr     DrawGlyphsDown
144a: a9 40        L144A           lda     #$40
144c: 85 09                        sta     char_row_ptr+1
144e: a9 af                        lda     #$af
1450: 85 08                        sta     char_row_ptr
1452: a0 02                        ldy     #$02
1454: 20 77 17                     jsr     DrawLineHorizontal
1457: a9 5d                        lda     #$5d
1459: 85 09                        sta     char_row_ptr+1
145b: a9 af                        lda     #$af
145d: 85 08                        sta     char_row_ptr
145f: a0 02                        ldy     #$02
1461: 20 77 17                     jsr     DrawLineHorizontal
1464: a9 07                        lda     #$07
1466: 85 06                        sta     char_horiz
1468: 85 07                        sta     char_vert
146a: a9 04                        lda     #$04
146c: a0 07                        ldy     #$07
146e: 20 a7 17                     jsr     DrawGlyphsDown
1471: 4c a1 14                     jmp     :DrawRight3

1474: 68           L1474           pla
1475: 48                           pha
1476: c9 03                        cmp     #$03
1478: d0 0d                        bne     L1487
147a: a9 09                        lda     #$09
147c: 85 06                        sta     char_horiz
147e: 85 07                        sta     char_vert
1480: a9 04                        lda     #$04
1482: a0 03                        ldy     #$03
1484: 20 a7 17                     jsr     DrawGlyphsDown
1487: a9 08        L1487           lda     #$08
1489: 85 06                        sta     char_horiz
148b: a9 07                        lda     #$07
148d: 85 07                        sta     char_vert
148f: a0 02                        ldy     #$02
1491: 20 95 17                     jsr     DrawDiagDownRight
1494: a9 09                        lda     #$09
1496: 85 06                        sta     char_horiz
1498: a9 0c                        lda     #$0c
149a: 85 07                        sta     char_vert
149c: a0 02                        ldy     #$02
149e: 20 7f 17                     jsr     DrawDiagDownLeft
                   ; 
14a1: ad 9a 61     :DrawRight3     lda     maze_walls_rt
14a4: 29 08                        and     #$08
14a6: d0 41                        bne     L14E9
14a8: 68                           pla
14a9: 48                           pha
14aa: c9 03                        cmp     #$03
14ac: f0 0f                        beq     L14BD
14ae: a9 0d                        lda     #$0d
14b0: 85 06                        sta     char_horiz
14b2: a9 09                        lda     #$09
14b4: 85 07                        sta     char_vert
14b6: a9 03                        lda     #$03
14b8: a0 03                        ldy     #$03
14ba: 20 a7 17                     jsr     DrawGlyphsDown
14bd: a9 40        L14BD           lda     #$40
14bf: 85 09                        sta     char_row_ptr+1
14c1: a9 b4                        lda     #$b4
14c3: 85 08                        sta     char_row_ptr
14c5: a0 02                        ldy     #$02
14c7: 20 77 17                     jsr     DrawLineHorizontal
14ca: a9 5d                        lda     #$5d
14cc: 85 09                        sta     char_row_ptr+1
14ce: a9 b4                        lda     #$b4
14d0: 85 08                        sta     char_row_ptr
14d2: a0 02                        ldy     #$02
14d4: 20 77 17                     jsr     DrawLineHorizontal
14d7: a9 0f                        lda     #$0f
14d9: 85 06                        sta     char_horiz
14db: a9 07                        lda     #$07
14dd: 85 07                        sta     char_vert
14df: a9 03                        lda     #$03
14e1: a0 07                        ldy     #$07
14e3: 20 a7 17                     jsr     DrawGlyphsDown
14e6: 4c 18 15                     jmp     :DrawLeft2

14e9: 68           L14E9           pla
14ea: 48                           pha
14eb: c9 03                        cmp     #$03
14ed: d0 0f                        bne     L14FE
14ef: a9 0d                        lda     #$0d
14f1: 85 06                        sta     char_horiz
14f3: a9 09                        lda     #$09
14f5: 85 07                        sta     char_vert
14f7: a9 03                        lda     #$03
14f9: a0 03                        ldy     #$03
14fb: 20 a7 17                     jsr     DrawGlyphsDown
14fe: a9 0e        L14FE           lda     #$0e
1500: 85 06                        sta     char_horiz
1502: a9 07                        lda     #$07
1504: 85 07                        sta     char_vert
1506: a0 02                        ldy     #$02
1508: 20 7f 17                     jsr     DrawDiagDownLeft
150b: a9 0d                        lda     #$0d
150d: 85 06                        sta     char_horiz
150f: a9 0c                        lda     #$0c
1511: 85 07                        sta     char_vert
1513: a0 02                        ldy     #$02
1515: 20 95 17                     jsr     DrawDiagDownRight
                   ; 
                   ; Repeat the process for the cell at dist=2.
                   ; 
1518: ad 99 61     :DrawLeft2      lda     maze_walls_lf
151b: 29 04                        and     #$04
151d: d0 3d                        bne     L155C
151f: 68                           pla
1520: 48                           pha
1521: c9 02                        cmp     #$02
1523: f0 0d                        beq     L1532
1525: a9 07                        lda     #$07
1527: 85 06                        sta     char_horiz
1529: 85 07                        sta     char_vert
152b: a9 04                        lda     #$04
152d: a0 07                        ldy     #$07
152f: 20 a7 17                     jsr     DrawGlyphsDown
1532: a9 43        L1532           lda     #$43
1534: 85 09                        sta     char_row_ptr+1
1536: a9 84                        lda     #$84
1538: 85 08                        sta     char_row_ptr
153a: a0 03                        ldy     #$03
153c: 20 77 17                     jsr     DrawLineHorizontal
153f: a9 5e                        lda     #$5e
1541: 85 09                        sta     char_row_ptr+1
1543: a9 ac                        lda     #$ac
1545: 85 08                        sta     char_row_ptr
1547: a0 03                        ldy     #$03
1549: 20 77 17                     jsr     DrawLineHorizontal
154c: a9 04                        lda     #$04
154e: 85 06                        sta     char_horiz
1550: 85 07                        sta     char_vert
1552: a9 04                        lda     #$04
1554: a0 0d                        ldy     #$0d
1556: 20 a7 17                     jsr     DrawGlyphsDown
1559: 4c 89 15                     jmp     :DrawRight2

155c: 68           L155C           pla
155d: 48                           pha
155e: c9 02                        cmp     #$02
1560: d0 0d                        bne     L156F
1562: a9 07                        lda     #$07
1564: 85 06                        sta     char_horiz
1566: 85 07                        sta     char_vert
1568: a9 04                        lda     #$04
156a: a0 07                        ldy     #$07
156c: 20 a7 17                     jsr     DrawGlyphsDown
156f: a9 05        L156F           lda     #$05
1571: 85 06                        sta     char_horiz
1573: a9 04                        lda     #$04
1575: 85 07                        sta     char_vert
1577: a0 03                        ldy     #$03
1579: 20 95 17                     jsr     DrawDiagDownRight
157c: a9 07                        lda     #$07
157e: 85 06                        sta     char_horiz
1580: a9 0e                        lda     #$0e
1582: 85 07                        sta     char_vert
1584: a0 03                        ldy     #$03
1586: 20 7f 17                     jsr     DrawDiagDownLeft
                   ; 
1589: ad 9a 61     :DrawRight2     lda     maze_walls_rt
158c: 29 04                        and     #$04
158e: d0 41                        bne     L15D1
1590: 68                           pla
1591: 48                           pha
1592: c9 02                        cmp     #$02
1594: f0 0f                        beq     L15A5
1596: a9 0f                        lda     #$0f
1598: 85 06                        sta     char_horiz
159a: a9 07                        lda     #$07
159c: 85 07                        sta     char_vert
159e: a9 03                        lda     #$03
15a0: a0 07                        ldy     #$07
15a2: 20 a7 17                     jsr     DrawGlyphsDown
15a5: a9 43        L15A5           lda     #$43
15a7: 85 09                        sta     char_row_ptr+1
15a9: a9 8e                        lda     #$8e
15ab: 85 08                        sta     char_row_ptr
15ad: a0 03                        ldy     #$03
15af: 20 77 17                     jsr     DrawLineHorizontal
15b2: a9 5e                        lda     #$5e
15b4: 85 09                        sta     char_row_ptr+1
15b6: a9 b6                        lda     #$b6
15b8: 85 08                        sta     char_row_ptr
15ba: a0 03                        ldy     #$03
15bc: 20 77 17                     jsr     DrawLineHorizontal
15bf: a9 12                        lda     #$12
15c1: 85 06                        sta     char_horiz
15c3: a9 04                        lda     #$04
15c5: 85 07                        sta     char_vert
15c7: a9 03                        lda     #$03
15c9: a0 0d                        ldy     #$0d
15cb: 20 a7 17                     jsr     DrawGlyphsDown
15ce: 4c 00 16                     jmp     :DrawLeft1

15d1: 68           L15D1           pla
15d2: 48                           pha
15d3: c9 02                        cmp     #$02
15d5: d0 0f                        bne     L15E6
15d7: a9 0f                        lda     #$0f
15d9: 85 06                        sta     char_horiz
15db: a9 07                        lda     #$07
15dd: 85 07                        sta     char_vert
15df: a9 03                        lda     #$03
15e1: a0 07                        ldy     #$07
15e3: 20 a7 17                     jsr     DrawGlyphsDown
15e6: a9 11        L15E6           lda     #$11
15e8: 85 06                        sta     char_horiz
15ea: a9 04                        lda     #$04
15ec: 85 07                        sta     char_vert
15ee: a0 03                        ldy     #$03
15f0: 20 7f 17                     jsr     DrawDiagDownLeft
15f3: a9 0f                        lda     #$0f
15f5: 85 06                        sta     char_horiz
15f7: a9 0e                        lda     #$0e
15f9: 85 07                        sta     char_vert
15fb: a0 03                        ldy     #$03
15fd: 20 95 17                     jsr     DrawDiagDownRight
                   ; 
                   ; Repeat the process for the cell at dist=1.
                   ; 
1600: ad 99 61     :DrawLeft1      lda     maze_walls_lf
1603: 29 02                        and     #$02
1605: d0 3d                        bne     L1644
1607: 68                           pla
1608: 48                           pha
1609: c9 01                        cmp     #$01
160b: f0 0d                        beq     L161A
160d: a9 04                        lda     #$04
160f: 85 06                        sta     char_horiz
1611: 85 07                        sta     char_vert
1613: a9 04                        lda     #$04
1615: a0 0d                        ldy     #$0d
1617: 20 a7 17                     jsr     DrawGlyphsDown
161a: a9 42        L161A           lda     #$42
161c: 85 09                        sta     char_row_ptr+1
161e: a9 00                        lda     #$00
1620: 85 08                        sta     char_row_ptr
1622: a0 04                        ldy     #$04
1624: 20 77 17                     jsr     DrawLineHorizontal
1627: a9 5c                        lda     #$5c
1629: 85 09                        sta     char_row_ptr+1
162b: a9 50                        lda     #$50
162d: 85 08                        sta     char_row_ptr
162f: a0 04                        ldy     #$04
1631: 20 77 17                     jsr     DrawLineHorizontal
1634: a9 00                        lda     #$00
1636: 85 06                        sta     char_horiz
1638: 85 07                        sta     char_vert
163a: a9 04                        lda     #$04
163c: a0 15                        ldy     #$15
163e: 20 a7 17                     jsr     DrawGlyphsDown
1641: 4c 71 16                     jmp     :DrawRight1

1644: 68           L1644           pla
1645: 48                           pha
1646: c9 01                        cmp     #$01
1648: d0 0d                        bne     L1657
164a: a9 04                        lda     #$04
164c: 85 06                        sta     char_horiz
164e: 85 07                        sta     char_vert
1650: a9 04                        lda     #$04
1652: a0 0d                        ldy     #$0d
1654: 20 a7 17                     jsr     DrawGlyphsDown
1657: a9 01        L1657           lda     #$01
1659: 85 06                        sta     char_horiz
165b: a9 00                        lda     #$00
165d: 85 07                        sta     char_vert
165f: a0 04                        ldy     #$04
1661: 20 95 17                     jsr     DrawDiagDownRight
1664: a9 04                        lda     #$04
1666: 85 06                        sta     char_horiz
1668: a9 11                        lda     #$11
166a: 85 07                        sta     char_vert
166c: a0 04                        ldy     #$04
166e: 20 7f 17                     jsr     DrawDiagDownLeft
                   ; 
1671: ad 9a 61     :DrawRight1     lda     maze_walls_rt
1674: 29 02                        and     #$02
1676: d0 41                        bne     L16B9
1678: 68                           pla
1679: 48                           pha
167a: c9 01                        cmp     #$01
167c: f0 0f                        beq     L168D
167e: a9 12                        lda     #$12
1680: 85 06                        sta     char_horiz
1682: a9 04                        lda     #$04
1684: 85 07                        sta     char_vert
1686: a9 03                        lda     #$03
1688: a0 0d                        ldy     #$0d
168a: 20 a7 17                     jsr     DrawGlyphsDown
168d: a9 42        L168D           lda     #$42
168f: 85 09                        sta     char_row_ptr+1
1691: a9 11                        lda     #$11
1693: 85 08                        sta     char_row_ptr
1695: a0 04                        ldy     #$04
1697: 20 77 17                     jsr     DrawLineHorizontal
169a: a9 5c                        lda     #$5c
169c: 85 09                        sta     char_row_ptr+1
169e: a9 61                        lda     #$61
16a0: 85 08                        sta     char_row_ptr
16a2: a0 04                        ldy     #$04
16a4: 20 77 17                     jsr     DrawLineHorizontal
16a7: a9 16                        lda     #$16
16a9: 85 06                        sta     char_horiz
16ab: a9 00                        lda     #$00
16ad: 85 07                        sta     char_vert
16af: a9 03                        lda     #$03
16b1: a0 15                        ldy     #$15
16b3: 20 a7 17                     jsr     DrawGlyphsDown
16b6: 4c e8 16                     jmp     :DrawCloseWalls

16b9: 68           L16B9           pla
16ba: 48                           pha
16bb: c9 01                        cmp     #$01
16bd: d0 0f                        bne     L16CE
16bf: a9 12                        lda     #$12
16c1: 85 06                        sta     char_horiz
16c3: a9 04                        lda     #$04
16c5: 85 07                        sta     char_vert
16c7: a9 03                        lda     #$03
16c9: a0 0d                        ldy     #$0d
16cb: 20 a7 17                     jsr     DrawGlyphsDown
16ce: a9 15        L16CE           lda     #$15
16d0: 85 06                        sta     char_horiz
16d2: a9 00                        lda     #$00
16d4: 85 07                        sta     char_vert
16d6: a0 04                        ldy     #$04
16d8: 20 7f 17                     jsr     DrawDiagDownLeft
16db: a9 12                        lda     #$12
16dd: 85 06                        sta     char_horiz
16df: a9 11                        lda     #$11
16e1: 85 07                        sta     char_vert
16e3: a0 04                        ldy     #$04
16e5: 20 95 17                     jsr     DrawDiagDownRight
                   ; 
                   ; Draw a little bit of the viewer's cell.  The horizontal lines at the top and
                   ; bottom were already drawn.
                   ; 
16e8: 68           :DrawCloseWalls pla                       ;get max view dist
16e9: c9 00                        cmp     #$00              ;are we right up against a wall?
16eb: f0 5f                        beq     :NoseToWall       ;yes, branch
                   ; We're not flush with the wall, so either there's a wall to the side (which we
                   ; ignore since the diagonal has already reached the top/bottom of the screen),
                   ; or there's a hallway there, which we want to draw as a vertical line to show
                   ; the corner.
16ed: ad 99 61                     lda     maze_walls_lf     ;check left side
16f0: 29 01                        and     #$01
16f2: d0 27                        bne     :LeftWall0        ;it's a wall, skip it
                   ; Right side of current cell is open, draw hallway.
16f4: a9 00                        lda     #0                ;top-left corner
16f6: 85 06                        sta     char_horiz
16f8: 85 07                        sta     char_vert
16fa: a9 04                        lda     #$04              ;vertical line, right edge
16fc: a0 15                        ldy     #21               ;full height of maze area
16fe: 20 a7 17                     jsr     DrawGlyphsDown
1701: a9 3f                        lda     #$3f              ;$3fff+1 = row 0 col 0
1703: 85 09                        sta     char_row_ptr+1
1705: a9 ff                        lda     #$ff
1707: 85 08                        sta     char_row_ptr
1709: a0 01                        ldy     #1                ;len=1
170b: 20 77 17                     jsr     DrawLineHorizontal
170e: a9 5e                        lda     #$5e              ;$5e4f+1 = row 167 col 0
1710: 85 09                        sta     char_row_ptr+1
1712: a9 4f                        lda     #$4f
1714: 85 08                        sta     char_row_ptr
1716: a0 01                        ldy     #1                ;len=1
1718: 20 77 17                     jsr     DrawLineHorizontal
171b: ad 9a 61     :LeftWall0      lda     maze_walls_rt     ;check right side
171e: 29 01                        and     #$01
1720: d0 29                        bne     :Return           ;it's a wall, we're done
1722: a9 16                        lda     #22               ;top-right corner
1724: 85 06                        sta     char_horiz
1726: a9 00                        lda     #$00
1728: 85 07                        sta     char_vert
172a: a9 03                        lda     #$03              ;vertical line, left edge
172c: a0 15                        ldy     #21               ;full height of maze area
172e: 20 a7 17                     jsr     DrawGlyphsDown
1731: a9 40                        lda     #$40              ;$4015+1 = row 0 col 22
1733: 85 09                        sta     char_row_ptr+1
1735: a9 15                        lda     #$15
1737: 85 08                        sta     char_row_ptr
1739: a0 01                        ldy     #1                ;len=1
173b: 20 77 17                     jsr     DrawLineHorizontal
173e: a9 5e                        lda     #$5e              ;$5e65+1 = row 167 col 22
1740: 85 09                        sta     char_row_ptr+1
1742: a9 65                        lda     #$65
1744: 85 08                        sta     char_row_ptr
1746: a0 01                        ldy     #1                ;len=1
1748: 20 77 17                     jsr     DrawLineHorizontal
174b: 60           :Return         rts

                   ; We're flush with the facing wall.  Draw a rectangle, leaving left/right open
                   ; if there's a hallway there.
174c: ad 99 61     :NoseToWall     lda     maze_walls_lf     ;check left edge
174f: 29 01                        and     #$01
1751: f0 0d                        beq     :NoseNoLeft       ;no wall, branch
1753: a9 00                        lda     #0                ;top-left corner
1755: 85 06                        sta     char_horiz
1757: 85 07                        sta     char_vert
1759: a9 04                        lda     #$04              ;vertical line, right edge of glyph
175b: a0 15                        ldy     #21               ;full height of maze area
175d: 20 a7 17                     jsr     DrawGlyphsDown
1760: ad 9a 61     :NoseNoLeft     lda     maze_walls_rt     ;check right edge
1763: 29 01                        and     #$01
1765: f0 e4                        beq     :Return           ;no wall, we're done
1767: a9 16                        lda     #22               ;top-right corner
1769: 85 06                        sta     char_horiz
176b: a9 00                        lda     #0
176d: 85 07                        sta     char_vert
176f: a9 03                        lda     #$03              ;vertical line, left edge of glyph
1771: a0 15                        ldy     #21               ;full height of maze area
1773: 20 a7 17                     jsr     DrawGlyphsDown
1776: 60                           rts

                   ; 
                   ; Draws a white horizontal line.  The Y-reg holds the number of segments.
                   ; 
                   ; Note the location pointed to is NOT drawn to.  If the address is $4000, and Y-
                   ; reg is 8, addresses $4001-4008 will be written to.
                   ; 
                   ; On entry:
                   ;   $08-09: pointer to address on hi-res screen
                   ;   Y-reg: number of 7-pixel segments to draw
                   ; 
                   DrawLineHorizontal
1777: a9 ff                        lda     #$ff              ;solid white line (with high bit set)
1779: 91 08        :Loop           sta     (char_row_ptr),y
177b: 88                           dey
177c: d0 fb                        bne     :Loop
177e: 60                           rts

                   ; 
                   ; Draws a diagonal line with glyphs, down and to the left.
                   ; 
                   ; On entry:
                   ;   $06: horizontal position (0-39)
                   ;   $07: vertical position (0-23)
                   ;   Y-reg: number of iterations
                   ; 
                   ]counter        .var    $1a    {addr/1}

                   DrawDiagDownLeft
177f: 98                           tya                       ;(why?)
1780: 85 1a                        sta     ]counter          ;set number of iterations
1782: 20 ef 11     :Loop           jsr     SetRowPtr         ;set hi-res pointer
1785: a9 02                        lda     #$02              ;line segment, looks like forward slash
1787: 20 92 11                     jsr     PrintSpecialChar  ;draw glyph, move right
178a: c6 06                        dec     char_horiz        ;return to initial horizontal position
178c: c6 06                        dec     char_horiz        ;back up one
178e: e6 07                        inc     char_vert         ;move down one line
1790: c6 1a                        dec     ]counter          ;done yet?
1792: d0 ee                        bne     :Loop             ;no, loop
1794: 60                           rts

                   ; 
                   ; Draws a diagonal line with glyphs, down and to the right.
                   ; 
                   ; On entry:
                   ;   $06: horizontal position (0-39)
                   ;   $07: vertical position (0-23)
                   ;   Y-reg: number of iterations
                   ; 
                   DrawDiagDownRight
1795: 98                           tya                       ;(why?)
1796: 85 1a                        sta     ]counter          ;set number of iterations
1798: 20 ef 11     :Loop           jsr     SetRowPtr         ;set hi-res pointer
179b: a9 01                        lda     #$01              ;line segment, looks like backslash
179d: 20 92 11                     jsr     PrintSpecialChar  ;draw glyph, move right
17a0: e6 07                        inc     char_vert         ;move down one line
17a2: c6 1a                        dec     ]counter          ;done yet?
17a4: d0 f2                        bne     :Loop             ;no, loop
17a6: 60                           rts

                   ; 
                   ; Draws the same character multiple times, moving down one line each time.  Set
                   ; the initial horizontal/vertical text position before calling.  Can be used to
                   ; draw a vertical line.
                   ; 
                   ; On entry:
                   ;   $06: horizontal position (0-39)
                   ;   $07: vertical position (0-23)
                   ;   A-reg: glyph index to draw
                   ;   Y-reg: number of times to draw
                   ; 
17a7: 48           DrawGlyphsDown  pha                       ;push char index
17a8: 98                           tya                       ;(why?)
17a9: 85 1a                        sta     ]counter          ;save counter in $1a
17ab: 68                           pla                       ;pull char index
17ac: 48           :Loop           pha                       ;push char index
17ad: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer for current text posn
17b0: 68                           pla                       ;pull char index
17b1: 48                           pha                       ;push char index
17b2: 20 a4 11                     jsr     DrawGlyph         ;draw glyph, move right
17b5: 68                           pla                       ;pull char index
17b6: c6 06                        dec     char_horiz        ;return to original horizontal position
17b8: e6 07                        inc     char_vert         ;increment vertical position
17ba: c6 1a                        dec     ]counter          ;done yet?
17bc: d0 ee                        bne     :Loop             ;no, loop
17be: 60                           rts

                   ; 
                   ; Walks through the maze wall data to determine what the corridor ahead looks
                   ; like.  Sets values for the distance to the opposite wall (1-5, where 5 is
                   ; "infinity"), and bit flags for the left and right walls for five cells,
                   ; starting with the one the player is standing in.
                   ; 
                   ; Because of limitations placed on the maze structure, e.g. there are no 2x2
                   ; rooms, this is sufficient information to draw the scene.
                   ; 
                   ; On exit:
                   ;   $6199 and $619a hold the results
                   ; 
                   • Clear variables
                   ]maze_ptr       .var    $0a    {addr/2}

                   ProcessMazeWalls
17bf: a0 00                        ldy     #$00
17c1: a9 00                        lda     #<maze_wall_data
17c3: 85 0a                        sta     ]maze_ptr
17c5: a9 60                        lda     #>maze_wall_data
17c7: 85 0b                        sta     ]maze_ptr+1
                   ; Find the start of the wall data for the current floor.
17c9: ae 94 61                     ldx     plyr_floor
17cc: a9 00                        lda     #$00
17ce: 18                           clc
17cf: ca           :Loop           dex
17d0: f0 05                        beq     :GotFloor
17d2: 69 21                        adc     #$21              ;each floor is 33 bytes
17d4: 4c cf 17                     jmp     :Loop

17d7: 65 0a        :GotFloor       adc     ]maze_ptr         ;add to pointer
17d9: 85 0a                        sta     ]maze_ptr
                   ; Find the offset and bit mask for the current cell.  The maze floor data uses
                   ; two bits per cell (south and west walls).  The mask is set for the south-wall
                   ; bit; shift once to the right for the west-wall bit.
17db: ae 95 61                     ldx     plyr_xpos
17de: ca           :XLoop          dex
17df: f0 09                        beq     :GotX
17e1: e6 0a                        inc     ]maze_ptr
17e3: e6 0a                        inc     ]maze_ptr
17e5: e6 0a                        inc     ]maze_ptr
17e7: 4c de 17                     jmp     :XLoop

17ea: ad 96 61     :GotX           lda     plyr_ypos
17ed: c9 05                        cmp     #$05              ;1-4?
17ef: 30 0e                        bmi     :YPos04           ;yes, branch
17f1: c9 09                        cmp     #$09              ;5-8?
17f3: 30 05                        bmi     :YPos58           ;yes, branch
17f5: e6 0a                        inc     ]maze_ptr         ;no, 9-12; ptr++
17f7: 38                           sec
17f8: e9 04                        sbc     #$04              ;Ypos -= 4 (now 5-8)
17fa: e6 0a        :YPos58         inc     ]maze_ptr         ;ptr++
17fc: 38                           sec
17fd: e9 04                        sbc     #$04              ;Ypos -= 4 (now 1-4)
17ff: aa           :YPos04         tax                       ;save in X-reg as shift count
1800: a9 80                        lda     #$80              ;set bit 7 (Y-coord=1 is two high bits)
1802: ca           :YLoop          dex                       ;count it down
1803: f0 05                        beq     :GotY
1805: 4a                           lsr     A                 ;$80/$20/$08/$04 for 1-4
1806: 4a                           lsr     A
1807: 4c 02 18                     jmp     :YLoop

                   ]dist_ctr       .var    $11    {addr/1}
                   ]end_dist       .var    $19    {addr/1}
                   ]bit_mask       .var    $1a    {addr/1}

180a: 85 1a        :GotY           sta     ]bit_mask
180c: 86 19                        stx     ]end_dist         ;init values to zero (X-reg=0)
180e: 86 11                        stx     ]dist_ctr
1810: 8e 99 61                     stx     maze_walls_lf
1813: 8e 9a 61                     stx     maze_walls_rt
                   ; Execute different code for each of the 4 directions.
1816: ae 93 61                     ldx     plyr_facing       ;1=W, 2=N, 3=E, 4=S
1819: ca                           dex
181a: d0 03                        bne     :ChkNorth
181c: 4c 10 19                     jmp     :FaceWest

181f: ca           :ChkNorth       dex
1820: d0 03                        bne     :ChkEast
1822: 4c 7c 19                     jmp     :FaceNorth

1825: ca           :ChkEast        dex
1826: f0 7f                        beq     :FaceEast
                   ; 
                   ; Handle south-facing player.  Start by finding the next perpendicular wall. 
                   ; Keep looking until we hit a wall or reach maximum distance.
                   ; 
                   ; The maze data guarantees that we will hit a wall eventually, so we don't need
                   ; to step carefully around the edge of the maze.
                   ; 
1828: b1 0a        :FaceSouth      lda     (]maze_ptr),y     ;get current cell
182a: 25 1a                        and     ]bit_mask         ;south wall here?
182c: d0 1e                        bne     :SFoundSouth      ;yes, branch
182e: e6 19                        inc     ]end_dist         ;no, increment end distance
1830: a5 19                        lda     ]end_dist
1832: c9 05                        cmp     #$05              ;have we reached max?
1834: f0 16                        beq     :SFoundSouth      ;yes, branch
                   ; Move to the next cell to the south.
1836: a5 1a                        lda     ]bit_mask
1838: c9 80                        cmp     #$80              ;at the end of the byte?
183a: d0 09                        bne     :SNotHighBit      ;not yet, branch
183c: c6 0a                        dec     ]maze_ptr         ;yes, decrement pointer
183e: a9 02                        lda     #$02
1840: 85 1a                        sta     ]bit_mask         ;reset mask
1842: 4c 28 18                     jmp     :FaceSouth

1845: 06 1a        :SNotHighBit    asl     ]bit_mask         ;left-shift twice to move south
1847: 06 1a                        asl     ]bit_mask
1849: 4c 28 18                     jmp     :FaceSouth

                   ; We found a wall on the south side of a cell.  We want to shift the mask from
                   ; testing the south wall ($80/20/08/02) to the west wall ($40/10/04/01).
                   ; 
                   ; Note we're walking from the farthest point back toward the viewer.  Thus, the
                   ; last thing we test will always end up in the low bit of the left/right masks,
                   ; even if we stop early.
184c: a5 19        :SFoundSouth    lda     ]end_dist         ;get distance to end point
184e: 20 10 1a                     jsr     SwapEndDist       ;do fancy swap maneuver
1851: 46 1a                        lsr     ]bit_mask         ;right shift to mask west wall bit
1853: b1 0a        :SSideLoop      lda     (]maze_ptr),y     ;get maze data
1855: 25 1a                        and     ]bit_mask         ;mask west wall bit
1857: f0 03                        beq     :SNotSet1
1859: ee 9a 61                     inc     maze_walls_rt     ;set low bit
185c: a0 03        :SNotSet1       ldy     #$03              ;index over to next column (to east)
185e: b1 0a                        lda     (]maze_ptr),y     ;get wall data there
1860: a0 00                        ldy     #$00              ;reset Y-reg
1862: 25 1a                        and     ]bit_mask         ;get west wall bit
1864: f0 03                        beq     :SNotSet2         ;not set, branch
1866: ee 99 61                     inc     maze_walls_lf     ;set low bit
1869: 20 10 1a     :SNotSet2       jsr     SwapEndDist       ;swap back (A-reg = end_dist)
186c: c5 11                        cmp     ]dist_ctr         ;have we reached the end?
186e: f0 2a                        beq     :Finish           ;yes, finish up
1870: 20 10 1a                     jsr     SwapEndDist       ;no, swap end dist back out
1873: a9 04                        lda     #$04
1875: c5 11                        cmp     ]dist_ctr         ;have we done the nearest 4 walls?
1877: f0 1e                        beq     :FinishSwap       ;yes, finish up
1879: 0e 99 61                     asl     maze_walls_lf     ;shift result bits to make room
187c: 0e 9a 61                     asl     maze_walls_rt
187f: e6 11                        inc     ]dist_ctr
                   ; Move to the next cell to the north.
1881: a5 1a                        lda     ]bit_mask
1883: c9 01                        cmp     #$01              ;at the end of the byte?
1885: f0 07                        beq     :SNextByte        ;yes, branch
1887: 46 1a                        lsr     ]bit_mask         ;right-shift twice to move north
1889: 46 1a                        lsr     ]bit_mask
188b: 4c 53 18                     jmp     :SSideLoop

188e: a9 40        :SNextByte      lda     #$40
1890: 85 1a                        sta     ]bit_mask         ;reset mask
1892: e6 0a                        inc     ]maze_ptr         ;move to next byte in column
1894: 4c 53 18                     jmp     :SSideLoop

                   ; 
                   ; Finish up by merging the end distance with the right wall mask.  Used for all
                   ; four directions.
                   ; 
1897: 20 10 1a     :FinishSwap     jsr     SwapEndDist       ;swap end distance back in
189a: 0a           :Finish         asl     A                 ;shift it left 5x
189b: 0a                           asl     A
189c: 0a                           asl     A
189d: 0a                           asl     A
189e: 0a                           asl     A
189f: 18                           clc                       ;(ORA)
18a0: 6d 9a 61                     adc     maze_walls_rt     ;merge with right wall flags
18a3: 8d 9a 61                     sta     maze_walls_rt
18a6: 60                           rts                       ;and we're done

                   ; 
                   ; Handle east-facing player.  Start by finding the next perpendicular wall.  We
                   ; store the west wall for each cell, so we need to move one cell east to see if
                   ; the current cell has a wall on its east side.
                   ; 
18a7: 46 1a        :FaceEast       lsr     ]bit_mask         ;adjust mask to get west wall bit
18a9: 18           :EFarLoop       clc
18aa: a5 0a                        lda     ]maze_ptr         ;move to next column to the east
18ac: 69 03                        adc     #$03
18ae: 85 0a                        sta     ]maze_ptr
18b0: b1 0a                        lda     (]maze_ptr),y     ;get wall data
18b2: 25 1a                        and     ]bit_mask         ;mask west wall bit
18b4: d0 08                        bne     :EFoundWest       ;found wall, branch
18b6: e6 19                        inc     ]end_dist         ;increment view distance
18b8: a5 19                        lda     ]end_dist
18ba: c9 05                        cmp     #$05              ;have we reached max?
18bc: d0 eb                        bne     :EFarLoop         ;no, loop
18be: a5 19        :EFoundWest     lda     ]end_dist         ;get distance
18c0: 20 10 1a                     jsr     SwapEndDist       ;swap distance out
                   ; We have a west-wall bit mask ($40/10/04/01).  We want to create two south-wall
                   ; bit masks ($80/20/08/02), one for the row of cells we're in, one for the row
                   ; of cells to the north (right shift).  This is a little tricky because we might
                   ; need to shift down one byte.
                   ]bit_mask2      .var    $19    {addr/1}

18c3: a5 1a                        lda     ]bit_mask         ;get mask
18c5: 85 19                        sta     ]bit_mask2        ;use end_dist local var as second mask
18c7: 06 1a                        asl     ]bit_mask         ;shift mask for south wall bit
18c9: 18                           clc                       ;(LSR?)
18ca: 66 19                        ror     ]bit_mask2        ;shift mask to be south wall of cell to north
18cc: 90 02                        bcc     :ESideLoop        ;branch if we stayed within byte
18ce: 66 19                        ror     ]bit_mask2        ;shift again to set it to $80
18d0: c6 0a        :ESideLoop      dec     ]maze_ptr         ;move one column west
18d2: c6 0a                        dec     ]maze_ptr
18d4: c6 0a                        dec     ]maze_ptr
18d6: b1 0a                        lda     (]maze_ptr),y     ;get wall data (Y-reg=0 here)
18d8: 25 1a                        and     ]bit_mask         ;mask south wall bit
18da: f0 03                        beq     :ENotSet1         ;not set, branch
18dc: ee 9a 61                     inc     maze_walls_rt     ;set low bit
18df: a5 19        :ENotSet1       lda     ]bit_mask2        ;get mask for other wall
18e1: c9 80                        cmp     #$80              ;did we roll over?
18e3: f0 05                        beq     :EOtherByte       ;yes, get a different byte
18e5: b1 0a                        lda     (]maze_ptr),y     ;no, get wall data
18e7: 4c ee 18                     jmp     :EGet2

18ea: c8           :EOtherByte     iny                       ;move north
18eb: b1 0a                        lda     (]maze_ptr),y
18ed: 88                           dey                       ;restore Y-reg to zero
18ee: 25 19        :EGet2          and     ]bit_mask2        ;mask south wall bit
18f0: f0 03                        beq     :ENotSet2         ;not set, branch
18f2: ee 99 61                     inc     maze_walls_lf     ;set low bit
18f5: a5 11        :ENotSet2       lda     ]dist_ctr
18f7: c9 04                        cmp     #$04              ;have we done the nearest 4 walls?
18f9: f0 9c        :ZFinish2       beq     :FinishSwap       ;yes, finish up
18fb: 20 10 1a                     jsr     SwapEndDist
18fe: c5 11                        cmp     ]dist_ctr         ;compare view range to counter
1900: f0 98        :ZFinish3       beq     :Finish           ;reached view end, finish up
1902: 20 10 1a                     jsr     SwapEndDist
1905: e6 11                        inc     ]dist_ctr
1907: 0e 99 61                     asl     maze_walls_lf     ;shift results to make room
190a: 0e 9a 61                     asl     maze_walls_rt
190d: 4c d0 18                     jmp     :ESideLoop

                   ; 
                   ; Handle west-facing player.  Start by finding the next perpendicular wall.
                   ; 
                   ]end_dist       .var    $19    {addr/1}

1910: 46 1a        :FaceWest       lsr     ]bit_mask         ;shift mask for west wall
1912: b1 0a        :WFarLoop       lda     (]maze_ptr),y     ;check current cell
1914: 25 1a                        and     ]bit_mask         ;has west wall?
1916: d0 11                        bne     :WFoundWest       ;yes, branch
1918: e6 19                        inc     ]end_dist         ;increment view distance
191a: a5 19                        lda     ]end_dist
191c: c9 05                        cmp     #$05              ;reached max?
191e: f0 09                        beq     :WFoundWest       ;yes, branch
1920: c6 0a                        dec     ]maze_ptr         ;move to previous column (westward)
1922: c6 0a                        dec     ]maze_ptr
1924: c6 0a                        dec     ]maze_ptr
1926: 4c 12 19                     jmp     :WFarLoop

1929: a5 19        :WFoundWest     lda     ]end_dist
192b: 20 10 1a                     jsr     SwapEndDist
                   ; We have a west-wall bit mask ($40/10/04/01).  We want to create two south-wall
                   ; bit masks ($80/20/08/02), one for the row of cells we're in, one for the row
                   ; of cells to the north (right shift).  This is a little tricky because we might
                   ; need to shift down one byte.
                   ]bit_mask2      .var    $19    {addr/1}

192e: a5 1a                        lda     ]bit_mask         ;get mask
1930: 85 19                        sta     ]bit_mask2        ;use end_dist local var as second mask
1932: 06 1a                        asl     ]bit_mask         ;shift mask for south wall bit
1934: 18                           clc                       ;(LSR?)
1935: 66 19                        ror     ]bit_mask2        ;shift mask to be south wall of cell to north
1937: 90 02                        bcc     :WSideLoop        ;branch if we stayed within byte
1939: 66 19                        ror     ]bit_mask2        ;shift again to set it to $80
193b: b1 0a        :WSideLoop      lda     (]maze_ptr),y     ;get wall data (Y-reg=0 here)
193d: 25 1a                        and     ]bit_mask         ;mask south wall bit
193f: f0 03                        beq     :WNotSet1         ;not set, branch
1941: ee 99 61                     inc     maze_walls_lf     ;set low bit
1944: a5 19        :WNotSet1       lda     ]bit_mask2        ;get mask for other wall
1946: c9 80                        cmp     #$80              ;did we roll over?
1948: d0 02                        bne     :WNoRoll          ;no, use same byte
194a: e6 0a                        inc     ]maze_ptr         ;move one row north
194c: b1 0a        :WNoRoll        lda     (]maze_ptr),y     ;get wall data
194e: 25 19                        and     ]bit_mask2        ;mask south wall bit
1950: f0 03                        beq     :WNotSet2
1952: ee 9a 61                     inc     maze_walls_rt     ;set low bit
1955: a5 19        :WNotSet2       lda     ]bit_mask2        ;check second mask to see if we already
1957: c9 80                        cmp     #$80              ; incremented once
1959: f0 02                        beq     :DidInc           ;yes, skip first inc
195b: e6 0a                        inc     ]maze_ptr         ;move one column to the east
195d: e6 0a        :DidInc         inc     ]maze_ptr
195f: e6 0a                        inc     ]maze_ptr
1961: 20 10 1a                     jsr     SwapEndDist       ;swap end_dist back in
1964: c5 11                        cmp     ]dist_ctr         ;reached the end?
1966: f0 98                        beq     :ZFinish3         ;yes, finish up
1968: 20 10 1a                     jsr     SwapEndDist
196b: a9 04                        lda     #$04
196d: c5 11                        cmp     ]dist_ctr         ;have we done the nearest 4 walls?
196f: f0 88        :ZFinish1       beq     :ZFinish2         ;yes, finish up
1971: e6 11                        inc     ]dist_ctr
1973: 0e 99 61                     asl     maze_walls_lf     ;shift results to make room
1976: 0e 9a 61                     asl     maze_walls_rt
1979: 4c 3b 19                     jmp     :WSideLoop

                   ; 
                   ; Handle north-facing player.  Start by finding the next perpendicular wall.  We
                   ; store the south wall for each cell, so we need to move one cell north to see
                   ; if the current cell has a wall on its north side.
                   ; 
                   ]end_dist       .var    $19    {addr/1}

197c: a5 1a        :FaceNorth      lda     ]bit_mask         ;check current mask
197e: c9 02                        cmp     #$02              ;on lowest bit pair (Y=4/8/12)?
1980: d0 09                        bne     :NNotLowBitA      ;no, can just shift
1982: a9 80                        lda     #$80              ;start at top of next byte
1984: 85 1a                        sta     ]bit_mask
1986: e6 0a                        inc     ]maze_ptr         ;move to next byte
1988: 4c 8f 19                     jmp     :NFarLoop

198b: 46 1a        :NNotLowBitA    lsr     ]bit_mask         ;shift mask one step toward +Y
198d: 46 1a                        lsr     ]bit_mask
198f: b1 0a        :NFarLoop       lda     (]maze_ptr),y     ;get value
1991: 25 1a                        and     ]bit_mask         ;mask south wall bit
1993: d0 1e                        bne     :NFoundSouth      ;found a wall, stop here
1995: e6 19                        inc     ]end_dist         ;increment distance
1997: a5 19                        lda     ]end_dist
1999: c9 05                        cmp     #$05              ;have we reached "infinity"?
199b: f0 16                        beq     :NFoundSouth      ;yes, stop here
                   ; Move to the next cell to the north.
199d: a5 1a                        lda     ]bit_mask
199f: c9 02                        cmp     #$02              ;at the end of the byte?
19a1: d0 09                        bne     :NNotLowBitB      ;not yet, branch
19a3: e6 0a                        inc     ]maze_ptr         ;move to next byte
19a5: a9 80                        lda     #$80              ;reset mask
19a7: 85 1a                        sta     ]bit_mask
19a9: 4c 8f 19                     jmp     :NFarLoop         ;loop

19ac: 46 1a        :NNotLowBitB    lsr     ]bit_mask         ;right-shift twice to move north
19ae: 46 1a                        lsr     ]bit_mask
19b0: 4c 8f 19                     jmp     :NFarLoop

                   ; We found a wall on the south side of a cell.  The player can't see into this
                   ; cell, so back up one step.
19b3: a5 1a        :NFoundSouth    lda     ]bit_mask
19b5: c9 80                        cmp     #$80              ;at edge of bit mask?
19b7: f0 05                        beq     :NHighBit         ;yes, branch
19b9: 06 1a                        asl     ]bit_mask         ;no, just shift mask for west wall bit
19bb: 4c c4 19                     jmp     :NAdjCommon

19be: c6 0a        :NHighBit       dec     ]maze_ptr         ;back up to previous byte
19c0: a9 01                        lda     #$01              ;set mask to low bit
19c2: 85 1a                        sta     ]bit_mask
                   ; 
19c4: a5 19        :NAdjCommon     lda     ]end_dist         ;get distance to end point
19c6: 20 10 1a                     jsr     SwapEndDist       ;do fancy swap maneuver
19c9: b1 0a        :NSideLoop      lda     (]maze_ptr),y     ;get chunk of maze data
19cb: 25 1a                        and     ]bit_mask         ;mask off everything but the west-wall bit
19cd: f0 03                        beq     :NNotSet1         ;not set, branch
19cf: ee 99 61                     inc     maze_walls_lf     ;set, add to left wall mask
19d2: a0 03        :NNotSet1       ldy     #$03              ;read one column to east
19d4: b1 0a                        lda     (]maze_ptr),y     ;get chunk
19d6: a0 00                        ldy     #$00              ;restore Y-reg
19d8: 25 1a                        and     ]bit_mask         ;mask off west wall bit
19da: f0 03                        beq     :NNotSet2         ;not set, branch
19dc: ee 9a 61                     inc     maze_walls_rt     ;set, add to right wall mask
19df: a9 04        :NNotSet2       lda     #$04
19e1: c5 11                        cmp     ]dist_ctr         ;was this the 5th wall (0-4)?
19e3: f0 8a                        beq     :ZFinish1         ;yes, swap and finish
19e5: 20 10 1a                     jsr     SwapEndDist       ;swap end_dist back in
19e8: c5 11                        cmp     ]dist_ctr         ;have we reached the end of the visible area?
19ea: d0 03                        bne     :NNext            ;not yet, branch
19ec: 4c 9a 18                     jmp     :Finish           ;yes, finish

19ef: 20 10 1a     :NNext          jsr     SwapEndDist       ;swap end_dist back out
19f2: 0e 99 61                     asl     maze_walls_lf     ;prep for next cell by shifting wall masks
19f5: e6 11                        inc     ]dist_ctr         ;update the counter
19f7: 0e 9a 61                     asl     maze_walls_rt
19fa: a5 1a                        lda     ]bit_mask         ;update the bit mask
19fc: c9 40                        cmp     #$40
19fe: f0 07                        beq     :NNextByte
1a00: 06 1a                        asl     ]bit_mask         ;same byte, shifted over
1a02: 06 1a                        asl     ]bit_mask
1a04: 4c c9 19                     jmp     :NSideLoop

1a07: a9 01        :NNextByte      lda     #$01              ;start in next byte
1a09: 85 1a                        sta     ]bit_mask
1a0b: c6 0a                        dec     ]maze_ptr
1a0d: 4c c9 19                     jmp     :NSideLoop

                   ; 
                   ; Swaps A-reg with $61f7, using $13 as temporary storage.  Does not touch X-reg
                   ; / Y-reg.
                   ; 
                   ; (It's unclear why the code does this, instead of just storing the value
                   ; somewhere.)
                   ; 
                   ]tmp            .var    $13    {addr/1}

1a10: 85 13        SwapEndDist     sta     ]tmp              ;save A-reg
1a12: ad f7 61                     lda     acc_swap_stash    ;get value from memory
1a15: 48                           pha                       ;preserve it
1a16: a5 13                        lda     ]tmp              ;restore A-reg
1a18: 8d f7 61                     sta     acc_swap_stash    ;save it
1a1b: 68                           pla                       ;restore value from memory
1a1c: 60                           rts

1a1d: 00 00 00 00+                 .junk   23

                   ; 
                   ; Object management function handler.  Pass in a function command index and
                   ; optional argument.  Some functions return a result in various ways.
                   ; 
                   ; State-modification functions assume the caller has already confirmed that the
                   ; action is legal, e.g. that there is enough room in the player's inventory
                   ; before picking up something new.
                   ; 
                   ; Commands:
                   ;   (for $00-$06, arg=object index ($01-17))
                   ;   $00/01 - delete object
                   ;   $02 - pick up object, still in box
                   ;   $03 - activate object in inventory (light torch, raise ring)
                   ;   $04 - pick up object
                   ;   $05 - drop object
                   ;   $06 - retrieve object info from inventory
                   ;      values returned in $19 (X/Y) and $1a (floor/state)
                   ; 
                   ;   $07 - draw player inventory
                   ;   $08 - count the number of items in inventory
                   ;      returned in $19
                   ;   $09 - reset player state
                   ;   $0a - find boxes on floor in front of player
                   ;   $0b - find boxed item at current location, or in inventory
                   ;      object index returned in A-reg
                   ;   $0c - find food in inventory
                   ;      object index returned in A-reg
                   ;   $0d - find lit torch in inventory
                   ;      object index returned in A-reg
                   ;   $0e - find unlit torch in inventory
                   ;      object index returned in A-reg
                   ; 
                   ; On entry:
                   ;   $0e: argument (optional)
                   ;   $0f: function to execute ($00-$0e)
                   ; 
                   ; On exit:
                   ;   $0e-0f: pointer into inventory area
                   ; 
                   • Clear variables
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]ret_xy         .var    $19    {addr/1}
                   ]ret_state      .var    $1a    {addr/1}

1a34: a5 0f        ObjMgmtFunc     lda     ]func_cmd         ;check command
1a36: c9 07                        cmp     #$07              ;is it an object operation?
1a38: 10 59                        bpl     DoCmd7Plus        ;no, branch
                   ; Functions 0-6 operate on inventory-able objects.  Convert the object index
                   ; argument in $0e (value $01-17) to a pointer into the object location table in
                   ; $0e-0f.
1a3a: 06 0e                        asl     ]func_arg         ;double the object index
1a3c: 48                           pha                       ;save function index
                   ]obj_ptr        .var    $0e    {addr/2}

1a3d: a9 00                        lda     #$00              ;form pointer to object data
1a3f: 85 0f                        sta     ]obj_ptr+1
1a41: 18                           clc
1a42: a9 b9                        lda     #<object_status
1a44: 65 0e                        adc     ]obj_ptr          ;add shifted index to address
1a46: 85 0e                        sta     ]obj_ptr
1a48: a9 61                        lda     #>object_status
1a4a: 65 0f                        adc     ]obj_ptr+1        ;("ADC #$00" would've saved a bit)
1a4c: 85 0f                        sta     ]obj_ptr+1
1a4e: 68                           pla                       ;restore function index
1a4f: c9 05                        cmp     #$05              ;was it 5 or 6?
1a51: 10 1b                        bpl     Func0506          ;yes, branch
                   ; Remap function index from {0-4} to {0,6-8}, with 0/1 --> 0.
1a53: c9 00                        cmp     #$00              ;no, 0-4... is it zero?
1a55: f0 08                        beq     Func00            ;yes, branch with A-reg=0
1a57: 38                           sec                       ;no, it's 1-4
1a58: e9 01                        sbc     #$01              ;subtract 1 (now 0-3)
1a5a: f0 03                        beq     Func00            ;if was 1, handle as equivalent to func 0
1a5c: 18                           clc                       ;now 1-3 (originally 2-4)
1a5d: 69 05                        adc     #$05              ;change to 6/7/8 and fall through
                   ; 
                   ; Function $00-04: set object state to value in A-reg.
                   ; 
                   ; Possible values for A-reg:
                   ;   $00: (func $00/$01) destroy object
                   ;   $06: (func $02) put object in inventory, still in box
                   ;   $07: (func $03) put object in inventory, activated
                   ;   $08: (func $04) put object in inventory
                   ; 
1a5f: a0 00        Func00          ldy     #$00
1a61: 91 0e                        sta     (]obj_ptr),y      ;set state to zero
1a63: e6 0e                        inc     ]obj_ptr          ;(INY is used a few lines down... why not here?)
1a65: d0 02                        bne     :NoInc
1a67: e6 0f                        inc     ]obj_ptr+1
1a69: a9 00        :NoInc          lda     #$00
1a6b: 91 0e                        sta     (]obj_ptr),y      ;clear second byte too
1a6d: 60                           rts

1a6e: c9 05        Func0506        cmp     #$05              ;function 5 or 6... was it 5?
1a70: f0 0c                        beq     Func05            ;yes, branch
                   ; 
                   ; Function $06: get object info.
                   ; 
                   ; Copies object location data to $19/1a.
                   ; 
1a72: a0 00                        ldy     #$00
1a74: b1 0e                        lda     (]obj_ptr),y      ;get state (floor or inventory state)
1a76: 85 1a                        sta     ]ret_state        ;copy to ZP
1a78: c8                           iny
1a79: b1 0e                        lda     (]obj_ptr),y      ;same for X/Y position
1a7b: 85 19                        sta     ]ret_xy           ;(will be zero for held item)
1a7d: 60                           rts

                   ; 
                   ; Function $05: drop object.
                   ; 
1a7e: ad 94 61     Func05          lda     plyr_floor        ;get current floor
1a81: a0 00                        ldy     #$00
1a83: 91 0e                        sta     (]obj_ptr),y      ;store that
1a85: ad 95 61                     lda     plyr_xpos         ;get X position
1a88: 0a                           asl     A                 ;multiply by 16
1a89: 0a                           asl     A
1a8a: 0a                           asl     A
1a8b: 0a                           asl     A
1a8c: 0d 96 61                     ora     plyr_ypos         ;combine with Y position
1a8f: c8                           iny
1a90: 91 0e                        sta     (]obj_ptr),y      ;store that
1a92: 60                           rts

1a93: 38           DoCmd7Plus      sec                       ;func index is 7+
1a94: e9 07                        sbc     #$07              ;reduce to 0+
1a96: f0 03                        beq     DrawInventory     ;if == 7, branch
1a98: 4c b5 1b                     jmp     ChkFunc08         ;go check 8+

                   ; 
                   ; Function $07: draw inventory.
                   ; 
                   ]counter        .var    $1a    {addr/1}

1a9b: a9 0f        DrawInventory   lda     #15               ;erasing 15 lines
1a9d: 85 1a                        sta     ]counter
1a9f: a9 19                        lda     #25               ;start in column 25
1aa1: 85 06                        sta     char_horiz
1aa3: a9 03                        lda     #3                ;row 3
1aa5: 85 07                        sta     char_vert
1aa7: 20 ef 11     :ClearLoop      jsr     SetRowPtr         ;set hi-res addr
1aaa: a9 1e                        lda     #$1e              ;clear to EOL
1aac: 20 92 11                     jsr     PrintSpecialChar
1aaf: e6 07                        inc     char_vert         ;advance to next line
1ab1: c6 1a                        dec     ]counter
1ab3: d0 f2                        bne     :ClearLoop
                   ; 
1ab5: a9 14                        lda     #$14              ;object $01-14 can be carried
1ab7: 85 1a                        sta     ]counter
1ab9: a9 bb                        lda     #<object_status2  ;set pointer to object state data
1abb: 85 0e                        sta     ]obj_ptr
1abd: a9 61                        lda     #>object_status2
1abf: 85 0f                        sta     ]obj_ptr+1
1ac1: a9 1a                        lda     #26               ;horizontal pos 26 (3 spaces over from maze)
1ac3: 85 06                        sta     char_horiz
1ac5: a9 03                        lda     #3                ;text row 3
1ac7: 85 07                        sta     char_vert
1ac9: 20 ef 11                     jsr     SetRowPtr         ;set hi-res addr
1acc: a9 01                        lda     #$01              ;"inventory:"
1ace: 20 e2 08                     jsr     DrawMsgN
1ad1: a9 1b                        lda     #27               ;indent one space
1ad3: 85 06                        sta     char_horiz
1ad5: a9 04                        lda     #4                ;start on text row 4
1ad7: 85 07                        sta     char_vert
1ad9: 20 ef 11                     jsr     SetRowPtr         ;set hi-res addr
                   ; Draw unboxed held items.
1adc: a0 00        :UnboxLoop      ldy     #$00
1ade: b1 0e                        lda     (]obj_ptr),y      ;get item state
1ae0: c9 08                        cmp     #$08              ;in inventory, unboxed?
1ae2: d0 03                        bne     :Not8             ;no, branch
1ae4: 4c 76 1b                     jmp     :DrawInvItem      ;yes, draw it

1ae7: c9 07        :Not8           cmp     #$07              ;in inventory, unboxed, activated?
1ae9: d0 03                        bne     :Not7             ;no, branch
1aeb: 4c 76 1b                     jmp     :DrawInvItem      ;yes, draw it

1aee: e6 0e        :Not7           inc     ]obj_ptr          ;advance pointer 2 bytes
1af0: d0 02                        bne     :NoInc1
1af2: e6 0f                        inc     ]obj_ptr+1
1af4: e6 0e        :NoInc1         inc     ]obj_ptr
1af6: d0 02                        bne     :NoInc2
1af8: e6 0f                        inc     ]obj_ptr+1
1afa: c6 1a        :NoInc2         dec     ]counter          ;done yet?
1afc: d0 de                        bne     :UnboxLoop        ;no, loop
                   ; Draw boxed held items.
1afe: a9 bb                        lda     #<object_status2  ;reset pointer to start of object list
1b00: 85 0e                        sta     ]obj_ptr
1b02: a9 61                        lda     #>object_status2
1b04: 85 0f                        sta     ]obj_ptr+1
1b06: a9 17                        lda     #$17              ;walk through boxed food and torches too
1b08: 85 1a                        sta     ]counter
1b0a: a0 00        :BoxLoop        ldy     #$00
1b0c: b1 0e                        lda     (]obj_ptr),y      ;get state
1b0e: c9 06                        cmp     #$06              ;in inventory, boxed?
1b10: d0 03                        bne     :NotInBox         ;no, branch
1b12: 4c 9c 1b                     jmp     :DrawBoxedItem    ;yes, draw it

1b15: e6 0e        :NotInBox       inc     ]obj_ptr          ;advance pointer 2 bytes
1b17: d0 02                        bne     :NoInc1
1b19: e6 0f                        inc     ]obj_ptr+1
1b1b: e6 0e        :NoInc1         inc     ]obj_ptr
1b1d: d0 02                        bne     :NoInc2
1b1f: e6 0f                        inc     ]obj_ptr+1
1b21: c6 1a        :NoInc2         dec     ]counter          ;done yet?
1b23: d0 e5                        bne     :BoxLoop          ;no, loop
                   ; Print lit/unlit torches.
1b25: a9 1a                        lda     #26               ;set text position
1b27: 85 06                        sta     char_horiz
1b29: a9 10                        lda     #16
1b2b: 85 07                        sta     char_vert
1b2d: 20 ef 11                     jsr     SetRowPtr
1b30: a9 02                        lda     #$02              ;"torches:"
1b32: 20 e2 08                     jsr     DrawMsgN
1b35: a9 1b                        lda     #27
1b37: 85 06                        sta     char_horiz
1b39: a9 11                        lda     #17
1b3b: 85 07                        sta     char_vert
1b3d: 20 ef 11                     jsr     SetRowPtr
1b40: a9 03                        lda     #$03              ;"lit:"
1b42: 20 e2 08                     jsr     DrawMsgN
1b45: e6 06                        inc     char_horiz        ;3 spaces, so numbers line up
1b47: e6 06                        inc     char_horiz
1b49: e6 06                        inc     char_horiz
1b4b: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
1b4e: ad 97 61                     lda     num_lit_torches   ;get number of lit torches
1b51: 18                           clc
1b52: 69 30                        adc     #‘0’              ;convert to ASCII
1b54: 20 92 11                     jsr     PrintSpecialChar  ;draw it
1b57: a9 1b                        lda     #27
1b59: 85 06                        sta     char_horiz
1b5b: a9 12                        lda     #18               ;down one line
1b5d: 85 07                        sta     char_vert
1b5f: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
1b62: a9 04                        lda     #$04              ;"unlit:"
1b64: 20 e2 08                     jsr     DrawMsgN
1b67: a9 20                        lda     #‘ ’
1b69: 20 92 11                     jsr     PrintSpecialChar  ;print one space ("INC char_horiz" would also work)
1b6c: ad 98 61                     lda     num_unlit_torches ;get number of unlit torches
1b6f: 18                           clc
1b70: 69 30                        adc     #‘0’              ;convert to ASCII
1b72: 20 92 11                     jsr     PrintSpecialChar  ;draw it
1b75: 60                           rts

                   ; Draw the name of an inventory item.
                   ]tmp            .var    $13    {addr/1}

1b76: a9 15        :DrawInvItem    lda     #$15              ;convert counter to noun; we're counting down from
1b78: 38                           sec                       ; $14, so noun is ($15 - counter)
1b79: e5 1a                        sbc     ]counter
1b7b: c9 12                        cmp     #$12              ;is it a food object ($12-$14)?
1b7d: 30 02                        bmi     :NotFood          ;no, branch
1b7f: a9 12                        lda     #$12              ;noun=food
1b81: 85 13        :NotFood        sta     ]tmp
1b83: a5 06                        lda     char_horiz        ;save current text position
1b85: 48                           pha
1b86: a5 07                        lda     char_vert
1b88: 48                           pha
1b89: a5 13                        lda     ]tmp              ;get noun
1b8b: 20 e3 25                     jsr     PrintNoun         ;draw it
1b8e: 68                           pla
1b8f: 85 07                        sta     char_vert         ;restore vertical position
1b91: e6 07                        inc     char_vert         ;move to next line
1b93: 68                           pla
1b94: 85 06                        sta     char_horiz        ;restore horizontal position
1b96: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
1b99: 4c ee 1a                     jmp     :Not7             ;loop

1b9c: a5 06        :DrawBoxedItem  lda     char_horiz        ;save current text position
1b9e: 48                           pha
1b9f: a5 07                        lda     char_vert
1ba1: 48                           pha
1ba2: a9 14                        lda     #$14              ;"box"
1ba4: 20 e3 25                     jsr     PrintNoun         ;print "box"
1ba7: 68                           pla
1ba8: 85 07                        sta     char_vert         ;restore vertical position
1baa: e6 07                        inc     char_vert         ;move down one line
1bac: 68                           pla
1bad: 85 06                        sta     char_horiz        ;restore horizontal position
1baf: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
1bb2: 4c 15 1b                     jmp     :NotInBox         ;loop

                   ]ret_count      .var    $19    {addr/1}
                   ]func_cmd_alt   .var    $1a    {addr/1}

1bb5: 85 1a        ChkFunc08       sta     ]func_cmd_alt     ;save function index
1bb7: c6 1a                        dec     ]func_cmd_alt     ;was it 8?
1bb9: d0 2d                        bne     ChkFunc09         ;no, branch
                   ; 
                   ; Function $08: count inventory items.
                   ; 
                   ; Count is returned in $1a.
                   ; 
                   ]counter        .var    $1a    {addr/1}

1bbb: a9 61                        lda     #>object_status2  ;set pointer to object info
1bbd: 85 0f                        sta     ]obj_ptr+1
1bbf: a9 bb                        lda     #<object_status2
1bc1: 85 0e                        sta     ]obj_ptr
1bc3: a9 14                        lda     #$14              ;count objects up to and including foods
1bc5: 85 1a                        sta     ]counter
1bc7: a9 00                        lda     #$00
1bc9: 85 19                        sta     ]ret_count        ;init counter
1bcb: a0 00                        ldy     #$00
1bcd: b1 0e        :CountLoop      lda     (]obj_ptr),y      ;get object state
1bcf: c9 06                        cmp     #$06              ;in inventory?
1bd1: 30 02                        bmi     :NotInv           ;no, branch
1bd3: e6 19                        inc     ]ret_count        ;yes, increment count
1bd5: c8           :NotInv         iny                       ;advance pointer to next entry
1bd6: c8                           iny
1bd7: c6 1a                        dec     ]counter          ;done yet?
1bd9: d0 f2                        bne     :CountLoop        ;no, branch
                   ; 
1bdb: ad a1 61                     lda     torch_level       ;is a torch lit?
1bde: d0 05                        bne     :TorchLit         ;yes, branch
1be0: ad 98 61                     lda     num_unlit_torches ;do we have unlit torches?
1be3: f0 02                        beq     :Return           ;no, branch
1be5: e6 19        :TorchLit       inc     ]ret_count        ;add one for lit torch
1be7: 60           :Return         rts

                   ]func_cmd_alt   .var    $1a    {addr/1}

1be8: c6 1a        ChkFunc09       dec     ]func_cmd_alt     ;was it 9?
1bea: d0 1a                        bne     ChkFunc0a         ;no, branch
                   ; 
                   ; Function $09: init player data area, copying $613d-6192 to $6193-61e8.
                   ; 
                   ]src_ptr        .var    $0e    {addr/2}
                   ]dst_ptr        .var    $10    {addr/2}

1bec: a0 55                        ldy     #$55              ;first 55 bytes are overwritten
1bee: a9 61                        lda     #>init_game_state ;source pointer
1bf0: 85 0f                        sta     ]src_ptr+1
1bf2: a9 3d                        lda     #<init_game_state
1bf4: 85 0e                        sta     ]src_ptr
1bf6: a9 93                        lda     #<plyr_facing     ;destination pointer
1bf8: 85 10                        sta     ]dst_ptr
1bfa: a9 61                        lda     #>plyr_facing
1bfc: 85 11                        sta     ]dst_ptr+1
1bfe: b1 0e        :Loop           lda     (]src_ptr),y      ;copy
1c00: 91 10                        sta     (]dst_ptr),y
1c02: 88                           dey
1c03: 10 f9                        bpl     :Loop
1c05: 60                           rts

1c06: c6 1a        ChkFunc0a       dec     ]func_cmd_alt
1c08: d0 03                        bne     ChkFunc0b
1c0a: 4c 0e 1d                     jmp     FindVisBoxes

1c0d: c6 1a        ChkFunc0b       dec     ]func_cmd_alt
1c0f: f0 03                        beq     FuncFindBox
1c11: 4c af 1c                     jmp     ChkFunc0c

                   ; 
                   ; Function $0b: find box in maze at current position.  If there's no box on the
                   ; ground, search inventory for a boxed object.
                   ; 
                   ; On exit:
                   ;   A-reg: object index
                   ; 
                   ]player_xy      .var    $11    {addr/1}
                   ]tmp_floor      .var    $13    {addr/1}
                   ]counter        .var    $1a    {addr/1}

1c14: ad 95 61     FuncFindBox     lda     plyr_xpos         ;get X position
1c17: 0a                           asl     A                 ;multiply by 16
1c18: 0a                           asl     A
1c19: 0a                           asl     A
1c1a: 0a                           asl     A
1c1b: 18                           clc
1c1c: 6d 96 61                     adc     plyr_ypos         ;add Y position
1c1f: 85 11                        sta     ]player_xy        ;save
1c21: a9 61                        lda     #>object_status2  ;set pointer one byte into data area
1c23: 85 0f                        sta     ]src_ptr+1
1c25: a9 bc                        lda     #<object_status2+1
1c27: 85 0e                        sta     ]src_ptr
1c29: a9 17                        lda     #$17              ;all inventory-able items (including torches)
1c2b: 85 1a                        sta     ]counter
                   ; 
1c2d: a0 00                        ldy     #$00
1c2f: a5 11                        lda     ]player_xy
1c31: d1 0e        :SearchLoop     cmp     (]src_ptr),y      ;does object X/Y position match?
1c33: f0 49                        beq     :MatchXY          ;yes, branch
1c35: c8           :SearchLoop1    iny                       ;no, advance pointer
1c36: c8                           iny
1c37: c6 1a                        dec     ]counter          ;done yet?
1c39: d0 f6                        bne     :SearchLoop       ;no, loop
                   ; Nothing found on ground.
1c3b: a9 61                        lda     #>object_status2  ;reset pointer
1c3d: 85 0f                        sta     ]src_ptr+1
1c3f: a9 bb                        lda     #<object_status2
1c41: 85 0e                        sta     ]src_ptr
1c43: a9 10                        lda     #$10              ;only consider first $10 objects, so we don't find
1c45: 85 1a                        sta     ]counter          ; the snake ($11)
1c47: a9 06                        lda     #$06
1c49: a0 00                        ldy     #$00
1c4b: d1 0e        :InvLoop        cmp     (]src_ptr),y      ;is item held and boxed?
1c4d: f0 45                        beq     :FoundMatch       ;yes, branch
1c4f: c8                           iny                       ;no, advance pointer
1c50: c8                           iny
1c51: c6 1a                        dec     ]counter          ;done yet?
1c53: d0 f6                        bne     :InvLoop          ;no, loop
                   ; Do it again, but only looking at food and torches.
1c55: a9 61                        lda     #>food_torch_loc  ;reset pointer
1c57: 85 0f                        sta     ]src_ptr+1
1c59: a9 dd                        lda     #<food_torch_loc
1c5b: 85 0e                        sta     ]src_ptr
1c5d: a9 06                        lda     #$06
1c5f: 85 1a                        sta     ]counter          ;3 food, 3 torches
1c61: a0 00                        ldy     #$00
1c63: d1 0e        :FoodTorchLoop  cmp     (]src_ptr),y      ;is item held and boxed?
1c65: f0 2d                        beq     :FoundMatch       ;yes, branch
1c67: c8                           iny                       ;no, advance pointer
1c68: c8                           iny
1c69: c6 1a                        dec     ]counter          ;done yet?
1c6b: d0 f6                        bne     :FoodTorchLoop    ;no, loop
                   ; Finally, open the box with the snake if we have it.
1c6d: a2 61                        ldx     #>snake_obj_loc   ;set pointer to the snake object entry
1c6f: 86 0f                        stx     ]src_ptr+1
1c71: a2 db                        ldx     #<snake_obj_loc
1c73: 86 0e                        stx     ]src_ptr
1c75: a0 00                        ldy     #$00
1c77: d1 0e                        cmp     (]src_ptr),y      ;is item held and boxed?
1c79: f0 19                        beq     :FoundMatch       ;yes, branch
1c7b: a9 00                        lda     #$00              ;nothing found, return zero
1c7d: 60                           rts

                   ; X/Y matched for box on floor, check floor number.
1c7e: c6 0e        :MatchXY        dec     ]src_ptr          ;back pointer up to floor/state value
1c80: b1 0e                        lda     (]src_ptr),y      ;get floor number
1c82: 85 13                        sta     ]tmp_floor        ;save it
1c84: e6 0e                        inc     ]src_ptr          ;change pointer back
1c86: 88                           dey                       ;and decrement Y-reg by one
1c87: a5 13                        lda     ]tmp_floor        ;see if floor matches
1c89: cd 94 61                     cmp     plyr_floor
1c8c: f0 06                        beq     :FoundMatch       ;it does, we have a winner; branch
1c8e: c8                           iny                       ;restore Y-reg to previous value
1c8f: a5 11                        lda     ]player_xy        ;restore A-reg to value we're comparing against
1c91: 4c 35 1c                     jmp     :SearchLoop1      ;keep looking

                   ; Found a matching object.  Get the object's index.
1c94: 18           :FoundMatch     clc
1c95: 98                           tya
1c96: 10 02                        bpl     :IsPos            ;if we went negative,
1c98: a9 00                        lda     #$00              ; clamp to zero
1c9a: 65 0e        :IsPos          adc     ]src_ptr          ;add Y index to pointer
1c9c: 85 0e                        sta     ]src_ptr
1c9e: a9 00                        lda     #$00
1ca0: 65 0f                        adc     ]src_ptr+1
1ca2: 85 0f                        sta     ]src_ptr+1
1ca4: 38                           sec
1ca5: a5 0e                        lda     ]src_ptr
1ca7: e9 bb                        sbc     #<object_status2  ;subtract base address to get... index
1ca9: 18                           clc                       ;(equivalent to TYA without the DEY)
1caa: 6a                           ror     A                 ;halve it and add one
1cab: 18                           clc
1cac: 69 01                        adc     #$01
1cae: 60                           rts                       ;return index of matching item in A-reg

1caf: c6 1a        ChkFunc0c       dec     ]counter
1cb1: d0 35                        bne     ChkFunc0d
                   ; 
                   ; Function $0c: find food in inventory.
                   ; 
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]desired_state  .var    $10    {addr/1}
                   ]item_counter   .var    $11    {addr/1}
                   ]obj_state      .var    $1a    {addr/1}

1cb3: a9 03                        lda     #3                ;3 instances of food
1cb5: 85 11                        sta     ]item_counter
1cb7: a9 08                        lda     #$08              ;wanted: in inventory, unboxed
1cb9: 85 10                        sta     ]desired_state
1cbb: a9 06                        lda     #FN_GET_OBJ_INFO
1cbd: 85 0f                        sta     ]func_cmd
1cbf: a9 12                        lda     #$12              ;foods ($12-14)
1cc1: 85 0e                        sta     ]func_arg         ;...fall through...
                   ; Iterate through inventory, looking for matching item.  The function index
                   ; should be $06 (get object info).
1cc3: a5 0f        FindConsumable  lda     ]func_cmd         ;save a copy of func index/arg
1cc5: 48                           pha
1cc6: a5 0e                        lda     ]func_arg
1cc8: 48                           pha
1cc9: 20 34 1a                     jsr     ObjMgmtFunc       ;get object info
1ccc: a5 10                        lda     ]desired_state
1cce: c5 1a                        cmp     ]obj_state        ;is it where we want it?
1cd0: f0 0f                        beq     :GotIt            ;yes, branch
1cd2: 68                           pla                       ;restore func index/arg values
1cd3: 85 0e                        sta     ]func_arg
1cd5: 68                           pla
1cd6: 85 0f                        sta     ]func_cmd
1cd8: e6 0e                        inc     ]func_arg         ;try next food/torch
1cda: c6 11                        dec     ]item_counter     ;done yet?
1cdc: d0 e5                        bne     FindConsumable    ;no, branch
1cde: a9 00                        lda     #$00              ;not found
1ce0: 60                           rts

1ce1: 68           :GotIt          pla                       ;get object ID
1ce2: 85 0e                        sta     ]func_arg         ;stash it
1ce4: 68                           pla                       ;pull thing we don't need
1ce5: a5 0e                        lda     ]func_arg         ;get object ID
1ce7: 60                           rts                       ;return in A-reg

1ce8: c6 1a        ChkFunc0d       dec     ]obj_state
1cea: d0 0a                        bne     ChkFunc0e
                   ; 
                   ; Function $0d: find lit torch in inventory
                   ; 
1cec: a9 03                        lda     #3                ;3 items
1cee: 85 11                        sta     ]item_counter
1cf0: a9 07                        lda     #$07              ;in inventory, activated
1cf2: 85 10                        sta     ]desired_state
1cf4: d0 0c                        bne     :FindTorch        ;(always)

1cf6: c6 1a        ChkFunc0e       dec     ]obj_state
1cf8: d0 13                        bne     :Return           ;invalid function index, bail
                   ; 
                   ; Function $0e: find unlit torch in inventory.
                   ; 
1cfa: a9 03                        lda     #3                ;3 items
1cfc: 85 11                        sta     ]item_counter
1cfe: a9 08                        lda     #$08              ;in inventory
1d00: 85 10                        sta     ]desired_state
1d02: a9 06        :FindTorch      lda     #FN_GET_OBJ_INFO
1d04: 85 0f                        sta     ]func_cmd
1d06: a9 15                        lda     #$15              ;torches ($15-17)
1d08: 85 0e                        sta     ]func_arg
1d0a: 20 c3 1c                     jsr     FindConsumable    ;jump to common code
1d0d: 60           :Return         rts

                   ; 
                   ; Function $0a: find all visible boxes (i.e. in the 4 cells directly in front of
                   ; player).
                   ; 
                   ; Sets $619b to a bit mask identifying which cells have boxes.
                   ; 
                   • Clear variables
                   ]flag_accum     .var    $0e    {addr/1}
                   ]max_dist       .var    $0f    {addr/1}
                   ]player_y       .var    $10    {addr/1}
                   ]player_x       .var    $11    {addr/1}
                   ]player_flr     .var    $19    {addr/1}
                   ]num_cells      .var    $1a    {addr/1}

1d0e: ad 9a 61     FindVisBoxes    lda     maze_walls_rt     ;get wall data
1d11: 29 e0                        and     #%11100000        ;just want dist to facing wall
1d13: 4a                           lsr     A                 ;right-shift 5x
1d14: 4a                           lsr     A
1d15: 4a                           lsr     A
1d16: 4a                           lsr     A
1d17: 4a                           lsr     A                 ;now 0-5
1d18: f0 1b                        beq     :NoseToWall       ;if we're right up against wall, no boxes are vis
1d1a: c9 05                        cmp     #$05              ;is far wall at "infinity"?
1d1c: d0 03                        bne     :NotInf           ;no, branch
1d1e: 38                           sec
1d1f: e9 01                        sbc     #$01              ;reduce to 4
1d21: 85 1a        :NotInf         sta     ]num_cells        ;save as number of cells to scan
1d23: ad 95 61                     lda     plyr_xpos         ;get local copies of X/Y/floor in ZP
1d26: 85 11                        sta     ]player_x
1d28: ad 96 61                     lda     plyr_ypos
1d2b: 85 10                        sta     ]player_y
1d2d: ad 94 61                     lda     plyr_floor
1d30: 85 19                        sta     ]player_flr
1d32: 4c 3b 1d                     jmp     :DoFind

1d35: a9 00        :NoseToWall     lda     #$00
1d37: 8d 9b 61                     sta     vis_box_flags     ;no boxes visible
1d3a: 60                           rts

1d3b: a5 1a        :DoFind         lda     ]num_cells
1d3d: 85 0f                        sta     ]max_dist
1d3f: a9 00                        lda     #$00
1d41: 85 0e                        sta     ]flag_accum       ;box flags initially zero
1d43: ad 93 61     :CellLoop       lda     plyr_facing       ;get facing (1=W 2=N 3=E 4=S)
1d46: 20 c7 1d                     jsr     :MoveOne
1d49: 20 69 1d                     jsr     :FindBox
1d4c: c6 1a                        dec     ]num_cells        ;done yet?
1d4e: f0 05                        beq     :Finish           ;yes, bail
1d50: 46 0e                        lsr     ]flag_accum       ;no, shift flag result
1d52: 4c 43 1d                     jmp     :CellLoop         ;next cell

1d55: a9 04        :Finish         lda     #$04              ;compute (4 - max dist)
1d57: 38                           sec
1d58: e5 0f                        sbc     ]max_dist
1d5a: f0 07                        beq     :WasDist4         ;was 4, don't shift it down
1d5c: 46 0e        :AlignLoop      lsr     ]flag_accum       ;shift down so dist=1 is in low bit
1d5e: 38                           sec
1d5f: e9 01                        sbc     #$01
1d61: d0 f9                        bne     :AlignLoop
1d63: a5 0e        :WasDist4       lda     ]flag_accum       ;copy result out
1d65: 8d 9b 61                     sta     vis_box_flags
1d68: 60                           rts

                   ; 
                   ; Look for a box at the current X/Y position.
                   ; 
1d69: 48           :FindBox        pha                       ;push most of the ZP values onto the stack
1d6a: a5 11                        lda     ]player_x
1d6c: 48                           pha
1d6d: a5 10                        lda     ]player_y
1d6f: 48                           pha
1d70: a5 0f                        lda     ]max_dist
1d72: 48                           pha
1d73: a5 0e                        lda     ]flag_accum
1d75: 48                           pha
1d76: a5 11                        lda     ]player_x         ;combine player's X and Y position
1d78: 0a                           asl     A
1d79: 0a                           asl     A
1d7a: 0a                           asl     A
1d7b: 0a                           asl     A
1d7c: 18                           clc
1d7d: 65 10                        adc     ]player_y
1d7f: 48                           pha                       ;...and push that too
                   ]obj_ptr        .var    $0e    {addr/2}
                   ]xy_tmp         .var    $10    {addr/1}
                   ]counter        .var    $11    {addr/1}

1d80: a9 61                        lda     #>object_status2  ;set pointer to object data + 1
1d82: 85 0f                        sta     ]obj_ptr+1        ;(trampling our own ZP state)
1d84: a9 bc                        lda     #<object_status2+1
1d86: 85 0e                        sta     ]obj_ptr
1d88: a9 17                        lda     #$17              ;check all inventory-able objects
1d8a: 85 11                        sta     ]counter
1d8c: 68                           pla                       ;get the combined X/Y position
1d8d: a0 00                        ldy     #$00
1d8f: d1 0e        :FindLoop       cmp     (]obj_ptr),y      ;does it match?
1d91: f0 14                        beq     :MatchXY          ;yes, branch
1d93: c8           :FindLoop2      iny                       ;advance pointer
1d94: c8                           iny
1d95: c6 11                        dec     ]counter          ;done yet?
1d97: d0 f6                        bne     :FindLoop         ;no, loop
1d99: 68                           pla
1d9a: 85 0e                        sta     ]obj_ptr
1d9c: 68                           pla
1d9d: 85 0f                        sta     ]obj_ptr+1
1d9f: 68           :FindLoopEnd    pla                       ;restore $10/$11
1da0: 85 10                        sta     ]xy_tmp
1da2: 68                           pla
1da3: 85 11                        sta     ]counter
1da5: 68                           pla
1da6: 60                           rts

1da7: 85 10        :MatchXY        sta     ]xy_tmp           ;save combined X/Y
1da9: c6 0e                        dec     ]obj_ptr          ;decrement pointer (low byte only!)
1dab: b1 0e                        lda     (]obj_ptr),y      ;get floor
1dad: e6 0e                        inc     ]obj_ptr          ;increment pointer back where it was
1daf: c5 19                        cmp     ]player_flr       ;does the floor match?
1db1: f0 05                        beq     :MatchAll         ;yes, branch
1db3: a5 10                        lda     ]xy_tmp           ;restore combined X/Y value
1db5: 4c 93 1d                     jmp     :FindLoop2        ;loop

                   ]flag_accum     .var    $0e    {addr/1}
                   ]max_dist       .var    $0f    {addr/1}

1db8: 68           :MatchAll       pla                       ;restore ZP values
1db9: 85 0e                        sta     ]flag_accum
1dbb: 68                           pla
1dbc: 85 0f                        sta     ]max_dist
1dbe: a5 0e                        lda     ]flag_accum
1dc0: 18                           clc
1dc1: 69 08                        adc     #%00001000        ;set flag in bit 4
1dc3: 85 0e                        sta     ]flag_accum
1dc5: d0 d8                        bne     :FindLoopEnd      ;(always)

                   ; 
                   ; Update X/Y based on player facing.
                   ; 
                   ]player_y       .var    $10    {addr/1}
                   ]player_x       .var    $11    {addr/1}

1dc7: c9 01        :MoveOne        cmp     #$01              ;west?
1dc9: f0 0b                        beq     :MoveWest
1dcb: c9 02                        cmp     #$02
1dcd: f0 0a                        beq     :MoveNorth
1dcf: c9 03                        cmp     #$03
1dd1: f0 09                        beq     :MoveEast
1dd3: c6 10                        dec     ]player_y
1dd5: 60                           rts

1dd6: c6 11        :MoveWest       dec     ]player_x
1dd8: 60                           rts

1dd9: e6 10        :MoveNorth      inc     ]player_y
1ddb: 60                           rts

1ddc: e6 11        :MoveEast       inc     ]player_x
1dde: 60                           rts

                   ; 
                   ; Finds a maze feature (such as a pit in the floor) visible from this position
                   ; and facing.
                   ; 
                   ; (Drawn below, at $1e5a.)
                   ; 
                   ; On exit:
                   ;   $0e: feature distance (0-4)
                   ;   $0f: feature index (1-10)
                   ; 
                   ; If nothing was found, both values will be zero.
                   ; 
                   • Clear variables
                   ]data_ptr       .var    $0e    {addr/2}
                   ]xy_posn        .var    $10    {addr/1}
                   ]facing_floor   .var    $11    {addr/1}
                   ]counter        .var    $19    {addr/1}

1ddf: ad 93 61     FindFeature     lda     plyr_facing       ;get facing (1-4)
1de2: 0a                           asl     A                 ;shift into high nibble
1de3: 0a                           asl     A
1de4: 0a                           asl     A
1de5: 0a                           asl     A
1de6: 18                           clc                       ;(could ORA here)
1de7: 6d 94 61                     adc     plyr_floor        ;merge with floor
1dea: 85 11                        sta     ]facing_floor     ;save it
1dec: ad 95 61                     lda     plyr_xpos         ;get X position
1def: 0a                           asl     A                 ;shift into high nibble
1df0: 0a                           asl     A
1df1: 0a                           asl     A
1df2: 0a                           asl     A
1df3: 18                           clc                       ;(could ORA here too)
1df4: 6d 96 61                     adc     plyr_ypos         ;merge with Y position
1df7: 85 10                        sta     ]xy_posn          ;save it
                   ; 
1df9: a9 60                        lda     #>maze_features   ;init pointer to maze features table
1dfb: 85 0f                        sta     ]data_ptr+1
1dfd: a9 a5                        lda     #<maze_features
1dff: 85 0e                        sta     ]data_ptr
1e01: a9 26                        lda     #38               ;#of features in the list
1e03: 85 19                        sta     ]counter
1e05: a0 00                        ldy     #$00
1e07: a5 11                        lda     ]facing_floor     ;get facing+floor
1e09: d1 0e        :Loop           cmp     (]data_ptr),y     ;match?
1e0b: f0 0f                        beq     :FacFlrMatch      ;yes, branch
1e0d: c8                           iny                       ;move on to next entry
1e0e: c8           :RejoinLoop     iny
1e0f: c8                           iny
1e10: c8                           iny
1e11: c6 19                        dec     ]counter          ;done yet?
1e13: d0 f4                        bne     :Loop             ;no loop
1e15: a9 00                        lda     #$00
1e17: 85 0f                        sta     ]data_ptr+1       ;no match found, return zeroes
1e19: 85 0e                        sta     ]data_ptr
1e1b: 60                           rts

                   ; Got match on facing and floor, check X/Y position.
1e1c: a5 10        :FacFlrMatch    lda     ]xy_posn          ;get X/Y position
1e1e: c8                           iny
1e1f: d1 0e                        cmp     (]data_ptr),y     ;match?
1e21: f0 04                        beq     :FullMatch        ;yes, branch
1e23: a5 11                        lda     ]facing_floor     ;no, rejoin the loop
1e25: d0 e7                        bne     :RejoinLoop       ;(always)

1e27: c8           :FullMatch      iny
1e28: b1 0e                        lda     (]data_ptr),y     ;get feature index
1e2a: 85 11                        sta     ]facing_floor     ;save in temp storage
1e2c: c8                           iny
1e2d: b1 0e                        lda     (]data_ptr),y     ;get feature distance
1e2f: 85 0e                        sta     ]data_ptr         ;set return value (overwrites pointer)
1e31: a5 11                        lda     ]facing_floor     ;get feature index
1e33: 85 0f                        sta     ]data_ptr+1       ;set return value
1e35: 60                           rts

                   ; 
                   ; Character glyph matrix for a full-sized keyhole.
                   ; 
1e36: 06 0b 0b 07  full_keyhole    .bulk   $06,$0b,$0b,$07
1e3a: 0b 0b 0b 0b                  .bulk   $0b,$0b,$0b,$0b
1e3e: 0b 0b 0b 0b                  .bulk   $0b,$0b,$0b,$0b
1e42: 0b 0b 0b 0b                  .bulk   $0b,$0b,$0b,$0b
1e46: 08 0b 0b 09                  .bulk   $08,$0b,$0b,$09
1e4a: 20 0b 0b 20                  .bulk   $20,$0b,$0b,$20
1e4e: 20 0b 0b 20                  .bulk   $20,$0b,$0b,$20
1e52: 0b 0b 0b 0b                  .bulk   $0b,$0b,$0b,$0b
1e56: 0b 0b 0b 0b                  .bulk   $0b,$0b,$0b,$0b

                   ; 
                   ; Draw a visual element, such as a box, keyhole, or elevator.
                   ; 
                   ; Elements:
                   ;   $01: full-sized (facing) keyhole
                   ;   $02: elevator (facing)
                   ;   $03: animate elevator walls crushing in
                   ;   $04: hole in floor (arg=distance)
                   ;   $05: hole in roof (arg=distance)
                   ;   $06: 1-4 boxes (arg is copy of box flags from $619b)
                   ;   $07: Perfect Square (arg=side/distance)
                   ;   $08: elevator on side wall (arg=side/distance)
                   ;   $09: 1-4 keyholes on side walls (arg=bit mask)
                   ;   $0a: elevator (facing), animating open
                   ; 
                   ; On entry:
                   ;   $0e: argument (usually position)
                   ;   $0f: element index
                   ; 
                   • Clear variables
                   ]feat_arg       .var    $0e    {addr/1}
                   ]feat_index     .var    $0f    {addr/1}

1e5a: a4 0f        DrawFeature     ldy     ]feat_index       ;get index of thing to draw
1e5c: 88                           dey                       ;is it a full-sized keyhole?
1e5d: d0 42                        bne     ChkDrwElevFac     ;no, branch
                   ; 
                   ; Feature $01: draw full-size keyhole, facing player.
                   ; 
                   ]data_ptr       .var    $0a    {addr/2}
                   ]h_count        .var    $19    {addr/1}
                   ]v_count        .var    $1a    {addr/1}

1e5f: a9 09                        lda     #9
1e61: 85 1a                        sta     ]v_count          ;9 rows of characters
1e63: 85 06                        sta     char_horiz        ;start in text column 9
1e65: a9 06                        lda     #6
1e67: 85 07                        sta     char_vert         ;text row 6
1e69: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
1e6c: a9 1e                        lda     #>full_keyhole    ;init pointer to keyhole data
1e6e: 85 0b                        sta     ]data_ptr+1
1e70: a9 36                        lda     #<full_keyhole
1e72: 85 0a                        sta     ]data_ptr
1e74: a0 00                        ldy     #$00
1e76: a9 04        :BlockLoop      lda     #4                ;4 chars per row
1e78: 85 19                        sta     ]h_count
1e7a: 98           :RowLoop        tya
1e7b: 48                           pha                       ;preserve Y-reg
1e7c: b1 0a                        lda     (]data_ptr),y     ;get character
1e7e: 20 a4 11                     jsr     DrawGlyph         ;draw it
1e81: 68                           pla
1e82: a8                           tay                       ;restore Y-reg
1e83: c8                           iny                       ;advance to next char
1e84: c6 19                        dec     ]h_count          ;done with this row?
1e86: d0 f2                        bne     :RowLoop          ;no, branch
1e88: c6 1a                        dec     ]v_count          ;done with all rows?
1e8a: f0 14                        beq     :Return           ;yes, bail
1e8c: 98                           tya
1e8d: 48                           pha                       ;preserve Y-reg
1e8e: e6 07                        inc     char_vert         ;advance to next row
1e90: c6 06                        dec     char_horiz        ;move back 4 chars
1e92: c6 06                        dec     char_horiz
1e94: c6 06                        dec     char_horiz
1e96: c6 06                        dec     char_horiz
1e98: 20 ef 11                     jsr     SetRowPtr         ;set hi-res pointer
1e9b: 68                           pla
1e9c: a8                           tay                       ;restore Y-reg
1e9d: 4c 76 1e                     jmp     :BlockLoop        ;loop

1ea0: 60           :Return         rts

1ea1: 88           ChkDrwElevFac   dey
1ea2: d0 77                        bne     ChkDrwWallsAnim
                   ; 
                   ; Feature $02: draw elevator, facing.
                   ; 
1ea4: a9 03                        lda     #3
1ea6: 85 07                        sta     char_vert
1ea8: a9 05                        lda     #5
1eaa: 85 06                        sta     char_horiz
1eac: a9 04                        lda     #$04              ;vertical line, right edge
1eae: a0 12                        ldy     #18
1eb0: 20 a7 17                     jsr     DrawGlyphsDown
1eb3: a9 03                        lda     #$03
1eb5: 85 07                        sta     char_vert
1eb7: a9 0a                        lda     #$0a
1eb9: 85 06                        sta     char_horiz
1ebb: a9 04                        lda     #$04              ;vertical line, right edge
1ebd: a0 12                        ldy     #18
1ebf: 20 a7 17                     jsr     DrawGlyphsDown
1ec2: a9 03                        lda     #3
1ec4: 85 07                        sta     char_vert
1ec6: a9 10                        lda     #16
1ec8: 85 06                        sta     char_horiz
1eca: a9 03                        lda     #$03              ;vertical line, left edge
1ecc: a0 12                        ldy     #$12
1ece: 20 a7 17                     jsr     DrawGlyphsDown
1ed1: a9 5e                        lda     #$5e              ;$5e50+1 = row 167 col 1
1ed3: 85 09                        sta     char_row_ptr+1
1ed5: a9 50                        lda     #$50
1ed7: 85 08                        sta     char_row_ptr
1ed9: a0 14                        ldy     #20
1edb: 20 77 17                     jsr     DrawLineHorizontal ;draw bottom line
1ede: a9 05                        lda     #$05              ;$5d05+1 = row 23 col 6
1ee0: 85 08                        sta     char_row_ptr
1ee2: a9 5d                        lda     #$5d
1ee4: 85 09                        sta     char_row_ptr+1
1ee6: a0 0a                        ldy     #10
1ee8: 20 77 17                     jsr     DrawLineHorizontal ;draw line near top
                   ; Draw "elevator" string.
1eeb: a9 07                        lda     #7                ;set text position
1eed: 85 06                        sta     char_horiz
1eef: a9 01                        lda     #1
1ef1: 85 07                        sta     char_vert
1ef3: 20 ef 11                     jsr     SetRowPtr
1ef6: a9 1f                        lda     #>msg_elevator    ;get pointer to string
1ef8: 85 0b                        sta     ]data_ptr+1
1efa: a9 13                        lda     #<msg_elevator
1efc: 85 0a                        sta     ]data_ptr
1efe: a0 00                        ldy     #$00
1f00: a9 08                        lda     #$08
1f02: 85 1a                        sta     ]v_count
1f04: 98           :DrawLoop       tya                       ;preserve Y-reg
1f05: 48                           pha
1f06: b1 0a                        lda     (]data_ptr),y
1f08: 20 a4 11                     jsr     DrawGlyph         ;draw character
1f0b: 68                           pla
1f0c: a8                           tay
1f0d: c8                           iny
1f0e: c6 1a                        dec     ]v_count
1f10: d0 f2                        bne     :DrawLoop
1f12: 60                           rts

1f13: 45 4c 45 56+ msg_elevator    .str    ‘ELEVATOR’

1f1b: 88           ChkDrwWallsAnim dey
1f1c: f0 03                        beq     FeatWallsCrush
1f1e: 4c 6a 20                     jmp     ChkDrwPit

                   ; 
                   ; Feature $03: animate walls closing in (like trash compactor).
                   ; 
                   ; Used when you enter the elevator on the second floor.
                   ; 
                   ]counter        .var    $0c    {addr/1}

1f21: a9 06        FeatWallsCrush  lda     #6                ;6 steps in animation
1f23: 85 0c                        sta     ]counter
1f25: a9 00        :Loop           lda     #0
1f27: 85 07                        sta     char_vert
1f29: a9 06                        lda     #$06
1f2b: 38                           sec
1f2c: e5 0c                        sbc     ]counter          ;compute (6 - counter)
1f2e: 85 06                        sta     char_horiz        ;use that as horizontal position
1f30: 48                           pha
1f31: a9 20                        lda     #$20              ;blank space
1f33: a0 15                        ldy     #$15
1f35: 20 a7 17                     jsr     DrawGlyphsDown    ;erase vertical column
1f38: 68                           pla
1f39: 48                           pha
1f3a: 85 06                        sta     char_horiz
1f3c: e6 06                        inc     char_horiz
1f3e: a9 00                        lda     #$00
1f40: 85 07                        sta     char_vert
1f42: a9 04                        lda     #$04              ;vertical line, right edge
1f44: a0 15                        ldy     #$15
1f46: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column
1f49: 68                           pla
1f4a: 48                           pha
1f4b: 85 06                        sta     char_horiz
1f4d: e6 06                        inc     char_horiz
1f4f: e6 06                        inc     char_horiz
1f51: a9 01                        lda     #1
1f53: 85 07                        sta     char_vert         ;back to top
1f55: 20 ef 11                     jsr     SetRowPtr
1f58: a9 20                        lda     #$20              ;blank space
1f5a: 20 92 11                     jsr     PrintSpecialChar
1f5d: e6 07                        inc     char_vert
1f5f: 20 ef 11                     jsr     SetRowPtr
1f62: a9 20                        lda     #$20              ;blank space
1f64: 20 92 11                     jsr     PrintSpecialChar
1f67: 68                           pla
1f68: 85 06                        sta     char_horiz
1f6a: e6 06                        inc     char_horiz
1f6c: e6 06                        inc     char_horiz
1f6e: a9 00                        lda     #0
1f70: 85 07                        sta     char_vert
1f72: a0 04                        ldy     #$04
1f74: 20 95 17                     jsr     DrawDiagDownRight ;draw perspective edge
1f77: c6 06                        dec     char_horiz
1f79: c6 06                        dec     char_horiz
1f7b: a5 06                        lda     char_horiz
1f7d: 48                           pha
1f7e: a5 07                        lda     char_vert
1f80: 48                           pha
1f81: c6 07                        dec     char_vert
1f83: a9 20                        lda     #$20
1f85: a0 0f                        ldy     #$0f
1f87: 20 a7 17                     jsr     DrawGlyphsDown
1f8a: c6 06                        dec     char_horiz
1f8c: 20 ef 11                     jsr     SetRowPtr
1f8f: a9 20                        lda     #$20              ;blank space
1f91: 20 92 11                     jsr     PrintSpecialChar
1f94: e6 07                        inc     char_vert
1f96: c6 06                        dec     char_horiz
1f98: c6 06                        dec     char_horiz
1f9a: 20 ef 11                     jsr     SetRowPtr
1f9d: a9 20                        lda     #$20              ;blank space
1f9f: 20 92 11                     jsr     PrintSpecialChar
1fa2: 68                           pla
1fa3: 85 07                        sta     char_vert
1fa5: 68                           pla
1fa6: 85 06                        sta     char_horiz
1fa8: e6 06                        inc     char_horiz
1faa: a9 04                        lda     #$04              ;vertical line, right edge
1fac: a0 0d                        ldy     #13
1fae: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column
1fb1: a0 04                        ldy     #$04
1fb3: 20 7f 17                     jsr     DrawDiagDownLeft  ;draw perspective edge
1fb6: a9 00                        lda     #0
1fb8: 85 07                        sta     char_vert
1fba: a9 10                        lda     #16
1fbc: 18                           clc
1fbd: 65 0c                        adc     ]counter
1fbf: 85 06                        sta     char_horiz
1fc1: 48                           pha
1fc2: a9 20                        lda     #$20              ;blank space
1fc4: a0 15                        ldy     #21
1fc6: 20 a7 17                     jsr     DrawGlyphsDown    ;erase column
1fc9: 68                           pla
1fca: 48                           pha
1fcb: 85 06                        sta     char_horiz
1fcd: c6 06                        dec     char_horiz
1fcf: a9 00                        lda     #$00
1fd1: 85 07                        sta     char_vert
1fd3: a9 03                        lda     #$03              ;vertical line, left edge
1fd5: a0 15                        ldy     #21
1fd7: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column
1fda: 68                           pla
1fdb: 48                           pha
1fdc: 85 06                        sta     char_horiz
1fde: c6 06                        dec     char_horiz
1fe0: c6 06                        dec     char_horiz
1fe2: a9 01                        lda     #1
1fe4: 85 07                        sta     char_vert
1fe6: 20 ef 11                     jsr     SetRowPtr
1fe9: a9 20                        lda     #$20              ;blank space
1feb: 20 92 11                     jsr     PrintSpecialChar
1fee: e6 07                        inc     char_vert
1ff0: c6 06                        dec     char_horiz
1ff2: c6 06                        dec     char_horiz
1ff4: 20 ef 11                     jsr     SetRowPtr
1ff7: a9 20                        lda     #$20              ;blank space
1ff9: 20 92 11                     jsr     PrintSpecialChar
1ffc: 68                           pla
1ffd: 85 06                        sta     char_horiz
1fff: c6 06                        dec     char_horiz
2001: c6 06                        dec     char_horiz
2003: a9 00                        lda     #0
2005: 85 07                        sta     char_vert
2007: a0 04                        ldy     #4
2009: 20 7f 17                     jsr     DrawDiagDownLeft  ;draw perspective edge
200c: e6 06                        inc     char_horiz
200e: e6 06                        inc     char_horiz
2010: a5 06                        lda     char_horiz
2012: 48                           pha
2013: a5 07                        lda     char_vert
2015: 48                           pha
2016: c6 07                        dec     char_vert
2018: a9 20                        lda     #$20              ;blank space
201a: a0 0f                        ldy     #15
201c: 20 a7 17                     jsr     DrawGlyphsDown    ;erase column
201f: e6 06                        inc     char_horiz
2021: 20 ef 11                     jsr     SetRowPtr
2024: a9 20                        lda     #$20              ;blank space
2026: 20 92 11                     jsr     PrintSpecialChar
2029: e6 07                        inc     char_vert
202b: 20 ef 11                     jsr     SetRowPtr
202e: a9 20                        lda     #$20              ;blank space
2030: 20 92 11                     jsr     PrintSpecialChar
2033: 68                           pla
2034: 85 07                        sta     char_vert
2036: 68                           pla
2037: 85 06                        sta     char_horiz
2039: c6 06                        dec     char_horiz
203b: a9 03                        lda     #$03              ;vertical line, left edge
203d: a0 0d                        ldy     #13
203f: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column
2042: a0 04                        ldy     #4
2044: 20 95 17                     jsr     DrawDiagDownRight ;draw perspective edge
2047: c6 0c                        dec     ]counter          ;are we done yet?
2049: f0 06                        beq     :Return           ;yes, bail
204b: 20 17 26                     jsr     ShortPause        ;pace animation
204e: 4c 25 1f                     jmp     :Loop

2051: 60           :Return         rts

                   ; 
                   ; Data for drawing a pit in the floor at different distances.  Each definition
                   ; takes 12 bytes: 3 bytes each for right edge, left edge, top edge, and bottom
                   ; edge.
                   ; The right/left edges are:
                   ;  +$00: horiz char position (0-22)
                   ;  +$01: vert char position (0-20)
                   ;  +$02: number of chars (1-20)
                   ; The top/bottom edges are:
                   ;  +$01-02: hi-res address (big-endian)
                   ;  +$03: number of chars (1-20)
                   ; 
2052: 11 11 04 05+ pit_data        .bulk   $11,$11,$04,$05,$11,$04,$40,$d4,$0d,$5e,$50,$15 ;1 space away
205e: 0e 0e 03 08+                 .bulk   $0e,$0e,$03,$08,$0e,$03,$43,$2f,$07,$5c,$54,$0d ;2 spaces away

206a: 88           ChkDrwPit       dey
206b: d0 7a                        bne     ChkDrwRoofHole
                   ; 
                   ; Feature $04: draw pit in floor.
                   ; 
                   ; Argument:
                   ;  $00: one space away
                   ;  $01: two spaces away
                   ; 
                   ]glyph_ctr      .var    $19    {addr/1}
                   ]tmp            .var    $1a    {addr/1}

206d: a9 52                        lda     #<pit_data        ;set pointer to pit data
206f: 85 0a                        sta     ]data_ptr
2071: a9 20                        lda     #>pit_data
2073: 85 0b                        sta     ]data_ptr+1
2075: a9 02                        lda     #$02
2077: 85 19                        sta     ]glyph_ctr        ;two lines (left/right)
2079: a5 0e                        lda     ]feat_arg         ;check distance
207b: f0 02                        beq     PitHoleCommon     ;zero, branch (note Y-reg=0 here)
207d: a0 0c                        ldy     #12               ;use second half
                   ; 
                   ; Common code for drawing a pit in the floor or a hole in the roof.  Y-reg
                   ; determines starting offset in table pointed to by $0a-0b.  Each entry is 12
                   ; bytes long, so Y-reg will be 0, 12, or 24.
207f: b1 0a        PitHoleCommon   lda     (]data_ptr),y     ;first byte is horizontal position
2081: 85 06                        sta     char_horiz
2083: c8                           iny
2084: b1 0a                        lda     (]data_ptr),y     ;second byte is vertical position
2086: 85 07                        sta     char_vert
2088: c8                           iny
2089: b1 0a                        lda     (]data_ptr),y     ;third byte is number of chars to output
208b: c8                           iny
208c: 85 1a                        sta     ]tmp              ;save height
208e: 98                           tya
208f: 48                           pha                       ;save Y-reg
2090: a5 1a                        lda     ]tmp              ;get height
2092: a8                           tay                       ;copy to Y-reg (could just "LDY")
2093: a9 02                        lda     #$02              ;compute glyph value by adding 2 to parameter
2095: 18                           clc                       ;first pass will be vertical/right, second pass
2096: 65 19                        adc     ]glyph_ctr        ; will be vertical/left
2098: 20 a7 17                     jsr     DrawGlyphsDown    ;draw vertical line of glyphs
209b: 68                           pla
209c: a8                           tay                       ;restore Y-reg
209d: c6 19                        dec     ]glyph_ctr        ;decrement counter / glyph adjustment
209f: d0 de                        bne     PitHoleCommon     ;loop
                   ; 
20a1: a9 02                        lda     #$02
20a3: 85 19                        sta     ]glyph_ctr        ;reset counter
20a5: b1 0a        :HLoop          lda     (]data_ptr),y     ;get high byte of hi-res pointer
20a7: 85 09                        sta     char_row_ptr+1
20a9: c8                           iny
20aa: b1 0a                        lda     (]data_ptr),y     ;get low byte of pointer
20ac: 85 08                        sta     char_row_ptr
20ae: c8                           iny
20af: b1 0a                        lda     (]data_ptr),y     ;get width, in character units
20b1: 85 1a                        sta     ]tmp              ;save width
20b3: c8                           iny
20b4: 98                           tya
20b5: 48                           pha                       ;save Y-reg
20b6: a5 1a                        lda     ]tmp              ;get width
20b8: a8                           tay
20b9: 20 77 17                     jsr     DrawLineHorizontal ;draw horizontal line
20bc: 68                           pla
20bd: a8                           tay                       ;restore Y-reg
20be: c6 19                        dec     ]glyph_ctr        ;decrement counter
20c0: d0 e3                        bne     :HLoop            ;loop if not done
20c2: 60                           rts

                   ; 
                   ; Data for drawing a hole in the roof.  Same format as the pit data, above.
20c3: 11 00 04 05+ roof_hole_data  .bulk   $11,$00,$04,$05,$00,$04,$40,$00,$15,$42,$04,$0d ;1 space away
20cf: 0e 04 03 08+                 .bulk   $0e,$04,$03,$08,$04,$03,$42,$04,$0d,$43,$87,$07 ;2 spaces away
20db: 0c 07 02 0a+                 .bulk   $0c,$07,$02,$0a,$07,$02,$43,$87,$07,$40,$b1,$03 ;3 spaces away

20e7: 88           ChkDrwRoofHole  dey
20e8: d0 1d                        bne     ChkDrwBoxes
                   ; 
                   ; Feature $05: hole in roof.
                   ; 
                   ; Argument (a little wonky):
                   ;  $00: 3 spaces away
                   ;  $01: 1 space away
                   ;  $02: 2 spaces away
                   ; 
20ea: a9 c3                        lda     #<roof_hole_data  ;set pointer to the roof hole data
20ec: 85 0a                        sta     ]data_ptr
20ee: a9 20                        lda     #>roof_hole_data
20f0: 85 0b                        sta     ]data_ptr+1
20f2: a9 02                        lda     #$02
20f4: 85 19                        sta     ]glyph_ctr        ;init glyph draw counter
20f6: a4 0e                        ldy     ]feat_arg         ;check distance
20f8: f0 08                        beq     :ThreeSpcAway     ;arg is zero, branch
20fa: 88                           dey
20fb: f0 82                        beq     PitHoleCommon     ;arg was 1, jump to common code with Y-reg=$00
20fd: a0 0c                        ldy     #12               ;offset for dist=2
20ff: 4c 7f 20                     jmp     PitHoleCommon

2102: a0 18        :ThreeSpcAway   ldy     #24               ;offset for dist=3
2104: 4c 7f 20                     jmp     PitHoleCommon

2107: 88           ChkDrwBoxes     dey
2108: f0 03                        beq     FeatBoxes
210a: 4c 72 22                     jmp     ChkDrwPrfSq

                   ; 
                   ; Feature $06: draw 0-4 visible boxes.
                   ; 
                   ; There can be up to four (large, medium, small, tiny) as we look into the
                   ; distance.
                   ; 
210d: ad 9b 61     FeatBoxes       lda     vis_box_flags     ;get box visibility flags
2110: 29 08                        and     #$08              ;is there a tiny box in the distance?
2112: f0 0e                        beq     :ChkSmall         ;no, branch
2114: a9 0b                        lda     #11
2116: 85 06                        sta     char_horiz
2118: 85 07                        sta     char_vert
211a: 20 ef 11                     jsr     SetRowPtr
211d: a9 0c                        lda     #$0c              ;tiny box
211f: 20 92 11                     jsr     PrintSpecialChar  ;draw it
                   ; 
2122: ad 9b 61     :ChkSmall       lda     vis_box_flags     ;get flags
2125: 29 04                        and     #$04              ;is there a small box?
2127: f0 34                        beq     :ChkMedium        ;no, branch
                   ; Draw small box.
2129: a9 0a                        lda     #10
212b: 85 06                        sta     char_horiz
212d: a9 0c                        lda     #12
212f: 85 07                        sta     char_vert
2131: 20 ef 11                     jsr     SetRowPtr
2134: a9 0d                        lda     #$0d              ;box top left
2136: 20 92 11                     jsr     PrintSpecialChar
2139: a9 10                        lda     #$10              ;double horizontal line, middle/bottom
213b: 20 92 11                     jsr     PrintSpecialChar
213e: a9 0e                        lda     #$0e              ;box top right
2140: 20 92 11                     jsr     PrintSpecialChar
2143: a9 0a                        lda     #10
2145: 85 06                        sta     char_horiz
2147: a9 0d                        lda     #13
2149: 85 07                        sta     char_vert
214b: 20 ef 11                     jsr     SetRowPtr
214e: a9 12                        lda     #$12              ;left/bottom 'L'
2150: 20 92 11                     jsr     PrintSpecialChar
2153: a9 13                        lda     #$13              ;horizontal line bottom
2155: 20 92 11                     jsr     PrintSpecialChar
2158: a9 0f                        lda     #$0f              ;box bottom right
215a: 20 92 11                     jsr     PrintSpecialChar
                   ; 
215d: ad 9b 61     :ChkMedium      lda     vis_box_flags     ;get flags
2160: 29 02                        and     #$02              ;is there a medium box?
2162: f0 67                        beq     :ChkLargeBox      ;no, branch
                   ; Draw medium box.
2164: a9 09                        lda     #9
2166: 85 06                        sta     char_horiz
2168: a9 0e                        lda     #14
216a: 85 07                        sta     char_vert
216c: 20 ef 11                     jsr     SetRowPtr
216f: a9 0d                        lda     #$0d              ;draw top of box
2171: 20 92 11                     jsr     PrintSpecialChar
2174: a9 10                        lda     #$10
2176: 20 92 11                     jsr     PrintSpecialChar
2179: a9 10                        lda     #$10
217b: 20 92 11                     jsr     PrintSpecialChar
217e: a9 10                        lda     #$10
2180: 20 92 11                     jsr     PrintSpecialChar
2183: a9 0e                        lda     #$0e
2185: 20 92 11                     jsr     PrintSpecialChar
2188: a9 09                        lda     #9
218a: 85 06                        sta     char_horiz
218c: a9 0f                        lda     #15
218e: 85 07                        sta     char_vert
2190: 20 ef 11                     jsr     SetRowPtr
2193: a9 03                        lda     #$03              ;vertical line, right edge
2195: 20 92 11                     jsr     PrintSpecialChar  ;draw, move right one
2198: e6 06                        inc     char_horiz        ;move over 3 more
219a: e6 06                        inc     char_horiz
219c: e6 06                        inc     char_horiz
219e: 20 ef 11                     jsr     SetRowPtr
21a1: a9 11                        lda     #$11              ;double vertical line, left and middle
21a3: 20 92 11                     jsr     PrintSpecialChar  ;draw and move right
21a6: c6 06                        dec     char_horiz        ;back up left
21a8: e6 07                        inc     char_vert         ;move down
21aa: 20 ef 11                     jsr     SetRowPtr
21ad: a9 0f                        lda     #$0f              ;bottom right corner of box
21af: 20 92 11                     jsr     PrintSpecialChar
21b2: a9 09                        lda     #9
21b4: 85 06                        sta     char_horiz        ;back to left edge
21b6: 20 ef 11                     jsr     SetRowPtr
21b9: a9 03                        lda     #$03              ;vertical line, left edge
21bb: 20 92 11                     jsr     PrintSpecialChar
21be: a9 40                        lda     #$40              ;line 136 + 8
21c0: 85 09                        sta     char_row_ptr+1
21c2: a9 d8                        lda     #$d8
21c4: 85 08                        sta     char_row_ptr
21c6: a0 04                        ldy     #4                ;draw 4 horizontal segments
21c8: 20 77 17                     jsr     DrawLineHorizontal
                   ; 
21cb: ad 9b 61     :ChkLargeBox    lda     vis_box_flags     ;get flags
21ce: 29 01                        and     #$01              ;is there a large box?
21d0: f0 73                        beq     :Return           ;no, branch
21d2: a9 0e                        lda     #14
21d4: 85 06                        sta     char_horiz
21d6: a9 11                        lda     #17
21d8: 85 07                        sta     char_vert
21da: 20 ef 11                     jsr     SetRowPtr
21dd: a9 02                        lda     #$02              ;diagonal line (slash)
21df: 20 92 11                     jsr     PrintSpecialChar
21e2: a9 07                        lda     #7
21e4: 85 06                        sta     char_horiz
21e6: 20 ef 11                     jsr     SetRowPtr
21e9: a0 07                        ldy     #7
21eb: 20 77 17                     jsr     DrawLineHorizontal
21ee: a9 02                        lda     #$02              ;diagonal line (slash)
21f0: 20 92 11                     jsr     PrintSpecialChar
21f3: a9 06                        lda     #6
21f5: 85 06                        sta     char_horiz
21f7: a9 12                        lda     #18
21f9: 85 07                        sta     char_vert
21fb: a9 04                        lda     #$04              ;vertical line, right edge
21fd: a0 03                        ldy     #3                ;draw 3 of them
21ff: 20 a7 17                     jsr     DrawGlyphsDown
2202: a9 0d                        lda     #13
2204: 85 06                        sta     char_horiz
2206: a9 12                        lda     #18
2208: 85 07                        sta     char_vert
220a: a9 04                        lda     #$04              ;vertical line, right edge
220c: a0 03                        ldy     #3                ;draw 3 of them
220e: 20 a7 17                     jsr     DrawGlyphsDown
2211: c6 07                        dec     char_vert
2213: e6 06                        inc     char_horiz
2215: 20 ef 11                     jsr     SetRowPtr
2218: a9 02                        lda     #$02
221a: 20 92 11                     jsr     PrintSpecialChar
221d: a9 41                        lda     #$41              ;line 144 + 6
221f: 85 09                        sta     char_row_ptr+1
2221: a9 56                        lda     #$56
2223: 85 08                        sta     char_row_ptr
2225: a0 07                        ldy     #7
2227: 20 77 17                     jsr     DrawLineHorizontal
222a: a9 0f                        lda     #15
222c: 85 06                        sta     char_horiz
222e: a9 11                        lda     #17
2230: 85 07                        sta     char_vert
2232: a9 03                        lda     #$03              ;vertical line, left edge
2234: a8                           tay                       ;draw 3 of them
2235: 20 a7 17                     jsr     DrawGlyphsDown
2238: a2 5e                        ldx     #$5e              ;line 167 + 6
223a: 86 09                        stx     char_row_ptr+1
223c: a2 56                        ldx     #$56
223e: 86 08                        stx     char_row_ptr
2240: a0 07                        ldy     #7
2242: 20 77 17                     jsr     DrawLineHorizontal
2245: 60           :Return         rts

                   ; Perfect Square graphics data, used when drawing on a side wall.  Two chars per
                   ; line, 7 lines high.
2246: 07 20        psq_left_data   .bulk   $07,$20
2248: 0b 07                        .bulk   $0b,$07
224a: 0b 0b                        .bulk   $0b,$0b
224c: 0b 0b                        .bulk   $0b,$0b
224e: 0b 0b                        .bulk   $0b,$0b
2250: 0b 09                        .bulk   $0b,$09
2252: 09 20                        .bulk   $09,$20
2254: 20 06        psq_right_data  .bulk   $20,$06
2256: 06 0b                        .bulk   $06,$0b
2258: 0b 0b                        .bulk   $0b,$0b
225a: 0b 0b                        .bulk   $0b,$0b
225c: 0b 0b                        .bulk   $0b,$0b
225e: 08 0b                        .bulk   $08,$0b
2260: 20 08                        .bulk   $20,$08
2262: 54 48 45 50+ perfect_square  .str    ‘THEPERFECTSQUARE’ ;written on the wall

2272: 88           ChkDrwPrfSq     dey
2273: f0 03                        beq     FeatPerfectSq
2275: 4c 47 23                     jmp     ChkDrwElevSide

                   ; 
                   ; Feature $07: The Perfect Square.
                   ; 
                   ; Argument:
                   ;   $01: right side, 1 space away
                   ;   $02: facing, 0 spaces away
                   ;   $04: left side, 1 space away
                   ; 
2278: a5 0e        FeatPerfectSq   lda     ]feat_arg
227a: c9 01                        cmp     #$01
227c: f0 7a                        beq     :DrawRightWall
227e: c9 04                        cmp     #$04
2280: d0 03                        bne     :DrawFacing
2282: 4c 32 23                     jmp     :DrawLeftWall

                   ; Draw when facing the square directly.  The "square" is 7 characters high and 7
                   ; wide, which fails to take into account that glyphs are 7x8.  (Perhaps
                   ; "perfect" is meant ironically?)
2285: a9 08        :DrawFacing     lda     #8                ;set text position
2287: 85 06                        sta     char_horiz
2289: 48                           pha                       ;push position on stack
228a: a9 07                        lda     #7
228c: 85 07                        sta     char_vert
228e: 48                           pha
228f: a9 0b        :SquareLoop     lda     #$0b              ;solid block
2291: a0 07                        ldy     #7                ;(change to 6 to improve squareness)
2293: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column of 7
2296: 68                           pla                       ;reset text position
2297: 85 07                        sta     char_vert
2299: 68                           pla
229a: 85 06                        sta     char_horiz
229c: e6 06                        inc     char_horiz        ;move over one character
229e: a5 06                        lda     char_horiz
22a0: c9 0f                        cmp     #15               ;have we reached column 15?
22a2: f0 07                        beq     :DrawText         ;yes, branch to draw text
22a4: 48                           pha                       ;no, push text position
22a5: a5 07                        lda     char_vert
22a7: 48                           pha
22a8: 4c 8f 22                     jmp     :SquareLoop       ;loop

                   ; Draw "the perfect square" text on the wall.
                   ]counter        .var    $1a    {addr/1}

22ab: a9 62        :DrawText       lda     #<perfect_square  ;get pointer to data
22ad: 85 0a                        sta     ]data_ptr
22af: a9 22                        lda     #>perfect_square
22b1: 85 0b                        sta     ]data_ptr+1
22b3: a9 0a                        lda     #10               ;set text position
22b5: 85 06                        sta     char_horiz
22b7: a9 04                        lda     #4
22b9: 85 07                        sta     char_vert
22bb: 20 ef 11                     jsr     SetRowPtr         ;set hi-res addr
22be: a9 03                        lda     #3                ;"the" = 3 chars
22c0: 85 1a                        sta     ]counter          ;set counter
22c2: 20 e6 22                     jsr     :DrawLoop         ;draw it
22c5: a9 08                        lda     #8                ;set position for next line
22c7: 85 06                        sta     char_horiz
22c9: a9 05                        lda     #5
22cb: 85 07                        sta     char_vert
22cd: 20 ef 11                     jsr     SetRowPtr
22d0: a9 07                        lda     #7                ;"perfect" = 7 chars
22d2: 85 1a                        sta     ]counter
22d4: 20 e6 22                     jsr     :DrawLoop         ;draw it
22d7: a9 09                        lda     #9
22d9: 85 06                        sta     char_horiz
22db: a9 06                        lda     #6
22dd: 85 07                        sta     char_vert
22df: 20 ef 11                     jsr     SetRowPtr
22e2: a9 06                        lda     #6                ;"square" = 6 chars
22e4: 85 1a                        sta     ]counter          ;set counter and fall through
                   ; 
22e6: a0 00        :DrawLoop       ldy     #$00
22e8: b1 0a                        lda     (]data_ptr),y     ;get char
22ea: 20 92 11                     jsr     PrintSpecialChar  ;print it
22ed: e6 0a                        inc     ]data_ptr         ;advance pointer
22ef: d0 02                        bne     :NoInc
22f1: e6 0b                        inc     ]data_ptr+1
22f3: c6 1a        :NoInc          dec     ]counter          ;decrement counter
22f5: d0 ef                        bne     :DrawLoop         ;loop if not done
22f7: 60                           rts

22f8: a9 54        :DrawRightWall  lda     #<psq_right_data  ;set up data for right side
22fa: 85 0a                        sta     ]data_ptr
22fc: a9 22                        lda     #>psq_right_data
22fe: 85 0b                        sta     ]data_ptr+1
2300: a9 13                        lda     #19               ;set text position
2302: 85 06                        sta     char_horiz
2304: a9 07                        lda     #7
2306: 85 07                        sta     char_vert
2308: 85 1a                        sta     ]counter          ;init counter
                   ; 
230a: 20 ef 11     :DrawArray      jsr     SetRowPtr
230d: a0 00                        ldy     #$00
230f: b1 0a                        lda     (]data_ptr),y     ;get character
2311: 20 92 11                     jsr     PrintSpecialChar  ;print it
2314: e6 0a                        inc     ]data_ptr         ;advance pointer
2316: d0 02                        bne     :NoInc1
2318: e6 0b                        inc     ]data_ptr+1
231a: a0 00        :NoInc1         ldy     #$00
231c: b1 0a                        lda     (]data_ptr),y     ;get character
231e: 20 92 11                     jsr     PrintSpecialChar  ;print it
2321: e6 0a                        inc     ]data_ptr         ;advance pointer
2323: d0 02                        bne     :NoInc2
2325: e6 0b                        inc     ]data_ptr+1
2327: e6 07        :NoInc2         inc     char_vert         ;move down one line
2329: c6 06                        dec     char_horiz        ;back up two
232b: c6 06                        dec     char_horiz
232d: c6 1a                        dec     ]counter          ;are we done?
232f: d0 d9                        bne     :DrawArray        ;not yet, loop
2331: 60                           rts

2332: a9 46        :DrawLeftWall   lda     #<psq_left_data   ;set up data for left side
2334: 85 0a                        sta     ]data_ptr
2336: a9 22                        lda     #>psq_left_data
2338: 85 0b                        sta     ]data_ptr+1
233a: a9 02                        lda     #2                ;set text position
233c: 85 06                        sta     char_horiz
233e: a9 07                        lda     #7
2340: 85 07                        sta     char_vert
2342: 85 1a                        sta     ]counter          ;init counter
2344: 4c 0a 23                     jmp     :DrawArray

2347: 88           ChkDrwElevSide  dey
2348: f0 03                        beq     FeatElevSide
234a: 4c 10 24                     jmp     ChkDrwKeyholes

                   ; 
                   ; Feature $08: draw elevator on left or right wall.
                   ; 
                   ; Argument:
                   ;  $01: right side, 2 spaces away
                   ;  $02: right side, 1 space away
                   ;  $04: left side, 1 space away
                   ; 
234d: a5 0e        FeatElevSide    lda     ]feat_arg
234f: c9 04                        cmp     #$04              ;on left side?
2351: d0 03                        bne     :DrawRight
2353: 4c dd 23                     jmp     :DrawLeftNear

2356: c9 02        :DrawRight      cmp     #$02
2358: f0 4e                        beq     :DrawRightNear
                   ; Draw on right side, two steps away.
235a: a9 10                        lda     #16
235c: 85 06                        sta     char_horiz
235e: a9 08                        lda     #8
2360: 85 07                        sta     char_vert
2362: 20 ef 11                     jsr     SetRowPtr
2365: a9 14                        lda     #$14              ;angled elevator top piece
2367: 20 92 11                     jsr     PrintSpecialChar
236a: e6 07                        inc     char_vert
236c: c6 06                        dec     char_horiz
236e: c6 06                        dec     char_horiz
2370: a9 0a                        lda     #$0a              ;double vertical line
2372: a0 05                        ldy     #5
2374: 20 a7 17                     jsr     DrawGlyphsDown
2377: 20 ef 11                     jsr     SetRowPtr
237a: a9 17                        lda     #$17              ;angled elevator bottom piece
237c: 20 92 11                     jsr     PrintSpecialChar
237f: e6 07                        inc     char_vert
2381: 20 ef 11                     jsr     SetRowPtr
2384: a9 15                        lda     #$15              ;angled elevator bottom piece
2386: 20 92 11                     jsr     PrintSpecialChar
2389: a9 10                        lda     #16
238b: 85 06                        sta     char_horiz
238d: a9 09                        lda     #9
238f: 85 07                        sta     char_vert
2391: a9 16                        lda     #$16              ;vertical line, middle
2393: a0 06                        ldy     #6
2395: 20 a7 17                     jsr     DrawGlyphsDown
2398: a9 11                        lda     #17
239a: 85 06                        sta     char_horiz
239c: a9 08                        lda     #8
239e: 85 07                        sta     char_vert
23a0: a9 03                        lda     #$03              ;vertical line, left edge
23a2: a0 08                        ldy     #$08
23a4: 20 a7 17                     jsr     DrawGlyphsDown
23a7: 60                           rts

23a8: a9 14        :DrawRightNear  lda     #20
23aa: 85 06                        sta     char_horiz
23ac: a9 04                        lda     #4
23ae: 85 07                        sta     char_vert
23b0: a0 02                        ldy     #2
23b2: 20 7f 17                     jsr     DrawDiagDownLeft
23b5: e6 06                        inc     char_horiz
23b7: a9 03                        lda     #$03              ;vertical line, left edge
23b9: a0 0c                        ldy     #12
23bb: 20 a7 17                     jsr     DrawGlyphsDown
23be: a9 14                        lda     #20
23c0: 85 06                        sta     char_horiz
23c2: a9 05                        lda     #5
23c4: 85 07                        sta     char_vert
23c6: a9 03                        lda     #$03              ;vertical line, left edge
23c8: a0 0e                        ldy     #14
23ca: 20 a7 17                     jsr     DrawGlyphsDown
23cd: a9 15                        lda     #$15              ;angled elevator bottom piece
23cf: 85 06                        sta     char_horiz
23d1: a9 04                        lda     #4
23d3: 85 07                        sta     char_vert
23d5: a9 03                        lda     #$03              ;vertical line, left edge
23d7: a0 10                        ldy     #16
23d9: 20 a7 17                     jsr     DrawGlyphsDown
23dc: 60                           rts

23dd: a9 02        :DrawLeftNear   lda     #2
23df: 85 06                        sta     char_horiz
23e1: a9 04                        lda     #4
23e3: 85 07                        sta     char_vert
23e5: a0 02                        ldy     #2
23e7: 20 95 17                     jsr     DrawDiagDownRight
23ea: c6 06                        dec     char_horiz
23ec: a9 04                        lda     #$04              ;vertical line, right edge
23ee: a0 0c                        ldy     #12
23f0: 20 a7 17                     jsr     DrawGlyphsDown
23f3: a9 02                        lda     #2
23f5: 85 06                        sta     char_horiz
23f7: a9 05                        lda     #5
23f9: 85 07                        sta     char_vert
23fb: a9 04                        lda     #$04              ;vertical line, right edge
23fd: a0 0e                        ldy     #14
23ff: 20 a7 17                     jsr     DrawGlyphsDown
2402: a9 01                        lda     #1
2404: 85 06                        sta     char_horiz
2406: a9 04                        lda     #4                ;(also used as char value)
2408: 85 07                        sta     char_vert
240a: a0 10                        ldy     #16
240c: 20 a7 17                     jsr     DrawGlyphsDown
240f: 60                           rts

2410: 88           ChkDrwKeyholes  dey
2411: f0 03                        beq     FeatKeyholes
2413: 4c 4c 25                     jmp     ElevOpenAnim

                   ; 
                   ; Feature $09: draw 1-4 keyholes on the left or right side of the hall.
                   ; 
                   ; Argument is a bit mask with 4 bits for left side and 4 for right, with lower
                   ; bits for nearer cells.  Four keyholes on left is $f0, four on right is $0f,
                   ; and if you stand at (10,10) and look west you can see a blank wall followed by
                   ; 3 keyholes on the left (arg=$0e).
                   ; 
2416: a5 0e        FeatKeyholes    lda     ]feat_arg
2418: 29 0f                        and     #$0f
241a: f0 33                        beq     :DrawKHOnLeft
                   ; Draw keyholes on right-side walls.
241c: 29 08                        and     #$08              ;need tiny?
241e: f0 07                        beq     :ChkSmall         ;no, branch
2420: a9 0c                        lda     #12
2422: 85 06                        sta     char_horiz
2424: 20 3f 25                     jsr     DrawTinyKeyhole   ;draw tiny
2427: a5 0e        :ChkSmall       lda     ]feat_arg
2429: 29 04                        and     #$04              ;need small?
242b: f0 07                        beq     :ChkMedium        ;no, branch
242d: a9 0d                        lda     #13
242f: 85 06                        sta     char_horiz
2431: 20 2d 25                     jsr     DrawSmallKeyhole  ;draw small
2434: a5 0e        :ChkMedium      lda     ]feat_arg
2436: 29 02                        and     #$02              ;need medium?
2438: f0 07                        beq     :IsLarge          ;no, branch
243a: a9 0f                        lda     #15
243c: 85 06                        sta     char_horiz
243e: 20 e2 24                     jsr     DrawMediumKeyhole ;draw medium
2441: a5 0e        :IsLarge        lda     ]feat_arg
2443: 29 01                        and     #$01              ;need large?
2445: f0 07                        beq     :Return           ;no, branch
2447: a9 13                        lda     #19
2449: 85 06                        sta     char_horiz
244b: 20 84 24                     jsr     DrawLargeKeyhole  ;draw large
244e: 60           :Return         rts

                   ; Draw keyholes on left-side walls.
244f: a5 0e        :DrawKHOnLeft   lda     ]feat_arg
2451: 29 10                        and     #$10              ;need large?
2453: f0 07                        beq     :ChkMedium        ;no, branch
2455: a9 02                        lda     #2
2457: 85 06                        sta     char_horiz
2459: 20 84 24                     jsr     DrawLargeKeyhole  ;draw large
245c: a5 0e        :ChkMedium      lda     ]feat_arg
245e: 29 20                        and     #$20              ;need medium?
2460: f0 07                        beq     :ChkSmall         ;no, branch
2462: a9 05                        lda     #5
2464: 85 06                        sta     char_horiz
2466: 20 e2 24                     jsr     DrawMediumKeyhole ;draw medium
2469: a5 0e        :ChkSmall       lda     ]feat_arg
246b: 29 40                        and     #$40              ;need small?
246d: f0 07                        beq     :ChkTiny          ;no, branch
246f: a9 08                        lda     #8
2471: 85 06                        sta     char_horiz
2473: 20 2d 25                     jsr     DrawSmallKeyhole  ;draw small
2476: a5 0e        :ChkTiny        lda     ]feat_arg
2478: 29 80                        and     #$80              ;need tiny?
247a: f0 07                        beq     :Return           ;no, branch
247c: a9 0a                        lda     #10
247e: 85 06                        sta     char_horiz
2480: 20 3f 25                     jsr     DrawTinyKeyhole   ;draw tiny
2483: 60           :Return         rts

                   DrawLargeKeyhole
2484: a9 08                        lda     #8
2486: 85 07                        sta     char_vert
2488: 20 ef 11                     jsr     SetRowPtr
248b: a9 7c                        lda     #$7c              ;keyhole top left
248d: 20 92 11                     jsr     PrintSpecialChar
2490: a9 7d                        lda     #$7d              ;keyhole top right
2492: 20 92 11                     jsr     PrintSpecialChar
2495: e6 07                        inc     char_vert
2497: c6 06                        dec     char_horiz
2499: c6 06                        dec     char_horiz
249b: 20 ef 11                     jsr     SetRowPtr
249e: a9 0b                        lda     #$0b              ;solid block
24a0: 20 92 11                     jsr     PrintSpecialChar
24a3: a9 0b                        lda     #$0b              ;solid block
24a5: 20 92 11                     jsr     PrintSpecialChar
24a8: e6 07                        inc     char_vert
24aa: c6 06                        dec     char_horiz
24ac: c6 06                        dec     char_horiz
24ae: 20 ef 11                     jsr     SetRowPtr
24b1: a9 7e                        lda     #$7e              ;keyhole mid bottom left
24b3: 20 92 11                     jsr     PrintSpecialChar
24b6: a9 7f                        lda     #$7f              ;keyhole mid bottom right
24b8: 20 92 11                     jsr     PrintSpecialChar
24bb: e6 07                        inc     char_vert
24bd: c6 06                        dec     char_horiz
24bf: c6 06                        dec     char_horiz
24c1: 20 ef 11                     jsr     SetRowPtr
24c4: a9 1f                        lda     #$1f              ;keyhole bottom top left
24c6: 20 92 11                     jsr     PrintSpecialChar
24c9: a9 7b                        lda     #$7b              ;keyhole bottom top right
24cb: 20 92 11                     jsr     PrintSpecialChar
24ce: e6 07                        inc     char_vert
24d0: c6 06                        dec     char_horiz
24d2: c6 06                        dec     char_horiz
24d4: 20 ef 11                     jsr     SetRowPtr
24d7: a9 0b                        lda     #$0b              ;solid block
24d9: 20 92 11                     jsr     PrintSpecialChar
24dc: a9 0b                        lda     #$0b              ;solid block
24de: 20 92 11                     jsr     PrintSpecialChar
24e1: 60                           rts

                   DrawMediumKeyhole
24e2: a9 09                        lda     #9
24e4: 85 07                        sta     char_vert
24e6: 20 ef 11                     jsr     SetRowPtr
24e9: a9 1e                        lda     #$1e              ;top left part
24eb: 20 a4 11                     jsr     DrawGlyph
24ee: a9 0b                        lda     #$0b              ;solid block
24f0: 20 92 11                     jsr     PrintSpecialChar
24f3: a9 1d                        lda     #$1d              ;top right part
24f5: 20 92 11                     jsr     PrintSpecialChar
24f8: e6 07                        inc     char_vert
24fa: c6 06                        dec     char_horiz
24fc: c6 06                        dec     char_horiz
24fe: c6 06                        dec     char_horiz
2500: 20 ef 11                     jsr     SetRowPtr
2503: a9 5f                        lda     #$5f              ;mid-bottom left part
2505: 20 a4 11                     jsr     DrawGlyph
2508: a9 0b                        lda     #$0b              ;solid block
250a: 20 92 11                     jsr     PrintSpecialChar
250d: a9 60                        lda     #$60              ;mid-bottom right part
250f: 20 a4 11                     jsr     DrawGlyph
2512: e6 07                        inc     char_vert
2514: c6 06                        dec     char_horiz
2516: c6 06                        dec     char_horiz
2518: c6 06                        dec     char_horiz
251a: 20 ef 11                     jsr     SetRowPtr
251d: a9 1c                        lda     #$1c              ;bottom left part (half block)
251f: 20 92 11                     jsr     PrintSpecialChar
2522: a9 0b                        lda     #$0b              ;solid block
2524: 20 92 11                     jsr     PrintSpecialChar
2527: a9 1b                        lda     #$1b              ;bottom right part (half block)
2529: 20 92 11                     jsr     PrintSpecialChar
252c: 60                           rts

                   DrawSmallKeyhole
252d: a9 0a                        lda     #10
252f: 85 07                        sta     char_vert
2531: 20 ef 11                     jsr     SetRowPtr
2534: a9 19                        lda     #$19              ;small keyhole, left
2536: 20 92 11                     jsr     PrintSpecialChar
2539: a9 1a                        lda     #$1a              ;small keyhole, right
253b: 20 92 11                     jsr     PrintSpecialChar
253e: 60                           rts

253f: a9 0a        DrawTinyKeyhole lda     #10
2541: 85 07                        sta     char_vert
2543: 20 ef 11                     jsr     SetRowPtr
2546: a9 18                        lda     #$18              ;tiny keyhole
2548: 20 92 11                     jsr     PrintSpecialChar
254b: 60                           rts

                   ; 
                   ; Feature $0a: show animated elevator opening
                   ; 
                   • Clear variables
                   ]left_posn      .var    $0c    {addr/1}
                   ]width          .var    $10    {addr/1}
                   ]counter        .var    $11    {addr/1}
                   ]right_posn     .var    $19    {addr/1}

254c: a9 0a        ElevOpenAnim    lda     #10               ;set text position
254e: 85 06                        sta     char_horiz
2550: a9 03                        lda     #3                ;(also glyph: $03 vertical line, left edge)
2552: 85 07                        sta     char_vert
2554: a0 12                        ldy     #18
2556: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column
2559: a9 0b                        lda     #11
255b: 85 06                        sta     char_horiz
255d: a9 03                        lda     #3
255f: 85 07                        sta     char_vert
2561: a9 04                        lda     #$04              ;vertical line, right edge
2563: a0 12                        ldy     #18
2565: 20 a7 17                     jsr     DrawGlyphsDown
2568: a9 40                        lda     #$40              ;$40d9+1 = row 136 col 10
256a: 85 09                        sta     char_row_ptr+1
256c: a9 d9                        lda     #$d9
256e: 85 08                        sta     char_row_ptr
2570: a0 02                        ldy     #$02
2572: 20 77 17                     jsr     DrawLineHorizontal
2575: a9 0a                        lda     #10
2577: 85 0c                        sta     ]left_posn
2579: a9 0b                        lda     #11
257b: 85 19                        sta     ]right_posn
257d: a9 04                        lda     #4
257f: 85 11                        sta     ]counter          ;4 steps
2581: a9 02                        lda     #2
2583: 85 10                        sta     ]width            ;initial door separation
2585: 20 17 26     :Loop           jsr     ShortPause
                   ; Erase left/right verticals.
2588: a5 0c                        lda     ]left_posn        ;erase left edge
258a: 85 06                        sta     char_horiz
258c: a9 03                        lda     #3
258e: 85 07                        sta     char_vert
2590: a9 20                        lda     #$20              ;blank space
2592: a0 12                        ldy     #18
2594: 20 a7 17                     jsr     DrawGlyphsDown    ;erase column
2597: a5 19                        lda     ]right_posn
2599: 85 06                        sta     char_horiz
259b: a9 03                        lda     #3
259d: 85 07                        sta     char_vert
259f: a9 20                        lda     #$20              ;blank space
25a1: a0 12                        ldy     #18
25a3: 20 a7 17                     jsr     DrawGlyphsDown    ;erase column
                   ; Advance left/right edges and draw.
25a6: c6 0c                        dec     ]left_posn
25a8: e6 19                        inc     ]right_posn
25aa: a5 0c                        lda     ]left_posn
25ac: 85 06                        sta     char_horiz
25ae: a9 03                        lda     #3                ;(also glyph $03 vertical line, left edge)
25b0: 85 07                        sta     char_vert
25b2: a0 12                        ldy     #18
25b4: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column
25b7: a5 19                        lda     ]right_posn
25b9: 85 06                        sta     char_horiz
25bb: a9 03                        lda     #3
25bd: 85 07                        sta     char_vert
25bf: a9 04                        lda     #$04              ;vertical line, right edge
25c1: a0 12                        ldy     #18
25c3: 20 a7 17                     jsr     DrawGlyphsDown    ;draw column
                   ; Draw horizontal component.
25c6: a9 11                        lda     #17
25c8: 85 07                        sta     char_vert
25ca: c6 0c                        dec     ]left_posn        ;back up one
25cc: a5 0c                        lda     ]left_posn        ;get value
25ce: e6 0c                        inc     ]left_posn        ;restore value
25d0: 85 06                        sta     char_horiz        ;save value (could be LDA/STA/DEC?)
25d2: 20 ef 11                     jsr     SetRowPtr
25d5: e6 10                        inc     ]width            ;increase width by 2
25d7: e6 10                        inc     ]width
25d9: a4 10                        ldy     ]width            ;get width
25db: 20 77 17                     jsr     DrawLineHorizontal ;draw line
25de: c6 11                        dec     ]counter          ;are we done yet?
25e0: d0 a3                        bne     :Loop             ;no, loop
25e2: 60                           rts

                   ; 
                   ; Prints a string from the list of nouns.
                   ; 
                   ; On entry:
                   ;   A-reg: noun index ($01-23)
                   ; 
                   • Clear variables
                   ]noun_index     .var    $13    {addr/1}

25e3: 85 13        PrintNoun       sta     ]noun_index       ;save index
25e5: a9 73                        lda     #<noun_list       ;get pointer to text strings
25e7: 85 0c                        sta     string_ptr
25e9: a9 67                        lda     #>noun_list
25eb: 85 0d                        sta     string_ptr+1
25ed: a0 00                        ldy     #$00
25ef: b1 0c        :ScanLoop       lda     (string_ptr),y
25f1: 30 08                        bmi     :FoundStart       ;found start of word, branch
25f3: e6 0c        :Loop1          inc     string_ptr        ;advance pointer
25f5: d0 f8                        bne     :ScanLoop
25f7: e6 0d                        inc     string_ptr+1
25f9: d0 f4                        bne     :ScanLoop         ;(always)

25fb: c6 13        :FoundStart     dec     ]noun_index
25fd: d0 f4                        bne     :Loop1            ;nouns are 2+ letters, so skip next read
                   ; Print noun.
25ff: b1 0c                        lda     (string_ptr),y    ;get char
2601: 29 7f                        and     #%01111111        ;strip high bit
2603: 20 92 11     :PrintLoop      jsr     PrintSpecialChar  ;print it
2606: e6 0c                        inc     string_ptr        ;advance to next char
2608: d0 02                        bne     :NoInc
260a: e6 0d                        inc     string_ptr+1
260c: a0 00        :NoInc          ldy     #$00
260e: b1 0c                        lda     (string_ptr),y    ;get char
2610: 10 f1                        bpl     :PrintLoop        ;if not start of next word, branch
2612: a9 20                        lda     #‘ ’
2614: 4c 92 11                     jmp     PrintSpecialChar  ;print a space

                   ; 
                   ; Pause briefly.
                   ; 
                   ]counter1       .var    $0e    {addr/1}
                   ]counter2       .var    $0f    {addr/1}

2617: a2 28        ShortPause      ldx     #40
2619: 86 0f                        stx     ]counter2
261b: c6 0e        :Loop           dec     ]counter1
261d: d0 fc                        bne     :Loop
261f: c6 0f                        dec     ]counter2
2621: d0 f8                        bne     :Loop
2623: 60                           rts

2624: 10 ad 09 01+                 .junk   28

                   ; 
                   ; Execute parsed input.  Does not handle movement commands (see $0949).
                   ; 
                   ; Verbs $01-0d are things like "eat" and "drop", operating on inventory objects.
                   ; Verbs $0e-1c are more general, and may apply to object in the inventory or
                   ; environment ("open"), or may not need a noun ("charge").
                   ; 
                   ; Note nouns were adjusted, from word $1d-3f to noun $01-23.  Nouns $01-13 are
                   ; names of inventory objects, $14-23 aren't exactly (box, dog, calculator
                   ; buttons, etc).
                   ; 
                   ; On entry, the results of parsing the verb and noun are at $619c and $619d.
                   ; 
                   • Clear variables
                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}
                   ]inv_obj_data   .var    $11    {addr/1}

2640: ad 9d 61     ExecParsedInput lda     parsed_noun       ;copy noun/verb to ZP
2643: 85 0e                        sta     ]noun_index
2645: ad 9c 61                     lda     parsed_verb
2648: 85 0f                        sta     ]verb_index
264a: c9 0e                        cmp     #$0e              ;is verb $00-0d (requires inventory-able object)?
264c: 30 03                        bmi     :InvObjReq        ;yes, branch
264e: 4c 1b 2b                     jmp     ChkMoreVerbs      ;no, jump to additional handlers

2651: a5 0e        :InvObjReq      lda     ]noun_index
2653: c9 15                        cmp     #$15              ;is noun a suitable object?
2655: 30 03                        bmi     :IsInvObj         ;yes, branch
2657: 4c 5a 10                     jmp     PrintLittleSense  ;no, complain

                   ; Check to see if the item is in the inventory.  If not, print an error message
                   ; and pop this address off the stack.  The return value in A-reg is either the
                   ; object state ($07/08) or, for food/torches, the object index ($12-17).
265a: 20 97 0b     :IsInvObj       jsr     CheckInventory    ;find object, or error and pop
265d: 85 11                        sta     ]inv_obj_data     ;save state or index
265f: ad 9d 61                     lda     parsed_noun       ;copy noun to ZP, again (trashed by inventory check)
2662: 85 0e                        sta     ]noun_index
2664: ad 9c 61                     lda     parsed_verb       ;copy verb to ZP, again
2667: 85 0f                        sta     ]verb_index
2669: c6 0f                        dec     ]verb_index       ;decrement to see if value = 1
266b: d0 3e                        bne     ChkVerbBlow       ;no, branch to check next verb
                   ; 
                   ; Verb $01: RAISe.
                   ; 
266d: a9 0b                        lda     #$0b              ;ring?
266f: c5 0e                        cmp     ]noun_index
2671: f0 0f                        beq     :IsRing           ;yes, branch
2673: a9 0d                        lda     #$0d              ;staff?
2675: c5 0e                        cmp     ]noun_index
2677: f0 05                        beq     :IsStaff          ;yes, branch
2679: a9 1f        :HavingFun      lda     #$1f              ;no; "having fun?"
267b: 4c a4 08     :MsgAndReturn   jmp     DrawMsgN_Row23

267e: a9 73        :IsStaff        lda     #$73              ;"the staff begins to quake"
2680: d0 f9                        bne     :MsgAndReturn     ;(always)

                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]inv_obj_state  .var    $1a    {addr/1}

2682: ad 94 61     :IsRing         lda     plyr_floor        ;check what floor we're on
2685: c9 05                        cmp     #$05
2687: d0 f0                        bne     :HavingFun        ;not five, ring does nothing; branch
2689: a9 07                        lda     #$07
268b: c5 1a                        cmp     ]inv_obj_state    ;already activated?
268d: f0 ea                        beq     :HavingFun        ;yes, nothing to do
268f: a9 0b                        lda     #$0b              ;ring
2691: 85 0e                        sta     ]func_arg
2693: a9 03                        lda     #FN_ACTIVATE_OBJ
2695: 85 0f                        sta     ]func_cmd
2697: 20 34 1a                     jsr     ObjMgmtFunc       ;activate ring
269a: a9 01                        lda     #$01
269c: 8d 9e 61                     sta     illumination_flag ;fiat lux
269f: 20 15 10                     jsr     DrawMaze
26a2: a9 71                        lda     #$71              ;"the ring is activated and"
26a4: 20 92 08                     jsr     DrawMsgN_Row22
26a7: a9 72                        lda     #$72              ;"shines light everywhere"
26a9: d0 d0                        bne     :MsgAndReturn     ;(always)

                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

26ab: c6 0f        ChkVerbBlow     dec     ]verb_index
26ad: d0 32                        bne     ChkVerbBrea
                   ; 
                   ; Verb $02: BLOW.
                   ; 
26af: a5 0e                        lda     ]noun_index
26b1: c9 05                        cmp     #$05              ;flute?
26b3: f0 28                        beq     :BlowFlute        ;yes, branch
26b5: c9 08                        cmp     #$08              ;horn?
26b7: d0 c0                        bne     :HavingFun        ;no, branch
26b9: ad 94 61                     lda     plyr_floor        ;get current floor
26bc: c9 05                        cmp     #$05              ;5th floor?
26be: d0 12                        bne     :NoSpec           ;no, nothing special for the horn to do
26c0: ad a5 61                     lda     special_zone      ;check zone
26c3: c9 09                        cmp     #$09              ;monster mother active?
26c5: d0 0b                        bne     :NoSpec           ;no, branch
26c7: a9 08                        lda     #$08              ;horn
26c9: 85 0e                        sta     ]noun_index
26cb: a9 03                        lda     #FN_ACTIVATE_OBJ
26cd: 85 0f                        sta     ]verb_index
26cf: 20 34 1a                     jsr     ObjMgmtFunc
26d2: a9 7f        :NoSpec         lda     #$7f              ;"a deafening roar evelopes"
26d4: 20 92 08                     jsr     DrawMsgN_Row22
26d7: a9 80                        lda     #$80              ;"you. Your ears are ringing"
26d9: 20 a4 08                     jsr     DrawMsgN_Row23
26dc: 60                           rts

26dd: a9 09        :BlowFlute      lda     #$09              ;PLAY ($0b - 2)
26df: 85 0f                        sta     ]verb_index
26e1: c6 0f        ChkVerbBrea     dec     ]verb_index
26e3: d0 71                        bne     ChkVerbBurn
                   ; 
                   ; Verb $03: BREAk.
                   ; 
                   ]zp10           .var    $10    {addr/1}
                   ]noun_tmp       .var    $13    {addr/1}

26e5: a5 0e                        lda     ]noun_index
26e7: c9 0b                        cmp     #$0b              ;ring?
26e9: d0 03                        bne     :NotRing
26eb: 20 1d 28                     jsr     RingGone          ;do special handling
26ee: c9 12        :NotRing        cmp     #$12              ;food or torch?
26f0: 30 1b                        bmi     :NotFoodTorch     ;no, branch
26f2: 85 13                        sta     ]noun_tmp
26f4: a5 10                        lda     ]zp10             ;preserve $10/$11
26f6: 48                           pha
26f7: a5 11                        lda     ]inv_obj_data     ;get object index
26f9: 48                           pha
26fa: a5 13                        lda     ]noun_tmp         ;check the noun
26fc: c9 13                        cmp     #$13              ;torch?
26fe: d0 03                        bne     :NotTorch         ;no, branch
2700: 20 23 27                     jsr     DiscardTorch      ;yes, discard a torch
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

2703: 68           :NotTorch       pla                       ;restore $10/$11
2704: 85 11                        sta     ]inv_obj_data
2706: 68                           pla
2707: 85 10                        sta     ]zp10
2709: a5 11                        lda     ]inv_obj_data     ;get object index
270b: 85 0e                        sta     ]func_arg         ;pass as argument
                   ; In the common case, $0f has been counted down to zero, so this call will
                   ; delete the object with the matching noun index.  For food/torches we need the
                   ; object index, which requires special handling.
                   ; 
                   ; For those cases, however, $0f has not been set, so this next call may not
                   ; actually do what is expected.  For example, "break torch" while holding an
                   ; unlit torch had $0f=$61.  (BUG)
270d: 20 34 1a     :NotFoodTorch   jsr     ObjMgmtFunc       ;destroy object
2710: 20 15 10                     jsr     DrawMaze
2713: a9 4e                        lda     #$4e              ;"you break the"
2715: 20 92 08                     jsr     DrawMsgN_Row22
2718: ad 9d 61                     lda     parsed_noun
271b: 20 e3 25                     jsr     PrintNoun         ;(should be a ' ' before this)
271e: a9 4f                        lda     #$4f              ;"and it disappears"
2720: 4c a4 08                     jmp     DrawMsgN_Row23

                   ; 
                   ; Handles situations where we lose a torch (eat torch, throw torch, etc).  Use
                   ; an unlit torch if we have one, otherwise use the lit torch.
                   ; 
2723: ad 98 61     DiscardTorch    lda     num_unlit_torches ;do we have any unlit torches
2726: d0 1b                        bne     :UseUnlit         ;yes, branch
2728: ce 97 61                     dec     num_lit_torches   ;decrement lit torches
272b: ad 94 61                     lda     plyr_floor        ;check floor
272e: c9 05                        cmp     #$05              ;are we on the 5th?
2730: f0 10                        beq     :Return           ;yes, torches don't work here; we're done
2732: a9 00                        lda     #$00
2734: 8d a1 61                     sta     torch_level       ;set light level to zero
2737: 8d 9e 61                     sta     illumination_flag
273a: 20 88 27                     jsr     PushSpecialZone
273d: a9 0a                        lda     #$0a              ;monster in the dark
273f: 8d a5 61                     sta     special_zone
2742: 60           :Return         rts

2743: ce 98 61     :UseUnlit       dec     num_unlit_torches ;decrement unlit torches
2746: a9 0e                        lda     #FN_FIND_UNLIT_T
2748: 85 0f                        sta     ]func_cmd
274a: 20 34 1a                     jsr     ObjMgmtFunc       ;find an unlit torch item
274d: 85 0e                        sta     ]func_arg
274f: a9 00                        lda     #FN_DESTROY_OBJ
2751: 85 0f                        sta     ]func_cmd
2753: 4c 34 1a                     jmp     ObjMgmtFunc       ;destroy it

2756: c6 0f        ChkVerbBurn     dec     ]func_cmd
2758: d0 3f                        bne     ChkVerbEat
                   ; 
                   ; Verb $04: BURN.
                   ; 
275a: ad 97 61                     lda     num_lit_torches   ;do we have a lit torch?
275d: f0 25                        beq     :NoneLit          ;no, branch
275f: a5 0e                        lda     ]func_arg         ;get noun index
2761: c9 0b                        cmp     #$0b              ;ring?
2763: d0 03                        bne     :NotRing          ;no, branch
2765: 20 1d 28                     jsr     RingGone          ;yes, destroy ring
2768: c9 12        :NotRing        cmp     #$12              ;inventory object?
276a: 30 08                        bmi     :BurnObj          ;yes, trash it
276c: c9 13                        cmp     #$13              ;torch?
276e: f0 25                        beq     BurnTorch         ;yes, handle with LIGHT
2770: a5 11                        lda     ]inv_obj_data     ;must be food; get object index
2772: 85 0e                        sta     ]func_arg
2774: 20 34 1a     :BurnObj        jsr     ObjMgmtFunc       ;destroy ($0f holds zero)
2777: 20 5f 10                     jsr     ClearMessages
277a: a9 52                        lda     #$52              ;"it vanishes in a"
277c: 20 92 08                     jsr     DrawMsgN_Row22
277f: a9 53                        lda     #$53              ;"burst of flames"
2781: 4c a4 08     :PrintMsg       jmp     DrawMsgN_Row23

2784: a9 88        :NoneLit        lda     #$88              ;"you have no fire"
2786: d0 f9                        bne     :PrintMsg         ;(always)

                   ; 
                   ; Push the special zone stack to make room for a new item.  Does not alter the
                   ; current zone.
                   ; 
2788: ad a6 61     PushSpecialZone lda     special_zone1
278b: 8d a7 61                     sta     special_zone2
278e: ad a5 61                     lda     special_zone
2791: 8d a6 61                     sta     special_zone1
2794: 60                           rts

                   ; Change BURN TORCH to LIGHT TORCH.
                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

2795: a9 06        BurnTorch       lda     #$06              ;set verb to LIGH ($0a - 4)
2797: 85 0f                        sta     ]verb_index       ; and fall through into verb switch
                   ; 
2799: c6 0f        ChkVerbEat      dec     ]verb_index
279b: f0 03                        beq     HndVerbEat
279d: 4c 39 28                     jmp     ChkVerbThro

                   ; 
                   ; Verb $05: CHEW / EAT.
                   ; 
27a0: a5 0e        HndVerbEat      lda     ]noun_index       ;get noun index
27a2: c9 0b                        cmp     #$0b              ;ring?
27a4: d0 03                        bne     :EatThing         ;no, branch
27a6: 20 1d 28                     jsr     RingGone          ;do special stuff then fall through
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

27a9: c9 12        :EatThing       cmp     #$12              ;non-food inventory object?
27ab: 30 0a                        bmi     :EatObj           ;yes, destroy it
27ad: f0 3c                        beq     :EatFood          ;food, handle that
27af: c9 13                        cmp     #$13              ;torch?
27b1: f0 26                        beq     :EatTorch         ;yes, go eat a torch (always?)
27b3: a5 11        :EatTorch2      lda     ]inv_obj_data     ;get torch object index
27b5: 85 0e                        sta     ]func_arg         ;pass as argument
                   ; $0e holds either the noun index or, for food/torch, the object index.
                   ; $0f holds $00 if we got here for a non-torch object, or a useless value ($61)
                   ; if we jumped here from $27e8 after discarding the torch. (This might be
                   ; considered a bug, but we don't want the function to do anything and $61 does
                   ; nothing... so it's wasting time but it's not incorrect.)
27b7: 20 34 1a     :EatObj         jsr     ObjMgmtFunc       ;destroy object ($0f == 0)
27ba: 20 15 10                     jsr     DrawMaze
27bd: a9 7d                        lda     #$7d              ;"You eat the"
27bf: 20 92 08                     jsr     DrawMsgN_Row22
27c2: a9 20                        lda     #‘ ’
27c4: 20 92 11                     jsr     PrintSpecialChar
27c7: ad 9d 61                     lda     parsed_noun       ;get noun index
27ca: 20 e3 25                     jsr     PrintNoun         ;print the noun
27cd: a9 7e                        lda     #$7e              ;"and you get heartburn"
27cf: 20 a4 08     :DrawMsgInv     jsr     DrawMsgN_Row23
27d2: a9 07                        lda     #FN_DRAW_INV
27d4: 85 0f                        sta     ]func_cmd
27d6: 4c 34 1a                     jmp     ObjMgmtFunc       ;redraw inventory

27d9: a5 10        :EatTorch       lda     ]zp10             ;if player has 1 lit torch and 0 unlit torches,
27db: 48                           pha                       ; they got a "you will do no such thing" earlier
27dc: a5 11                        lda     ]inv_obj_data     ;preserve $10/$11
27de: 48                           pha
27df: 20 23 27                     jsr     DiscardTorch
27e2: 68                           pla
27e3: 85 11                        sta     ]inv_obj_data     ;restore $10/$11
27e5: 68                           pla
27e6: 85 10                        sta     ]zp10
27e8: 4c b3 27                     jmp     :EatTorch2        ;(torch already destroyed; should JMP $27ba)

27eb: a5 11        :EatFood        lda     ]inv_obj_data     ;get food object index
27ed: 85 0e                        sta     ]func_arg
27ef: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy object ($0f == 0)
                   ]tmp1           .var    $0e    {addr/2}
                   ]tmp2           .var    $19    {addr/2}

27f2: ad 9f 61                     lda     food_level_hi     ;add 170 to food level
27f5: 85 0f                        sta     ]tmp1+1           ; (in a really convoluted way)
27f7: ad a0 61                     lda     food_level_lo
27fa: 85 0e                        sta     ]tmp1
27fc: a9 aa                        lda     #170
27fe: 85 19                        sta     ]tmp2
2800: a9 00                        lda     #0
2802: 85 1a                        sta     ]tmp2+1
                   ; 
2804: 18                           clc
2805: a5 19                        lda     ]tmp2
2807: 65 0e                        adc     ]tmp1
2809: 85 0e                        sta     ]tmp1
280b: a5 1a                        lda     ]tmp2+1
280d: 65 0f                        adc     ]tmp1+1
280f: 85 0f                        sta     ]tmp1+1
2811: 8d 9f 61                     sta     food_level_hi
2814: a5 0e                        lda     ]tmp1
2816: 8d a0 61                     sta     food_level_lo
2819: a9 58                        lda     #$58              ;"the food is being digested"
281b: d0 b2                        bne     :DrawMsgInv       ;(always)

                   ; 
                   ; Handle the consequences of losing the ring (e.g. eating it), which may be the
                   ; current source of light.
                   ; 
                   ; On exit:
                   ;   A-reg: $0b (noun index for "ring")
                   ; 
281d: ad 94 61     RingGone        lda     plyr_floor
2820: c9 05                        cmp     #$05              ;5th floor?
2822: d0 12                        bne     :Done             ;no, nothing special to do
2824: a9 00                        lda     #$00              ;yes, remove illumination
2826: 8d 9e 61                     sta     illumination_flag ;extinguish light
2829: ad ac 61                     lda     monster2_alive    ;is monster's mother still alive?
282c: f0 08                        beq     :Done             ;no, chill
282e: a9 0a                        lda     #$0a              ;darkness
2830: 8d a5 61                     sta     special_zone
2833: 20 7e 12                     jsr     EraseMaze         ;clear maze from screen
2836: a9 0b        :Done           lda     #$0b              ;set A-reg back to "ring"
2838: 60                           rts

                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

2839: c6 0f        ChkVerbThro     dec     ]verb_index
283b: f0 03                        beq     HndVerbThro
283d: 4c 3d 29                     jmp     ChkVerbClim

                   ; 
                   ; Verb $06: ROLL / CHUCk / HEAVe / THROw
                   ; 
2840: a5 0e        HndVerbThro     lda     ]noun_index       ;check the noun index
2842: c9 0b                        cmp     #$0b              ;ring?
2844: d0 03                        bne     :NotRing
2846: 20 1d 28                     jsr     RingGone          ;do special handling for ring, then fall through
2849: c9 06        :NotRing        cmp     #$06              ;frisbee?
284b: d0 03                        bne     :NotFrisbee
284d: 4c 12 29                     jmp     ThrowFrisbee

2850: c9 0f        :NotFrisbee     cmp     #$0f              ;wool?
2852: f0 31                        beq     :ThrowWool
2854: c9 10                        cmp     #$10              ;yoyo?
2856: f0 61                        beq     :ThrowYoYo
2858: c9 12                        cmp     #$12              ;food or torch?
285a: 30 0d                        bmi     :DoSail           ;no, do general "sail around corner" handling
285c: f0 68                        beq     :ThrowFood        ;food, branch
285e: c9 13                        cmp     #$13              ;torch?
2860: d0 03                        bne     :NotTorch         ;(never taken?)
2862: 20 23 27                     jsr     DiscardTorch
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

2865: a5 11        :NotTorch       lda     ]inv_obj_data     ;get object index for food or torch
2867: 85 0e                        sta     ]func_arg
                   ; $0e is either the noun index, or the object index for food/torch.
                   ; $0f will be $00 in the common case, or $61 if we discarded a torch.
2869: 20 34 1a     :DoSail         jsr     ObjMgmtFunc       ;destroy object ($0f == 0)
286c: 20 d9 28                     jsr     SailAroundCorner
286f: 20 2f 33                     jsr     CheckThrowTarget  ;see if monster is around (and handle "throw ball")
2872: ea                           nop                       ;computes $61ad & $02
2873: ea                           nop
2874: d0 05                        bne     :EatThrownObj     ;monster is alive, eat it
2876: a9 97                        lda     #$97              ;no monster... "and it vanishes"
2878: 4c 92 08                     jmp     DrawMsgN_Row22

287b: a9 5c        :EatThrownObj   lda     #$5c              ;"and is eaten by"
287d: 20 92 08                     jsr     DrawMsgN_Row22
2880: a9 5d                        lda     #$5d              ;"the monster"
2882: 4c a4 08                     jmp     DrawMsgN_Row23

2885: ad 94 61     :ThrowWool      lda     plyr_floor
2888: c9 04                        cmp     #$04              ;4th floor?
288a: d0 dd                        bne     :DoSail           ;no, do nothing special
288c: ad a4 61                     lda     floor_move_lo     ;check number of moves
288f: c9 29                        cmp     #41               ;41+?
2891: 90 d6                        bcc     :DoSail           ;no, nothing special
2893: 20 88 27                     jsr     PushSpecialZone
2896: a9 0e                        lda     #$0e
2898: 8d a5 61                     sta     special_zone      ;tangle the monster
289b: a9 0f                        lda     #$0f              ;wool
289d: 85 0e                        sta     ]func_arg
289f: a9 00                        lda     #FN_DESTROY_OBJ
28a1: 85 0f                        sta     ]func_cmd
28a3: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy wool
28a6: 20 d9 28                     jsr     SailAroundCorner
28a9: a9 5e                        lda     #$5e              ;"and the monster grabs it,"
28ab: 20 92 08                     jsr     DrawMsgN_Row22
28ae: a9 5f                        lda     #$5f              ;"gets tangled, and topples over"
28b0: 20 a4 08                     jsr     DrawMsgN_Row23
28b3: a9 00                        lda     #$00
28b5: 8d b2 61                     sta     monster1_dist     ;set distance to zero
28b8: 60                           rts

28b9: 20 d9 28     :ThrowYoYo      jsr     SailAroundCorner
28bc: a9 6b                        lda     #$6b              ;"returns and hits you"
28be: 20 92 08                     jsr     DrawMsgN_Row22
28c1: a9 6c                        lda     #$6c              ;"in the eye"
28c3: 4c a4 08                     jmp     DrawMsgN_Row23

28c6: a5 11        :ThrowFood      lda     ]inv_obj_data     ;get food object index
28c8: 85 0e                        sta     ]func_arg
28ca: 20 34 1a                     jsr     ObjMgmtFunc       ;$0f should be zero, so this drops the food
28cd: a9 07                        lda     #FN_DRAW_INV
28cf: 85 0f                        sta     ]func_cmd
28d1: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
28d4: a9 81                        lda     #$81              ;"food fight"
28d6: 4c a4 08                     jmp     DrawMsgN_Row23

                   ; 
                   ; Tells the player that their thrown object has sailed around a corner.
                   ; 
                   SailAroundCorner
28d9: a9 07                        lda     #FN_DRAW_INV
28db: 85 0f                        sta     ]func_cmd
28dd: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
28e0: a9 59                        lda     #$59              ;"the"
28e2: 20 92 08                     jsr     DrawMsgN_Row22
28e5: ad 9d 61                     lda     parsed_noun       ;get noun
28e8: 20 e3 25                     jsr     PrintNoun         ;print it
                   ; It's unclear what this next bit does.  $0e-0f was left pointing just past the
                   ; end of the object list ($61e9) by the draw-inventory function.  This fiddles
                   ; with the pointer, looks for #$20 in an area that's generally zero, and then
                   ; does nothing with the result.
                   ]inv_ptr        .var    $0e    {addr/2}

28eb: 20 bd 32                     jsr     Decr0e0f          ;decrement pointer
28ee: a9 20                        lda     #$20
28f0: a0 00                        ldy     #$00
28f2: d1 0e                        cmp     (]inv_ptr),y
28f4: f0 06                        beq     :NoInc1
28f6: e6 0e                        inc     ]inv_ptr
28f8: d0 02                        bne     :NoInc1
28fa: e6 0f                        inc     ]inv_ptr+1
28fc: e6 0e        :NoInc1         inc     ]inv_ptr
28fe: d0 02                        bne     :NoInc2
2900: e6 0f                        inc     ]inv_ptr+1
                   ; 
2902: a9 5a        :NoInc2         lda     #$5a              ;"magically sails"
2904: 20 e2 08                     jsr     DrawMsgN
2907: a9 5b                        lda     #$5b              ;"around a nearby corner"
2909: 20 a4 08                     jsr     DrawMsgN_Row23
290c: 20 45 10                     jsr     LongDelay         ;pause for reading
290f: 4c 5f 10                     jmp     ClearMessages     ;clear text

                   ; Handle flung frisbee.
2912: ad ad 61     ThrowFrisbee    lda     monster1_alive
2915: 29 02                        and     #$02              ;is monster alive?
2917: d0 03                        bne     :MonsterFrisbee   ;yes, play catch
2919: 4c 69 28                     jmp     :DoSail           ;no, just destroy frisbee

                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

291c: a9 06        :MonsterFrisbee lda     #$06              ;frisbee
291e: 85 0e                        sta     ]func_arg
2920: a9 00                        lda     #FN_DESTROY_OBJ
2922: 85 0f                        sta     ]func_cmd
2924: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy frisbee
2927: 20 d9 28                     jsr     SailAroundCorner
292a: 20 5f 10                     jsr     ClearMessages
292d: a9 3f                        lda     #$3f              ;"the monster grabs the frisbee, throws"
292f: 20 92 08                     jsr     DrawMsgN_Row22
2932: a9 40                        lda     #$40              ;"it back, and saws your head off"
2934: 20 a4 08                     jsr     DrawMsgN_Row23
2937: 20 45 10                     jsr     LongDelay
293a: 4c b9 10                     jmp     HandleDeath       ;bye

                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

293d: c6 0f        ChkVerbClim     dec     ]verb_index
293f: d0 03                        bne     ChkVerbDrop
                   ; 
                   ; Verb $07: CLIMb
                   ; 
2941: 4c 5a 10                     jmp     PrintLittleSense  ;climb only makes sense in special zone (snake)

2944: c6 0f        ChkVerbDrop     dec     ]verb_index
2946: d0 7f                        bne     ChkVerbFill
                   ; 
                   ; Verb $08: DROP / LEAVe / PUT
                   ; 
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]inv_ret_val    .var    $1a    {addr/1}

2948: 20 74 32                     jsr     SwapZPValues      ;preserve ZP values
294b: a9 0b                        lda     #FN_OBJ_HERE
294d: 85 0f                        sta     ]func_cmd
294f: 20 34 1a                     jsr     ObjMgmtFunc       ;get object index of item at this location
2952: c9 00                        cmp     #$00              ;did we find anything?
2954: f0 17                        beq     :SpaceAvail       ;no, we're free to drop; branch
2956: 85 0e                        sta     ]func_arg         ;store object index
2958: a9 06                        lda     #FN_GET_OBJ_INFO
295a: 85 0f                        sta     ]func_cmd
295c: 20 34 1a                     jsr     ObjMgmtFunc       ;get info for object on ground
295f: a5 1a                        lda     ]inv_ret_val
2961: c9 06                        cmp     #$06              ;is object on ground also in inventory? (how?)
2963: b0 08                        bcs     :SpaceAvail       ;yes, keep going
2965: a9 82                        lda     #$82              ;"the hallway is too crowded"
2967: 20 a4 08                     jsr     DrawMsgN_Row23
296a: 4c 74 32                     jmp     SwapZPValues      ;restore ZP values and bail

296d: 20 74 32     :SpaceAvail     jsr     SwapZPValues      ;restore ZP values ($0e-11 and $19-1a)
2970: a5 0e                        lda     ]func_arg         ;get noun index
2972: c9 12                        cmp     #$12              ;is it food/torch?
2974: 10 15                        bpl     :IsConsumable     ;yes, handle those
2976: c9 0b                        cmp     #$0b              ;ring?
2978: d0 03                        bne     :NotRing          ;no, branch
297a: 20 1d 28                     jsr     RingGone          ;yes, do special ring-drop handling
297d: a9 05        :NotRing        lda     #FN_DROP_OBJ
297f: 85 0f                        sta     ]func_cmd
2981: 20 34 1a                     jsr     ObjMgmtFunc       ;drop the object (noun index == obj index for these)
2984: a2 07                        ldx     #FN_DRAW_INV
2986: 86 0f                        stx     ]func_cmd
2988: 4c 34 1a                     jmp     ObjMgmtFunc       ;redraw inventory and bail

298b: c9 13        :IsConsumable   cmp     #$13              ;torch?
298d: f0 07                        beq     :IsTorch          ;yes, branch
298f: a5 11                        lda     ]inv_obj_data     ;get object index
2991: 85 0e                        sta     ]func_arg
2993: 4c 7d 29                     jmp     :NotRing          ;do common handling

2996: a9 0e        :IsTorch        lda     #FN_FIND_UNLIT_T
2998: 85 0f                        sta     ]func_cmd
299a: 20 34 1a                     jsr     ObjMgmtFunc       ;find an unlit torch object in inventory
299d: f0 06                        beq     :NoUnlit          ;not found, branch
299f: ce 98 61                     dec     num_unlit_torches ;reduce unlit torch count
29a2: 4c 7d 29                     jmp     :NotRing          ;do common handling

29a5: a9 0d        :NoUnlit        lda     #FN_FIND_LIT_T
29a7: 85 0f                        sta     ]func_cmd
29a9: 20 34 1a                     jsr     ObjMgmtFunc       ;find a lit torch object in inventory
29ac: 85 0e                        sta     ]func_arg
29ae: ce 97 61                     dec     num_lit_torches   ;reduce lit torch count
29b1: 20 88 27                     jsr     PushSpecialZone   ;push whatever we have going on
29b4: a9 00                        lda     #$00
29b6: 8d 9e 61                     sta     illumination_flag ;deilluminate
29b9: 8d 97 61                     sta     num_lit_torches
29bc: a9 0a                        lda     #$0a
29be: 8d a5 61                     sta     special_zone      ;set darkness zone
29c1: 20 7e 12                     jsr     EraseMaze         ;remove maze from screen
29c4: 4c 7d 29                     jmp     :NotRing          ;do common handling

29c7: c6 0f        ChkVerbFill     dec     ]func_cmd
29c9: d0 0e                        bne     CheckVerbLigh
                   ; 
                   ; Verb $09: FILL
                   ; 
                   ; Only works with the jar, and only in special zone (newly-slain monster).
                   ; 
29cb: a5 0e                        lda     ]func_arg
29cd: c9 09                        cmp     #$09              ;jar?
29cf: f0 03                        beq     :IsJar
29d1: 4c 5a 10                     jmp     PrintLittleSense

29d4: a9 89        :IsJar          lda     #$89              ;"with what? air?"
29d6: 4c a4 08                     jmp     DrawMsgN_Row23

29d9: c6 0f        CheckVerbLigh   dec     ]func_cmd
29db: d0 66                        bne     ChkVerbPlay
                   ; 
                   ; Verb $0a: LIGHt
                   ; 
                   ]ret_state      .var    $1a    {addr/1}

29dd: 85 11                        sta     ]inv_obj_data     ;save A-reg (verb index... not used)
29df: a5 0e                        lda     ]func_arg         ;get noun index
29e1: c9 13                        cmp     #$13              ;torch?
29e3: f0 03                        beq     :LightTorch
29e5: 4c 5a 10                     jmp     PrintLittleSense

29e8: a5 1a        :LightTorch     lda     ]ret_state        ;check object state
29ea: c9 07                        cmp     #$07              ;is object active?
29ec: d0 03                        bne     :Inactive         ;no, branch
29ee: 4c ad 0b                     jmp     CheckInvDolt      ;can't self-light

29f1: ad 9e 61     :Inactive       lda     illumination_flag ;do we currently have illumination?
29f4: d0 0c                        bne     :HaveLight        ;yes, branch
29f6: a9 88                        lda     #$88              ;"you have no fire"
29f8: 20 a4 08                     jsr     DrawMsgN_Row23
29fb: a9 07                        lda     #FN_DRAW_INV
29fd: 85 0f                        sta     ]func_cmd
29ff: 4c 34 1a                     jmp     ObjMgmtFunc       ;redraw inventory (why?)

2a02: a9 0d        :HaveLight      lda     #FN_FIND_LIT_T
2a04: 85 0f                        sta     ]func_cmd
2a06: 20 34 1a                     jsr     ObjMgmtFunc       ;find the lit torch
2a09: c9 00                        cmp     #$00              ;none?
2a0b: f0 09                        beq     :NoLit
2a0d: 85 0e                        sta     ]func_arg
2a0f: a9 01                        lda     #FN_DESTROY_OBJ1
2a11: 85 0f                        sta     ]func_cmd
2a13: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy that one
2a16: a9 0e        :NoLit          lda     #FN_FIND_UNLIT_T
2a18: 85 0f                        sta     ]func_cmd
2a1a: 20 34 1a                     jsr     ObjMgmtFunc       ;find an unlit torch
2a1d: 85 0e                        sta     ]func_arg
2a1f: a9 03                        lda     #FN_ACTIVATE_OBJ
2a21: 85 0f                        sta     ]func_cmd
2a23: 20 34 1a                     jsr     ObjMgmtFunc       ;activate it
2a26: 20 5f 10                     jsr     ClearMessages
2a29: a9 65                        lda     #$65              ;"the torch is lit and the"
2a2b: 20 92 08                     jsr     DrawMsgN_Row22
2a2e: a9 66                        lda     #$66              ;"old torch dies and vanishes"
2a30: 20 a4 08                     jsr     DrawMsgN_Row23
2a33: ce 98 61                     dec     num_unlit_torches
2a36: a9 07                        lda     #FN_DRAW_INV
2a38: 85 0f                        sta     ]func_cmd
2a3a: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
2a3d: a9 96                        lda     #150
2a3f: 8d a1 61                     sta     torch_level       ;init torch level to 150
2a42: 60                           rts

2a43: c6 0f        ChkVerbPlay     dec     ]func_cmd
2a45: f0 03                        beq     HndVerbPlay
2a47: 4c df 2a                     jmp     ChkVerbStri

                   ; 
                   ; Verb $0b: PLAY
                   ; 
                   ]noun_index     .var    $0e    {addr/1}

2a4a: a5 0e        HndVerbPlay     lda     ]noun_index       ;get noun index
2a4c: c9 05                        cmp     #$05              ;flute?
2a4e: f0 18                        beq     :PlayFlute
2a50: c9 01                        cmp     #$01              ;ball?
2a52: f0 0f                        beq     :PlayBall
2a54: c9 08                        cmp     #$08              ;horn?
2a56: f0 03                        beq     :PlayHorn
2a58: 4c 5a 10                     jmp     PrintLittleSense

2a5b: a9 02        :PlayHorn       lda     #$02              ;change verb to BLOW
2a5d: 8d 9c 61                     sta     parsed_verb
2a60: 4c 40 26                     jmp     ExecParsedInput   ;start over

2a63: a9 87        :PlayBall       lda     #$87              ;"with who? the monster?"
2a65: 4c a4 08     :PrintMsgRet    jmp     DrawMsgN_Row23    ;print message and bail

                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]ret_xy         .var    $19    {addr/1}
                   ]ret_state      .var    $1a    {addr/1}

2a68: a9 11        :PlayFlute      lda     #$11              ;set noun to "snake"
2a6a: 85 0e                        sta     ]func_arg
2a6c: a9 06                        lda     #FN_GET_OBJ_INFO
2a6e: 85 0f                        sta     ]func_cmd
2a70: 20 34 1a                     jsr     ObjMgmtFunc       ;get info
2a73: a5 1a                        lda     ]ret_state        ;get state / floor
2a75: cd 94 61                     cmp     plyr_floor        ;is the snake on this floor?
2a78: d0 0f                        bne     :NoSnake          ;no, branch
2a7a: ad 95 61                     lda     plyr_xpos
2a7d: 0a                           asl     A
2a7e: 0a                           asl     A
2a7f: 0a                           asl     A
2a80: 0a                           asl     A
2a81: 18                           clc
2a82: 6d 96 61                     adc     plyr_ypos         ;compute X*16 + Y
2a85: c5 19                        cmp     ]ret_xy           ;is the snake in this cell?
2a87: f0 0d                        beq     :AnimateSnake     ;yes, do the animation
2a89: 20 5f 10     :NoSnake        jsr     ClearMessages     ;no snake here, just make music
2a8c: a9 83                        lda     #$83              ;"a high shrill note comes"
2a8e: 20 92 08                     jsr     DrawMsgN_Row22
2a91: a9 84                        lda     #$84              ;"from the flute"
2a93: 4c 65 2a                     jmp     :PrintMsgRet

2a96: a9 0a        :AnimateSnake   lda     #10               ;set text position near bottom-center of screen
2a98: 85 06                        sta     char_horiz
2a9a: a9 14                        lda     #20
2a9c: 85 07                        sta     char_vert
2a9e: 20 ef 11     :DrawSnakeSeg   jsr     SetRowPtr         ;set hi-res pointer
2aa1: a9 1c                        lda     #$1c              ;draw snake segment
2aa3: 20 a4 11                     jsr     DrawGlyph
2aa6: a9 05                        lda     #$05
2aa8: 20 a4 11                     jsr     DrawGlyph
2aab: a9 1b                        lda     #$1b
2aad: 20 a4 11                     jsr     DrawGlyph
                   ; Pause briefly.
                   ]delay_ctr      .var    $10    {addr/2}

2ab0: a9 30                        lda     #$30
2ab2: 85 11                        sta     ]delay_ctr+1
2ab4: c6 10        :DelayLoop      dec     ]delay_ctr
2ab6: d0 fc                        bne     :DelayLoop
2ab8: c6 11                        dec     ]delay_ctr+1
2aba: d0 f8                        bne     :DelayLoop
2abc: c6 06                        dec     char_horiz        ;back up 3 chars
2abe: c6 06                        dec     char_horiz
2ac0: c6 06                        dec     char_horiz
2ac2: c6 07                        dec     char_vert         ;move up one line
2ac4: 10 d8                        bpl     :DrawSnakeSeg
2ac6: a9 03                        lda     #FN_ACTIVATE_OBJ
2ac8: 85 0f                        sta     ]func_cmd
2aca: a9 11                        lda     #$11              ;snake
2acc: 85 0e                        sta     ]func_arg
2ace: 20 34 1a                     jsr     ObjMgmtFunc       ;mark snake as active
2ad1: 20 88 27                     jsr     PushSpecialZone
2ad4: a9 0f                        lda     #$0f              ;snake is out of box
2ad6: 8d a5 61                     sta     special_zone      ;do special stuff (climb or die)
2ad9: a9 00                        lda     #$00
2adb: 8d b9 61                     sta     object_status     ;set status of object 0 (?)
2ade: 60                           rts

                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

2adf: c6 0f        ChkVerbStri     dec     ]verb_index
2ae1: d0 16                        bne     ChkVerbWear
                   ; 
                   ; Verb $0c: STRIke(?)
                   ; 
                   ; Only meaningful for the staff (and even that's useless).
                   ; 
2ae3: a5 0e                        lda     ]noun_index
2ae5: c9 0d                        cmp     #$0d              ;staff?
2ae7: f0 03                        beq     :StrikeStaff
2ae9: 4c 5a 10                     jmp     PrintLittleSense

2aec: 20 5f 10     :StrikeStaff    jsr     ClearMessages
2aef: a9 21                        lda     #$21              ;"thunderbolts shoot out above you"
2af1: 20 92 08                     jsr     DrawMsgN_Row22
2af4: a9 22                        lda     #$22              ;"the staff thunders with useless energy"
2af6: 4c a4 08                     jmp     DrawMsgN_Row23

2af9: c6 0f        ChkVerbWear     dec     ]verb_index
2afb: f0 01                        beq     HndVerbWear
2afd: 60                           rts                       ;verb out of range, do nothing (BUG)

                   ; 
                   ; Verb $0d: WEAR.
                   ; 
                   ; Only meaningful for the hat.
                   ; 
                   ]func_cmd       .var    $0f    {addr/1}

2afe: a5 0e        HndVerbWear     lda     ]noun_index
2b00: c9 07                        cmp     #$07              ;hat?
2b02: f0 0d                        beq     :WearHat
2b04: 20 5f 10     :PrintMsg       jsr     ClearMessages
2b07: a9 91                        lda     #$91              ;"OK...if you really want to"
2b09: 20 92 08                     jsr     DrawMsgN_Row22
2b0c: a9 23                        lda     #$23              ;"you are wearing it"
2b0e: 4c a4 08                     jmp     DrawMsgN_Row23

2b11: a9 03        :WearHat        lda     #FN_ACTIVATE_OBJ
2b13: 85 0f                        sta     ]func_cmd
2b15: 20 34 1a                     jsr     ObjMgmtFunc       ;activate hat
2b18: 4c 04 2b                     jmp     :PrintMsg

                   ; 
                   ; Handles verbs $0e - 1c, which may or may not involve an inventory object.
                   ; 
                   • Clear variables
                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

2b1b: a5 0f        ChkMoreVerbs    lda     ]verb_index
2b1d: 38                           sec
2b1e: e9 0e                        sbc     #$0e              ;adjust index so we start at zero
2b20: 85 0f                        sta     ]verb_index
2b22: d0 40                        bne     ChkVerbWipe
                   ; 
                   ; Verb $0e: EXAM / LOOK.
                   ; 
2b24: a5 0e                        lda     ]noun_index
2b26: c9 07                        cmp     #$07              ;hat?
2b28: d0 03                        bne     :NotHat
2b2a: 4c 19 33                     jmp     PrintHatMsg       ;hat message is printed specially

2b2d: c9 15        :NotHat         cmp     #$15              ;inventory-able noun?
2b2f: 30 19                        bmi     :InvObj           ;yes, branch
2b31: c9 1a                        cmp     #$1a              ;noun that isn't a calculator button?
2b33: 30 03                        bmi     :NonButton        ;yes, branch
2b35: 4c 5a 10                     jmp     PrintLittleSense  ;no, can't "examine three"

2b38: c9 17        :NonButton      cmp     #$17              ;door / elev?
2b3a: f0 05                        beq     :DoorElev
2b3c: a9 90        :DontSee        lda     #$90              ;"i don't see that here"
2b3e: 4c a4 08     :DrawMsg        jmp     DrawMsgN_Row23

2b41: 20 8e 2c     :DoorElev       jsr     FindDoor          ;is there a door here?
2b44: c9 00                        cmp     #$00
2b46: f0 f4                        beq     :DontSee          ;no, complain
2b48: d0 03                        bne     :DoExamine        ;(always)

2b4a: 20 97 0b     :InvObj         jsr     CheckInventory    ;see if it's in inventory (not found = pop stack)
2b4d: 20 5f 10     :DoExamine      jsr     ClearMessages
2b50: a9 67                        lda     #$67              ;"a close inspection reveals"
2b52: 20 92 08                     jsr     DrawMsgN_Row22
2b55: ad 9d 61                     lda     parsed_noun
2b58: c9 03                        cmp     #$03              ;calculator?
2b5a: f0 04                        beq     :ExamCalc         ;yes, branch
2b5c: a9 68                        lda     #$68              ;"absolutely nothing of value"
2b5e: d0 de                        bne     :DrawMsg

2b60: a9 69        :ExamCalc       lda     #$69              ;"a smudged display"
2b62: d0 da                        bne     :DrawMsg

2b64: c6 0f        ChkVerbWipe     dec     ]verb_index
2b66: d0 12                        bne     ChkVerbOpen
                   ; 
                   ; Verb $0f: WIPE / CLEAn / POLIsh / RUB
                   ; 
2b68: 20 97 0b                     jsr     CheckInventory    ;see if we're holding the item; does not return
2b6b: ad 9d 61                     lda     parsed_noun       ; on failure
2b6e: c9 03                        cmp     #$03              ;calculator?
2b70: f0 04                        beq     :IsCalc           ;yes, branch to handle that
2b72: a9 7a                        lda     #$7a              ;"OK...it is clean"
2b74: d0 c8                        bne     :DrawMsg

2b76: a9 28        :IsCalc         lda     #$28              ;"it displays 317.2"
2b78: d0 c4                        bne     :DrawMsg

                   ]verb_index     .var    $0f    {addr/1}

2b7a: c6 0f        ChkVerbOpen     dec     ]verb_index
2b7c: f0 03                        beq     HndVerbOpen
2b7e: 4c fa 2c                     jmp     ChkVerbPres

                   ; 
                   ; Verb $10: OPEN / UNLOck
                   ; 
                   ; Can be used on doors and boxes.
                   ; 
2b81: a5 0e        HndVerbOpen     lda     ]noun_index
2b83: c9 17                        cmp     #$17              ;door?
2b85: d0 03                        bne     :NotDoor          ;no, branch
2b87: 4c 26 2c                     jmp     :OpenDoor

2b8a: c9 14        :NotDoor        cmp     #$14              ;box?
2b8c: f0 03                        beq     :OpenBox          ;yes, branch
2b8e: 4c 5a 10                     jmp     PrintLittleSense  ;no, complain

                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]noun_index     .var    $10    {addr/1}
                   ]obj_index      .var    $11    {addr/1}
                   ]tmp            .var    $13    {addr/1}
                   ]ret_xy         .var    $19    {addr/1}
                   ]ret_state      .var    $1a    {addr/1}

2b91: a9 0b        :OpenBox        lda     #FN_OBJ_HERE
2b93: 85 0f                        sta     ]func_cmd
2b95: 20 34 1a                     jsr     ObjMgmtFunc       ;get info about box at this location
2b98: 85 11                        sta     ]obj_index        ;save object index
2b9a: f0 a0                        beq     :DontSee          ;branch if zero
                   ; 
2b9c: a5 10                        lda     ]noun_index       ;preserve $10/$11
2b9e: 48                           pha
2b9f: a5 11                        lda     ]obj_index
2ba1: 48                           pha
2ba2: 85 0e                        sta     ]func_arg
2ba4: a9 06                        lda     #FN_GET_OBJ_INFO
2ba6: 85 0f                        sta     ]func_cmd
2ba8: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on object
2bab: a5 1a                        lda     ]ret_state        ;check object state
2bad: c9 06                        cmp     #$06              ;object already in inventory (boxed or not)?
2baf: b0 03                        bcs     :InInventory      ;yes, branch
2bb1: 4c bf 2b                     jmp     :OnGround         ;no, handle box on ground

2bb4: a5 11        :InInventory    lda     ]obj_index        ;get object index
2bb6: 85 0e                        sta     ]func_arg
2bb8: a9 04                        lda     #FN_GET_OBJ
2bba: 85 0f                        sta     ]func_cmd
2bbc: 20 34 1a                     jsr     ObjMgmtFunc       ;unbox the item
2bbf: a5 11        :OnGround       lda     ]obj_index
2bc1: c9 11                        cmp     #$11              ;snake?
2bc3: f0 55                        beq     :OpenSnake        ;yes, branch
2bc5: 30 0a                        bmi     :InsideBox        ;is non-consumable object, branch
2bc7: c9 15                        cmp     #$15              ;$12-14 (food)?
2bc9: 30 04                        bmi     :IsFood           ;yes, branch
2bcb: a9 13                        lda     #$13              ;must be $15-17 (torch), use noun id $13
2bcd: d0 02                        bne     :InsideBox        ;(always)

2bcf: a9 12        :IsFood         lda     #$12              ;use noun ID for food
2bd1: 20 5f 10     :InsideBox      jsr     ClearMessages     ;(preserves A-reg)
2bd4: 85 10                        sta     ]noun_index       ;store the noun index
2bd6: 18                           clc                       ;noun + 4 = description text
2bd7: 69 04                        adc     #$04              ;e.g. "basket of food"
2bd9: 20 a4 08                     jsr     DrawMsgN_Row23
2bdc: a9 18                        lda     #$18              ;"inside the box there is a"
2bde: 20 92 08                     jsr     DrawMsgN_Row22
2be1: a5 10                        lda     ]noun_index       ;get noun
2be3: c9 03                        cmp     #$03              ;calculator?
2be5: d0 03                        bne     :NotCalc
2be7: 20 c2 2e                     jsr     UnboxCalcSpecial
2bea: 85 13        :NotCalc        sta     ]tmp              ;save copy of noun_index
2bec: c9 11                        cmp     #$11              ;snake?
2bee: d0 03                        bne     :NotSnake         ;no, branch
2bf0: 20 45 10                     jsr     LongDelay
2bf3: 68           :NotSnake       pla                       ;restore $10/$11
2bf4: 85 11                        sta     ]obj_index
2bf6: 68                           pla
2bf7: 85 10                        sta     ]noun_index
2bf9: a5 13                        lda     ]tmp              ;load copy of noun_index
2bfb: c9 13                        cmp     #$13              ;torch?
2bfd: d0 14                        bne     :NotTorch         ;no, branch
                   ; 
2bff: a9 06                        lda     #FN_GET_OBJ_INFO  ;handle torch
2c01: 85 0f                        sta     ]func_cmd
2c03: a5 11                        lda     ]obj_index
2c05: 85 0e                        sta     ]func_arg
2c07: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on object
2c0a: a9 08                        lda     #$08
2c0c: c5 1a                        cmp     ]ret_state        ;in inventory and unboxed?
2c0e: d0 03                        bne     :NotTorch         ;no, branch
2c10: ee 98 61                     inc     num_unlit_torches ;yes, add to unlit torch count
2c13: a9 07        :NotTorch       lda     #FN_DRAW_INV
2c15: 85 0f                        sta     ]func_cmd
2c17: 4c 34 1a                     jmp     ObjMgmtFunc       ;redraw inventory

2c1a: 20 88 27     :OpenSnake      jsr     PushSpecialZone
2c1d: a2 0b                        ldx     #$0b              ;snake out of the box
2c1f: 8e a5 61                     stx     special_zone
2c22: a9 11                        lda     #$11              ;snake object id
2c24: d0 ab                        bne     :InsideBox        ;(always)

2c26: 20 8e 2c     :OpenDoor       jsr     FindDoor          ;is there a door here?
2c29: c9 00                        cmp     #$00              ;A-reg nonzero if there is one
2c2b: d0 03                        bne     :IsDoor           ;found a door, branch to open it
2c2d: 4c 3c 2b                     jmp     :DontSee          ;no, complain

2c30: c9 05        :IsDoor         cmp     #$05              ;is it a keyhole?
2c32: b0 03                        bcs     :OpenKeyhole      ;yes, branch
2c34: 4c 83 2c                     jmp     :OpenElev         ;no, must be elevator

2c37: 20 67 32     :OpenKeyhole    jsr     SwapOutAReg       ;preserve A-reg (holds keyhole index)
2c3a: a2 0a                        ldx     #$0a              ;key
2c3c: 86 0e                        stx     ]func_arg
2c3e: a2 06                        ldx     #FN_GET_OBJ_INFO
2c40: 86 0f                        stx     ]func_cmd
2c42: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on key
2c45: a5 1a                        lda     ]ret_state
2c47: c9 07                        cmp     #$07              ;in inventory and unboxed?
2c49: 30 1e                        bmi     :NoKey            ;no, branch
2c4b: 20 67 32                     jsr     SwapOutAReg       ;restore keyhole index (5-9)
2c4e: 18                           clc
2c4f: 69 15                        adc     #$15              ;now $1a-1e
2c51: c9 1b                        cmp     #$1b              ;door #2?
2c53: f0 1c                        beq     :Keyhole2         ;yes, start the ticking
2c55: 20 67 32                     jsr     SwapOutAReg       ;preserve modified key value
2c58: 20 5f 10                     jsr     ClearMessages
2c5b: a9 19                        lda     #$19              ;"you unlock the door"
2c5d: 20 92 08                     jsr     DrawMsgN_Row22
2c60: 20 67 32                     jsr     SwapOutAReg       ;restore modified key value
2c63: 20 a4 08                     jsr     DrawMsgN_Row23    ;various msgs: 20,000 volt, gorilla, white coats
2c66: 4c b9 10                     jmp     HandleDeath       ;all fatal

2c69: 20 67 32     :NoKey          jsr     SwapOutAReg
2c6c: a9 92                        lda     #$92              ;"but you have no key"
2c6e: 4c a4 08                     jmp     DrawMsgN_Row23

2c71: a2 0c        :Keyhole2       ldx     #$0c
2c73: 8e a5 61                     stx     special_zone      ;start the key ticking
2c76: 20 5f 10                     jsr     ClearMessages
2c79: a9 19                        lda     #$19              ;"you unlock the door"
2c7b: 20 92 08                     jsr     DrawMsgN_Row22
2c7e: a9 1b                        lda     #$1b              ;"and the key begins to tick"
2c80: 4c a4 08                     jmp     DrawMsgN_Row23

2c83: 20 88 27     :OpenElev       jsr     PushSpecialZone
2c86: a2 0d                        ldx     #$0d              ;special elevator zone
2c88: 8e a5 61                     stx     special_zone      ;wait for 'Z' to enter
2c8b: 4c 5d 32                     jmp     OpenElevatorAnim

                   ; 
                   ; Finds the door in front of the player, if any.  Doors 1-4 are elevators, 5-10
                   ; are keyholes.
                   ; 
                   ; On exit:
                   ;   A-reg: index into door table, or $00 if none found
                   ; 
                   ]ptr            .var    $0e    {addr/2}
                   ]xy_posn        .var    $11    {addr/1}
                   ]floor_facing   .var    $19    {addr/1}
                   ]counter        .var    $1a    {addr/1}

2c8e: a2 e8        FindDoor        ldx     #<door_loc        ;set pointer to door location table
2c90: 86 0e                        stx     ]ptr
2c92: a2 2c                        ldx     #>door_loc
2c94: 86 0f                        stx     ]ptr+1
                   ; We want one byte with ((floor << 4) | facing), and one byte with ((xpos << 4)
                   ; | ypos).
2c96: ae 94 61                     ldx     plyr_floor        ;copy floor to ZP
2c99: 86 19                        stx     ]floor_facing
2c9b: ad 95 61                     lda     plyr_xpos         ;X position in A-reg
2c9e: a2 04                        ldx     #$04              ;4 shifts
2ca0: 86 1a                        stx     ]counter
2ca2: 0a           :ShiftLoop      asl     A                 ;shift X pos
2ca3: 06 19                        asl     ]floor_facing     ;shift floor
2ca5: c6 1a                        dec     ]counter
2ca7: d0 f9                        bne     :ShiftLoop
2ca9: 18                           clc
2caa: 6d 96 61                     adc     plyr_ypos         ;combine X and Y posn
2cad: 85 11                        sta     ]xy_posn          ;save in ZP
2caf: a5 19                        lda     ]floor_facing     ;get shifted floor
2cb1: 18                           clc
2cb2: 6d 93 61                     adc     plyr_facing       ;combine with facing
2cb5: 85 19                        sta     ]floor_facing     ;save in ZP
                   ; 
2cb7: a2 09                        ldx     #9                ;4 elevator doors, 5 keyholes
2cb9: 86 1a                        stx     ]counter
2cbb: a0 00        :Loop           ldy     #$00
2cbd: d1 0e                        cmp     (]ptr),y          ;compare floor/facing value
2cbf: d0 12                        bne     :NotIt
2cc1: a5 11                        lda     ]xy_posn
2cc3: e6 0e                        inc     ]ptr              ;check next byte
2cc5: d0 02                        bne     :NoInc
2cc7: e6 0f                        inc     ]ptr+1
2cc9: d1 0e        :NoInc          cmp     (]ptr),y          ;does it match player X/Y?
2ccb: d0 0c                        bne     :NoInc1
                   ; Found a match.
2ccd: a9 0a                        lda     #10
2ccf: 38                           sec
2cd0: e5 1a                        sbc     ]counter          ;return (10 - counter)
2cd2: 60                           rts

2cd3: e6 0e        :NotIt          inc     ]ptr              ;increment pointer twice
2cd5: d0 02                        bne     :NoInc1
2cd7: e6 0f                        inc     ]ptr+1
2cd9: e6 0e        :NoInc1         inc     ]ptr
2cdb: d0 02                        bne     :NoInc2
2cdd: e6 0f                        inc     ]ptr+1
2cdf: a5 19        :NoInc2         lda     ]floor_facing     ;load this back into A-reg
2ce1: c6 1a                        dec     ]counter          ;done yet?
2ce3: d0 d6                        bne     :Loop             ;no, loop
2ce5: a9 00                        lda     #$00              ;no match found, return zero
2ce7: 60                           rts

                   ; 
                   ; Door/keyhole access locations.  First byte is ((floor << 4) | facing), second
                   ; byte is ((xpos << 4) | ypos).  The first four entries are the elevators, the
                   ; last 5 are the row of keyholes on level 5.
                   ; 
                   ; For example, the first entry is for the second floor elevator, which the
                   ; player must face east to enter while standing at (7,7).
2ce8: 23 77        door_loc        .bulk   $23,$77           ;elevators on floors 2/3/4/5
2cea: 31 44                        .bulk   $31,$44
2cec: 42 14                        .bulk   $42,$14
2cee: 52 35                        .bulk   $52,$35
2cf0: 52 4a                        .bulk   $52,$4a           ;keyholes 1-5, in a row on 5th floor
2cf2: 52 5a                        .bulk   $52,$5a
2cf4: 52 6a                        .bulk   $52,$6a
2cf6: 52 7a                        .bulk   $52,$7a
2cf8: 52 8a                        .bulk   $52,$8a

                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

2cfa: c6 0f        ChkVerbPres     dec     ]verb_index
2cfc: f0 03                        beq     HndVerbPres
2cfe: 4c 2a 2e                     jmp     ChkVerbGet

                   ; 
                   ; Verb $11: PRESS
                   ; 
2d01: a5 0e        HndVerbPres     lda     ]noun_index
2d03: c9 1a                        cmp     #$1a              ;is it a calculator button?
2d05: 10 03                        bpl     :CalcButton       ;yes, branch
2d07: 4c 5a 10                     jmp     PrintLittleSense  ;no, complain

                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

2d0a: a2 06        :CalcButton     ldx     #FN_GET_OBJ_INFO
2d0c: 86 0f                        stx     ]func_cmd
2d0e: a2 03                        ldx     #$03              ;calculator
2d10: 86 0e                        stx     ]func_arg
2d12: 20 34 1a                     jsr     ObjMgmtFunc       ;get calculator info
2d15: a5 1a                        lda     ]counter
2d17: c9 08                        cmp     #$08              ;in inventory and unboxed?
2d19: f0 03                        beq     :HaveCalc         ;yes, branch
2d1b: 4c ad 0b                     jmp     CheckInvDolt

2d1e: ad ad 61     :HaveCalc       lda     monster1_alive    ;is the monster still alive?
2d21: 29 02                        and     #$02
2d23: d0 05                        bne     :NoMagic          ;yes, no teleportation; branch
2d25: ad a5 61                     lda     special_zone      ;are we in a special zone?
2d28: f0 13                        beq     :ButtonPressed    ;no, go do button fanciness
                   ; If the monster is alive, or we're in a special zone (e.g. darkness), the
                   ; buttons don't do anything useful.
2d2a: a9 85        :NoMagic        lda     #$85              ;"the calculator displays"
2d2c: 20 a4 08                     jsr     DrawMsgN_Row23
2d2f: a9 20                        lda     #‘ ’              ;draw space
2d31: 20 92 11                     jsr     PrintSpecialChar
2d34: ad 9d 61                     lda     parsed_noun       ;get noun for pressed button
2d37: 18                           clc                       ;e.g. "zero" is $1a
2d38: 69 16                        adc     #$16              ;add $16 to get ASCII digit ($1a + $16 = $30 = '0')
2d3a: 4c 92 11                     jmp     PrintSpecialChar  ;draw it and bail

                   ]ptr            .var    $0e    {addr/2}

2d3d: ad 9d 61     :ButtonPressed  lda     parsed_noun       ;get button noun index
2d40: 38                           sec                       ;e.g. "zero" is $1a
2d41: e9 19                        sbc     #$19              ;subtract so "zero" = $01
2d43: a2 02                        ldx     #<calc_teleport   ;get pointer to teleport destination data
2d45: 86 0e                        stx     ]ptr
2d47: a2 2e                        ldx     #>calc_teleport
2d49: 86 0f                        stx     ]ptr+1
                   ; 
2d4b: 38           :Loop           sec
2d4c: e9 01                        sbc     #$01              ;decrement modified noun index
2d4e: f0 12                        beq     :Teleport         ;if we hit zero, teleport
2d50: 18                           clc
2d51: 48                           pha                       ;preserve button counter
2d52: a9 04                        lda     #$04              ;advance pointer by 4 bytes
2d54: 65 0e                        adc     ]ptr
2d56: 85 0e                        sta     ]ptr
2d58: a5 0f                        lda     ]ptr+1
2d5a: 69 00                        adc     #$00
2d5c: 85 0f                        sta     ]ptr+1
2d5e: 68                           pla                       ;restore button counter
2d5f: 4c 4b 2d                     jmp     :Loop

2d62: a0 00        :Teleport       ldy     #$00
2d64: b1 0e                        lda     (]ptr),y          ;get facing
2d66: 8d 93 61                     sta     plyr_facing
2d69: e6 0e                        inc     ]ptr              ;(could just INY here)
2d6b: d0 02                        bne     :NoInc
2d6d: e6 0f                        inc     ]ptr+1
2d6f: b1 0e        :NoInc          lda     (]ptr),y          ;get floor
2d71: 8d 94 61                     sta     plyr_floor
2d74: e6 0e                        inc     ]ptr
2d76: d0 02                        bne     :NoInc
2d78: e6 0f                        inc     ]ptr+1
2d7a: b1 0e        :NoInc          lda     (]ptr),y          ;get X position
2d7c: 8d 95 61                     sta     plyr_xpos
2d7f: e6 0e                        inc     ]ptr
2d81: d0 02                        bne     :NoInc
2d83: e6 0f                        inc     ]ptr+1
2d85: b1 0e        :NoInc          lda     (]ptr),y          ;get Y position
2d87: 8d 96 61                     sta     plyr_ypos
2d8a: a2 00                        ldx     #$00
2d8c: 8e a3 61                     stx     floor_move_hi     ;reset step counter
2d8f: 8e a4 61                     stx     floor_move_lo
2d92: ad 9d 61                     lda     parsed_noun       ;get the original noun index
2d95: c9 1c                        cmp     #$1c              ;"two"?
2d97: d0 2a                        bne     :NotTwo           ;no, skip special stuff
2d99: ad 9e 61                     lda     illumination_flag ;is there light?
2d9c: d0 07                        bne     :WasLight         ;yes, branch
2d9e: a2 01                        ldx     #$01              ;no, don't need to extinguish
2da0: 8e a2 61                     stx     ring_light_flag
2da3: d0 1e                        bne     :NotTwo           ;(always)

                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

2da5: ce 9e 61     :WasLight       dec     illumination_flag ;kill the light
2da8: a2 00                        ldx     #$00
2daa: 8e a2 61                     stx     ring_light_flag
2dad: ee 98 61                     inc     num_unlit_torches ;adjust torch inventory, changing
2db0: ce 97 61                     dec     num_lit_torches   ; lit torch to unlit torch
2db3: a2 0d                        ldx     #FN_FIND_LIT_T
2db5: 86 0f                        stx     ]func_cmd
2db7: 20 34 1a                     jsr     ObjMgmtFunc       ;find the first "activated" torch object
2dba: a2 04                        ldx     #FN_GET_OBJ
2dbc: 86 0f                        stx     ]func_cmd
2dbe: 85 0e                        sta     ]func_arg         ;store object index of torch we found
2dc0: 20 34 1a                     jsr     ObjMgmtFunc       ;get the torch
2dc3: a2 03        :NotTwo         ldx     #$03              ;calculator
2dc5: 86 0e                        stx     ]func_arg
2dc7: a2 01                        ldx     #FN_DESTROY_OBJ1
2dc9: 86 0f                        stx     ]func_cmd
2dcb: a2 0a                        ldx     #$0a
2dcd: 8e a5 61                     stx     special_zone      ;now in dark, enable "monster near in darkness"
2dd0: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy the calculator
2dd3: 20 7e 12                     jsr     EraseMaze         ;clear the maze portion of the screen
2dd6: a2 07                        ldx     #FN_DRAW_INV
2dd8: 86 0f                        stx     ]func_cmd
2dda: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
2ddd: a9 86                        lda     #$86              ;"you have been teleported"
2ddf: 20 92 08                     jsr     DrawMsgN_Row22
2de2: a9 74                        lda     #$74              ;"the calculator vanishes"
2de4: 20 a4 08                     jsr     DrawMsgN_Row23
2de7: ad 9d 61                     lda     parsed_noun       ;check noun
2dea: c9 1c                        cmp     #$1c              ;"two"?
2dec: d0 13                        bne     :Return
2dee: ad a2 61                     lda     ring_light_flag   ;is ring already lit?
2df1: d0 0e                        bne     :Return           ;yes, we're done
2df3: 20 45 10                     jsr     LongDelay
2df6: 20 5f 10                     jsr     ClearMessages
2df9: a9 70                        lda     #$70              ;"a draft blows your torch out"
2dfb: 20 a4 08                     jsr     DrawMsgN_Row23
2dfe: 4c dc 0f                     jmp     MediumPause

2e01: 60           :Return         rts

                   ; 
                   ; Calculator teleportation destinations.  One entry for each digit on the
                   ; calculator (0-9).
                   ; 
                   ; Most of the destinations are to locations that you wouldn't otherwise travel
                   ; to.  Since you don't get an in-game indication of which floor you're on, this
                   ; was probably done to make it harder to figure out where you were after the
                   ; teleport: no immediately familiar hallway patterns.  The one that drops you
                   ; right in front of the invisible guillotine is sort of mean, but at least it's
                   ; unambiguous.
                   ; 
                   ;  +$00: facing direction (2=north)
                   ;  +$01: floor (1-5)
                   ;  +$03: X position (1-10)
                   ;  +$04: Y position (1-10)
                   ; 
2e02: 02 02 05 04  calc_teleport   .bulk   $02,$02,$05,$04   ;0 - level 2, near dog #1
2e06: 02 02 07 09                  .bulk   $02,$02,$07,$09   ;1 - level 2, deep in a dead-end
2e0a: 01 05 03 03                  .bulk   $01,$05,$03,$03   ;2 - level 5 (only way there)
2e0e: 02 03 04 06                  .bulk   $02,$03,$04,$06   ;3 - level 3, past perfect square
2e12: 02 01 08 05                  .bulk   $02,$01,$08,$05   ;4 - level 1, near start
2e16: 03 02 01 03                  .bulk   $03,$02,$01,$03   ;5 - level 2, near the entry point
2e1a: 02 01 05 05                  .bulk   $02,$01,$05,$05   ;6 - level 1, near the dagger
2e1e: 01 01 07 0a                  .bulk   $01,$01,$07,$0a   ;7 - level 1, facing the invisible guillotine
2e22: 03 04 09 0a                  .bulk   $03,$04,$09,$0a   ;8 - level 4, near the flute
2e26: 03 03 07 0a                  .bulk   $03,$03,$07,$0a   ;9 - level 3, dead end

                   ]verb_index     .var    $0f    {addr/1}

2e2a: c6 0f        ChkVerbGet      dec     ]verb_index
2e2c: f0 03                        beq     HndVerbGet
2e2e: 4c 98 2f                     jmp     ChkVerbKill

                   ; 
                   ; Verb $12: GET / GRAB / HOLD / TAKE
                   ; 
                   ; Note this is NOT in the range that only applies to inventory objects, so you
                   ; can GET DOOR or GET BAT.
                   ; 
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]obj_index      .var    $11    {addr/1}
                   ]obj_xy         .var    $19    {addr/1}
                   ]obj_state      .var    $1a    {addr/1}

2e31: a2 0b        HndVerbGet      ldx     #FN_OBJ_HERE
2e33: 86 0f                        stx     ]func_cmd
2e35: 20 34 1a                     jsr     ObjMgmtFunc       ;find object on ground in this cell
2e38: aa                           tax                       ;set flags based on value
2e39: d0 03                        bne     :FoundObj         ;found something, branch
2e3b: 4c 30 2f                     jmp     CurrentlyImposs1  ;nothing here, impossible

2e3e: 85 11        :FoundObj       sta     ]obj_index        ;save object index
2e40: 85 0e                        sta     ]func_arg
2e42: a2 06                        ldx     #FN_GET_OBJ_INFO
2e44: 86 0f                        stx     ]func_cmd
2e46: 20 34 1a                     jsr     ObjMgmtFunc       ;get object info
2e49: ad 9d 61                     lda     parsed_noun       ;check what player asked for
2e4c: c9 14                        cmp     #$14              ;box?
2e4e: d0 03                        bne     :NotBox
2e50: 4c de 2e                     jmp     DoGetBox

2e53: c9 12        :NotBox         cmp     #$12              ;food, torch, or non-inventory noun?
2e55: 30 03                        bmi     :GetOrdinary      ;no, branch
2e57: 4c f5 2e                     jmp     GetConsumable     ;yes, go handle it

2e5a: c5 11        :GetOrdinary    cmp     ]obj_index        ;compare noun to object index
2e5c: d0 0c                        bne     :WrongItem        ;noun doesn't match object in box, branch
2e5e: a6 11                        ldx     ]obj_index        ;copy object index to func arg
2e60: 86 0e                        stx     ]func_arg
2e62: a5 1a                        lda     ]obj_state        ;check object state
2e64: c9 06                        cmp     #$06              ;in inventory, boxed? (possible?)
2e66: d0 32                        bne     GetThing          ;no, get thing
2e68: a5 11                        lda     ]obj_index        ;get object index
2e6a: 85 0e        :WrongItem      sta     ]func_arg
2e6c: a2 06                        ldx     #FN_GET_OBJ_INFO
2e6e: 86 0f                        stx     ]func_cmd
2e70: 20 34 1a                     jsr     ObjMgmtFunc       ;get object info
2e73: a9 06                        lda     #$06
2e75: c5 1a                        cmp     ]obj_state        ;in inventory, boxed?
2e77: f0 03                        beq     :BoxedInv         ;yes, branch
2e79: 4c 30 2f                     jmp     CurrentlyImposs1

2e7c: ae 9d 61     :BoxedInv       ldx     parsed_noun       ;get requested noun
2e7f: 86 0e                        stx     ]func_arg         ;use that as thing to get
2e81: 4c 9d 2e                     jmp     :GetOrUnbox

                   ; 
                   ; Check inventory count to see if we have room to pick something up.  On
                   ; failure, pops stack before returning.
                   ; 
                   ]inv_count      .var    $19    {addr/1}

2e84: 20 74 32     CheckInvCount   jsr     SwapZPValues
2e87: a2 08                        ldx     #FN_COUNT_INV
2e89: 86 0f                        stx     ]func_cmd
2e8b: 20 34 1a                     jsr     ObjMgmtFunc
2e8e: a5 19                        lda     ]inv_count
2e90: c9 08                        cmp     #$08              ;have we hit 8 items (including lit torch)?
2e92: 90 03                        bcc     :HaveRoom         ;no, branch
2e94: 4c 35 2f                     jmp     :InvAtLimit       ;print error message, don't return

2e97: 4c 74 32     :HaveRoom       jmp     SwapZPValues

                   ; Continuation of the GET verb handler.
2e9a: 20 84 2e     GetThing        jsr     CheckInvCount     ;make sure we have enough room
2e9d: a2 04        :GetOrUnbox     ldx     #FN_GET_OBJ
2e9f: 86 0f                        stx     ]func_cmd
2ea1: 20 34 1a                     jsr     ObjMgmtFunc       ;move object to inventory, unboxed
2ea4: a2 07        :RedrawAndCont  ldx     #FN_DRAW_INV
2ea6: 86 0f                        stx     ]func_cmd
2ea8: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
                   ; 
2eab: ad 9d 61                     lda     parsed_noun       ;get noun
2eae: c9 03                        cmp     #$03              ;"calculator"?
2eb0: d0 03                        bne     :NotCalc          ;no, branch
2eb2: 20 c2 2e                     jsr     UnboxCalcSpecial  ;do special calculator puzzle stuff
2eb5: c9 11        :NotCalc        cmp     #$11              ;snake?
2eb7: d0 08                        bne     :NotSnake
2eb9: 20 88 27                     jsr     PushSpecialZone
2ebc: a2 0b                        ldx     #$0b              ;snake on the loose
2ebe: 8e a5 61                     stx     special_zone
2ec1: 60           :NotSnake       rts

                   ; 
                   ; Slightly special handling for getting the calculator while standing in the
                   ; calculator puzzle room.  Called for "OPEN BOX" and "GET CALCULATOR".
                   ; 
                   ; On entry:
                   ;   $11: object index ($03)
                   ; 
                   UnboxCalcSpecial
2ec2: ad a5 61                     lda     special_zone      ;are we in the special calculator zone?
2ec5: c9 02                        cmp     #$02              ;(not true if puzzle solved or we dropped it)
2ec7: d0 12                        bne     :NotCalcZone      ;no, nothing for us to do; branch
2ec9: ad 9c 61                     lda     parsed_verb       ;check verb
2ecc: c9 12                        cmp     #$12              ;get?
2ece: f0 03                        beq     :GetCalc          ;yes, skip delay
2ed0: 20 45 10                     jsr     LongDelay         ;no, was "open"; pause
2ed3: 20 5f 10     :GetCalc        jsr     ClearMessages
2ed6: a9 27                        lda     #$27              ;"the calculator displays 317"
2ed8: 20 a4 08                     jsr     DrawMsgN_Row23
2edb: a9 03        :NotCalcZone    lda     #$03              ;return calculator noun ID
2edd: 60                           rts

                   ; 
                   ; Handle GET BOX.  $11 holds the object index, $1a holds the object state from
                   ; the "get object state" function.
                   ; 
                   ]obj_index      .var    $11    {addr/1}
                   ]obj_state      .var    $1a    {addr/1}

2ede: a5 1a        DoGetBox        lda     ]obj_state
2ee0: c9 06                        cmp     #$06              ;currently in inventory?
2ee2: 10 4c                        bpl     CurrentlyImposs1  ;yes, can't get it again
2ee4: 20 84 2e                     jsr     CheckInvCount     ;confirm room in inventory (no return on failure)
2ee7: a6 11                        ldx     ]obj_index
2ee9: 86 0e                        stx     ]func_arg
2eeb: a2 02                        ldx     #FN_GET_BOX_OBJ
2eed: 86 0f                        stx     ]func_cmd
2eef: 20 34 1a                     jsr     ObjMgmtFunc       ;move box to inventory
2ef2: 4c a4 2e                     jmp     :RedrawAndCont

                   ; 
                   ; Special handling for consumables (GET FOOD and GET TORCH) and non-inventory
                   ; objects (GET DOG).  We can only get here if there is a box on the ground.
                   ; 
                   ;   A-reg: noun index ($01-$23)
                   ;   $11: object index for the object in the current cell ($00 if none)
                   ;   $1a: object state 
                   ; 
2ef5: c9 12        GetConsumable   cmp     #$12              ;food?
2ef7: f0 1d                        beq     :GetFood          ;yes, branch
2ef9: a5 11                        lda     ]obj_index        ;get index of object on ground
2efb: c9 18                        cmp     #$18              ;in valid range?
2efd: 10 43                        bpl     :BadObj           ;no, branch (not sure this is possible)
2eff: c9 15                        cmp     #$15              ;is it a torch?
2f01: 30 3f                        bmi     :BadObj           ;no, branch
                   ; Pick up a torch.
2f03: a6 11                        ldx     ]obj_index        ;get object index
2f05: 86 0e                        stx     ]func_arg
2f07: a5 1a                        lda     ]obj_state        ;get state of object on ground
2f09: c9 06                        cmp     #$06              ;is it in our inventory? (how?)
2f0b: f0 90                        beq     :GetOrUnbox       ;yes, deal with that
2f0d: 20 84 2e                     jsr     CheckInvCount     ;make sure we have enough room
2f10: ee 98 61                     inc     num_unlit_torches ;increment unlit torch count
2f13: 4c 9d 2e                     jmp     :GetOrUnbox       ;pick up the item

2f16: a5 11        :GetFood        lda     ]obj_index        ;get object index
2f18: c9 15                        cmp     #$15              ;is it out of valid food range?
2f1a: 10 2c                        bpl     :BadObj1          ;yes, branch
2f1c: c9 12                        cmp     #$12              ;is it out of valid food range?
2f1e: 30 28                        bmi     :BadObj1          ;yes, branch
                   ; Pick up food.
2f20: a6 11                        ldx     ]obj_index        ;get object index
2f22: 86 0e                        stx     ]func_arg
2f24: a5 1a                        lda     ]obj_state
2f26: c9 06                        cmp     #$06              ;is it in our inventory? (how?)
2f28: d0 03                        bne     :NotTorch         ;no, do normal pickup
2f2a: 4c 9d 2e                     jmp     :GetOrUnbox       ;yes, unbox it

2f2d: 4c 9a 2e     :NotTorch       jmp     GetThing

                   CurrentlyImposs1
2f30: a9 9a                        lda     #$9a              ;"it is currently impossible"
2f32: 4c a4 08     :DrawMsg        jmp     DrawMsgN_Row23

2f35: 68           :InvAtLimit     pla                       ;pull return address
2f36: 85 0e                        sta     ]func_arg         ;save in ZP (not used?)
2f38: 68                           pla
2f39: 85 0f                        sta     ]func_cmd
2f3b: 20 74 32                     jsr     SwapZPValues
2f3e: a9 99                        lda     #$99              ;"you are carrying the limit"
2f40: d0 f0                        bne     :DrawMsg          ;(always)

                   ; Search inventory for a boxed torch or food item.
                   ]counter        .var    $11    {addr/1}

2f42: a2 14        :BadObj         ldx     #$14              ;start search at $15 (torches)
2f44: 86 0e                        stx     ]func_arg
2f46: d0 04                        bne     :search           ;(always)

2f48: a2 11        :BadObj1        ldx     #$11              ;start search at $12 (foods)
2f4a: 86 0e                        stx     ]func_arg
2f4c: a5 0f        :search         lda     ]func_cmd
2f4e: 48                           pha
2f4f: a5 0e                        lda     ]func_arg
2f51: 48                           pha
2f52: a2 03                        ldx     #$03              ;repeat 3x
2f54: 86 11                        stx     ]counter
2f56: 68           :Loop           pla
2f57: 85 0e                        sta     ]func_arg
2f59: 68                           pla
2f5a: 85 0f                        sta     ]func_cmd
2f5c: e6 0e                        inc     ]func_arg
2f5e: d0 02                        bne     :NoInc
2f60: e6 0f                        inc     ]func_cmd
2f62: a5 0f        :NoInc          lda     ]func_cmd
2f64: 48                           pha
2f65: a5 0e                        lda     ]func_arg
2f67: 48                           pha
2f68: a2 06                        ldx     #FN_GET_OBJ_INFO
2f6a: 86 0f                        stx     ]func_cmd
2f6c: 20 34 1a                     jsr     ObjMgmtFunc       ;get object info
2f6f: a9 06                        lda     #$06
2f71: c5 1a                        cmp     ]obj_state        ;boxed, in inventory?
2f73: f0 0d                        beq     :FoundBoxInv      ;yes, branch
2f75: c6 11                        dec     ]counter          ;done yet?
2f77: d0 dd                        bne     :Loop             ;no, loop
2f79: 68                           pla
2f7a: 85 0e                        sta     ]func_arg
2f7c: 68                           pla
2f7d: 85 0f                        sta     ]func_cmd
2f7f: 4c 30 2f                     jmp     CurrentlyImposs1  ;not found, report

2f82: 68           :FoundBoxInv    pla
2f83: 85 0e                        sta     ]func_arg
2f85: 68                           pla
2f86: 85 0f                        sta     ]func_cmd
2f88: ad 9d 61                     lda     parsed_noun       ;get the noun
2f8b: c9 13                        cmp     #$13              ;torch?
2f8d: f0 03                        beq     :MoreTorch        ;yes, do that
2f8f: 4c 9d 2e                     jmp     :GetOrUnbox       ;no, just unbox it

2f92: ee 98 61     :MoreTorch      inc     num_unlit_torches ;increase unlit torch count
2f95: 4c 9d 2e                     jmp     :GetOrUnbox       ;unbox the torch

                   ]verb_index     .var    $0f    {addr/1}

2f98: c6 0f        ChkVerbKill     dec     ]verb_index
2f9a: d0 21                        bne     ChkVerbPain
                   ; 
                   ; Verb $13: STAB / KILL / SLASh / ATTAck / HACK
                   ; 
                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

2f9c: a5 0e                        lda     ]noun_index       ;get noun index
2f9e: c9 11                        cmp     #$11              ;snake?
2fa0: f0 15                        beq     :KillCritter      ;yes, branch
2fa2: c9 15                        cmp     #$15              ;bat, dog, monster, elevator, etc?
2fa4: 10 03                        bpl     :CheckMore        ;yes, check some more
2fa6: 4c 5a 10                     jmp     PrintLittleSense

2fa9: c9 1a        :CheckMore      cmp     #$1a              ;calculator button?
2fab: 30 03                        bmi     :NotCalc          ;no, keep looking
2fad: 4c 5a 10                     jmp     PrintLittleSense

2fb0: c9 17        :NotCalc        cmp     #$17              ;door / elev?
2fb2: d0 03                        bne     :KillCritter
2fb4: 4c 5a 10                     jmp     PrintLittleSense

2fb7: a9 90        :KillCritter    lda     #$90              ;"I don't see that here"
2fb9: 20 a4 08     :DrawMsg        jsr     DrawMsgN_Row23    ;(would be in special zone if monster present)
2fbc: 60                           rts

2fbd: c6 0f        ChkVerbPain     dec     ]verb_index
2fbf: d0 18                        bne     ChkVerbGren
                   ; 
                   ; Verb $14: PAINt
                   ; 
                   ; Only works if you have the brush (which does not need to be specified as the
                   ; noun).  Just prints a snarky message.
                   ; 
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

2fc1: a2 02                        ldx     #$02              ;brush
2fc3: 86 0e                        stx     ]func_arg
2fc5: a2 06                        ldx     #FN_GET_OBJ_INFO
2fc7: 86 0f                        stx     ]func_cmd
2fc9: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on brush
2fcc: a5 1a                        lda     ]obj_state
2fce: c9 08                        cmp     #$08              ;in inventory, unboxed?
2fd0: f0 03                        beq     :HaveBrush        ;yes, branch
2fd2: 4c ad 0b                     jmp     CheckInvDolt

2fd5: a9 6f        :HaveBrush      lda     #$6f              ;"with what? toenail polish?"
2fd7: d0 e0                        bne     :DrawMsg

                   ]noun_index     .var    $0e    {addr/1}
                   ]verb_index     .var    $0f    {addr/1}

2fd9: c6 0f        ChkVerbGren     dec     ]verb_index
2fdb: d0 03                        bne     ChkVerbSay
                   ; 
                   ; Verb $15: GRENdel.
                   ; 
                   ; Only useful in one special zone.
                   ; 
2fdd: 4c 5a 10                     jmp     PrintLittleSense

2fe0: c6 0f        ChkVerbSay      dec     ]verb_index
2fe2: d0 39                        bne     ChkVerbChar
                   ; 
                   ; Verb $16: SAY / YELL / SCREam
                   ; 
                   ]dst_ptr        .var    $0a    {addr/2}
                   ]src_ptr        .var    $0e    {addr/2}

2fe4: a9 76                        lda     #$76              ;"OK..."
2fe6: 20 a4 08                     jsr     DrawMsgN_Row23    ;this leaves $0a-0b pointed into 2nd line text buf
2fe9: a9 7a                        lda     #<text_row22      ;set pointer to input buffer
2feb: 85 0e                        sta     ]src_ptr
2fed: a9 0c                        lda     #>text_row22
2fef: 85 0f                        sta     ]src_ptr+1
2ff1: a0 00                        ldy     #$00
2ff3: a9 20                        lda     #‘ ’
2ff5: d1 0e        :ScanLoop       cmp     (]src_ptr),y      ;find the space between the verb and noun
2ff7: f0 15                        beq     :FoundSpace
2ff9: e6 0e                        inc     ]src_ptr
2ffb: d0 f8                        bne     :ScanLoop
2ffd: e6 0f                        inc     ]src_ptr+1
2fff: d0 f4                        bne     :ScanLoop         ;(always)

3001: a0 00        :DrawLoop       ldy     #$00
3003: b1 0e                        lda     (]src_ptr),y      ;get char
3005: c9 20                        cmp     #‘ ’              ;reached the end of the noun?
3007: f0 13                        beq     :Return           ;yes, done
3009: 91 0a                        sta     (]dst_ptr),y      ;add to "OK..." line
300b: 20 a4 11                     jsr     DrawGlyph         ;draw on screen
300e: e6 0a        :FoundSpace     inc     ]dst_ptr
3010: d0 02                        bne     :NoInc
3012: e6 0b                        inc     ]dst_ptr+1
3014: e6 0e        :NoInc          inc     ]src_ptr
3016: d0 e9                        bne     :DrawLoop
3018: e6 0f                        inc     ]src_ptr+1
301a: d0 e5                        bne     :DrawLoop
301c: 60           :Return         rts

                   ]verb_index     .var    $0f    {addr/1}

301d: c6 0f        ChkVerbChar     dec     ]verb_index
301f: f0 03                        beq     HndVerbChar
3021: 4c be 30                     jmp     ChkVerbFart

                   ; 
                   ; Verb $17: CHARge
                   ; 
3024: a9 02        HndVerbChar     lda     #$02
3026: cd 93 61                     cmp     plyr_facing       ;facing north?
3029: d0 47                        bne     :NotSpecWall      ;no, branch
302b: aa                           tax                       ;set A-reg to $01
302c: ca                           dex
302d: 8a                           txa
302e: cd 94 61                     cmp     plyr_floor        ;on first floor?
3031: d0 3f                        bne     :NotSpecWall      ;no, branch
3033: cd 95 61                     cmp     plyr_xpos         ;at X=1?
3036: d0 3a                        bne     :NotSpecWall      ;no, branch
3038: a9 0b                        lda     #11
303a: cd 96 61                     cmp     plyr_ypos         ;at Y=11?
303d: d0 33                        bne     :NotSpecWall      ;no, branch
                   ; In right place for special charge, check hat.
                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}

303f: a2 07                        ldx     #$07              ;hat
3041: 86 0e                        stx     ]func_arg
3043: a2 06                        ldx     #FN_GET_OBJ_INFO
3045: 86 0f                        stx     ]func_cmd
3047: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on hat
304a: a9 07                        lda     #$07
304c: c5 1a                        cmp     ]obj_state        ;is it in inventory and active (worn)?
304e: d0 55                        bne     :BashBrains
3050: 20 15 10                     jsr     DrawMaze          ;redraw maze (?)
3053: 20 dc 0f                     jsr     MediumPause
3056: 20 c5 30                     jsr     FlashYellow       ;do crash and pit fall
3059: 20 7c 10                     jsr     FallIntoPit
305c: ee 94 61                     inc     plyr_floor        ;move to 2nd floor
305f: a2 03                        ldx     #$03
3061: 8e 96 61                     stx     plyr_ypos         ;at 3,3
3064: 8e 95 61                     stx     plyr_xpos
3067: a2 00                        ldx     #$00
3069: 8e a3 61                     stx     floor_move_hi     ;reset move counters
306c: 8e a4 61                     stx     floor_move_lo
306f: 4c 15 10                     jmp     DrawMaze          ;redraw maze and bail

3072: ad 9a 61     :NotSpecWall    lda     maze_walls_rt     ;check distance to facing wall
3075: 29 e0                        and     #$e0
3077: f0 2c                        beq     :BashBrains       ;we've reached wall, go bash brains
3079: 20 85 30                     jsr     :MoveOneStep      ;move one step
307c: 20 dc 0f                     jsr     MediumPause
307f: 20 15 10                     jsr     DrawMaze          ;redraw the maze
3082: 4c 24 30                     jmp     HndVerbChar       ;loop until we die or break through wall

3085: ad 93 61     :MoveOneStep    lda     plyr_facing       ;update position based on facing
3088: aa                           tax                       ;(in a really awkward way)
3089: ca                           dex
308a: 8a                           txa
308b: f0 0c                        beq     :MoveWest
308d: ca                           dex
308e: 8a                           txa
308f: f0 0c                        beq     :MoveNorth
3091: ca                           dex
3092: 8a                           txa
3093: f0 0c                        beq     :MoveEast
3095: ce 96 61                     dec     plyr_ypos         ;move south
3098: 60                           rts

3099: ce 95 61     :MoveWest       dec     plyr_xpos
309c: 60                           rts

309d: ee 96 61     :MoveNorth      inc     plyr_ypos
30a0: 60                           rts

30a1: ee 95 61     :MoveEast       inc     plyr_xpos
30a4: 60                           rts

30a5: 20 15 10     :BashBrains     jsr     DrawMaze
30a8: 20 dc 0f                     jsr     MediumPause
30ab: 20 c5 30                     jsr     FlashYellow       ;flash the lo-res screen
30ae: 20 5f 10                     jsr     ClearMessages
30b1: a9 2a                        lda     #$2a              ;"you have rammed your head into a steel"
30b3: 20 92 08                     jsr     DrawMsgN_Row22
30b6: a9 2b                        lda     #$2b              ;"wall and bashed your brains out"
30b8: 20 a4 08                     jsr     DrawMsgN_Row23
30bb: 4c b9 10                     jmp     HandleDeath       ;go die

                   ]verb_index     .var    $0f    {addr/1}

30be: c6 0f        ChkVerbFart     dec     ]verb_index
30c0: f0 39                        beq     HndVerbFart
30c2: 4c 97 31                     jmp     ChkVerbSave

                   ; 
                   ; Shows a yellow screen, by filling the lo-res graphics screen with yellow and
                   ; then flipping to it briefly.
                   ; 
                   ; Note this tramples the text page 1 screen holes.
                   ; 
                   ]lores_ptr      .var    $0e    {addr/2}

30c5: a2 00        FlashYellow     ldx     #<TEXT_PAGE_1     ;set pointer to text screen
30c7: 86 0e                        stx     ]lores_ptr
30c9: a2 04                        ldx     #<TEXT_PAGE_1+4
30cb: 86 0f                        stx     ]lores_ptr+1
30cd: a0 00                        ldy     #$00
30cf: a9 dd        :Loop           lda     #$dd              ;yellow lo/hi
30d1: 91 0e        :Loop1          sta     (]lores_ptr),y    ;store on text screen
30d3: e6 0e                        inc     ]lores_ptr        ;advance pointer
30d5: d0 fa                        bne     :Loop1
30d7: e6 0f                        inc     ]lores_ptr+1
30d9: a5 0f                        lda     ]lores_ptr+1
30db: c9 08                        cmp     #>TEXT_PAGE_1+$400 ;reached the end of the page?
30dd: d0 f0                        bne     :Loop             ;not yet, loop
30df: 2c 54 c0                     bit     TXTPAGE1          ;page 1
30e2: 2c 52 c0                     bit     MIXCLR            ;full screen
30e5: 2c 56 c0                     bit     LORES             ;lo-res mode
30e8: 2c 50 c0                     bit     TXTCLR            ;graphics on
30eb: 20 dc 0f                     jsr     MediumPause
30ee: 2c 55 c0                     bit     TXTPAGE2          ;page 2
30f1: 2c 52 c0                     bit     MIXCLR            ;full screen
30f4: 2c 57 c0                     bit     HIRES             ;hi-res mode
30f7: 2c 50 c0                     bit     TXTCLR            ;graphics on
30fa: 60                           rts

                   ; 
                   ; Verb $18: FART
                   ; 
                   ]food_tmp       .var    $0e    {addr/2}
                   ]tmp            .var    $19    {addr/2}

30fb: ad a5 61     HndVerbFart     lda     special_zone      ;in a special zone?
30fe: f0 05                        beq     :NotSpec          ;no, branch
3100: a9 98                        lda     #$98              ;"you will do no such thing"
3102: 4c 92 08                     jmp     DrawMsgN_Row22

3105: 20 c5 30     :NotSpec        jsr     FlashYellow       ;visual effects
3108: 4c 11 31                     jmp     :InLoop           ;skip first pause/redraw

310b: 20 dc 0f     :Loop           jsr     MediumPause
310e: 20 15 10                     jsr     DrawMaze
3111: ad 9a 61     :InLoop         lda     maze_walls_rt     ;check distance to facing wall
3114: 29 e0                        and     #$e0
3116: f0 27                        beq     :ReachedWall      ;we reached it
3118: 20 85 30                     jsr     :MoveOneStep
                   ; Check for guillotine.  This seems redundant with the test in CheckSpecialCell
                   ; ($0a10).
311b: ad 94 61                     lda     plyr_floor
311e: c9 01                        cmp     #$01              ;on 1st floor?
3120: d0 0e                        bne     :NoGuil           ;no, branch
3122: ad 95 61                     lda     plyr_xpos
3125: c9 06                        cmp     #$06              ;X=6?
3127: d0 07                        bne     :NoGuil           ;no, branch
3129: ad 96 61                     lda     plyr_ypos
312c: c9 0a                        cmp     #$0a              ;Y=10?
312e: f0 06                        beq     :DeathByG         ;yes, branch and die
3130: 20 19 0b     :NoGuil         jsr     ReduceResources   ;reduce food/torch
3133: 4c 0b 31                     jmp     :Loop

3136: 20 15 10     :DeathByG       jsr     DrawMaze
3139: 20 dc 0f                     jsr     MediumPause
313c: 4c 4a 0a                     jmp     ReportGuillotine

313f: 20 15 10     :ReachedWall    jsr     DrawMaze
3142: ae 9f 61                     ldx     food_level_hi     ;copy satiation level to ZP
3145: 86 0f                        stx     ]food_tmp+1
3147: ae a0 61                     ldx     food_level_lo
314a: 86 0e                        stx     ]food_tmp
314c: a5 0f                        lda     ]food_tmp+1       ;is player too hungry to fart?
314e: d0 0d                        bne     :NotStarving      ;no, branch
3150: a5 0e                        lda     ]food_tmp
3152: c9 05                        cmp     #$05              ;is food level >= 5?
3154: b0 03                        bcs     :NotStarving1     ;yes, branch
3156: 4c 64 0b                     jmp     StarvedToDeath    ;no, food is 1-4, starve now

3159: c9 0f        :NotStarving1   cmp     #$0f              ;food level < 15?
315b: 90 33                        bcc     :NearlyStarving   ;yes, branch
                   ; Reduce energy level by 10 (on top of the per-step cost).
315d: a9 00        :NotStarving    lda     #$00              ;reduce food level by 10
315f: 85 1a                        sta     ]tmp+1
3161: a9 0a                        lda     #10
3163: 85 19                        sta     ]tmp
3165: a5 0e                        lda     ]food_tmp
3167: 38                           sec
3168: e5 19                        sbc     ]tmp              ;(could SBC #10 on $619f-61a0 directly)
316a: 85 0e                        sta     ]food_tmp
316c: a5 0f                        lda     ]food_tmp+1
316e: e5 1a                        sbc     ]tmp+1
3170: 85 0f                        sta     ]food_tmp+1
3172: 8d 9f 61                     sta     food_level_hi
3175: a5 0e                        lda     ]food_tmp
3177: 8d a0 61                     sta     food_level_lo
317a: 20 dc 0f     :WhamWall       jsr     MediumPause       ;pause for each step
317d: 20 7e 12                     jsr     EraseMaze         ;redraw maze after pause
3180: a9 2d                        lda     #$2d              ;"wham"
3182: a2 08                        ldx     #8
3184: 86 06                        stx     char_horiz
3186: a2 0a                        ldx     #10
3188: 86 07                        stx     char_vert
318a: 20 e2 08                     jsr     DrawMsgN
318d: 4c 10 0a                     jmp     CheckSpecialCell  ;check for special (can't run past dog)

3190: a2 05        :NearlyStarving ldx     #$05              ;set level to 5
3192: 8e a0 61                     stx     food_level_lo
3195: d0 e3                        bne     :WhamWall         ;(always)

                   ]verb_index     .var    $0f    {addr/1}

3197: c6 0f        ChkVerbSave     dec     ]verb_index
3199: d0 44                        bne     ChkVerbQuit
                   ; 
                   ; Verb $19: SAVE
                   ; 
319b: ad a5 61                     lda     special_zone      ;disallow save while in special zone
319e: f0 05                        beq     AskSaveGame
31a0: a9 9a                        lda     #$9a              ;"it is currently impossible"
31a2: 4c a4 08                     jmp     DrawMsgN_Row23

31a5: 20 5f 10     AskSaveGame     jsr     ClearMessages
31a8: a9 93                        lda     #$93              ;"do you wish to save the game?"
31aa: 20 92 08                     jsr     DrawMsgN_Row22
31ad: 20 f7 0f                     jsr     GetYesNo
31b0: 29 7f                        and     #$7f
31b2: c9 59                        cmp     #‘Y’
31b4: f0 03                        beq     :DoSaveGame
31b6: 4c 5f 10                     jmp     ClearMessages

31b9: 4c 66 7c     :DoSaveGame     jmp     SaveDiskOrTape

31bc: a9 95        SaveToTape      lda     #$95              ;"please prepare your cassette"
31be: 20 92 08                     jsr     DrawMsgN_Row22
31c1: a9 96                        lda     #$96              ;"when ready, press any key"
31c3: 20 a4 08                     jsr     DrawMsgN_Row23
31c6: 20 e9 0f                     jsr     WaitKeyCursor     ;wait for keypress
31c9: a2 93                        ldx     #<plyr_facing
31cb: 86 3c                        stx     MON_A1L
31cd: a2 61                        ldx     #>plyr_facing
31cf: 86 3d                        stx     MON_A1H
31d1: a2 92                        ldx     #<plyr_facing-1
31d3: 86 3e                        stx     MON_A2L
31d5: a2 62                        ldx     #>plyr_facing+$100
31d7: 86 3f                        stx     MON_A2H
31d9: 20 cd fe                     jsr     MON_WRITE         ;write data to tape
31dc: 4c 5f 10                     jmp     ClearMessages

31df: c6 0f        ChkVerbQuit     dec     ]verb_index
31e1: d0 18                        bne     ChkVerbInst
                   ; 
                   ; Verb $1a: QUIT
                   ; 
31e3: 20 5f 10                     jsr     ClearMessages
31e6: a9 9c                        lda     #$9c              ;"are you sure you want to quit?"
31e8: 20 92 08                     jsr     DrawMsgN_Row22
31eb: 20 f7 0f                     jsr     GetYesNo
31ee: c9 59                        cmp     #‘Y’
31f0: f0 03                        beq     :DoQuit
31f2: 4c 5f 10                     jmp     ClearMessages

31f5: 20 a5 31     :DoQuit         jsr     AskSaveGame       ;allow player to save game, even if in special zone
31f8: 4c c4 10                     jmp     AskPlayAgain

31fb: c6 0f        ChkVerbInst     dec     ]verb_index
31fd: d0 39                        bne     HndVerbHelp
                   ; 
                   ; Verb $1b: INSTtructions / DIREctions
                   ; 
                   ; Shows full page of instructions.
                   ; 
                   ]inst_ptr       .var    $0e    {addr/2}

31ff: 20 55 08                     jsr     ClearScreen       ;clear hi-res screen
3202: a9 00                        lda     #$00
3204: 85 06                        sta     char_horiz        ;set text position to top left
3206: 85 07                        sta     char_vert
3208: 20 ef 11                     jsr     SetRowPtr
320b: a2 bf                        ldx     #<instructions    ;get pointer to instruction text
320d: 86 0e                        stx     ]inst_ptr
320f: a2 77                        ldx     #>instructions
3211: 86 0f                        stx     ]inst_ptr+1
                   ; Copy text, skipping the first byte.
3213: e6 0e        :Loop           inc     ]inst_ptr
3215: d0 02                        bne     :NoInc
3217: e6 0f                        inc     ]inst_ptr+1
3219: a0 00        :NoInc          ldy     #$00
321b: b1 0e                        lda     (]inst_ptr),y     ;get char
321d: 29 7f                        and     #$7f              ;strip high bit
321f: 20 92 11                     jsr     PrintSpecialChar  ;print it
3222: a0 00                        ldy     #$00
3224: b1 0e                        lda     (]inst_ptr),y     ;get char again
3226: 10 eb                        bpl     :Loop             ;branch if not done
                   ]func_cmd       .var    $0f    {addr/1}

3228: 20 e9 0f                     jsr     WaitKeyCursor     ;wait for any key
322b: 20 55 08                     jsr     ClearScreen       ;clear and redraw screen
322e: 20 15 10                     jsr     DrawMaze
3231: a9 07                        lda     #FN_DRAW_INV
3233: 85 0f                        sta     ]func_cmd
3235: 4c 34 1a                     jmp     ObjMgmtFunc       ;draw inventory

                   ; 
                   ; Verb $1c: HELP / HINT
                   ; 
3238: ad a5 61     HndVerbHelp     lda     special_zone      ;check for special zone
323b: c9 02                        cmp     #$02              ;calculator room?
323d: f0 19                        beq     :CalcHelp         ;yes, show specific help
323f: ad b1 61                     lda     help_ctr          ;no, alternate responses
3242: f0 0b                        beq     :Help0
3244: a9 9d                        lda     #$9d              ;"try examining things"
3246: 20 a4 08                     jsr     DrawMsgN_Row23
3249: a2 00                        ldx     #$00
324b: 8e b1 61                     stx     help_ctr          ;reset counter
324e: 60                           rts

324f: a9 9e        :Help0          lda     #$9e              ;"type instructions"
3251: 20 a4 08                     jsr     DrawMsgN_Row23
3254: ee b1 61                     inc     help_ctr          ;change message for next time
3257: 60                           rts

3258: a9 9f        :CalcHelp       lda     #$9f              ;"invert and telephone"
325a: 4c a4 08                     jmp     DrawMsgN_Row23

                   ; Show the elevator-open animation.
                   OpenElevatorAnim
325d: 20 15 10                     jsr     DrawMaze
3260: a9 0a                        lda     #$0a              ;elevator opening
3262: 85 0f                        sta     ]func_cmd
3264: 4c 5a 1e                     jmp     DrawFeature       ;show the animation

                   ; Swaps the accumulator with a value in memory.
                   • Clear variables

3267: 85 13        SwapOutAReg     sta     $13
3269: ad f7 61                     lda     acc_swap_stash
326c: 48                           pha
326d: a5 13                        lda     $13
326f: 8d f7 61                     sta     acc_swap_stash
3272: 68                           pla
3273: 60                           rts

                   ; 
                   ; Swaps zero page values at $0e-11 and $19-1a with saved values in program
                   ; memory.
                   ; 
3274: a5 0e        SwapZPValues    lda     $0e
3276: aa                           tax
3277: ad f8 61                     lda     saved_0e
327a: 85 0e                        sta     $0e
327c: 8a                           txa
327d: 8d f8 61                     sta     saved_0e
3280: a5 0f                        lda     $0f
3282: aa                           tax
3283: ad f9 61                     lda     saved_0f
3286: 85 0f                        sta     $0f
3288: 8a                           txa
3289: 8d f9 61                     sta     saved_0f
328c: a5 10                        lda     $10
328e: aa                           tax
328f: ad fa 61                     lda     saved_10
3292: 85 10                        sta     $10
3294: 8a                           txa
3295: 8d fa 61                     sta     saved_10
3298: a5 11                        lda     $11
329a: aa                           tax
329b: ad fb 61                     lda     saved_11
329e: 85 11                        sta     $11
32a0: 8a                           txa
32a1: 8d fb 61                     sta     saved_11
32a4: a5 19                        lda     $19
32a6: aa                           tax
32a7: ad fc 61                     lda     saved_19
32aa: 85 19                        sta     $19
32ac: 8a                           txa
32ad: 8d fc 61                     sta     saved_19
32b0: ad fd 61                     lda     saved_1a
32b3: aa                           tax
32b4: a5 1a                        lda     $1a
32b6: 8d fd 61                     sta     saved_1a
32b9: 8a                           txa
32ba: 85 1a                        sta     $1a
32bc: 60                           rts

                   ; 
                   ; Decrements $0e/0f as a 16-bit value.  Preserves all registers.
                   ; 
                   ; Only called from one place, for mysterious reasons.
                   ; 
                   ]val            .var    $0e    {addr/2}

32bd: 48           Decr0e0f        pha
32be: c6 0e                        dec     ]val
32c0: a5 0e                        lda     ]val
32c2: c9 ff                        cmp     #$ff
32c4: d0 02                        bne     :NoDec
32c6: c6 0f                        dec     ]val+1
32c8: 68           :NoDec          pla
32c9: 60                           rts

                   ; 
                   ; Inscription on hat.  (Not sure why this isn't in the string table.)
32ca: 41 4e 20 49+ hat_inscript    .str    ‘AN INSCRIPTION READS: WEAR THIS HAT AND CHARGE A WALL NEAR WHE’
                                    +      ‘RE YOU FOUND IT!’
3318: a0                           .dd1    $a0

                   ; 
                   ; Prints special message written on hat.
                   ; 
                   ]txt_ptr        .var    $0c    {addr/2}

3319: a2 32        PrintHatMsg     ldx     #>hat_inscript
331b: 86 0d                        stx     ]txt_ptr+1
331d: a2 ca                        ldx     #<hat_inscript
331f: 86 0c                        stx     ]txt_ptr
3321: 20 5f 10                     jsr     ClearMessages
3324: a9 00                        lda     #0
3326: 85 06                        sta     char_horiz
3328: a9 16                        lda     #22
332a: 85 07                        sta     char_vert
332c: 4c e5 08                     jmp     DrawMsg

                   ; 
                   ; Additional check for THROW.  If the player did "throw ball" outside the
                   ; special zone, die in a fiery explosion.  Otherwise, returns with Z-flag clear
                   ; if monster #1 is alive.
                   ; 
                   CheckThrowTarget
332f: ad 9d 61                     lda     parsed_noun
3332: c9 01                        cmp     #$01              ;ball?
3334: f0 06                        beq     :ThrowBall
3336: ad ad 61                     lda     monster1_alive    ;do monster check
3339: 29 02                        and     #$02
333b: 60                           rts

333c: 20 c5 30     :ThrowBall      jsr     FlashYellow       ;explosion and death
333f: 20 55 08                     jsr     ClearScreen
3342: 4c b9 10                     jmp     HandleDeath

3345: 07 ea                        .junk   2

                   ; 
                   ; Handles behavior in special zones, e.g. when encountering the dog, bat, or
                   ; playing the flute to raise the snake.  Generally speaking the player must
                   ; either solve the problem (kill the bat, climb the snake, move correctly in the
                   ; calculator room, etc.) before moving on.
                   ; 
                   ; The zone is specified by $61a5; see comments there for a list.
                   ; 
                   • Clear variables

                   HandleSpecialZone
3347: ae a5 61                     ldx     special_zone      ;in special zone?
334a: d0 01                        bne     :NonZero          ;yes, handle it
334c: 60                           rts                       ;no, bail

334d: ca           :NonZero        dex                       ;see if X-reg holds $02
334e: ca                           dex
334f: f0 03                        beq     SpecCalcRoom
3351: 4c 57 34                     jmp     ChkSpec04

                   ; 
                   ; Special $02: calculator room.
                   ; 
                   ; Player must turn 5x/4x/3x to escape.
                   ; 
                   ]tmp            .var    $1a    {addr/1}

3354: 20 15 10     SpecCalcRoom    jsr     DrawMaze
3357: 20 22 34                     jsr     InitCalcMove      ;initialize counters
335a: a2 01                        ldx     #$01
335c: 86 1a                        stx     ]tmp
335e: 20 f3 33                     jsr     PrintCalcPuzMsg
3361: 20 ca 0c     :CalcLoop       jsr     GetInput
3364: ad 9c 61                     lda     parsed_verb       ;get action
3367: c9 46                        cmp     #$46              ;was it movement (>= $40)?
3369: 10 0f                        bpl     :WasMove          ;yes, branch
336b: 20 40 26                     jsr     ExecParsedInput   ;not movement, handle it
336e: 20 19 0b     :SpendMove      jsr     ReduceResources   ;all actions here diminish resources
3371: 20 77 0b                     jsr     ReportLowRsrc
3374: 20 35 34                     jsr     ShowCalcPuzMsg
3377: 4c 61 33                     jmp     :CalcLoop

337a: c9 5b        :WasMove        cmp     #VERB_FWD         ;moved forward?
337c: f0 5f                        beq     :SplatAndReset    ;yes, branch
337e: 85 1a                        sta     ]tmp              ;save verb
3380: ad b6 61                     lda     calc_prev_move    ;first move?
3383: d0 0b                        bne     :NotFirst         ;no, branch
3385: a6 1a                        ldx     ]tmp
3387: 8e b6 61                     stx     calc_prev_move    ;save verb
338a: ee b5 61                     inc     calc_turn_count   ;increment first turn counter
338d: 4c d4 33                     jmp     :DrawAndCont

3390: c5 1a        :NotFirst       cmp     ]tmp              ;same as last time?
3392: d0 1d                        bne     :Changed          ;no, branch
3394: ee b5 61                     inc     calc_turn_count   ;increment the turn counter
3397: ad b4 61                     lda     calc_turn_goal    ;check the goal
339a: c9 03                        cmp     #$03              ;are we on the last set?
339c: d0 36                        bne     :DrawAndCont      ;not yet, branch
339e: cd b5 61                     cmp     calc_turn_count   ;on last set; have we turned 3x?
33a1: d0 31                        bne     :DrawAndCont      ;no, branch
                   ; Puzzle complete.
33a3: a2 04                        ldx     #$04
33a5: 8e 93 61                     stx     plyr_facing       ;set direction to south
33a8: 20 15 10                     jsr     DrawMaze
33ab: 20 22 34                     jsr     InitCalcMove      ;reset counters
33ae: 4c d5 34                     jmp     PopSpecialZone    ;done with puzzle

33b1: a6 1a        :Changed        ldx     ]tmp
33b3: 8e b6 61                     stx     calc_prev_move    ;save verb
33b6: ad b4 61                     lda     calc_turn_goal    ;get goal
33b9: cd b5 61                     cmp     calc_turn_count   ;have we reached it?
33bc: d0 0b                        bne     :FailReset        ;no, stopped early; reset
33be: a2 01                        ldx     #$01
33c0: 8e b5 61                     stx     calc_turn_count   ;reset count, counting this move as first
33c3: ce b4 61                     dec     calc_turn_goal    ;next set requires one fewer turn
33c6: 4c d4 33                     jmp     :DrawAndCont

                   ; We failed; reset movement, counting this move as the first step.
33c9: 20 27 34     :FailReset      jsr     ResetCalcMove     ;reset counters
33cc: ee b5 61                     inc     calc_turn_count   ;add one turn
33cf: a6 1a                        ldx     ]tmp
33d1: 8e b6 61                     stx     calc_prev_move    ;save verb
33d4: 20 15 10     :DrawAndCont    jsr     DrawMaze
33d7: ee b7 61                     inc     calc_total_moves
33da: 4c 6e 33                     jmp     :SpendMove

33dd: 20 7e 12     :SplatAndReset  jsr     EraseMaze         ;do the usual walk-into-walls thing
33e0: a2 09                        ldx     #9
33e2: 86 06                        stx     char_horiz
33e4: a2 0a                        ldx     #10
33e6: 86 07                        stx     char_vert
33e8: a9 7c                        lda     #$7c              ;"splat"
33ea: 20 e2 08                     jsr     DrawMsgN
33ed: 20 27 34                     jsr     ResetCalcMove     ;reset puzzle movement counters
33f0: 4c 61 33                     jmp     :CalcLoop         ;loop

                   ; 
                   ; Prints the calculator puzzle message.
                   ; 
                   ; On entry:
                   ;   $1a: suppress additional text if set to 1
                   ; 
                   ]suppress_msg   .var    $1a    {addr/1}

33f3: ad 9c 61     PrintCalcPuzMsg lda     parsed_verb       ;check verb
33f6: c9 08                        cmp     #$08              ;drop?
33f8: f0 07                        beq     :NoDelay          ;yes, branch
33fa: c9 5a                        cmp     #$5a              ;movement?
33fc: 10 03                        bpl     :NoDelay          ;yes, branch
33fe: 20 45 10                     jsr     LongDelay         ;pause briefly so prev msg is viewable
3401: a9 24        :NoDelay        lda     #$24              ;"to everything"
3403: 20 92 08                     jsr     DrawMsgN_Row22    ;draw string
3406: a5 1a                        lda     ]suppress_msg     ;check "turn,turn,turn" flag
3408: c9 01                        cmp     #$01              ;is it 1?
340a: f0 05                        beq     :NoTurn1          ;yes, don't show msg
340c: a9 26                        lda     #$26              ;"turn, turn, turn"
340e: 20 e2 08                     jsr     DrawMsgN          ;append to previous message
3411: a9 25        :NoTurn1        lda     #$25              ;"there is a season"
3413: 20 a4 08                     jsr     DrawMsgN_Row23
3416: a5 1a                        lda     ]suppress_msg     ;check "turn,turn,turn" flag
3418: c9 01                        cmp     #$01              ;is it 1?
341a: f0 05                        beq     :Return           ;yes, don't show msg
341c: a9 26                        lda     #$26              ;"turn, turn, turn"
341e: 20 e2 08                     jsr     DrawMsgN          ;append to previous message
3421: 60           :Return         rts

                   ; 
                   ; Initializes calculator puzzle counters.
                   ; 
3422: a2 00        InitCalcMove    ldx     #$00
3424: 8e b7 61                     stx     calc_total_moves
                   ; 
                   ; Resets calculator puzzle movement counters.
                   ; 
3427: a2 05        ResetCalcMove   ldx     #$05              ;first set should be 5 turns
3429: 8e b4 61                     stx     calc_turn_goal
342c: a2 00                        ldx     #$00
342e: 8e b5 61                     stx     calc_turn_count
3431: 8e b6 61                     stx     calc_prev_move
3434: 60                           rts

                   ; 
                   ; Determines whether or not we should show the ", TURN, TURN, TURN" string, then
                   ; branches to the code that prints the in-puzzle message.
                   ; 
3435: ad b7 61     ShowCalcPuzMsg  lda     calc_total_moves  ;check total moves
3438: c9 06                        cmp     #6                ;0-5?
343a: 90 0d                        bcc     :SetTurnFlag      ;yes, set flag and print
343c: c9 0f                        cmp     #15               ;6-14?
343e: 90 e1                        bcc     :Return           ;yes, show nothing
3440: c9 15                        cmp     #21               ;15-20?
3442: 90 05                        bcc     :SetTurnFlag      ;yes, set flag and print
3444: c9 1a                        cmp     #26               ;21-25?
3446: 90 08                        bcc     :ClearTurnFlag    ;yes, clear flag and print
3448: 60                           rts

3449: a2 01        :SetTurnFlag    ldx     #$01
344b: 86 1a                        stx     ]suppress_msg
344d: 4c f3 33                     jmp     PrintCalcPuzMsg

3450: a2 00        :ClearTurnFlag  ldx     #$00
3452: 86 1a                        stx     ]suppress_msg
3454: 4c f3 33                     jmp     PrintCalcPuzMsg

3457: ca           ChkSpec04       dex
3458: ca                           dex
3459: f0 03                        beq     BatAttack
345b: 4c f0 34                     jmp     ChkSpec06

                   ; 
                   ; Special $04: vampire bat. The player must do the correct counter-move, or they
                   ; die.
                   ; 
                   • Clear variables
                   ]saved_noun     .var    $1a    {addr/1}

345e: 20 15 10     BatAttack       jsr     DrawMaze
3461: a9 31                        lda     #$31              ;"a vampire bat attacks you"
3463: 20 a4 08                     jsr     DrawMsgN_Row23
3466: 20 45 10                     jsr     LongDelay
3469: 20 ca 0c     :BatInput       jsr     GetInput          ;get a command
346c: ae 9d 61                     ldx     parsed_noun
346f: 86 1a                        stx     ]saved_noun
3471: ad 9c 61                     lda     parsed_verb
3474: c9 0e                        cmp     #$0e              ;examine?
3476: f0 13                        beq     :ExamBat          ;yes, branch
3478: c9 06                        cmp     #$06              ;throw?
347a: f0 1d                        beq     :ThrowAtBat       ;yes, handle it
347c: c9 03                        cmp     #$03              ;break?
347e: f0 19                        beq     :ThrowAtBat       ;yes, treat same as throw
3480: 20 5f 10     :DeathByBat     jsr     ClearMessages
3483: a9 9b                        lda     #$9b              ;"the bat drains you of your vital fluids"
3485: 20 92 08                     jsr     DrawMsgN_Row22
3488: 4c b9 10                     jmp     HandleDeath

348b: a5 1a        :ExamBat        lda     ]saved_noun
348d: c9 15                        cmp     #$15              ;bat?
348f: d0 ef                        bne     :DeathByBat       ;no, can only look at bad; die
3491: a9 8c                        lda     #$8c              ;"it looks very dangerous"
3493: 20 a4 08                     jsr     DrawMsgN_Row23
3496: 4c 69 34                     jmp     :BatInput         ;let them try again

                   ]func_arg       .var    $0e    {addr/1}
                   ]func_cmd       .var    $0f    {addr/1}
                   ]obj_state      .var    $1a    {addr/1}

3499: 20 5f 10     :ThrowAtBat     jsr     ClearMessages
349c: a2 09                        ldx     #$09              ;jar
349e: 86 0e                        stx     ]func_arg
34a0: a2 06                        ldx     #FN_GET_OBJ_INFO
34a2: 86 0f                        stx     ]func_cmd
34a4: 20 34 1a                     jsr     ObjMgmtFunc
34a7: a5 1a                        lda     ]obj_state
34a9: c9 07                        cmp     #$07              ;do we have monster blood?
34ab: d0 d3                        bne     :DeathByBat       ;no, die
34ad: ad 9d 61                     lda     parsed_noun
34b0: c9 09                        cmp     #$09              ;throwing or breaking jar?
34b2: d0 cc                        bne     :DeathByBat       ;no, die
                   ; 
34b4: a9 50                        lda     #$50              ;"what a mess! the vampire bat"
34b6: 20 92 08                     jsr     DrawMsgN_Row22
34b9: a9 51                        lda     #$51              ;"drinks the blood and dies"
34bb: 20 a4 08                     jsr     DrawMsgN_Row23
34be: a2 00                        ldx     #FN_DESTROY_OBJ   ;destroy item
34c0: 86 0f                        stx     ]func_cmd
34c2: a2 09                        ldx     #$09              ;jar
34c4: 86 0e                        stx     ]func_arg
34c6: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy jar
34c9: a2 07                        ldx     #FN_DRAW_INV
34cb: 86 0f                        stx     ]func_cmd
34cd: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
34d0: a2 00                        ldx     #$00
34d2: 8e ab 61                     stx     bat_alive         ;mark bat as dead
                   ; 
                   ; Pops the current special zone off.
                   ; 
                   ]tmp            .var    $1a    {addr/1}

34d5: ad a6 61     PopSpecialZone  lda     special_zone1     ;shift everything up
34d8: 85 1a                        sta     ]tmp
34da: 8d a5 61                     sta     special_zone
34dd: ae a7 61                     ldx     special_zone2
34e0: 8e a6 61                     stx     special_zone1
34e3: a2 00                        ldx     #$00
34e5: 8e a7 61                     stx     special_zone2
34e8: a5 1a                        lda     ]tmp              ;are we in a special zone now?
34ea: f0 03                        beq     :Return           ;no, bail
34ec: 4c 47 33                     jmp     HandleSpecialZone ;yes, handle it

34ef: 60           :Return         rts

34f0: ca           ChkSpec06       dex
34f1: ca                           dex
34f2: d0 0b                        bne     ChkSpec07
                   ; 
                   ; Special $06: dog #1 (2nd floor, after 60 steps).
                   ; 
34f4: 20 10 35                     jsr     SpecDogCommon     ;handle dog; does not return if we die
34f7: a2 00                        ldx     #$00
34f9: 8e ae 61                     stx     dog1_alive        ;mark dog #1 as dead
34fc: 4c d5 34                     jmp     PopSpecialZone

34ff: ca           ChkSpec07       dex
3500: f0 03                        beq     SpecDog2
3502: 4c ea 35                     jmp     ChkSpec08

                   ; 
                   ; Special $07: dog #2 (2nd floor, X=5 Y=5).
                   ; 
3505: 20 10 35     SpecDog2        jsr     SpecDogCommon     ;handle dog; does not return if we die
3508: a2 00                        ldx     #$00
350a: 8e af 61                     stx     dog2_alive        ;mark dog #2 as dead
350d: 4c d5 34                     jmp     PopSpecialZone

                   ; 
                   ; Common code for handling encounter with dog.  If we die this jumps to the
                   ; death handler, if we kill the dog this returns to the caller.
                   ; 
                   ]noun_copy      .var    $1a    {addr/1}

3510: 20 15 10     SpecDogCommon   jsr     DrawMaze
3513: a9 2e                        lda     #$2e
3515: 20 a4 08                     jsr     DrawMsgN_Row23    ;"a vicious dog attacks you"
3518: 20 45 10                     jsr     LongDelay
351b: 20 ca 0c                     jsr     GetInput
351e: ad 9d 61                     lda     parsed_noun
3521: 85 1a                        sta     ]noun_copy        ;stash a copy of the noun in ZP
3523: ad 9c 61                     lda     parsed_verb
3526: c9 59                        cmp     #$59              ;player movement?
3528: b0 0c                        bcs     :DeathByDog       ;yes, branch (to death)
352a: c9 06                        cmp     #$06              ;throw?
352c: f0 71                        beq     :ThrowSomething   ;yes, branch
352e: c9 13                        cmp     #$13              ;kill?
3530: f0 1d                        beq     :KillSomething    ;yes, branch
3532: c9 0e                        cmp     #$0e              ;examine?
3534: f0 0b                        beq     :ExamSomething    ;yes, branch
3536: 20 5f 10     :DeathByDog     jsr     ClearMessages
3539: a9 2f                        lda     #$2f              ;"he rips your throat out"
353b: 20 a4 08                     jsr     DrawMsgN_Row23
353e: 4c b9 10                     jmp     HandleDeath       ;ow

3541: a5 1a        :ExamSomething  lda     ]noun_copy        ;get noun
3543: c9 16                        cmp     #$16              ;dog?
3545: d0 ef                        bne     :DeathByDog       ;no, branch to pay the price for ADD
3547: a9 28                        lda     #$28              ;"it displays 317.2"
3549: 20 a4 08                     jsr     DrawMsgN_Row23    ;(BUG... should be $8c in row 22?)
354c: 4c 10 35                     jmp     SpecDogCommon

354f: a5 1a        :KillSomething  lda     ]noun_copy        ;get noun
3551: c9 16                        cmp     #$16              ;dog?
3553: d0 e1                        bne     :DeathByDog       ;no, branch (to death)
                   ]obj_state      .var    $1a    {addr/1}

3555: a2 04                        ldx     #$04              ;dagger
3557: 86 0e                        stx     ]func_arg
3559: a2 06                        ldx     #FN_GET_OBJ_INFO
355b: 86 0f                        stx     ]func_cmd
355d: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on dagger
3560: a9 08                        lda     #$08
3562: c5 1a                        cmp     ]obj_state        ;in inventory and unboxed?
3564: f0 1f                        beq     :WithDagger       ;yes, branch
3566: a2 0e                        ldx     #$0e              ;sword
3568: 86 0e                        stx     ]func_arg
356a: a2 06                        ldx     #FN_GET_OBJ_INFO
356c: 86 0f                        stx     ]func_cmd
356e: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on sword
3571: a9 08                        lda     #$08
3573: c5 1a                        cmp     ]obj_state        ;in inventory and unboxed?
3575: d0 bf                        bne     :DeathByDog       ;no, branch to die
3577: 20 5f 10                     jsr     ClearMessages
357a: a9 97                        lda     #$97              ;"and it vanishes"
357c: 20 a4 08                     jsr     DrawMsgN_Row23
357f: a9 63        :KilledIt       lda     #$63              ;"you have killed it"
3581: 20 92 08                     jsr     DrawMsgN_Row22
3584: 60                           rts                       ;return triumphantly

3585: a2 00        :WithDagger     ldx     #FN_DESTROY_OBJ
3587: 86 0f                        stx     ]func_cmd
3589: a2 04                        ldx     #$04              ;dagger
358b: 86 0e                        stx     ]func_arg
358d: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy dagger
3590: a2 07                        ldx     #FN_DRAW_INV
3592: 86 0f                        stx     ]func_cmd
3594: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
3597: a9 64                        lda     #$64              ;"the dagger disappears"
3599: 20 a4 08                     jsr     DrawMsgN_Row23
359c: 4c 7f 35                     jmp     :KilledIt

359f: a5 1a        :ThrowSomething lda     ]obj_state        ;get noun
35a1: c9 0c                        cmp     #$0c              ;sneaker?
35a3: d0 91                        bne     :DeathByDog       ;no, branch to death
35a5: a2 0c                        ldx     #$0c              ;sneaker
35a7: 86 0e                        stx     ]func_arg
35a9: a2 06                        ldx     #FN_GET_OBJ_INFO
35ab: 86 0f                        stx     ]func_cmd
35ad: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on sneaker
35b0: a9 08                        lda     #$08
35b2: c5 1a                        cmp     ]obj_state        ;in inventory and unboxed?
35b4: d0 80                        bne     :DeathByDog       ;no, die
35b6: a2 0c                        ldx     #$0c              ;sneaker
35b8: 86 0e                        stx     ]func_arg
35ba: a2 00                        ldx     #FN_DESTROY_OBJ
35bc: 86 0f                        stx     ]func_cmd
35be: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy sneaker
35c1: 20 d9 28                     jsr     SailAroundCorner
35c4: a9 5c                        lda     #$5c              ;"and is eaten by"
35c6: 20 92 08                     jsr     DrawMsgN_Row22
35c9: a9 5d                        lda     #$5d              ;"the monster"
35cb: 20 a4 08                     jsr     DrawMsgN_Row23
35ce: 20 45 10                     jsr     LongDelay
35d1: 20 5f 10                     jsr     ClearMessages
35d4: a9 30                        lda     #$30              ;"the dog chases the sneaker"
35d6: 20 92 08                     jsr     DrawMsgN_Row22
35d9: 20 45 10                     jsr     LongDelay
35dc: 20 5f 10                     jsr     ClearMessages
35df: a9 5c                        lda     #$5c              ;"and is eaten by"
35e1: 20 92 08                     jsr     DrawMsgN_Row22
35e4: a9 5d                        lda     #$5d              ;"the monster"
35e6: 20 a4 08                     jsr     DrawMsgN_Row23
35e9: 60                           rts

35ea: ca           ChkSpec08       dex
35eb: f0 03                        beq     SpecMonster
35ed: 4c 86 36                     jmp     ChkSpec09

                   ; 
                   ; Special $08: monster has found us (4th floor).
                   ; 
35f0: ad 9c 61     SpecMonster     lda     parsed_verb       ;check previous verb
35f3: c9 50                        cmp     #$50              ;was it movement ($5b-5e)?
35f5: 90 03                        bcc     :NotMove          ;no, branch
35f7: 20 15 10                     jsr     DrawMaze          ;update maze view
35fa: ad b2 61     :NotMove        lda     monster1_dist     ;was monster nearby?
35fd: d0 13                        bne     :MonstNear        ;yes, branch
35ff: 20 6c 36                     jsr     DelayClearMsg     ;no, show first message
3602: a9 43                        lda     #$43              ;"the ground beneath your feet"
3604: 20 92 08                     jsr     DrawMsgN_Row22
3607: a9 44                        lda     #$44              ;"begins to shake"
3609: 20 a4 08                     jsr     DrawMsgN_Row23
360c: ee b2 61                     inc     monster1_dist     ;closer
360f: 4c 4e 36                     jmp     ReqMonstInput

3612: ad b2 61     :MonstNear      lda     monster1_dist
3615: c9 01                        cmp     #$01
3617: d0 10                        bne     :AttackDie
3619: a9 45                        lda     #$45              ;"a disgusting odor permeates"
361b: 20 92 08                     jsr     DrawMsgN_Row22
361e: a9 46                        lda     #$46              ;"the hallway as it darkens"
3620: 20 a4 08                     jsr     DrawMsgN_Row23
3623: ee b2 61                     inc     monster1_dist     ;closer
3626: 4c 4e 36                     jmp     ReqMonstInput

3629: 20 55 08     :AttackDie      jsr     ClearScreen
362c: a9 36                        lda     #$36              ;"the monster attacks you and"
362e: 20 92 08                     jsr     DrawMsgN_Row22
3631: a9 37                        lda     #$37              ;"you are his next meal"
3633: 20 a4 08                     jsr     DrawMsgN_Row23
3636: ad b8 61                     lda     wool_msg_flag     ;was wool destroyed by "raiding lair"?
3639: d0 03                        bne     :NeverRaidLair    ;yes, add warning
363b: 4c b9 10                     jmp     HandleDeath

363e: a9 75        :NeverRaidLair  lda     #$75              ;"never, ever raid a monster's lair"
3640: a2 00                        ldx     #0
3642: 86 06                        stx     char_horiz
3644: a2 15                        ldx     #21               ;row 21 (normally blank)
3646: 86 07                        stx     char_vert
3648: 20 e2 08                     jsr     DrawMsgN
364b: 4c b9 10                     jmp     HandleDeath

                   ; Various monster-handling code branches here.
364e: 20 ca 0c     ReqMonstInput   jsr     GetInput
3651: ad 9c 61                     lda     parsed_verb
3654: c9 50                        cmp     #$50
3656: 90 06                        bcc     :NotMove
3658: 20 49 09                     jsr     HandleImmCmd
365b: 4c 47 33                     jmp     HandleSpecialZone

365e: 20 40 26     :NotMove        jsr     ExecParsedInput
3661: a2 0c                        ldx     #$0c
3663: 8e b2 61                     stx     monster1_dist     ;special value for monster distance
3666: 20 6c 36                     jsr     DelayClearMsg
3669: 4c 47 33                     jmp     HandleSpecialZone

                   ; 
                   ; If there are messages in rows 22/23, delay briefly, then clear them.  If the
                   ; area is already clear, return immediately.
                   ; 
366c: ad 7a 0c     DelayClearMsg   lda     text_row22        ;check row 22
366f: c9 80                        cmp     #$80              ;blank?
3671: f0 04                        beq     :Blank22          ;yes, branch
3673: c9 20                        cmp     #$20              ;space (also means blank?)?
3675: d0 08                        bne     :NotBlank         ;no, not blank
3677: ad a2 0c     :Blank22        lda     text_row23        ;check row 23
367a: c9 80                        cmp     #$80              ;blank?
367c: d0 01                        bne     :NotBlank         ;no, branch
367e: 60                           rts                       ;all blank, return immediately

367f: 20 45 10     :NotBlank       jsr     LongDelay         ;delay to let them read message
3682: 20 5f 10                     jsr     ClearMessages     ;clear previous message
3685: 60                           rts

3686: ca           ChkSpec09       dex
3687: f0 03                        beq     SpecMother
3689: 4c 77 37                     jmp     ChkSpec0a

                   ; 
                   ; Special $09: monster's mother (5th floor).
                   ; 
368c: ad 9c 61     SpecMother      lda     parsed_verb       ;check verb
368f: c9 50                        cmp     #$50              ;movement?
3691: 90 03                        bcc     :NotMove          ;no, branch
3693: 20 15 10                     jsr     DrawMaze          ;yes, redraw maze
3696: ad b3 61     :NotMove        lda     monst_dark_dist   ;is movement progress nonzero?
3699: d0 13                        bne     :Close            ;yes, branch
369b: 20 6c 36                     jsr     DelayClearMsg
369e: a9 43                        lda     #$43              ;"the ground beneath your feet"
36a0: 20 92 08                     jsr     DrawMsgN_Row22
36a3: a9 44                        lda     #$44              ;"begins to shake"
36a5: 20 a4 08                     jsr     DrawMsgN_Row23
36a8: ee b3 61                     inc     monst_dark_dist   ;update distance
36ab: 4c 4e 36                     jmp     ReqMonstInput

                   ]ret_xy         .var    $19    {addr/1}
                   ]ret_state      .var    $1a    {addr/1}

36ae: aa           :Close          tax                       ;is movement progress at 1?
36af: ca                           dex
36b0: d0 21                        bne     :SeduceOrDie      ;no, we're at 2; do or die time
36b2: a2 06                        ldx     #FN_GET_OBJ_INFO
36b4: 86 0f                        stx     ]func_cmd
36b6: a2 08                        ldx     #$08              ;horn
36b8: 86 0e                        stx     ]func_arg
36ba: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on horn
36bd: a9 07                        lda     #$07
36bf: c5 1a                        cmp     ]ret_state        ;horn activated?
36c1: f0 10                        beq     :SeduceOrDie      ;yes, branch
36c3: a9 45                        lda     #$45              ;"a disgusting odor permeates"
36c5: 20 92 08                     jsr     DrawMsgN_Row22
36c8: a9 46                        lda     #$46              ;"the hallway as it darkens"
36ca: 20 a4 08                     jsr     DrawMsgN_Row23
36cd: ee b3 61                     inc     monst_dark_dist
36d0: 4c 4e 36                     jmp     ReqMonstInput

36d3: a9 48        :SeduceOrDie    lda     #$48              ;"it is the monster's mother"
36d5: 20 92 08                     jsr     DrawMsgN_Row22
36d8: a2 08                        ldx     #$08              ;horn
36da: 86 0e                        stx     ]func_arg
36dc: a2 06                        ldx     #FN_GET_OBJ_INFO
36de: 86 0f                        stx     ]func_cmd
36e0: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on horn
36e3: a9 07                        lda     #$07
36e5: c5 1a                        cmp     ]ret_state        ;horn activated?
36e7: d0 05                        bne     :NoHorn           ;no, branch
36e9: a9 49                        lda     #$49              ;"she has been seduced"
36eb: 20 a4 08                     jsr     DrawMsgN_Row23
36ee: a5 1a        :NoHorn         lda     ]ret_state        ;preserve $19/$1a
36f0: 48                           pha
36f1: a5 19                        lda     ]ret_xy
36f3: 48                           pha
36f4: 20 ca 0c                     jsr     GetInput          ;get another command from player
36f7: 20 5f 10                     jsr     ClearMessages
36fa: ad 9d 61                     lda     parsed_noun       ;check what they're acting on
36fd: c9 18                        cmp     #$18              ;"monster"
36ff: f0 1d                        beq     :CheckAction
3701: c9 19                        cmp     #$19              ;"mother"
3703: f0 19                        beq     :CheckAction
3705: 68           :SlashBits      pla
3706: 85 19                        sta     ]ret_xy
3708: 68                           pla
3709: 85 1a                        sta     ]ret_state
370b: a9 07                        lda     #$07
370d: c5 1a                        cmp     ]ret_state        ;horn activated?
370f: d0 05                        bne     :NoHorn1          ;no, branch
3711: a9 4a                        lda     #$4a              ;"she tiptoes up to you"
3713: 20 92 08                     jsr     DrawMsgN_Row22
3716: a9 4b        :NoHorn1        lda     #$4b              ;"she slashes you to bits"
3718: 20 a4 08                     jsr     DrawMsgN_Row23
371b: 4c b9 10                     jmp     HandleDeath

371e: ad 9c 61     :CheckAction    lda     parsed_verb       ;check verb
3721: c9 0e                        cmp     #$0e              ;examine?
3723: d0 10                        bne     :NotExamine       ;no, branch
3725: a9 8c                        lda     #$8c              ;"it looks very dangerous"
3727: 20 a4 08                     jsr     DrawMsgN_Row23
372a: aa                           tax
372b: 68                           pla
372c: 85 19                        sta     ]ret_xy
372e: 68                           pla
372f: 85 1a                        sta     ]ret_state
3731: 8a                           txa
3732: 4c ee 36                     jmp     :NoHorn           ;loop

3735: c9 13        :NotExamine     cmp     #$13              ;kill?
3737: d0 cc                        bne     :SlashBits        ;no, mother wins
3739: a2 0e                        ldx     #$0e              ;sword
373b: 86 0e                        stx     ]func_arg
373d: a2 06                        ldx     #FN_GET_OBJ_INFO
373f: 86 0f                        stx     ]func_cmd
3741: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on sword
3744: a9 08                        lda     #$08
3746: c5 1a                        cmp     ]ret_state        ;in inventory, unboxed?
3748: d0 bb                        bne     :SlashBits        ;no, can't kill with what we got
374a: 68                           pla
374b: 85 19                        sta     ]ret_xy
374d: 68                           pla
374e: 85 1a                        sta     ]ret_state
3750: a9 07                        lda     #$07
3752: c5 1a                        cmp     ]ret_state        ;horn in "active" state?
3754: d0 c0                        bne     :NoHorn1          ;no, can't kill without blowing horn
                   ; Slay monster's mother (trivia: never named in Beowulf).
3756: a9 4a                        lda     #$4a              ;"she tiptoes up to you"
3758: 20 92 08                     jsr     DrawMsgN_Row22
375b: a9 4c                        lda     #$4c              ;"you slash her to bits"
375d: 20 a4 08                     jsr     DrawMsgN_Row23
3760: 20 45 10                     jsr     LongDelay
3763: a9 78                        lda     #$78              ;"the body has vanished"
3765: 20 a4 08                     jsr     DrawMsgN_Row23
3768: a2 00                        ldx     #$00
376a: 8e b3 61                     stx     monst_dark_dist   ;reset counters
376d: 8e ac 61                     stx     monster2_alive
3770: 8e a5 61                     stx     special_zone      ;exit zone
3773: 8e a6 61                     stx     special_zone1
3776: 60                           rts

3777: ca           ChkSpec0a       dex
3778: f0 03                        beq     SpecDarkMonst
377a: 4c 02 38                     jmp     ChkSpec0b

                   ; 
                   ; Special $0a: darkness; monster approaching.
                   ; 
                   ; We leave the zone when the lights turn on.  If the monster is dead (for floors
                   ; 1-4) or the monster's mother is dead (for floor 5), we leave the zone
                   ; immediately.
                   ; 
377d: ad 9c 61     SpecDarkMonst   lda     parsed_verb       ;check verb
3780: c9 50                        cmp     #$50              ;movement?
3782: 90 03                        bcc     :NotMove
3784: 20 15 10                     jsr     DrawMaze          ;erases maze, only redraws if now lit
3787: ad 9e 61     :NotMove        lda     illumination_flag ;is there illumination?
378a: f0 08                        beq     :NoLight          ;no, branch
378c: a2 00                        ldx     #$00              ;yes, reset distance
378e: 8e b3 61                     stx     monst_dark_dist
3791: 4c d5 34                     jmp     PopSpecialZone    ;clear flag

3794: a2 00        :NoLight        ldx     #$00
3796: 8e a4 61                     stx     floor_move_lo
3799: ad b3 61                     lda     monst_dark_dist   ;check distance
379c: d0 29                        bne     :GettingClose     ;already getting close
379e: ad 94 61                     lda     plyr_floor        ;check floor
37a1: c9 05                        cmp     #$05              ;5th?
37a3: f0 0a                        beq     :Floor5           ;yes, branch
37a5: ad ad 61                     lda     monster1_alive    ;monster still alive?
37a8: 29 02                        and     #$02
37aa: d0 08                        bne     :BadMoAlive       ;yes, branch
37ac: 4c d5 34     :PopDone        jmp     PopSpecialZone    ;no monster here

37af: ad ac 61     :Floor5         lda     monster2_alive    ;monster's mother still alive?
37b2: f0 f8                        beq     :PopDone          ;no, nothing to do
                   ; Lights are off and there's a monster nearby.
37b4: 20 6c 36     :BadMoAlive     jsr     DelayClearMsg
37b7: a9 43                        lda     #$43              ;"the ground beneath your feet"
37b9: 20 92 08                     jsr     DrawMsgN_Row22
37bc: a9 44                        lda     #$44              ;begins to shake"
37be: 20 a4 08                     jsr     DrawMsgN_Row23
37c1: ee b3 61                     inc     monst_dark_dist
37c4: 4c 4e 36                     jmp     ReqMonstInput

37c7: c9 01        :GettingClose   cmp     #$01              ;how close?
37c9: d0 13                        bne     :Arrived          ;monster has arrived, branch
37cb: 20 6c 36                     jsr     DelayClearMsg
37ce: ee b3 61                     inc     monst_dark_dist   ;move closer
37d1: a9 45                        lda     #$45              ;"a disgusting odor permeates"
37d3: 20 92 08                     jsr     DrawMsgN_Row22
37d6: a9 47                        lda     #$47              ;"the hallway"
37d8: 20 a4 08                     jsr     DrawMsgN_Row23
37db: 4c 4e 36                     jmp     ReqMonstInput

37de: 20 6c 36     :Arrived        jsr     DelayClearMsg
37e1: ad 94 61                     lda     plyr_floor        ;check which monster we're fighting
37e4: c9 05                        cmp     #$05
37e6: f0 0d                        beq     :Mother           ;it's mother, branch
37e8: a9 36                        lda     #$36              ;"the monster attacks you and"
37ea: 20 92 08                     jsr     DrawMsgN_Row22
37ed: a9 37                        lda     #$37              ;"you are his next meal"
37ef: 20 a4 08                     jsr     DrawMsgN_Row23
37f2: 4c b9 10                     jmp     HandleDeath

37f5: a9 48        :Mother         lda     #$48              ;"it is the monster's mother"
37f7: 20 92 08                     jsr     DrawMsgN_Row22
37fa: a9 4b                        lda     #$4b              ;"she slashes you to bits"
37fc: 20 a4 08     :MsgThenDie     jsr     DrawMsgN_Row23
37ff: 4c b9 10                     jmp     HandleDeath

3802: ca           ChkSpec0b       dex
3803: d0 6f                        bne     ChkSpec0c
                   ; 
                   ; Special $0b: snake on the loose.
                   ; 
3805: ad 9d 61                     lda     parsed_noun       ;check what we're interacting with
3808: c9 11                        cmp     #$11              ;snake?
380a: f0 07                        beq     SpecSnakeLoose    ;yes, branch
380c: 20 5f 10     SnakeBitesYou   jsr     ClearMessages
380f: a9 20                        lda     #$20              ;"the snake bites you and you die"
3811: d0 e9                        bne     :MsgThenDie       ;(always)

3813: ad 9c 61     SpecSnakeLoose  lda     parsed_verb       ;check verb
3816: c9 0e                        cmp     #$0e              ;examine?
3818: f0 52                        beq     :LookSnake        ;yes, branch
381a: c9 13                        cmp     #$13              ;kill?
381c: d0 ee                        bne     SnakeBitesYou     ;no, die
381e: a2 04                        ldx     #$04              ;dagger
3820: 86 0e                        stx     ]func_arg
3822: a2 06                        ldx     #FN_GET_OBJ_INFO
3824: 86 0f                        stx     ]func_cmd
3826: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on dagger in inventory
3829: a5 1a                        lda     ]ret_state
382b: c9 07                        cmp     #$07              ;in inventory (active or not)?
382d: 10 13                        bpl     :HaveDagger       ;yes, we have it
382f: a2 0e                        ldx     #$0e              ;sword
3831: 86 0e                        stx     ]func_arg
3833: a2 06                        ldx     #FN_GET_OBJ_INFO
3835: 86 0f                        stx     ]func_cmd
3837: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on sword
383a: a5 1a                        lda     ]ret_state
383c: c9 07                        cmp     #$07              ;in inventory (active or not)?
383e: 30 cc                        bmi     SnakeBitesYou     ;no, die
3840: 10 22                        bpl     :HaveSword        ;yes, swing the sword

3842: a2 04        :HaveDagger     ldx     #$04              ;dagger
3844: 86 0e                        stx     ]func_arg
3846: a2 00                        ldx     #FN_DESTROY_OBJ
3848: 86 0f                        stx     ]func_cmd
384a: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy dagger
384d: a2 00                        ldx     #FN_DESTROY_OBJ
384f: 86 0f                        stx     ]func_cmd
3851: a2 11                        ldx     #$11              ;snake
3853: 86 0e                        stx     ]func_arg
3855: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy snake
3858: a2 07                        ldx     #FN_DRAW_INV
385a: 86 0f                        stx     ]func_cmd
385c: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
385f: a9 64                        lda     #$64              ;"the dagger disappears"
3861: 20 a4 08                     jsr     DrawMsgN_Row23
3864: a9 63        :HaveSword      lda     #$63              ;"you have killed it"
3866: 20 92 08                     jsr     DrawMsgN_Row22
3869: 4c d5 34                     jmp     PopSpecialZone

386c: a9 8c        :LookSnake      lda     #$8c              ;"it looks very dangerous"
386e: 20 a4 08                     jsr     DrawMsgN_Row23
3871: 4c 4e 36                     jmp     ReqMonstInput

3874: ca           ChkSpec0c       dex
3875: f0 03                        beq     SpecKeyTicking
3877: 4c 6e 39                     jmp     ChkSpec0d

                   ; 
                   ; Special $0c: key is ticking after unlocking door #2.
                   ; 
                   ; It takes 9 moves (R ZZZZZ L Z L) to get into position at the new keyhole. 
                   ; After the 9th move, they either open the door or detonate.
                   ; 
387a: ad 9c 61     SpecKeyTicking  lda     parsed_verb       ;check verb
387d: c9 50                        cmp     #$50              ;movement?
387f: 90 03                        bcc     :NotMove          ;no, branch
3881: 20 15 10                     jsr     DrawMaze          ;redraw maze
3884: ad b6 61     :NotMove        lda     calc_prev_move    ;zeroed by calc puzzle finish; now counts key ticks
3887: c9 09                        cmp     #$09              ;out of time?
3889: f0 5f                        beq     :TimesUp          ;yes, branch
388b: ee b6 61                     inc     calc_prev_move    ;increment counter
388e: 20 94 38                     jsr     :ShowNewHole
3891: 4c 2c 39                     jmp     :GetCmd

                   ; Show the keyhole that appears after unlocking the second door.  In theory you
                   ; can see this from X=10 and Y=7-11, but in practice only Y=9-11 are possible
                   ; because the key explodes before you can get farther.
                   ]tmp            .var    $1a    {addr/1}

3894: ad 93 61     :ShowNewHole    lda     plyr_facing       ;get facing
3897: 85 1a                        sta     ]tmp              ;save in ZP
3899: ad 95 61                     lda     plyr_xpos         ;get X position
389c: c9 0a                        cmp     #10               ;X = 10?
389e: d0 3d                        bne     :PrintTickTick    ;no, new keyhole not visible
38a0: ad 96 61                     lda     plyr_ypos         ;get Y position
38a3: 38                           sec
38a4: e9 09                        sbc     #9
38a6: f0 24                        beq     :Y9               ;Y=9, branch
38a8: aa                           tax
38a9: ca                           dex
38aa: f0 0f                        beq     :Y10              ;Y=10, branch
38ac: ca                           dex
38ad: d0 2e                        bne     :PrintTickTick    ;Y < 9 (not possible due to timer), branch
38af: a9 01                        lda     #$01              ;Y=11, check facing
38b1: c5 1a                        cmp     ]tmp              ;facing west?
38b3: d0 28                        bne     :PrintTickTick    ;no, nothing to see
38b5: a2 01                        ldx     #$01              ;full-sized facing keyhole
38b7: 86 0f                        stx     ]func_cmd
38b9: d0 1f                        bne     :DrawHole

38bb: a9 02        :Y10            lda     #$02
38bd: c5 1a                        cmp     ]tmp              ;facing north?
38bf: d0 1c                        bne     :PrintTickTick    ;no, branch
38c1: a2 10                        ldx     #$10              ;mask: keyhole on left side wall at dist=1
38c3: 86 0e                        stx     ]func_arg
38c5: a2 09                        ldx     #$09              ;feature: keyhole on side wall
38c7: 86 0f                        stx     ]func_cmd
38c9: 4c da 38                     jmp     :DrawHole

38cc: a9 02        :Y9             lda     #$02              ;facing north?
38ce: c5 1a                        cmp     ]tmp
38d0: d0 0b                        bne     :PrintTickTick    ;no, branch
38d2: a2 20                        ldx     #$20              ;mask: keyhole on left side wall at dist=2
38d4: 86 0e                        stx     ]func_arg
38d6: a9 09                        lda     #$09              ;feature: keyhole on side wall
38d8: 86 0f                        stx     ]func_cmd
                   ; 
38da: 20 5a 1e     :DrawHole       jsr     DrawFeature
38dd: a9 41        :PrintTickTick  lda     #$41              ;"tick! tick!"
38df: a2 06                        ldx     #6
38e1: 86 06                        stx     char_horiz
38e3: a2 02                        ldx     #2
38e5: 86 07                        stx     char_vert
38e7: 4c e2 08                     jmp     DrawMsgN

                   ; They've made 9 moves, do or die.
38ea: 20 94 38     :TimesUp        jsr     :ShowNewHole      ;show the hole if it's visible
38ed: 20 ca 0c                     jsr     GetInput
38f0: ad 9c 61                     lda     parsed_verb       ;check verb
38f3: c9 10                        cmp     #$10              ;open?
38f5: d0 1f                        bne     :Kaboom           ;no, die
38f7: ad 9d 61                     lda     parsed_noun       ;check noun
38fa: c9 17                        cmp     #$17              ;door?
38fc: d0 18                        bne     :Kaboom           ;no, die
38fe: ad 93 61                     lda     plyr_facing       ;check facing
3901: c9 01                        cmp     #$01              ;west?
3903: d0 11                        bne     :Kaboom           ;no, die?
3905: ad 95 61                     lda     plyr_xpos         ;check position
3908: c9 0a                        cmp     #10               ;X=10?
390a: d0 0a                        bne     :Kaboom           ;no, die
390c: ad 96 61                     lda     plyr_ypos
390f: c9 0b                        cmp     #11               ;Y=11?
3911: d0 03                        bne     :Kaboom           ;no, die
3913: 4c 86 3c                     jmp     SpecEndGame       ;play the end sequence

3916: 20 c5 30     :Kaboom         jsr     FlashYellow       ;blow up the inside world
3919: 20 55 08                     jsr     ClearScreen
391c: a2 00                        ldx     #0
391e: 86 06                        stx     char_horiz
3920: a2 15                        ldx     #21
3922: 86 07                        stx     char_vert
3924: a9 42                        lda     #$42              ;"the key blows up the whole maze"
3926: 20 e2 08                     jsr     DrawMsgN
3929: 4c b9 10                     jmp     HandleDeath

392c: 20 ca 0c     :GetCmd         jsr     GetInput
392f: ad 9c 61                     lda     parsed_verb
3932: c9 59                        cmp     #$59              ;movement?
3934: 90 06                        bcc     :ChkOpen          ;no, handle typed command
3936: 20 49 09                     jsr     HandleImmCmd      ;yes, handle movement
3939: 4c 47 33                     jmp     HandleSpecialZone ;loop

                   ; See if they're trying to open the final door.  (Only possible to succeed here
                   ; if the timer allows some slack in movement.)
393c: ad 9c 61     :ChkOpen        lda     parsed_verb
393f: c9 10                        cmp     #$10              ;open?
3941: d0 1f                        bne     :NotOpenDoor
3943: ad 9d 61                     lda     parsed_noun
3946: c9 17                        cmp     #$17              ;door?
3948: d0 18                        bne     :NotOpenDoor
394a: ad 93 61                     lda     plyr_facing
394d: c9 01                        cmp     #$01              ;west?
394f: d0 11                        bne     :NotOpenDoor
3951: ad 95 61                     lda     plyr_xpos
3954: c9 0a                        cmp     #10               ;X pos = 10?
3956: d0 0a                        bne     :NotOpenDoor
3958: ad 96 61                     lda     plyr_ypos
395b: c9 0b                        cmp     #11               ;Y pos = 11?
395d: d0 03                        bne     :NotOpenDoor
395f: 4c 86 3c                     jmp     SpecEndGame       ;enter the final sequence

3962: 20 19 0b     :NotOpenDoor    jsr     ReduceResources   ;reduce food/torch
3965: 20 40 26                     jsr     ExecParsedInput   ;execute whatever the command was
3968: 20 77 0b                     jsr     ReportLowRsrc
396b: 4c 47 33                     jmp     HandleSpecialZone ;loop

396e: ca           ChkSpec0d       dex
396f: f0 03                        beq     SpecElevOpen
3971: 4c 20 3a                     jmp     ChkSpec0e

                   ; 
                   ; Special $0d: elevator doors have opened, awaiting 'Z'.
                   ; 
3974: 20 ca 0c     SpecElevOpen    jsr     GetInput          ;wait for an action
3977: ad 9c 61                     lda     parsed_verb
397a: c9 5b                        cmp     #VERB_FWD         ;forward movement?
397c: f0 37                        beq     :EnterElev        ;yes, do the elevator stuff
397e: ad a6 61     :PopZone        lda     special_zone1     ;didn't move forward; pop special zone
3981: 8d a5 61                     sta     special_zone      ; (closes elevator doors)
3984: ad a7 61                     lda     special_zone2
3987: a2 00                        ldx     #$00
3989: 8e a7 61                     stx     special_zone2
398c: 8d a6 61                     sta     special_zone1
398f: 20 15 10                     jsr     DrawMaze          ;redraw maze
3992: ad 9c 61                     lda     parsed_verb
3995: c9 5b                        cmp     #VERB_FWD         ;movement command?
3997: 90 03                        bcc     :NotMove          ;no, handle it
3999: 4c 49 09                     jmp     HandleImmCmd      ;yes, handle it the other way

399c: 4c 40 26     :NotMove        jmp     ExecParsedInput   ;handle command

399f: a9 a3        :ElevMoving     lda     #$a3              ;"the elevator is moving"
39a1: 20 92 08                     jsr     DrawMsgN_Row22
39a4: 20 45 10                     jsr     LongDelay
39a7: a9 a4                        lda     #$a4              ;"you are deposited at the next level"
39a9: 20 a4 08                     jsr     DrawMsgN_Row23
39ac: 20 45 10                     jsr     LongDelay
39af: 20 15 10                     jsr     DrawMaze          ;draw new location
39b2: 4c d5 34                     jmp     PopSpecialZone    ;exit elevator

39b5: 20 7e 12     :EnterElev      jsr     EraseMaze
39b8: ae 94 61                     ldx     plyr_floor        ;get floor
39bb: ca                           dex                       ;floor 2?
39bc: ca                           dex
39bd: f0 13                        beq     :ElevFloor2       ;yes, branch
39bf: ca                           dex                       ;floor 3?
39c0: f0 41                        beq     :ElevFloor3       ;yes, branch
39c2: ca                           dex                       ;floor 4?
39c3: f0 48                        beq     :ElevFloor4       ;yes, branch
39c5: a9 6d                        lda     #$6d              ;"you are trapped in a fake"
39c7: 20 92 08                     jsr     DrawMsgN_Row22
39ca: a9 6e                        lda     #$6e              ;"elevator. There is no escape"
39cc: 20 a4 08                     jsr     DrawMsgN_Row23
39cf: 4c b9 10                     jmp     HandleDeath

                   ; Handle 2nd-floor elevator (crushes you to death).
39d2: 20 7e 12     :ElevFloor2     jsr     EraseMaze         ;clear maze from screen
39d5: a2 03                        ldx     #$03
39d7: 86 0f                        stx     ]func_cmd         ;(?)
39d9: 8e 99 61                     stx     maze_walls_lf     ;set left walls
39dc: a2 23                        ldx     #$23
39de: 86 0e                        stx     ]func_arg         ;(?)
39e0: 8e 9a 61                     stx     maze_walls_rt     ;set right walls
39e3: 20 a6 12                     jsr     DrawVisWalls
39e6: a2 03                        ldx     #$03
39e8: 86 0f                        stx     ]func_cmd
39ea: 20 5a 1e                     jsr     DrawFeature       ;draw animated walls closing in
39ed: 20 dc 0f                     jsr     MediumPause
39f0: 20 7e 12                     jsr     EraseMaze
39f3: a9 79                        lda     #$79              ;"glitch"
39f5: a2 08                        ldx     #8
39f7: 86 06                        stx     char_horiz
39f9: a2 0a                        ldx     #10
39fb: 86 07                        stx     char_vert
39fd: 20 e2 08                     jsr     DrawMsgN
3a00: 4c b9 10                     jmp     HandleDeath

                   ; Handle 3rd floor elevator (moves down to 4th).
3a03: ee 94 61     :ElevFloor3     inc     plyr_floor
3a06: a2 01                        ldx     #$01
3a08: 8e 95 61                     stx     plyr_xpos         ;set X pos = 1
3a0b: d0 08                        bne     :ElevCommon       ;(always)

                   ; Handle 4th floor elevator (moves up to 3rd).
3a0d: ce 94 61     :ElevFloor4     dec     plyr_floor
3a10: a2 04                        ldx     #$04
3a12: 8e 95 61                     stx     plyr_xpos         ;set X pos = 4
3a15: a2 00        :ElevCommon     ldx     #$00
3a17: 8e a3 61                     stx     floor_move_hi
3a1a: 8e a4 61                     stx     floor_move_lo
3a1d: 4c 9f 39                     jmp     :ElevMoving

3a20: ca           ChkSpec0e       dex
3a21: f0 03                        beq     SpecMonsterWool
3a23: 4c ea 3a                     jmp     ChkSpec0f

                   ; 
                   ; Special $0e: monster tangled in wool
                   ; 
                   ; Player can kill monster and fill jar.
                   ; 
3a26: ad b2 61     SpecMonsterWool lda     monster1_dist     ;check distance
3a29: c9 0c                        cmp     #$0c              ;special flag set?
3a2b: d0 03                        bne     :NoSpec           ;no, branch
3a2d: 20 ca 0c                     jsr     GetInput          ;get command
3a30: a2 00        :NoSpec         ldx     #$00
3a32: 8e b2 61                     stx     monster1_dist     ;reset distance
3a35: ad 9d 61     :CheckCmd       lda     parsed_noun       ;check noun
3a38: c9 18                        cmp     #$18              ;monster?
3a3a: f0 03                        beq     :NounMonster      ;yes, branch
3a3c: 4c 29 36     :JmpAttackDie   jmp     :AttackDie        ;no, we're dead

3a3f: ad 9c 61     :NounMonster    lda     parsed_verb       ;check verb
3a42: c9 0e                        cmp     #$0e              ;examine?
3a44: d0 03                        bne     :NoExam           ;no, branch
3a46: 4c d4 3a                     jmp     :ExamMonster

3a49: c9 13        :NoExam         cmp     #$13              ;kill?
3a4b: d0 ef                        bne     :JmpAttackDie     ;no, branch and die
3a4d: ad 9e 61                     lda     illumination_flag ;are we in the dark?
3a50: f0 ea                        beq     :JmpAttackDie     ;yes, die
3a52: a2 04                        ldx     #$04              ;dagger
3a54: 86 0e                        stx     ]func_arg
3a56: a2 06                        ldx     #FN_GET_OBJ_INFO
3a58: 86 0f                        stx     ]func_cmd
3a5a: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on dagger
3a5d: a9 08                        lda     #$08
3a5f: c5 1a                        cmp     ]tmp              ;in inventory and unboxed?
3a61: d0 d9                        bne     :JmpAttackDie     ;no, die
                   ; Kill monster.
3a63: 20 5f 10                     jsr     ClearMessages
3a66: a2 04                        ldx     #$04
3a68: 86 0e                        stx     ]func_arg
3a6a: a2 01                        ldx     #FN_DESTROY_OBJ1
3a6c: 86 0f                        stx     ]func_cmd
3a6e: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy dagger
3a71: a2 07                        ldx     #FN_DRAW_INV
3a73: 86 0f                        stx     ]func_cmd
3a75: 20 34 1a                     jsr     ObjMgmtFunc
3a78: a9 64                        lda     #$64              ;"the dagger disappears"
3a7a: 20 92 08                     jsr     DrawMsgN_Row22
3a7d: 20 45 10                     jsr     LongDelay
3a80: a9 61                        lda     #$61              ;"the monster is dead and"
3a82: 20 92 08                     jsr     DrawMsgN_Row22
3a85: a9 62                        lda     #$62              ;"much blood is spilt"
3a87: 20 a4 08                     jsr     DrawMsgN_Row23
3a8a: a2 00                        ldx     #$00
3a8c: 8e ad 61                     stx     monster1_alive    ;mark as dead
3a8f: ad a6 61                     lda     special_zone1     ;is monster special on stack?
3a92: c9 08                        cmp     #$08
3a94: d0 09                        bne     :NotSecondary     ;no, branch
3a96: ad a7 61                     lda     special_zone2     ;yes, remove monster from stack
3a99: 8d a6 61                     sta     special_zone1
3a9c: 8e a7 61                     stx     special_zone2     ;set to zero
3a9f: 20 ca 0c     :NotSecondary   jsr     GetInput          ;get command
3aa2: ad 9c 61                     lda     parsed_verb       ;check verb
3aa5: c9 09                        cmp     #$09              ;fill?
3aa7: d0 36                        bne     :NotFillJar       ;no, branch
3aa9: ad 9d 61                     lda     parsed_noun
3aac: c9 09                        cmp     #$09              ;jar?
3aae: d0 2f                        bne     :NotFillJar
3ab0: a2 06                        ldx     #FN_GET_OBJ_INFO
3ab2: 86 0f                        stx     ]func_cmd
3ab4: a2 09                        ldx     #$09              ;jar
3ab6: 86 0e                        stx     ]func_arg
3ab8: 20 34 1a                     jsr     ObjMgmtFunc       ;get info on jar
3abb: a9 08                        lda     #$08
3abd: c5 1a                        cmp     ]tmp              ;in inventory, unboxed, inactive?
3abf: d0 1e                        bne     :NotFillJar       ;no, branch
3ac1: a2 09                        ldx     #$09              ;jar
3ac3: 86 0e                        stx     ]func_arg
3ac5: a2 03                        ldx     #FN_ACTIVATE_OBJ
3ac7: 86 0f                        stx     ]func_cmd
3ac9: 20 34 1a                     jsr     ObjMgmtFunc       ;mark jar as active
3acc: a9 60                        lda     #$60              ;"it is now full of blood"
3ace: 20 a4 08                     jsr     DrawMsgN_Row23
3ad1: 4c d5 34                     jmp     PopSpecialZone    ;done with special handling

3ad4: a9 8c        :ExamMonster    lda     #$8c              ;"it looks very dangerous"
3ad6: 20 92 08                     jsr     DrawMsgN_Row22
3ad9: 20 ca 0c                     jsr     GetInput          ;get another command
3adc: 4c 35 3a                     jmp     :CheckCmd         ;loop

3adf: 20 5f 10     :NotFillJar     jsr     ClearMessages
3ae2: a9 78                        lda     #$78              ;"the body has vanished"
3ae4: 20 92 08                     jsr     DrawMsgN_Row22
3ae7: 4c 7e 39                     jmp     :PopZone          ;done with zone

3aea: ca           ChkSpec0f       dex
3aeb: f0 03                        beq     SpecSnakeRisen
3aed: 4c 86 3c                     jmp     SpecEndGame

                   ; 
                   ; Special $0f: snake has risen.
                   ; 
                   ; Besides dealing with the act of climbing the snake, this also drives movement
                   ; while you're in the two-cell area above the snake.  (I think this is because
                   ; they didn't want to make the snake vanish while you were standing on it,
                   ; though they could have gone back to "normal" mode after stepping off.)
                   ; 
3af0: 20 ca 0c     SpecSnakeRisen  jsr     GetInput          ;get command
3af3: ad 9c 61                     lda     parsed_verb
3af6: c9 5a                        cmp     #$5a              ;movement?
3af8: 90 03                        bcc     :NotMove          ;no, branch
3afa: 4c 0c 38     :SnakeBites     jmp     SnakeBitesYou     ;die

3afd: c9 07        :NotMove        cmp     #$07              ;climb?
3aff: d0 f9                        bne     :SnakeBites       ;no, die
3b01: ad 9d 61                     lda     parsed_noun       ;check noun
3b04: c9 11                        cmp     #$11              ;snake?
3b06: d0 f2                        bne     :SnakeBites       ;no, die
                   ; 
                   ]ypos           .var    $19    {addr/1}
                   ]xpos           .var    $1a    {addr/1}

3b08: ad 95 61                     lda     plyr_xpos         ;copy player position to ZP
3b0b: 85 1a                        sta     ]xpos
3b0d: ad 96 61                     lda     plyr_ypos
3b10: 85 19                        sta     ]ypos
3b12: ad 94 61                     lda     plyr_floor        ;get current floor
3b15: c9 03                        cmp     #$03              ;are we on the 3rd?
3b17: f0 13                        beq     :NotFloor3        ;no, branch
3b19: c9 04                        cmp     #$04              ;on the 4th?
3b1b: d0 1b                        bne     :NoHole           ;definitely not under hole
3b1d: a5 1a                        lda     ]xpos             ;under hole at (1,10)?
3b1f: c9 01                        cmp     #1
3b21: d0 15                        bne     :NoHole
3b23: a5 19                        lda     ]ypos
3b25: c9 0a                        cmp     #10
3b27: d0 0f                        bne     :NoHole
3b29: 4c 61 3b                     jmp     :UpFrom4          ;yes, allow climb

3b2c: a5 1a        :NotFloor3      lda     ]xpos             ;under hole at (8,5)?
3b2e: c9 08                        cmp     #8
3b30: d0 06                        bne     :NoHole
3b32: a5 19                        lda     ]ypos
3b34: c9 05                        cmp     #5
3b36: f0 1e                        beq     :UpFrom3          ;yes, allow climb
                   ; Attempted to climb snake when not below hole in ceiling.
3b38: 20 c5 30     :NoHole         jsr     FlashYellow
3b3b: a9 2d                        lda     #$2d              ;"wham"
3b3d: 20 92 08                     jsr     DrawMsgN_Row22
3b40: a9 a5                        lda     #$a5              ;"your head smashes into the ceiling"
3b42: 20 a4 08                     jsr     DrawMsgN_Row23
3b45: 20 45 10                     jsr     LongDelay
3b48: 20 5f 10                     jsr     ClearMessages
3b4b: a9 a6                        lda     #$a6              ;"you fall on the snake"
3b4d: 20 92 08                     jsr     DrawMsgN_Row22
3b50: 20 45 10                     jsr     LongDelay
3b53: 4c 0c 38                     jmp     SnakeBitesYou

                   ]facing_flag    .var    $19    {addr/1}

3b56: a2 01        :UpFrom3        ldx     #$01
3b58: 86 19                        stx     ]facing_flag
3b5a: e8                           inx
3b5b: 8e 93 61                     stx     plyr_facing       ;face north
3b5e: 4c 6a 3b                     jmp     :UpCommon

3b61: a2 00        :UpFrom4        ldx     #$00
3b63: 86 19                        stx     ]facing_flag
3b65: a2 03                        ldx     #$03
3b67: 8e 93 61                     stx     plyr_facing       ;face east
                   ; We've moved up one floor, and are standing on the pit.  Move forward or die.
3b6a: ce 94 61     :UpCommon       dec     plyr_floor        ;climb up one floor
3b6d: a5 1a                        lda     ]xpos             ;preserve ZP
3b6f: 48                           pha
3b70: a5 19                        lda     ]facing_flag
3b72: 48                           pha
3b73: 20 15 10                     jsr     DrawMaze          ;redraw maze
3b76: 20 ca 0c                     jsr     GetInput          ;get a command
3b79: ad 9c 61                     lda     parsed_verb
3b7c: c9 5b                        cmp     #VERB_FWD         ;step forward?
3b7e: f0 0e                        beq     :MoveFwd          ;yes, branch
3b80: 20 5f 10                     jsr     ClearMessages
3b83: a9 54                        lda     #$54              ;"you can't be serious"
3b85: 20 92 08                     jsr     DrawMsgN_Row22
3b88: 20 45 10                     jsr     LongDelay
3b8b: 4c 0c 38                     jmp     SnakeBitesYou

3b8e: 68           :MoveFwd        pla                       ;restore ZP
3b8f: 85 19                        sta     ]facing_flag
3b91: 68                           pla
3b92: 85 1a                        sta     ]xpos
3b94: 48                           pha
3b95: a5 19                        lda     ]facing_flag      ;check flag
3b97: 48                           pha
3b98: c9 01                        cmp     #$01              ;are we facing north?
3b9a: f0 06                        beq     :MoveNorth        ;yes, branch
3b9c: ee 95 61                     inc     plyr_xpos         ;move one step east
3b9f: 4c a5 3b                     jmp     :Moved

3ba2: ee 96 61     :MoveNorth      inc     plyr_ypos         ;move one step north
3ba5: 20 15 10     :Moved          jsr     DrawMaze
3ba8: a9 59                        lda     #$59              ;"the"
3baa: 20 92 08                     jsr     DrawMsgN_Row22
3bad: a9 11                        lda     #$11              ;"snake"
3baf: 20 e3 25                     jsr     PrintNoun
3bb2: a9 77                        lda     #$77              ;"has vanished"
3bb4: 20 e2 08                     jsr     DrawMsgN
3bb7: a2 11                        ldx     #$11              ;snake
3bb9: 86 0e                        stx     ]func_arg
3bbb: a2 00                        ldx     #FN_DESTROY_OBJ
3bbd: 86 0f                        stx     ]func_cmd
3bbf: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy snake
3bc2: a2 07                        ldx     #FN_DRAW_INV
3bc4: 86 0f                        stx     ]func_cmd
3bc6: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory (why?)
3bc9: 68                           pla                       ;restore ZP
3bca: 85 19                        sta     ]facing_flag
3bcc: 68                           pla
3bcd: 85 1a                        sta     ]xpos
3bcf: a5 19                        lda     ]facing_flag
3bd1: c9 01                        cmp     #$01              ;facing east?
3bd3: d0 03                        bne     :SwordZone        ;yes, we must be in sword area, branch
3bd5: 4c d5 34                     jmp     PopSpecialZone    ;no, just on 2nd floor; done here

3bd8: ad ad 61     :SwordZone      lda     monster1_alive    ;is the monster still alive?
3bdb: f0 26                        beq     :NoMonster        ;no, branch
                   ; For some reason, we delete the wool if the player climbs the snake before
                   ; defeating the monster (which means they can't kill the monster).  This happens
                   ; whether or not we're holding the wool.
3bdd: a9 59                        lda     #$59              ;"the"
3bdf: 20 a4 08                     jsr     DrawMsgN_Row23
3be2: a9 0f                        lda     #$0f              ;wool
3be4: 20 e3 25                     jsr     PrintNoun
3be7: a9 77                        lda     #$77              ;"has vanished"
3be9: 20 e2 08                     jsr     DrawMsgN
3bec: a2 00                        ldx     #FN_DESTROY_OBJ
3bee: 86 0f                        stx     ]func_cmd
3bf0: a2 0f                        ldx     #$0f              ;wool
3bf2: 86 0e                        stx     ]func_arg
3bf4: 20 34 1a                     jsr     ObjMgmtFunc       ;destroy wool
3bf7: a2 01                        ldx     #$01
3bf9: 8e b8 61                     stx     wool_msg_flag     ;set flag (msg about monster lair on death)
3bfc: a2 07                        ldx     #FN_DRAW_INV
3bfe: 86 0f                        stx     ]func_cmd
3c00: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
                   ; We're now standing in the cell where the sword is.
3c03: a2 01        :NoMonster      ldx     #$01
3c05: 8e b9 61                     stx     object_status     ;set status of object 0 (?)
3c08: a2 07                        ldx     #FN_DRAW_INV
3c0a: 86 0f                        stx     ]func_cmd
3c0c: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
3c0f: 20 ca 0c     :InputLoop      jsr     GetInput
3c12: ad 9c 61                     lda     parsed_verb
3c15: c9 5a                        cmp     #$5a              ;movement key?
3c17: b0 12                        bcs     :WasMove          ;yes, branch
3c19: c9 11                        cmp     #$11              ;"press"?
3c1b: d0 08                        bne     :HandleCmd        ;no, branch
3c1d: a9 98                        lda     #$98              ;"you will do no such thing"
3c1f: 20 a4 08                     jsr     DrawMsgN_Row23
3c22: 4c 0f 3c                     jmp     :InputLoop        ;loop

3c25: 20 40 26     :HandleCmd      jsr     ExecParsedInput
3c28: 4c 37 3c                     jmp     :Common

3c2b: c9 5b        :WasMove        cmp     #VERB_FWD         ;foward move?
3c2d: f0 29                        beq     :FwdMove
3c2f: ae 93 61                     ldx     plyr_facing       ;copy player facing to ZP (why?)
3c32: 86 1a                        stx     ]xpos
3c34: 20 56 09                     jsr     DirectionChange   ;handle direction-change key
3c37: ad 93 61     :Common         lda     plyr_facing       ;get facing
3c3a: a2 00                        ldx     #$00              ;hole is right in front
3c3c: 86 0e                        stx     ]func_arg
3c3e: a2 04                        ldx     #$04              ;hole in floor
3c40: 86 0f                        stx     ]func_cmd
3c42: c9 01                        cmp     #$01              ;facing west?
3c44: d0 0f                        bne     :FacingWall       ;no, that's a wall
3c46: ad 9e 61                     lda     illumination_flag ;is there light?
3c49: f0 0a                        beq     :FacingWall       ;no, don't move
3c4b: ad 9a 61                     lda     maze_walls_rt     ;get wall flags
3c4e: 29 e0                        and     #%11100000        ;mask off view distance bits
3c50: f0 03                        beq     :FacingWall       ;right up against wall, branch
3c52: 20 5a 1e                     jsr     DrawFeature       ;pit is visible, draw it
3c55: 4c 0f 3c     :FacingWall     jmp     :InputLoop

3c58: ad 93 61     :FwdMove        lda     plyr_facing       ;get facing
3c5b: c9 01                        cmp     #$01              ;west?
3c5d: f0 13                        beq     :IntoPit          ;yes, walked into pit; branch
3c5f: 20 7e 12                     jsr     EraseMaze         ;no, walked into a wall
3c62: a2 09                        ldx     #9
3c64: 86 06                        stx     char_horiz
3c66: a2 0a                        ldx     #10
3c68: 86 07                        stx     char_vert
3c6a: a9 7c                        lda     #$7c              ;"splat"
3c6c: 20 e2 08                     jsr     DrawMsgN
3c6f: 4c 0f 3c                     jmp     :InputLoop

3c72: ee 94 61     :IntoPit        inc     plyr_floor        ;back to floor 3
3c75: a2 03                        ldx     #$03              ;face east
3c77: 8e 93 61                     stx     plyr_facing
3c7a: ce 95 61                     dec     plyr_xpos         ;move one cell west
3c7d: 20 7c 10                     jsr     FallIntoPit       ;notify them of the pit
3c80: 20 15 10                     jsr     DrawMaze
3c83: 4c d5 34                     jmp     PopSpecialZone    ;done with snakeland

                   ; 
                   ; Special $10: endgame.  (We jump straight here from the handler for $0c, and
                   ; don't leave until victory or death, so the zone is never actually set to $10.)
                   ; 
                   ; The player is not actually in the maze.  The visible walls are hard-coded in
                   ; the state machine.
                   ; 
                   ]end_move_copy  .var    $1a    {addr/1}

3c86: 20 7e 12     SpecEndGame     jsr     EraseMaze         ;clear maze area
3c89: a9 07                        lda     #$07              ;3 walls on left
3c8b: 8d 99 61                     sta     maze_walls_lf
3c8e: a2 47                        ldx     #$47              ;3 walls on right, dist=2
3c90: 8e 9a 61                     stx     maze_walls_rt
3c93: 20 a6 12                     jsr     DrawVisWalls      ;redraw maze walls
3c96: a2 08                        ldx     #$08              ;elevator doors ahead
3c98: 86 0f                        stx     ]func_cmd
3c9a: a2 01                        ldx     #$01              ;on right side
3c9c: 86 0e                        stx     ]func_arg
3c9e: 20 5a 1e                     jsr     DrawFeature       ;draw it
3ca1: a2 01                        ldx     #$01
3ca3: 8e a8 61                     stx     end_state         ;count moves down the hallway
3ca6: a9 a0        :Hallway        lda     #$a0              ;"don't make unnecessary turns"
3ca8: 20 92 08                     jsr     DrawMsgN_Row22
3cab: 20 ca 0c                     jsr     GetInput          ;get next move
3cae: ad a8 61                     lda     end_state
3cb1: 85 1a                        sta     ]end_move_copy    ;save copy in ZP
3cb3: ad 9c 61                     lda     parsed_verb
3cb6: c6 1a                        dec     ]end_move_copy    ;was this our first move?
3cb8: d0 2f                        bne     :NotMove1         ;no, branch
3cba: c9 5a                        cmp     #$5a              ;movement key?
3cbc: 10 03                        bpl     :CheckMove1       ;yes, branch
3cbe: 4c ca 3e                     jmp     CurrentlyImposs2  ;reject all other input

                   ; First move must be forward.
3cc1: c9 5b        :CheckMove1     cmp     #VERB_FWD
3cc3: f0 03                        beq     :DoMove1
3cc5: 4c aa 3e                     jmp     SaltPillarDie     ;unnecessary turn

3cc8: 20 7e 12     :DoMove1        jsr     EraseMaze
3ccb: a2 03                        ldx     #$03              ;2 walls on left
3ccd: 8e 99 61                     stx     maze_walls_lf
3cd0: a2 23                        ldx     #$23              ;2 walls on right, dist=1
3cd2: 8e 9a 61                     stx     maze_walls_rt
3cd5: 20 a6 12                     jsr     DrawVisWalls      ;redraw
3cd8: a2 08                        ldx     #$08              ;elevator doors ahead
3cda: 86 0f                        stx     ]func_cmd
3cdc: a2 02                        ldx     #$02              ;on right side
3cde: 86 0e                        stx     ]func_arg
3ce0: 20 5a 1e                     jsr     DrawFeature       ;draw it
3ce3: ee a8 61                     inc     end_state
3ce6: 4c a6 3c                     jmp     :Hallway

3ce9: c6 1a        :NotMove1       dec     ]end_move_copy    ;was this our second move?
3ceb: d0 24                        bne     :NotMove2         ;no, branch
3ced: c9 5a                        cmp     #$5a              ;movement key?
3cef: 10 03                        bpl     :CheckMove2       ;yes, branch
3cf1: 4c ca 3e                     jmp     CurrentlyImposs2  ;no, no can do

                   ; Second move must be forward.
3cf4: c9 5b        :CheckMove2     cmp     #VERB_FWD         ;foward move?
3cf6: f0 03                        beq     :DoMove2          ;yes, branch
3cf8: 4c aa 3e                     jmp     SaltPillarDie     ;no, get salty

3cfb: 20 7e 12     :DoMove2        jsr     EraseMaze
3cfe: a2 01                        ldx     #$01              ;one wall on left
3d00: 8e 99 61                     stx     maze_walls_lf
3d03: a2 00                        ldx     #$00              ;no walls on right, dist=0
3d05: 8e 9a 61                     stx     maze_walls_rt
3d08: 20 a6 12                     jsr     DrawVisWalls      ;redraw
3d0b: ee a8 61                     inc     end_state         ;bump position
3d0e: 4c a6 3c                     jmp     :Hallway          ;loop

                   ; Third move must be right turn.
3d11: c6 1a        :NotMove2       dec     ]end_move_copy
3d13: d0 2b                        bne     :NotMove3
3d15: c9 5a                        cmp     #$5a              ;movement?
3d17: 10 03                        bpl     :CheckMove3       ;yes, check it
3d19: 4c ca 3e                     jmp     CurrentlyImposs2

3d1c: c9 5d        :CheckMove3     cmp     #VERB_RIGHT       ;right turn?
3d1e: f0 03                        beq     :DoMove3          ;yes, all is well
3d20: 4c aa 3e                     jmp     SaltPillarDie     ;no, die

3d23: 20 7e 12     :DoMove3        jsr     EraseMaze
3d26: a2 01                        ldx     #$01
3d28: 8e 99 61                     stx     maze_walls_lf
3d2b: a2 00                        ldx     #$00
3d2d: 8e 9a 61                     stx     maze_walls_rt
3d30: 20 a6 12                     jsr     DrawVisWalls
3d33: a2 02                        ldx     #$02
3d35: 86 0f                        stx     ]func_cmd
3d37: 20 5a 1e                     jsr     DrawFeature
3d3a: ee a8 61                     inc     end_state
3d3d: 4c a6 3c                     jmp     :Hallway

3d40: c6 1a        :NotMove3       dec     ]end_move_copy
3d42: d0 25                        bne     :NotMove4
3d44: c9 5a                        cmp     #$5a              ;movement?
3d46: 30 03                        bmi     :CheckMove4       ;no, branch
3d48: 4c aa 3e                     jmp     SaltPillarDie     ;can't move from here; die

                   ; Fourth move must be open elevator.
3d4b: c9 10        :CheckMove4     cmp     #$10              ;"open"?
3d4d: f0 03                        beq     :DoMove4          ;yes, continue
3d4f: 4c ca 3e                     jmp     CurrentlyImposs2  ;not allowed

3d52: ad 9d 61     :DoMove4        lda     parsed_noun
3d55: c9 17                        cmp     #$17              ;"door" / "elev"?
3d57: f0 03                        beq     :DoOpen           ;yes, good
3d59: 4c ca 3e                     jmp     CurrentlyImposs2  ;no, can't do that

3d5c: a2 0a        :DoOpen         ldx     #$0a              ;elevator opening
3d5e: 86 0f                        stx     ]func_cmd
3d60: 20 5a 1e                     jsr     DrawFeature       ;animate it
3d63: ee a8 61                     inc     end_state         ;advance
3d66: 4c a6 3c                     jmp     :Hallway          ;loop

3d69: c6 1a        :NotMove4       dec     ]end_move_copy
3d6b: d0 70                        bne     :NotMove5
                   ; Fifth move must be "throw ball".  Stepping into the elevator is bad.
3d6d: c9 5b                        cmp     #VERB_FWD         ;forward movement?
3d6f: d0 1d                        bne     :NotIntoSpikes    ;no, branch
3d71: 20 7e 12                     jsr     EraseMaze
3d74: a2 00                        ldx     #0
3d76: 86 06                        stx     char_horiz
3d78: a2 14                        ldx     #20
3d7a: 86 07                        stx     char_vert
3d7c: a9 3a                        lda     #$3a              ;"you fall through the floor"
3d7e: 20 e2 08                     jsr     DrawMsgN
3d81: a9 0a                        lda     #$0a
3d83: 20 92 11                     jsr     PrintSpecialChar
3d86: a9 3b                        lda     #$3b              ;"onto a bed of spikes"
3d88: 20 e2 08                     jsr     DrawMsgN
3d8b: 4c b9 10                     jmp     HandleDeath

3d8e: c9 5a        :NotIntoSpikes  cmp     #$5a              ;movement?
3d90: 30 03                        bmi     :CheckThrow       ;no, branch to check it
3d92: 4c aa 3e                     jmp     SaltPillarDie     ;yes, die

3d95: c9 06        :CheckThrow     cmp     #$06              ;throw?
3d97: f0 03                        beq     :ThrowThing       ;yes, branch
3d99: 4c ca 3e     :JmpImpossible  jmp     CurrentlyImposs2  ;can't do that

                   ]inv_result     .var    $1a    {addr/1}

3d9c: ad 9d 61     :ThrowThing     lda     parsed_noun
3d9f: c9 01                        cmp     #$01              ;ball?
3da1: d0 f6                        bne     :JmpImpossible    ;no, fail
3da3: a2 06                        ldx     #FN_GET_OBJ_INFO
3da5: 86 0f                        stx     ]func_cmd
3da7: a2 01                        ldx     #$01              ;ball
3da9: 86 0e                        stx     ]func_arg
3dab: 20 34 1a                     jsr     ObjMgmtFunc       ;see if we have it in our inventory
3dae: a5 1a                        lda     ]inv_result
3db0: c9 08                        cmp     #$08              ;owned and un-boxed?
3db2: d0 e5                        bne     :JmpImpossible    ;no, reject
                   ; Throwing the ball teleports us to another short hallway.
3db4: 20 7e 12                     jsr     EraseMaze
3db7: 20 c5 30                     jsr     FlashYellow       ;do the explody thing
3dba: a2 07                        ldx     #$07              ;3 walls on left
3dbc: 8e 99 61                     stx     maze_walls_lf
3dbf: a2 46                        ldx     #$46              ;2 walls on right (not closest), dist=2
3dc1: 8e 9a 61                     stx     maze_walls_rt
3dc4: 20 a6 12                     jsr     DrawVisWalls      ;draw them
3dc7: a2 01                        ldx     #FN_DESTROY_OBJ1
3dc9: 86 0f                        stx     ]func_cmd
3dcb: 86 0e                        stx     ]func_arg         ;ball
3dcd: 20 34 1a                     jsr     ObjMgmtFunc       ;delete ball
3dd0: a2 07                        ldx     #FN_DRAW_INV
3dd2: 86 0f                        stx     ]func_cmd
3dd4: 20 34 1a                     jsr     ObjMgmtFunc       ;redraw inventory
3dd7: ee a8 61                     inc     end_state
3dda: 4c a6 3c                     jmp     :Hallway          ;loop

3ddd: c6 1a        :NotMove5       dec     ]inv_result
3ddf: d0 24                        bne     :NotMove6
3de1: c9 5a                        cmp     #$5a              ;movement?
3de3: 10 03                        bpl     :CheckHallB       ;yes, branch
3de5: 4c ca 3e     :JmpImpossible  jmp     CurrentlyImposs2

                   ; Moves 6/7 are forward steps.
3de8: c9 5b        :CheckHallB     cmp     #VERB_FWD         ;forward movement?
3dea: f0 03                        beq     :IntoHallB        ;yes, step down the hallway
3dec: 4c aa 3e     :JmpSaltDie     jmp     SaltPillarDie

                   ; Took first step forward in hallway B.
3def: 20 7e 12     :IntoHallB      jsr     EraseMaze
3df2: a2 03                        ldx     #$03              ;2 walls on left
3df4: 8e 99 61                     stx     maze_walls_lf
3df7: a2 23                        ldx     #$23              ;2 walls on right, dist=2
3df9: 8e 9a 61                     stx     maze_walls_rt
3dfc: 20 a6 12                     jsr     DrawVisWalls      ;draw walls
3dff: ee a8 61                     inc     end_state         ;advance counter
3e02: 4c a6 3c                     jmp     :Hallway          ;loop

3e05: c9 5a        :NotMove6       cmp     #$5a              ;movement?
3e07: 30 dc                        bmi     :JmpImpossible    ;no, impossible
3e09: c9 5b                        cmp     #VERB_FWD         ;forward movement?
3e0b: d0 df                        bne     :JmpSaltDie       ;no, was rotation; die
3e0d: 20 7e 12                     jsr     EraseMaze
                   ; Took second step in hallway B, reached the end.
3e10: a2 01                        ldx     #$01              ;1 wall on left, 1 on right, dist=0
3e12: 8e 99 61                     stx     maze_walls_lf
3e15: 8e 9a 61                     stx     maze_walls_rt
3e18: 20 a6 12                     jsr     DrawVisWalls      ;draw walls
                   ; Final move: literature quiz time.
3e1b: a9 3c        :AskMonsterName lda     #$3c              ;"before i let you go free"
3e1d: 20 92 08                     jsr     DrawMsgN_Row22
3e20: a9 3d                        lda     #$3d              ;"what was the name of the monster"
3e22: 20 a4 08                     jsr     DrawMsgN_Row23
3e25: 20 ca 0c                     jsr     GetInput
3e28: ad 9c 61                     lda     parsed_verb
3e2b: c9 5a                        cmp     #$5a              ;movement key?
3e2d: 10 bd                        bpl     :JmpSaltDie       ;yes, die
3e2f: c9 15                        cmp     #$15              ;grendel?
3e31: f0 56                        beq     Victory           ;yes, branch to victory
3e33: 4c 49 3e                     jmp     :BeowulfDisagree  ;no, give a hint

3e36: 42 45 4f 57+ :msg_beowulf    .str    ‘BEOWULF DISAGREES!’
3e48: 80                           .dd1    $80

                   :BeowulfDisagree
3e49: 20 5f 10                     jsr     ClearMessages
3e4c: a2 00                        ldx     #0                ;set text position to top text line
3e4e: 86 06                        stx     char_horiz
3e50: a2 16                        ldx     #22
3e52: 86 07                        stx     char_vert
3e54: a2 36                        ldx     #<:msg_beowulf    ;get pointer to hint message
3e56: 86 0c                        stx     string_ptr
3e58: a2 3e                        ldx     #>:msg_beowulf
3e5a: 86 0d                        stx     string_ptr+1
3e5c: 20 e5 08                     jsr     DrawMsg           ;draw hint
3e5f: 20 45 10                     jsr     LongDelay         ;pause
3e62: 4c 1b 3e                     jmp     :AskMonsterName   ;loop

3e65: 52 45 54 55+ msg_sanity      .str    ‘RETURN TO SANITY BY PRESSING RESET!’
3e88: 80                           .dd1    $80

                   ; 
                   ; Reports escape from the maze.
                   ; 
3e89: 20 55 08     Victory         jsr     ClearScreen
3e8c: a2 00                        ldx     #0                ;top left corner
3e8e: 86 06                        stx     char_horiz
3e90: 86 07                        stx     char_vert
3e92: a9 4d                        lda     #$4d              ;"correct! you have survived"
3e94: 20 e2 08                     jsr     DrawMsgN
3e97: a9 0a                        lda     #$0a              ;linefeed
3e99: 20 92 11                     jsr     PrintSpecialChar
3e9c: a2 65                        ldx     #<msg_sanity      ;get pointer to final message
3e9e: 86 0c                        stx     string_ptr
3ea0: a2 3e                        ldx     #>msg_sanity
3ea2: 86 0d                        stx     string_ptr+1
3ea4: 20 e5 08                     jsr     DrawMsg           ;"return to sanity by pressing reset"
3ea7: 4c a7 3e     :Loop           jmp     :Loop             ;spin forever

                   ; 
                   ; Informs player that they are now seasoning.  These are drawn in rows 20/21,
                   ; partly overlapping the maze; this allows them to be on the screen at the same
                   ; time as the "you're another victim / play again?" text.
                   ; 
3eaa: 20 7e 12     SaltPillarDie   jsr     EraseMaze
3ead: 20 5f 10                     jsr     ClearMessages
3eb0: a2 00                        ldx     #0
3eb2: 86 06                        stx     char_horiz
3eb4: a2 14                        ldx     #20
3eb6: 86 07                        stx     char_vert
3eb8: a9 a1                        lda     #$a1              ;"you have turned into a pillar of salt"
3eba: 20 e2 08                     jsr     DrawMsgN
3ebd: a9 0a                        lda     #$0a              ;linefeed
3ebf: 20 92 11                     jsr     PrintSpecialChar
3ec2: a9 a2                        lda     #$a2              ;"don't say I didn't warn you"
3ec4: 20 e2 08                     jsr     DrawMsgN
3ec7: 4c b9 10                     jmp     HandleDeath       ;go be dead

                   CurrentlyImposs2
3eca: a9 9a                        lda     #$9a              ;"it is currently impossible"
3ecc: 20 a4 08                     jsr     DrawMsgN_Row23
3ecf: 4c a6 3c                     jmp     :Hallway

3ed2: 86 e6 c3 d0+                 .junk   46

                   ; 
                   ; Does initial setup.
                   ; 
                   ; On exit:
                   ;   X-reg: zero
                   ; 
                   • Clear variables
                   ]src_ptr        .var    $0e    {addr/2}
                   ]dst_ptr        .var    $10    {addr/2}
                   ]length         .var    $19    {addr/2}

3f00: ad ff 3f     Setup           lda     reloc_flag        ;have we already copied the data out?
3f03: f0 2b                        beq     :SkipCopy         ;yes, skip copy
3f05: a2 00                        ldx     #$00
3f07: 86 0e                        stx     ]src_ptr
3f09: 86 10                        stx     ]dst_ptr
3f0b: 8e ff 3f                     stx     reloc_flag        ;clear flag
                   ; Copy $4000-5ffe to $6000-7ffe.
3f0e: a2 40                        ldx     #$40
3f10: 86 0f                        stx     ]src_ptr+1
3f12: a2 60                        ldx     #$60
3f14: 86 11                        stx     ]dst_ptr+1
3f16: a2 ff                        ldx     #$ff
3f18: 86 19                        stx     ]length
3f1a: a2 1f                        ldx     #$1f
3f1c: 86 1a                        stx     ]length+1
3f1e: 20 02 0c                     jsr     CopyData
                   ; Point Ctrl+Y vector at $3f4e.
3f21: a2 4c                        ldx     #$4c              ;JMP
3f23: 8e f8 03                     stx     MON_USRADDR
3f26: a2 4e                        ldx     #<CtrlY
3f28: 8e f9 03                     stx     MON_USRADDR+1
3f2b: a2 3f                        ldx     #>CtrlY
3f2d: 8e fa 03                     stx     MON_USRADDR+2
                   ; Init a few things.
3f30: a2 44        :SkipCopy       ldx     #‘D’              ;set "DEATH" magic value in game state
3f32: 8e 00 62                     stx     save_magic        ; so we can identify our saved games
3f35: a2 45                        ldx     #‘E’
3f37: 8e 01 62                     stx     save_magic+1
3f3a: a2 41                        ldx     #‘A’
3f3c: 8e 02 62                     stx     save_magic+2
3f3f: a2 54                        ldx     #‘T’
3f41: 8e 03 62                     stx     save_magic+3
3f44: a2 48                        ldx     #‘H’
3f46: 8e 04 62                     stx     save_magic+4
3f49: a2 00                        ldx     #$00              ;init vertical text position
3f4b: 86 07                        stx     char_vert
3f4d: 60                           rts

                   ; 
                   ; Ctrl+Y jumps here, presumably for use by the developer.
                   ; 
3f4e: 2c 55 c0     CtrlY           bit     TXTPAGE2          ;page 2
3f51: 2c 52 c0                     bit     MIXCLR            ;full screen
3f54: 2c 57 c0                     bit     HIRES             ;hi-res
3f57: 2c 50 c0                     bit     TXTCLR            ;show graphics
3f5a: 4c 38 09                     jmp     MainLoop2         ;jump into the game

3f5d: a0 00 98 91+                 .junk   162
3fff: ff           reloc_flag      .dd1    $ff               ;relocation flag, set to zero after data moved

                                   .org    $6000
                   ; 
                   ; Maze wall data.  There are five floors, with 11x12 cells in each.
                   ; 
                   ; The wall data uses two bits per cell, indicating the presence or absence of
                   ; walls on the south and west sides of the cell.  Adjoining cells provide the
                   ; other two walls.  The data is stored in column-major order, 3 bytes per
                   ; column.  Column 0 comes first; row 0 is in the high bits of the first byte.
                   ; 
                   ; To hold 11 columns requires 33 bytes per floor.  The last row and column must
                   ; be filled with the outer walls, so the the map uses an 11x12 grid to represent
                   ; a 10x11 map.
                   ; 
                   ; The coordinate system used by most of the code starts at (1,1) rather than
                   ; (0,0).
                   vis vis vis vis vis
6000: d5 7d 57 a6+ maze_wall_data  .bulk   $d5,$7d,$57,$a6,$95,$d3,$b6,$56,$9c,$a5,$da,$48,$96,$13,$6f,$cb
                                    +      $94,$af,$b8,$57,$2f,$a9,$da,$6f,$a3,$49,$2f,$94,$95,$0f,$ff,$ff
                                    +      $ff
6021: df 77 5f c8+                 .bulk   $df,$77,$5f,$c8,$aa,$cf,$9d,$1a,$df,$cd,$4a,$6f,$9b,$68,$8f,$a2
                                    +      $a4,$df,$96,$96,$af,$d8,$4e,$cf,$b7,$76,$9f,$88,$88,$4f,$ff,$ff
                                    +      $ff
6042: d5 d5 7f 9c+                 .bulk   $d5,$d5,$7f,$9c,$bd,$af,$cb,$a2,$9f,$99,$b6,$2f,$cd,$99,$2f,$a2
                                    +      $55,$af,$b5,$5a,$bf,$8d,$e2,$6f,$a2,$37,$2f,$95,$54,$4f,$ff,$ff
                                    +      $ff
6063: d7 f7 7f b2+                 .bulk   $d7,$f7,$7f,$b2,$66,$af,$a5,$28,$af,$97,$0c,$8f,$c8,$bb,$df,$9b
                                    +      $22,$2f,$ea,$d9,$6f,$92,$2d,$af,$d3,$22,$2f,$94,$55,$4f,$ff,$ff
                                    +      $ff
6084: d7 55 df 9a+                 .bulk   $d7,$55,$df,$9a,$cc,$4f,$da,$b9,$5f,$a0,$f6,$6f,$b1,$9b,$2f,$ac
                                    +      $e0,$6f,$bd,$9d,$af,$aa,$4a,$af,$a2,$52,$2f,$9c,$9d,$07,$ff,$ff
                                    +      $ff
                   ; 
                   ; Visible maze features, like pits, elevators, and holes in the ceiling.
                   ; 
                   ; Instead of starting with a list of positions and features, and determining
                   ; facing, distance, and whether there are intervening walls, the code has a
                   ; complete list of every position/facing from which a feature is visible. 
                   ; Features are drawn at $1e5a (see comment there for explanation).
                   ; 
                   ;  +$00 (facing << 4) | floor
                   ;  +$01 (X-coord << 4) | Y-coord
                   ;  +$02 result: feature
                   ;  +$03 result: argument
                   ; 
                   ; Facing: 1=W 2=N 3=E 4=S
60a5: 42 34 05 01  maze_features   .bulk   $42,$34,$05,$01   ;facing S on lv 2 at (3,4), hole in ceiling, arg=1
60a9: 42 35 05 02                  .bulk   $42,$35,$05,$02   ;...
60ad: 42 36 05 00                  .bulk   $42,$36,$05,$00
60b1: 22 83 04 01                  .bulk   $22,$83,$04,$01
60b5: 22 84 04 00                  .bulk   $22,$84,$04,$00
60b9: 42 86 04 00                  .bulk   $42,$86,$04,$00
60bd: 22 75 08 01                  .bulk   $22,$75,$08,$01
60c1: 22 76 08 02                  .bulk   $22,$76,$08,$02
60c5: 32 77 02 00                  .bulk   $32,$77,$02,$00
60c9: 23 43 08 04                  .bulk   $23,$43,$08,$04
60cd: 13 44 02 00                  .bulk   $13,$44,$02,$00
60d1: 13 95 05 01                  .bulk   $13,$95,$05,$01
60d5: 33 68 07 04                  .bulk   $33,$68,$07,$04
60d9: 23 78 07 02                  .bulk   $23,$78,$07,$02
60dd: 13 88 07 01                  .bulk   $13,$88,$07,$01
60e1: 24 14 02 00                  .bulk   $24,$14,$02,$00
60e5: 14 24 08 02                  .bulk   $14,$24,$08,$02
60e9: 14 2a 05 01                  .bulk   $14,$2a,$05,$01
60ed: 14 3a 05 02                  .bulk   $14,$3a,$05,$02
60f1: 14 4a 05 00                  .bulk   $14,$4a,$05,$00
60f5: 35 25 08 04                  .bulk   $35,$25,$08,$04
60f9: 25 35 02 00                  .bulk   $25,$35,$02,$00
60fd: 35 3a 09 f0                  .bulk   $35,$3a,$09,$f0   ;keyholes...
6101: 35 4a 09 f0                  .bulk   $35,$4a,$09,$f0
6105: 35 5a 09 70                  .bulk   $35,$5a,$09,$70
6109: 35 6a 09 30                  .bulk   $35,$6a,$09,$30
610d: 35 7a 09 10                  .bulk   $35,$7a,$09,$10
6111: 15 5a 09 01                  .bulk   $15,$5a,$09,$01
6115: 15 6a 09 03                  .bulk   $15,$6a,$09,$03
6119: 15 7a 09 07                  .bulk   $15,$7a,$09,$07
611d: 15 8a 09 0f                  .bulk   $15,$8a,$09,$0f
6121: 15 9a 09 0f                  .bulk   $15,$9a,$09,$0f
6125: 15 aa 09 0e                  .bulk   $15,$aa,$09,$0e
6129: 25 4a 01 00                  .bulk   $25,$4a,$01,$00
612d: 25 5a 01 00                  .bulk   $25,$5a,$01,$00
6131: 25 6a 01 00                  .bulk   $25,$6a,$01,$00
6135: 25 7a 01 00                  .bulk   $25,$7a,$01,$00
6139: 25 8a 01 00                  .bulk   $25,$8a,$01,$00
                   ; 
                   ; Initial player state.  This is copied to $6193.
                   ; 
613d: 02           init_game_state .dd1    $02               ;facing north
613e: 01                           .dd1    $01               ;floor 1
613f: 0a                           .dd1    $0a               ;X=10
6140: 06                           .dd1    $06               ;Y=6
6141: 01                           .dd1    $01               ;1 lit torch
6142: 00                           .dd1    $00               ;0 unlit torches
6143: 07 bf 00 00+                 .bulk   $07,$bf,$00,$00,$00,$01,$00,$a0,$c8,$00,$00,$00,$00,$00,$00,$00
                                    +      $00,$00,$02,$04,$02,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00
6163: 00 00        init_obj_state  .bulk   $00,$00
6165: 01 35                        .bulk   $01,$35           ;$01 ball
6167: 03 a5                        .bulk   $03,$a5           ;$02 brush
6169: 01 33                        .bulk   $01,$33           ;$03 calculator
616b: 01 46                        .bulk   $01,$46           ;$04 dagger
616d: 04 58                        .bulk   $04,$58           ;$05 flute
616f: 01 64                        .bulk   $01,$64           ;$06 frisbee
6171: 01 1b                        .bulk   $01,$1b           ;$07 hat
6173: 04 71                        .bulk   $04,$71           ;$08 horn
6175: 02 11                        .bulk   $02,$11           ;$09 jar
6177: 05 72                        .bulk   $05,$72           ;$0a key
6179: 01 23                        .bulk   $01,$23           ;$0b ring
617b: 01 72                        .bulk   $01,$72           ;$0c sneaker
617d: 02 86                        .bulk   $02,$86           ;$0d staff
617f: 03 2a                        .bulk   $03,$2a           ;$0e sword (area up snake)
6181: 03 6a                        .bulk   $03,$6a           ;$0f wool
6183: 04 57                        .bulk   $04,$57           ;$10 yoyo
6185: 02 39                        .bulk   $02,$39           ;$11 snake (in box)
6187: 02 26                        .bulk   $02,$26           ;$12 food #1
6189: 03 56                        .bulk   $03,$56           ;    food #2
618b: 04 72                        .bulk   $04,$72           ;    food #3
618d: 02 82                        .bulk   $02,$82           ;    torch #1
618f: 03 26                        .bulk   $03,$26           ;    torch #2
6191: 04 96                        .bulk   $04,$96           ;    torch #3
                   ; 
                   ; All game state is collected here. The next 256 bytes are saved/restored to
                   ; disk or tape.  The data is initialized from init_game_state (above).
                   ; 
                   ; 
                   ; Player facing.  East is 1, north is 2, west is 3, south is 4.
6193: 02           plyr_facing     .dd1    $02               ;facing direction (1-4), right turn increments
                   ; 
                   ; Player's position within the maze.  On a given floor, the bottom-left corner
                   ; is (1,1), and the NE corner is usually (10,10).
6194: 05           plyr_floor      .dd1    $05               ;which floor we're on (1-5)
6195: 04           plyr_xpos       .dd1    $04               ;X position (1-10)
6196: 0a           plyr_ypos       .dd1    $0a               ;Y position (1-10)
                   ; 
                   ; Number of lit and unlit torches.  Shown in inventory.
6197: 00           num_lit_torches .dd1    $00               ;lit torches in inventory
                   num_unlit_torches
6198: 01                           .dd1    $01               ;unlit torches in inventory
                   ; 
                   ; Results of maze wall processing.  The low 5 bits of each byte have the form
                   ;   ---43210
                   ; indicating the presence of a wall on the left or right of the viewer at that
                   ; distance.
                   ; 
                   ; In addition, the high 3 bits of the right wall flag byte hold the distance to
                   ; the next perpendicular wall, which will be 0-5 (where 5 represents
                   ; "infinity").
6199: 00           maze_walls_lf   .dd1    $00
619a: 00           maze_walls_rt   .dd1    $00
619b: 00           vis_box_flags   .dd1    $00               ;boxes visible; $01/02/04/08 into distance
                   ; 
                   ; Results of input processing.
619c: 10           parsed_verb     .dd1    $10               ;last verb entered
619d: 17           parsed_noun     .dd1    $17               ;last noun entered ($00 if none)
                   ; 
                   ; Player state flags and counters.
                   illumination_flag
619e: 01                           .dd1    $01               ;0=no light, 1=light (torch or ring)
619f: 00           food_level_hi   .dd1    $00               ;16-bit food level, in big-endian order
61a0: 80           food_level_lo   .dd1    $80
61a1: 80           torch_level     .dd1    $80               ;moves before torch goes out
61a2: 00           ring_light_flag .dd1    $00               ;$01=ring providing light, $00=not
61a3: 00           floor_move_hi   .dd1    $00               ;number of steps taken on current floor (16-bit
61a4: 29           floor_move_lo   .dd1    $29               ; big-endian value)
                   ; 
                   ; Special room stuff.  Sometimes it's a special occurrence in a specific
                   ; location, sometimes we're just locked in after a specific action (like raising
                   ; the snake).  While this is nonzero, we're executing in a separate state
                   ; machine.
                   ; 
                   ; Sometimes we need to push/pop the zone, e.g. we're in the calculator room and
                   ; the torch went out, so there are two additional slots.
                   ; 
                   ;  $00 = (nothing special)
                   ;  $02 = calculator room (1st floor 3,3) [$0a3d]
                   ;  $04 = attacked by bat (5th floor 4,4) [$0afa]
                   ;  $06 = attacked by dog #1 (60+ moves on 2nd floor) [$0a7b]
                   ;  $07 = attacked by dog #2 (2nd floor 5,5) [$0ab6]
                   ;  $08 = monster in lair (80+ moves on 4th floor) [$0b13]
                   ;  $09 = monster mother in lair (5th floor) [$0ade]
                   ;  $0a = monster nearby in darkness (torch went out) [$0b4a, $273f, etc.]
                   ;  $0b = opened box with snake [$2c1d, $2ebc]
                   ;  $0c = keyhole #2 unlocked, key ticking [$2c71]
                   ;  $0d = elevator doors have been opened, awaiting 'Z' [$2c86]
                   ;  $0e = monster tangled [$2896]
                   ;  $0f = snake risen from box [$2ad4]
                   ;  $10 = endgame
61a5: 00           special_zone    .dd1    $00
61a6: 00           special_zone1   .dd1    $00
61a7: 00           special_zone2   .dd1    $00
                   ; 
61a8: 00           end_state       .dd1    $00               ;endgame state machine state
61a9: 00 00                        .junk   2
                   ; 
                   ; Hostile creature flags.  Each is in its own byte, though much of the code
                   ; tests for a specific bit rather than zero/nonzero.
61ab: 00           bat_alive       .dd1    $00               ;$02=alive, $00=dead
61ac: 04           monster2_alive  .dd1    $04               ;$04=alive, $00=dead (monster's mother)
61ad: 00           monster1_alive  .dd1    $00               ;$02=alive, $00=dead (monster)
61ae: 00           dog1_alive      .dd1    $00               ;$01=alive, $00=dead
61af: 01           dog2_alive      .dd1    $01               ;$01=alive, $00=dead
61b0: 00                           .dd1    $00
                   ; 
61b1: 00           help_ctr        .dd1    $00               ;help msg cycle counter (0=$9e, 1=$9d)
                   ; 
                   ; Monster distance.  Affects the messages displayed if we perform an action. 
                   ; (Starts with ground shaking, then bad odor, then death.)
                   ; 
                   ;   $00 = not near, $01 = near, $02 = death
                   ; 
                   ; The monster special handler at $3661 also uses $0c.
61b2: 0c           monster1_dist   .dd1    $0c               ;monster approaching lair
61b3: 00           monst_dark_dist .dd1    $00               ;monster approaching while in darkness
                   ; 
                   ; Calculator room puzzle tracking.
61b4: 05           calc_turn_goal  .dd1    $05               ;calc puzzle: current turn goal
61b5: 00           calc_turn_count .dd1    $00               ;calc puzzle: current turn count
61b6: 00           calc_prev_move  .dd1    $00               ;calc puzzle: previous verb (also key counter)
                   calc_total_moves
61b7: 00                           .dd1    $00               ;calc puzzle: total moves made
                   ; 
                   ; Special wool message.
61b8: 00           wool_msg_flag   .dd1    $00               ;nonzero if wool destroyed by "raiding lair"
                   ; 
                   ; Object location and status.  There are 24 entries, one for every object, but
                   ; entry zero is unused.
                   ; 
                   ; Each entry specifies either a position within the maze or inclusion in the
                   ; player's inventory.  For the former, the first byte is the floor of the maze
                   ; on which it's located, the second holds the X/Y position (X*16+Y).  For an
                   ; inventory item, the first byte indicates the object's state, the second is
                   ; $00.
                   ; 
                   ; For example, the dagger is item $04, initially in a box at floor=1 X=4 Y=6. 
                   ; There will be an entry at $61b9+(4*2)=$61c1 with the values $01 $46.  When the
                   ; box is picked up, the entry changes to $06 $00.
                   ; 
                   ; Non-floor state values are:
                   ;   $00 - destroyed
                   ;   $06 - in inventory, in box
                   ;   $07 - in inventory, activated (torch/ring lit)
                   ;   $08 - in inventory
                   ; 
                   ; Note the inventory state values are outside the range [1,5] so as not to
                   ; overlap with valid floor numbers.
                   ; 
                   ; Entries before the first food item correspond directly to the noun index. 
                   ; Starting with the entry for $12 (noun="food"), there are 3 entries for food,
                   ; followed by 3 entries for torches.
                   ; 
61b9: 01 00        object_status   .bulk   $01,$00           ;object $00 (which doesn't exist)
61bb: 08 00        object_status2  .bulk   $08,$00           ;object $01 (ball)
61bd: 03 a5                        .bulk   $03,$a5
61bf: 00 00                        .bulk   $00,$00
61c1: 04 a9                        .bulk   $04,$a9
61c3: 08 00                        .bulk   $08,$00
61c5: 01 64                        .bulk   $01,$64
61c7: 02 33                        .bulk   $02,$33
61c9: 08 00                        .bulk   $08,$00
61cb: 00 00                        .bulk   $00,$00
61cd: 05 72                        .bulk   $05,$72
61cf: 07 00                        .bulk   $07,$00
61d1: 00 00                        .bulk   $00,$00
61d3: 02 86                        .bulk   $02,$86
61d5: 08 00                        .bulk   $08,$00
61d7: 04 a8                        .bulk   $04,$a8
61d9: 04 57                        .bulk   $04,$57
61db: 00 00        snake_obj_loc   .bulk   $00,$00           ;$11 snake (in box)
61dd: 00 00        food_torch_loc  .bulk   $00,$00           ;$12 food #1
61df: 00 00                        .bulk   $00,$00           ;    food #2
61e1: 00 00                        .bulk   $00,$00           ;    food #3
61e3: 00 00                        .bulk   $00,$00           ;    torch #1
61e5: 00 00                        .bulk   $00,$00           ;    torch #2
61e7: 08 00                        .bulk   $08,$00           ;    torch #3
                   ; (end of region initialized by data copy)
61e9: 00 00 00 00+                 .junk   14
61f7: 44           acc_swap_stash  .dd1    $44               ;temp storage
                   ; 
                   ; Temporary storage for some zero-page data.
61f8: 45           saved_0e        .dd1    $45
61f9: 41           saved_0f        .dd1    $41
61fa: 54           saved_10        .dd1    $54
61fb: 48           saved_11        .dd1    $48
61fc: 07           saved_19        .dd1    $07
61fd: 00           saved_1a        .dd1    $00
61fe: 00 00                        .junk   2
                   ; (end of useful state)
6200: 44 45 41 54+ save_magic      .str    ‘DEATH’           ;magic value, tested by saved game restore
6205: 00 00 00 00+                 .junk   143               ;unused

                   vis
6294: 10 08 3e 7f+ font_glyphs     .bulk   $10,$08,$3e,$7f,$ff,$ff,$be,$1c,$01,$02,$04,$08,$08,$10,$20,$40
                                    +      $40,$20,$10,$08,$08,$04,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01
                                    +      $40,$40,$40,$40,$40,$40,$40,$40,$41,$22,$14,$08,$14,$22,$41,$41
                                    +      $40,$60,$70,$78,$78,$7c,$7e,$7f,$01,$03,$07,$0f,$0f,$1f,$3f,$7f
                                    +      $7f,$7e,$7c,$78,$78,$70,$60,$40,$7f,$3f,$1f,$0f,$0f,$07,$03,$01
                                    +      $41,$41,$41,$41,$41,$41,$41,$41,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
                                    +      $00,$78,$64,$5e,$52,$32,$1e,$00,$00,$00,$00,$00,$78,$04,$02,$7f
                                    +      $00,$00,$00,$00,$0f,$0c,$0a,$09,$09,$09,$09,$09,$09,$05,$03,$01
                                    +      $00,$00,$00,$00,$7f,$00,$00,$7f,$09,$09,$09,$09,$09,$09,$09,$09
                                    +      $01,$01,$01,$01,$01,$01,$01,$7f,$00,$00,$00,$00,$00,$00,$00,$7f
                                    +      $40,$20,$10,$08,$08,$0c,$0a,$09,$09,$0a,$0c,$08,$08,$10,$20,$40
                                    +      $08,$08,$08,$08,$08,$08,$08,$08,$41,$42,$44,$48,$48,$50,$60,$40
                                    +      $00,$00,$00,$1c,$08,$1c,$00,$00,$60,$70,$70,$60,$60,$70,$70,$70
                                    +      $03,$07,$07,$03,$03,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07
                                    +      $70,$70,$70,$70,$70,$70,$70,$70,$01,$03,$07,$07,$07,$07,$07,$07
                                    +      $40,$60,$70,$70,$70,$70,$70,$70,$78,$78,$78,$78,$7f,$7f,$7f,$7f
                                    +      $00,$00,$00,$00,$00,$00,$00,$00,$08,$08,$08,$08,$08,$00,$08,$00
                                    +      $14,$14,$14,$00,$00,$00,$00,$00,$14,$14,$3e,$14,$3e,$14,$14,$00
                                    +      $1c,$2a,$0a,$1c,$28,$2a,$1c,$00,$26,$26,$10,$08,$04,$32,$32,$00
                                    +      $04,$0a,$0a,$04,$2a,$12,$2c,$00,$08,$08,$08,$00,$00,$00,$00,$00
                                    +      $10,$08,$04,$04,$04,$08,$10,$00,$04,$08,$10,$10,$10,$08,$04,$00
                                    +      $08,$2a,$1c,$08,$1c,$2a,$08,$00,$00,$08,$08,$3e,$08,$08,$00,$00
                                    +      $00,$00,$00,$00,$10,$10,$08,$00,$00,$00,$00,$3e,$00,$00,$00,$00
                                    +      $00,$00,$00,$00,$00,$0c,$0c,$00,$20,$20,$10,$08,$04,$02,$02,$00
                                    +      $1c,$22,$32,$2a,$26,$22,$1c,$00,$08,$0c,$08,$08,$08,$08,$1c,$00
                                    +      $1c,$22,$20,$1c,$02,$02,$3e,$00,$1e,$20,$20,$1c,$20,$20,$1e,$00
                                    +      $10,$18,$14,$12,$3e,$10,$10,$00,$3e,$02,$1e,$20,$20,$20,$1e,$00
                                    +      $18,$04,$02,$1e,$22,$22,$1c,$00,$3e,$20,$10,$08,$04,$04,$04,$00
                                    +      $1c,$22,$22,$1c,$22,$22,$1c,$00,$1c,$22,$22,$3c,$20,$10,$0c,$00
                                    +      $00,$0c,$0c,$00,$0c,$0c,$00,$00,$00,$0c,$0c,$00,$0c,$0c,$04,$00
                                    +      $10,$08,$04,$02,$04,$08,$10,$00,$00,$00,$3e,$00,$3e,$00,$00,$00
                                    +      $04,$08,$10,$20,$10,$08,$04,$00,$1c,$22,$10,$08,$08,$00,$08,$00
                                    +      $1c,$22,$3a,$2a,$3a,$02,$3c,$00,$08,$14,$22,$22,$3e,$22,$22,$00
                                    +      $1e,$24,$24,$1c,$24,$24,$1e,$00,$1c,$22,$02,$02,$02,$22,$1c,$00
                                    +      $1e,$24,$24,$24,$24,$24,$1e,$00,$3e,$02,$02,$1e,$02,$02,$3e,$00
                                    +      $3e,$02,$02,$1e,$02,$02,$02,$00,$3c,$02,$02,$02,$32,$22,$3c,$00
                                    +      $22,$22,$22,$3e,$22,$22,$22,$00,$1c,$08,$08,$08,$08,$08,$1c,$00
                                    +      $20,$20,$20,$20,$22,$22,$1c,$00,$22,$12,$0a,$06,$0a,$12,$22,$00
                                    +      $02,$02,$02,$02,$02,$02,$7e,$00,$22,$36,$2a,$2a,$22,$22,$22,$00
                                    +      $22,$26,$2a,$32,$22,$22,$22,$00,$1c,$22,$22,$22,$22,$22,$1c,$00
                                    +      $1e,$22,$22,$1e,$02,$02,$02,$00,$1c,$22,$22,$22,$2a,$12,$2c,$00
                                    +      $1e,$22,$22,$1e,$0a,$12,$22,$00,$1c,$22,$02,$1c,$20,$22,$1c,$00
                                    +      $3e,$08,$08,$08,$08,$08,$08,$00,$22,$22,$22,$22,$22,$22,$1c,$00
                                    +      $22,$22,$22,$14,$14,$08,$08,$00,$22,$22,$2a,$2a,$2a,$36,$22,$00
                                    +      $22,$22,$14,$08,$14,$22,$22,$00,$22,$22,$22,$1c,$08,$08,$08,$00
                                    +      $3e,$20,$10,$08,$04,$02,$3e,$00,$08,$1c,$2a,$08,$08,$08,$08,$00
                                    +      $08,$08,$08,$08,$2a,$1c,$08,$00,$00,$04,$02,$7f,$02,$04,$00,$00
                                    +      $00,$10,$20,$7f,$20,$10,$00,$00,$70,$60,$40,$00,$00,$00,$00,$00
                                    +      $07,$03,$01,$00,$00,$00,$00,$00,$00,$00,$1c,$20,$3c,$22,$3c,$00
                                    +      $02,$02,$1a,$26,$22,$22,$1e,$00,$00,$00,$1c,$22,$02,$22,$1c,$00
                                    +      $20,$20,$2c,$32,$22,$22,$3c,$00,$00,$00,$1c,$22,$3e,$02,$1c,$00
                                    +      $18,$24,$04,$0e,$04,$04,$04,$00,$00,$00,$2c,$32,$22,$3c,$20,$1e
                                    +      $02,$02,$1a,$26,$22,$22,$22,$00,$08,$00,$0c,$08,$08,$08,$1c,$00
                                    +      $20,$00,$20,$20,$20,$20,$22,$1c,$02,$02,$12,$0a,$06,$0a,$12,$00
                                    +      $00,$0c,$08,$08,$08,$08,$1c,$00,$00,$00,$16,$2a,$2a,$2a,$2a,$00
                                    +      $00,$00,$1a,$26,$22,$22,$22,$00,$00,$00,$1c,$22,$22,$22,$1c,$00
                                    +      $00,$00,$1e,$22,$22,$1e,$02,$02,$00,$00,$3c,$22,$22,$3c,$20,$20
                                    +      $00,$00,$1a,$26,$02,$02,$02,$00,$00,$00,$3c,$02,$1c,$20,$1e,$00
                                    +      $04,$04,$1e,$04,$04,$24,$18,$00,$00,$00,$22,$22,$22,$32,$2c,$00
                                    +      $00,$00,$22,$22,$14,$14,$08,$00,$00,$00,$2a,$2a,$2a,$2a,$14,$00
                                    +      $00,$00,$22,$14,$08,$14,$22,$00,$00,$00,$22,$22,$22,$3c,$20,$1c
                                    +      $00,$00,$3e,$10,$08,$04,$3e,$00,$0f,$0f,$0f,$0f,$7f,$7f,$7f,$7f
                                    +      $70,$78,$7c,$7e,$7f,$7f,$7f,$7f,$07,$0f,$1f,$3f,$7f,$7f,$7f,$7f
                                    +      $7f,$7f,$7f,$7f,$7e,$7c,$78,$70,$7f,$7f,$7f,$7f,$3f,$1f,$0f,$07
                   ; 
                   ; Recognized words, verbs first.  The first character has the high bit set.
                   ; 
                   ; Each verb name is 4 letters long, the last of which may be a space.  Anything
                   ; past that on the input line is ignored, so "clim" and "climb" are equivalent. 
                   ; The letters 'Z' and 'X' cause movement, and so may not start a verb.
                   ; 
                   ; If two entries are separated by a '*', the next entry is an alias for the
                   ; previous entry (roll/chuck/heave/throw are identical, as are door/elevator). 
                   ; The table starts with $ff because the scanner looks backward to see if the
                   ; current word is an alias for the previous one.
                   ; 
6694: ff           verb_list       .dd1    $ff
6695: f2                           .dd1    “r”               ;$01
6696: 61 69 73                     .str    ‘ais’
6699: e2                           .dd1    “b”
669a: 6c 6f 77                     .str    ‘low’
669d: e2                           .dd1    “b”
669e: 72 65 61                     .str    ‘rea’
66a1: e2                           .dd1    “b”
66a2: 75 72 6e                     .str    ‘urn’
66a5: e3                           .dd1    “c”
66a6: 68 65 77 2a                  .str    ‘hew*’
66aa: e5                           .dd1    “e”
66ab: 61 74 20                     .str    ‘at ’
66ae: f2                           .dd1    “r”
66af: 6f 6c 6c 2a                  .str    ‘oll*’
66b3: e3                           .dd1    “c”
66b4: 68 75 63 2a                  .str    ‘huc*’
66b8: e8                           .dd1    “h”
66b9: 65 61 76 2a                  .str    ‘eav*’
66bd: f4                           .dd1    “t”
66be: 68 72 6f                     .str    ‘hro’
66c1: e3                           .dd1    “c”
66c2: 6c 69 6d                     .str    ‘lim’
66c5: e4                           .dd1    “d”
66c6: 72 6f 70 2a                  .str    ‘rop*’
66ca: ec                           .dd1    “l”
66cb: 65 61 76 2a                  .str    ‘eav*’
66cf: f0                           .dd1    “p”
66d0: 75 74 20                     .str    ‘ut ’
66d3: e6                           .dd1    “f”
66d4: 69 6c 6c                     .str    ‘ill’
66d7: ec                           .dd1    “l”
66d8: 69 67 68                     .str    ‘igh’
66db: f0                           .dd1    “p”
66dc: 6c 61 79                     .str    ‘lay’
66df: f3                           .dd1    “s”
66e0: 74 72 69                     .str    ‘tri’
66e3: f7                           .dd1    “w”
66e4: 65 61 72                     .str    ‘ear’
66e7: e5                           .dd1    “e”
66e8: 78 61 6d 2a                  .str    ‘xam*’
66ec: ec                           .dd1    “l”
66ed: 6f 6f 6b                     .str    ‘ook’
66f0: f7                           .dd1    “w”
66f1: 69 70 65 2a                  .str    ‘ipe*’
66f5: e3                           .dd1    “c”
66f6: 6c 65 61 2a                  .str    ‘lea*’
66fa: f0                           .dd1    “p”
66fb: 6f 6c 69 2a                  .str    ‘oli*’
66ff: f2                           .dd1    “r”
6700: 75 62 20                     .str    ‘ub ’
6703: ef                           .dd1    “o”               ;$10
6704: 70 65 6e 2a                  .str    ‘pen*’
6708: f5                           .dd1    “u”
6709: 6e 6c 6f                     .str    ‘nlo’
670c: f0                           .dd1    “p”
670d: 72 65 73                     .str    ‘res’
6710: e7                           .dd1    “g”
6711: 65 74 20 2a                  .str    ‘et *’
6715: e7                           .dd1    “g”
6716: 72 61 62 2a                  .str    ‘rab*’
671a: e8                           .dd1    “h”
671b: 6f 6c 64 2a                  .str    ‘old*’
671f: f4                           .dd1    “t”
6720: 61 6b 65                     .str    ‘ake’
6723: f3                           .dd1    “s”
6724: 74 61 62 2a                  .str    ‘tab*’
6728: eb                           .dd1    “k”
6729: 69 6c 6c 2a                  .str    ‘ill*’
672d: f3                           .dd1    “s”
672e: 6c 61 73 2a                  .str    ‘las*’
6732: e1                           .dd1    “a”
6733: 74 74 61 2a                  .str    ‘tta*’
6737: e8                           .dd1    “h”
6738: 61 63 6b                     .str    ‘ack’
673b: f0                           .dd1    “p”
673c: 61 69 6e                     .str    ‘ain’
673f: e7                           .dd1    “g”
6740: 72 65 6e                     .str    ‘ren’
6743: f3                           .dd1    “s”
6744: 61 79 20 2a                  .str    ‘ay *’
6748: f9                           .dd1    “y”
6749: 65 6c 6c 2a                  .str    ‘ell*’
674d: f3                           .dd1    “s”
674e: 63 72 65                     .str    ‘cre’
6751: e3                           .dd1    “c”
6752: 68 61 72                     .str    ‘har’
6755: e6                           .dd1    “f”
6756: 61 72 74                     .str    ‘art’
6759: f3                           .dd1    “s”
675a: 61 76 65                     .str    ‘ave’
675d: f1                           .dd1    “q”
675e: 75 69 74                     .str    ‘uit’
6761: e9                           .dd1    “i”
6762: 6e 73 74 2a                  .str    ‘nst*’
6766: e4                           .dd1    “d”
6767: 69 72 65                     .str    ‘ire’
676a: e8                           .dd1    “h”
676b: 65 6c 70 2a                  .str    ‘elp*’
676f: e8                           .dd1    “h”
6770: 69 6e 74                     .str    ‘int’
                   ; Nouns start here.
6773: c2           noun_list       .dd1    “B”               ;$1d
6774: 61 6c 6c                     .str    ‘all’
6777: c2                           .dd1    “B”
6778: 72 75 73 68                  .str    ‘rush’
677c: c3                           .dd1    “C”
677d: 61 6c 63 75+                 .str    ‘alculator’
6786: c4                           .dd1    “D”               ;$20
6787: 61 67 67 65+                 .str    ‘agger’
678c: c6                           .dd1    “F”
678d: 6c 75 74 65                  .str    ‘lute’
6791: c6                           .dd1    “F”
6792: 72 69 73 62+                 .str    ‘risbee’
6798: c8                           .dd1    “H”
6799: 61 74 20                     .str    ‘at ’
679c: c8                           .dd1    “H”
679d: 6f 72 6e                     .str    ‘orn’
67a0: ca                           .dd1    “J”
67a1: 61 72 20                     .str    ‘ar ’
67a4: cb                           .dd1    “K”
67a5: 65 79 20                     .str    ‘ey ’
67a8: d2                           .dd1    “R”
67a9: 69 6e 67                     .str    ‘ing’
67ac: d3                           .dd1    “S”
67ad: 6e 65 61 6b+                 .str    ‘neaker’
67b3: d3                           .dd1    “S”
67b4: 74 61 66 66                  .str    ‘taff’
67b8: d3                           .dd1    “S”
67b9: 77 6f 72 64                  .str    ‘word’
67bd: d7                           .dd1    “W”
67be: 6f 6f 6c                     .str    ‘ool’
67c1: d9                           .dd1    “Y”
67c2: 6f 79 6f                     .str    ‘oyo’
67c5: d3                           .dd1    “S”
67c6: 6e 61 6b 65                  .str    ‘nake’
67ca: c6                           .dd1    “F”
67cb: 6f 6f 64                     .str    ‘ood’
67ce: d4                           .dd1    “T”
67cf: 6f 72 63 68                  .str    ‘orch’
67d3: c2                           .dd1    “B”               ;$30
67d4: 6f 78 20                     .str    ‘ox ’
67d7: c2                           .dd1    “B”
67d8: 61 74 20                     .str    ‘at ’
67db: c4                           .dd1    “D”
67dc: 6f 67 20                     .str    ‘og ’
67df: c4                           .dd1    “D”
67e0: 6f 6f 72 2a                  .str    ‘oor*’
67e4: c5                           .dd1    “E”
67e5: 6c 65 76                     .str    ‘lev’
67e8: cd                           .dd1    “M”
67e9: 6f 6e 73 74+                 .str    ‘onster’
67ef: cd                           .dd1    “M”
67f0: 6f 74 68 65+                 .str    ‘other’
67f5: da                           .dd1    “Z”
67f6: 65 72 6f                     .str    ‘ero’
67f9: cf                           .dd1    “O”
67fa: 6e 65 20                     .str    ‘ne ’
67fd: d4                           .dd1    “T”
67fe: 77 6f 20                     .str    ‘wo ’
6801: d4                           .dd1    “T”
6802: 68 72 65 65                  .str    ‘hree’
6806: c6                           .dd1    “F”
6807: 6f 75 72                     .str    ‘our’
680a: c6                           .dd1    “F”
680b: 69 76 65                     .str    ‘ive’
680e: d3                           .dd1    “S”
680f: 69 78 20                     .str    ‘ix ’
6812: d3                           .dd1    “S”
6813: 65 76 65 6e                  .str    ‘even’
6817: c5                           .dd1    “E”
6818: 69 67 68 74                  .str    ‘ight’
681c: ce                           .dd1    “N”               ;$3f
681d: 69 6e 65                     .str    ‘ine’
6820: ff                           .dd1    $ff               ;end of list
6821: ff 00 00 ff+                 .junk   8
                   ; 
                   ; Messages displayed to user.
                   ; 
                   ; The first character in each message has its high bit set.  Entries are
                   ; addressed by index, which is determined by walking the table.
                   ; 
6829: c9           msg_strings     .dd1    “I”               ;$01
682a: 6e 76 65 6e+                 .str    ‘nventory:’
6833: d4                           .dd1    “T”
6834: 6f 72 63 68+                 .str    ‘orches:’
683b: cc                           .dd1    “L”
683c: 69 74 3a                     .str    ‘it:’
683f: d5                           .dd1    “U”
6840: 6e 6c 69 74+                 .str    ‘nlit:’
6845: e3                           .dd1    “c”
6846: 72 79 73 74+                 .str    ‘rystal ball.’
6852: f0                           .dd1    “p”
6853: 61 69 6e 74+                 .str    ‘aintbrush used by Van Gogh.’
686e: e3                           .dd1    “c”
686f: 61 6c 63 75+                 .str    ‘alculator with 10 buttons.’
6889: ea                           .dd1    “j”
688a: 65 77 65 6c+                 .str    ‘eweled handled dagger.’
68a0: e6                           .dd1    “f”
68a1: 6c 75 74 65+                 .str    ‘lute.’
68a6: f0                           .dd1    “p”
68a7: 72 65 63 69+                 .str    ‘recision crafted frisbee.’
68c0: e8                           .dd1    “h”
68c1: 61 74 20 77+                 .str    ‘at with two ram's horns.’
68d9: e3                           .dd1    “c”
68da: 61 72 65 66+                 .str    ‘arefully polished horn.’
68f1: e7                           .dd1    “g”
68f2: 6c 61 73 73+                 .str    ‘lass jar complete with lid.’
690d: e7                           .dd1    “g”
690e: 6f 6c 64 65+                 .str    ‘olden key.’
6918: e4                           .dd1    “d”
6919: 69 61 6d 6f+                 .str    ‘iamond ring.’
6925: f2                           .dd1    “r”               ;$10
6926: 6f 74 74 65+                 .str    ‘otted mutilated sneaker.’
693e: ed                           .dd1    “m”
693f: 61 67 69 63+                 .str    ‘agic staff.’
694a: b9                           .dd1    “9”
694b: 30 20 70 6f+                 .str    ‘0 pound two-handed sword.’
6964: e2                           .dd1    “b”
6965: 61 6c 6c 20+                 .str    ‘all of blue wool.’
6976: f9                           .dd1    “y”
6977: 6f 79 6f 2e                  .str    ‘oyo.’
697b: f3                           .dd1    “s”
697c: 6e 61 6b 65+                 .str    ‘nake !!!’
6984: e2                           .dd1    “b”
6985: 61 73 6b 65+                 .str    ‘asket of food.’
6993: f4                           .dd1    “t”
6994: 6f 72 63 68+                 .str    ‘orch.’
6999: c9                           .dd1    “I”
699a: 6e 73 69 64+                 .str    ‘nside the box there is a’
69b2: d9                           .dd1    “Y”
69b3: 6f 75 20 75+                 .str    ‘ou unlock the door...’
69c8: e1                           .dd1    “a”
69c9: 6e 64 20 74+                 .str    ‘nd the wall falls on you!’
69e2: e1                           .dd1    “a”
69e3: 6e 64 20 74+                 .str    ‘nd the key begins to tick!’
69fd: e1                           .dd1    “a”
69fe: 6e 64 20 61+                 .str    ‘nd a 20,000 volt shock kills you!’
6a1f: c1                           .dd1    “A”
6a20: 20 36 30 30+                 .str    ‘ 600 pound gorilla rips your face off!’
6a46: d4                           .dd1    “T”
6a47: 77 6f 20 6d+                 .str    ‘wo men in white coats take you away!’
6a6b: c8                           .dd1    “H”
6a6c: 61 76 69 6e+                 .str    ‘aving fun?’
6a76: d4                           .dd1    “T”               ;$20
6a77: 68 65 20 73+                 .str    ‘he snake bites you and you die!’
6a96: d4                           .dd1    “T”
6a97: 68 75 6e 64+                 .str    ‘hunderbolts shoot out above you!’
6ab7: d4                           .dd1    “T”
6ab8: 68 65 20 73+                 .str    ‘he staff thunders with useless energy!’
6ade: f9                           .dd1    “y”
6adf: 6f 75 20 61+                 .str    ‘ou are wearing it.’
6af1: d4                           .dd1    “T”
6af2: 6f 20 65 76+                 .str    ‘o everything’
6afe: d4                           .dd1    “T”
6aff: 68 65 72 65+                 .str    ‘here is a season’
6b0f: ac                           .dd1    “,”
6b10: 20 54 55 52+                 .str    ‘ TURN,TURN,TURN’
6b1f: d4                           .dd1    “T”
6b20: 68 65 20 63+                 .str    ‘he calculator displays 317.’
6b3b: c9                           .dd1    “I”
6b3c: 74 20 64 69+                 .str    ‘t displays 317.2 !’
6b4e: d4                           .dd1    “T”
6b4f: 68 65 20 69+                 .str    ‘he invisible guillotine beheads you!’
6b73: d9                           .dd1    “Y”
6b74: 6f 75 20 68+                 .str    ‘ou have rammed your head into a steel’
6b99: f7                           .dd1    “w”
6b9a: 61 6c 6c 20+                 .str    ‘all and bashed your brains out!’
6bb9: c1                           .dd1    “A”
6bba: 41 41 41 41+                 .str    ‘AAAAAAAAAAHHHHH!’
6bca: d7                           .dd1    “W”
6bcb: 48 41 4d 21+                 .str    ‘HAM!!!’
6bd1: c1                           .dd1    “A”
6bd2: 20 76 69 63+                 .str    ‘ vicious dog attacks you!’
6beb: c8                           .dd1    “H”
6bec: 65 20 72 69+                 .str    ‘e rips your throat out!’
6c03: d4                           .dd1    “T”               ;$30
6c04: 68 65 20 64+                 .str    ‘he dog chases the sneaker!’
6c1e: c1                           .dd1    “A”
6c1f: 20 76 61 6d+                 .str    ‘ vampire bat attacks you!’
6c38: d9                           .dd1    “Y”
6c39: 6f 75 72 20+                 .str    ‘our stomach is growling!’
6c51: d9                           .dd1    “Y”
6c52: 6f 75 72 20+                 .str    ‘our torch is dying!’
6c65: d9                           .dd1    “Y”
6c66: 6f 75 20 61+                 .str    ‘ou are another victim of the maze!’
6c88: d9                           .dd1    “Y”
6c89: 6f 75 20 68+                 .str    ‘ou have died of starvation!’
6ca4: d4                           .dd1    “T”
6ca5: 68 65 20 6d+                 .str    ‘he monster attacks you and’
6cbf: f9                           .dd1    “y”
6cc0: 6f 75 20 61+                 .str    ‘ou are his next meal!’
6cd5: f4                           .dd1    “t”
6cd6: 68 65 20 6d+                 .str    ‘he magic word works! you have escaped!’
6cfc: c4                           .dd1    “D”
6cfd: 6f 20 79 6f+                 .str    ‘o you want to play again (Y or N)?’
6d1f: d9                           .dd1    “Y”
6d20: 6f 75 20 66+                 .str    ‘ou fall through the floor’
6d39: ef                           .dd1    “o”
6d3a: 6e 74 6f 20+                 .str    ‘nto a bed of spikes!’
6d4e: c2                           .dd1    “B”
6d4f: 65 66 6f 72+                 .str    ‘efore I let you go free’
6d66: f7                           .dd1    “w”
6d67: 68 61 74 20+                 .str    ‘hat was the name of the monster?’
6d87: e9                           .dd1    “i”
6d88: 74 20 73 61+                 .str    ‘t says "the magic word is camelot".’
6dab: d4                           .dd1    “T”
6dac: 68 65 20 6d+                 .str    ‘he monster grabs the frisbee, throws ’
6dd1: e9                           .dd1    “i”               ;$40
6dd2: 74 20 62 61+                 .str    ‘t back, and it saws your head off!’
6df4: d4                           .dd1    “T”
6df5: 49 43 4b 21+                 .str    ‘ICK! TICK!’
6dff: d4                           .dd1    “T”
6e00: 68 65 20 6b+                 .str    ‘he key blows up the whole maze!’
6e1f: d4                           .dd1    “T”
6e20: 68 65 20 67+                 .str    ‘he ground beneath your feet’
6e3b: e2                           .dd1    “b”
6e3c: 65 67 69 6e+                 .str    ‘egins to shake!’
6e4b: c1                           .dd1    “A”
6e4c: 20 64 69 73+                 .str    ‘ disgusting odor permeates’
6e66: f4                           .dd1    “t”
6e67: 68 65 20 68+                 .str    ‘he hallway as it darkens!’
6e80: f4                           .dd1    “t”
6e81: 68 65 20 68+                 .str    ‘he hallway!’
6e8c: c9                           .dd1    “I”
6e8d: 74 20 69 73+                 .str    ‘t is the monster's mother!’
6ea7: d3                           .dd1    “S”
6ea8: 68 65 20 68+                 .str    ‘he has been seduced!’
6ebc: d3                           .dd1    “S”
6ebd: 68 65 20 74+                 .str    ‘he tiptoes up to you!’
6ed2: d3                           .dd1    “S”
6ed3: 68 65 20 73+                 .str    ‘he slashes you to bits!’
6eea: d9                           .dd1    “Y”
6eeb: 6f 75 20 73+                 .str    ‘ou slash her to bits!’
6f00: c3                           .dd1    “C”
6f01: 6f 72 72 65+                 .str    ‘orrect! You have survived!’
6f1b: d9                           .dd1    “Y”
6f1c: 6f 75 20 62+                 .str    ‘ou break the’
6f28: e1                           .dd1    “a”
6f29: 6e 64 20 69+                 .str    ‘nd it disappears!’
6f3a: d7                           .dd1    “W”               ;$50
6f3b: 68 61 74 20+                 .str    ‘hat a mess! The vampire bat’
6f56: e4                           .dd1    “d”
6f57: 72 69 6e 6b+                 .str    ‘rinks the blood and dies!’
6f70: c9                           .dd1    “I”
6f71: 74 20 76 61+                 .str    ‘t vanishes in a’
6f80: e2                           .dd1    “b”
6f81: 75 72 73 74+                 .str    ‘urst of flames!’
6f90: d9                           .dd1    “Y”
6f91: 6f 75 20 63+                 .str    ‘ou can't be serious!’
6fa5: d9                           .dd1    “Y”
6fa6: 6f 75 20 61+                 .str    ‘ou are making little sense.’
6fc1: a0                           .dd1    “ ”
6fc2: 77 68 61 74+                 .str    ‘what?                   ’
6fda: e1                           .dd1    “a”
6fdb: 6c 6c 20 66+                 .str    ‘ll form into darts!’
6fee: d4                           .dd1    “T”
6fef: 68 65 20 66+                 .str    ‘he food is being digested.’
7009: d4                           .dd1    “T”
700a: 68 65 20                     .str    ‘he ’
700d: ed                           .dd1    “m”
700e: 61 67 69 63+                 .str    ‘agically sails’
701c: e1                           .dd1    “a”
701d: 72 6f 75 6e+                 .str    ‘round a nearby corner’
7032: e1                           .dd1    “a”
7033: 6e 64 20 69+                 .str    ‘nd is eaten by’
7041: f4                           .dd1    “t”
7042: 68 65 20 6d+                 .str    ‘he monster !!!!’
7051: e1                           .dd1    “a”
7052: 6e 64 20 74+                 .str    ‘nd the monster grabs it,’
706a: e7                           .dd1    “g”
706b: 65 74 73 20+                 .str    ‘ets tangled, and topples over!’
7089: c9                           .dd1    “I”               ;$60
708a: 74 20 69 73+                 .str    ‘t is now full of blood.’
70a1: d4                           .dd1    “T”
70a2: 68 65 20 6d+                 .str    ‘he monster is dead and’
70b8: ed                           .dd1    “m”
70b9: 75 63 68 20+                 .str    ‘uch blood is spilt!’
70cc: d9                           .dd1    “Y”
70cd: 6f 75 20 68+                 .str    ‘ou have killed it.’
70df: d4                           .dd1    “T”
70e0: 68 65 20 64+                 .str    ‘he dagger disappears!’
70f5: d4                           .dd1    “T”
70f6: 68 65 20 74+                 .str    ‘he torch is lit and the’
710d: ef                           .dd1    “o”
710e: 6c 64 20 74+                 .str    ‘ld torch dies and vanishes!’
7129: c1                           .dd1    “A”
712a: 20 63 6c 6f+                 .str    ‘ close inspection reveals’
7143: e1                           .dd1    “a”
7144: 62 73 6f 6c+                 .str    ‘bsolutely nothing of value!’
715f: e1                           .dd1    “a”
7160: 20 73 6d 75+                 .str    ‘ smudged display!’
7171: c1                           .dd1    “A”
7172: 20 63 61 6e+                 .str    ‘ can of spinach?’
7182: f2                           .dd1    “r”
7183: 65 74 75 72+                 .str    ‘eturns and hits you’
7196: e9                           .dd1    “i”
7197: 6e 20 74 68+                 .str    ‘n the eye!’
71a1: d9                           .dd1    “Y”
71a2: 6f 75 20 61+                 .str    ‘ou are trapped in a fake’
71ba: e5                           .dd1    “e”
71bb: 6c 65 76 61+                 .str    ‘levator. There is no escape!’
71d7: d7                           .dd1    “W”
71d8: 69 74 68 20+                 .str    ‘ith what? Toenail polish?’
71f1: c1                           .dd1    “A”               ;$70
71f2: 20 64 72 61+                 .str    ‘ draft blows your torch out!’
720e: d4                           .dd1    “T”
720f: 68 65 20 72+                 .str    ‘he ring is activated and’
7227: f3                           .dd1    “s”
7228: 68 69 6e 65+                 .str    ‘hines light everywhere!’
723f: d4                           .dd1    “T”
7240: 68 65 20 73+                 .str    ‘he staff begins to quake!’
7259: d4                           .dd1    “T”
725a: 68 65 20 63+                 .str    ‘he calculator vanishes.’
7271: ce                           .dd1    “N”
7272: 45 56 45 52+                 .str    ‘EVER, EVER raid a monster's lair.’
7293: cf                           .dd1    “O”
7294: 4b 2e 2e 2e                  .str    ‘K...’
7298: e8                           .dd1    “h”
7299: 61 73 20 76+                 .str    ‘as vanished.’
72a5: d4                           .dd1    “T”
72a6: 68 65 20 62+                 .str    ‘he body has vanished!’
72bb: c7                           .dd1    “G”
72bc: 4c 49 54 43+                 .str    ‘LITCH!’
72c2: cf                           .dd1    “O”
72c3: 4b 2e 2e 2e+                 .str    ‘K...it is clean.’
72d3: c3                           .dd1    “C”
72d4: 68 65 63 6b+                 .str    ‘heck your inventory, DOLT!’
72ee: d3                           .dd1    “S”
72ef: 50 4c 41 54+                 .str    ‘PLAT!’
72f4: d9                           .dd1    “Y”
72f5: 6f 75 20 65+                 .str    ‘ou eat the’
72ff: e1                           .dd1    “a”
7300: 6e 64 20 79+                 .str    ‘nd you get heartburn!’
7315: c1                           .dd1    “A”
7316: 20 64 65 61+                 .str    ‘ deafening roar envelopes’
732f: f9                           .dd1    “y”               ;$80
7330: 6f 75 2e 20+                 .str    ‘ou. Your ears are ringing!’
734a: c6                           .dd1    “F”
734b: 4f 4f 44 20+                 .str    ‘OOD FIGHT!! FOOD FIGHT!!’
7363: d4                           .dd1    “T”
7364: 68 65 20 68+                 .str    ‘he hallway is too crowded.’
737e: c1                           .dd1    “A”
737f: 20 68 69 67+                 .str    ‘ high shrill note comes’
7396: e6                           .dd1    “f”
7397: 72 6f 6d 20+                 .str    ‘rom the flute!’
73a5: d4                           .dd1    “T”
73a6: 68 65 20 63+                 .str    ‘he calculator displays’
73bc: d9                           .dd1    “Y”
73bd: 6f 75 20 68+                 .str    ‘ou have been teleported!’
73d5: d7                           .dd1    “W”
73d6: 69 74 68 20+                 .str    ‘ith who? The monster?’
73eb: d9                           .dd1    “Y”
73ec: 6f 75 20 68+                 .str    ‘ou have no fire.’
73fc: d7                           .dd1    “W”
73fd: 69 74 68 20+                 .str    ‘ith what? Air?’
740b: c9                           .dd1    “I”
740c: 74 27 73 20+                 .str    ‘t's awfully dark.’
741d: cc                           .dd1    “L”
741e: 6f 6f 6b 20+                 .str    ‘ook at your monitor.’
7432: c9                           .dd1    “I”
7433: 74 20 6c 6f+                 .str    ‘t looks very dangerous!’
744a: c9                           .dd1    “I”
744b: 27 6d 20 73+                 .str    ‘'m sorry, but I can't ’
7461: d9                           .dd1    “Y”
7462: 6f 75 20 61+                 .str    ‘ou are confusing me.’
7476: d7                           .dd1    “W”
7477: 68 61 74 20+                 .str    ‘hat in tarnation is a ’
748d: c9                           .dd1    “I”               ;$90
748e: 20 64 6f 6e+                 .str    ‘ don't see that here.’
74a3: cf                           .dd1    “O”
74a4: 4b 2e 2e 2e+                 .str    ‘K...if you really want to,’
74be: c2                           .dd1    “B”
74bf: 75 74 20 79+                 .str    ‘ut you have no key.’
74d2: c4                           .dd1    “D”
74d3: 6f 20 79 6f+                 .str    ‘o you wish to save the game (Y or N)?’
74f8: c4                           .dd1    “D”
74f9: 6f 20 79 6f+                 .str    ‘o you wish to continue a game (Y or N)?’
7520: d0                           .dd1    “P”
7521: 6c 65 61 73+                 .str    ‘lease prepare your cassette.’
753d: d7                           .dd1    “W”
753e: 68 65 6e 20+                 .str    ‘hen ready, press any key.’
7557: e1                           .dd1    “a”
7558: 6e 64 20 69+                 .str    ‘nd it vanishes!’
7567: d9                           .dd1    “Y”
7568: 6f 75 20 77+                 .str    ‘ou will do no such thing!’
7581: d9                           .dd1    “Y”
7582: 6f 75 20 61+                 .str    ‘ou are carrying the limit.’
759c: c9                           .dd1    “I”
759d: 74 20 69 73+                 .str    ‘t is currently impossible.’
75b7: d4                           .dd1    “T”
75b8: 68 65 20 62+                 .str    ‘he bat drains you of your vital fluids!’
75df: c1                           .dd1    “A”
75e0: 72 65 20 79+                 .str    ‘re you sure you want to quit (Y or N)?’
7606: d4                           .dd1    “T”
7607: 72 79 20 65+                 .str    ‘ry examining things.’
761b: d4                           .dd1    “T”
761c: 79 70 65 20+                 .str    ‘ype instructions.’
762d: c9                           .dd1    “I”
762e: 6e 76 65 72+                 .str    ‘nvert and telephone.’
7642: c4                           .dd1    “D”               ;$a0
7643: 6f 6e 27 74+                 .str    ‘on't make unnecessary turns.’
765f: d9                           .dd1    “Y”
7660: 6f 75 20 68+                 .str    ‘ou have turned into a pillar of salt!’
7685: c4                           .dd1    “D”
7686: 6f 6e 27 74+                 .str    ‘on't say I didn't warn you!’
76a1: d4                           .dd1    “T”
76a2: 68 65 20 65+                 .str    ‘he elevator is moving!’
76b8: d9                           .dd1    “Y”
76b9: 6f 75 20 61+                 .str    ‘ou are deposited at the next level.’
76dc: d9                           .dd1    “Y”
76dd: 6f 75 72 20+                 .str    ‘our head smashes into the ceiling!’
76ff: d9                           .dd1    “Y”
7700: 6f 75 20 66+                 .str    ‘ou fall on the snake!’
7715: cf                           .dd1    “O”               ;$a7
7716: 68 20 6e 6f+                 .str    ‘h no! A pit!’
7722: ff                           .dd1    $ff               ;end of string table
                   ; 
7723: 46 45 d2 85+                 .junk   156
77bf: 60 20 20 20+ instructions    .str    ‘`           Deathmaze 5000                Location is constant’
                                    +      ‘ly displayed via   3-D graphics. To move forward one step, pre’
                                    +      ‘ss Z. To turn to the left or right,  press the left or right a’
                                    +      ‘rrow. To turn  around, press X. Only Z actually changesyour po’
                                    +      ‘sition. Additionally, words such as CHARGE may be helpful in m’
                                    +      ‘ovement.    At any time, one and two word commands may be ente’
                                    +      ‘red. Some useful commands areOPEN BOX, GET BOX, DROP and HELP.’
                                    +      ‘ Many  more exist. To manipulate an object, youmust be on top ’
                                    +      ‘of it, or be carrying it. To save a game in progress, enter SA’
                                    +      ‘VE.This is encouraged. Deathmaze is huge.  It will take some t’
                                    +      ‘ime to escape.        The five levels of Deathmaze are con-  n’
                                    +      ‘ected by elevators, pits, and science. Connections are not alw’
                                    +      ‘ays obvious.                  Good Luck!                      ’
                                    +      ‘                                   Copyright 1980 by Med Syste’
                                    +      ‘ms Software  All rights reserved.                  ’
7b56: a0                           .dd1    $a0
7b57: 80 52 54 d3+                 .align  $0100 (169 bytes)
7c00: 53 61 76 65+ msg_save_dort   .str    ‘Save to DISK or TAPE (T or D)?’
7c1e: 80                           .dd1    $80
7c1f: c7           msg_load_dort   .dd1    “G”
7c20: 65 74 20 66+                 .str    ‘et from DISK or TAPE (T or D)?’
7c3e: 80                           .dd1    $80

                   ; 
                   ; Loads a saved game from disk or tape.
                   ; 
                   ; On failure, does not return (jumps back to Start).
                   ; 
7c3f: 20 55 08     LoadDiskOrTape  jsr     ClearScreen       ;clear hi-res screen
7c42: a2 00                        ldx     #$00              ;set text position to upper left
7c44: 86 06                        stx     char_horiz
7c46: 86 07                        stx     char_vert
7c48: a2 1f                        ldx     #<msg_load_dort   ;get pointer to disk-or-tape string
7c4a: 86 0c                        stx     string_ptr
7c4c: a2 7c                        ldx     #>msg_load_dort
7c4e: 86 0d                        stx     string_ptr+1
7c50: 20 e5 08                     jsr     DrawMsg           ;"get from disk or tape (T or D)?"
7c53: 20 94 7c                     jsr     GetKeyTD          ;get answer
7c56: c9 44                        cmp     #‘D’
7c58: d0 03                        bne     :LoadTape         ;go do tape
7c5a: 4c 0c 7d                     jmp     LoadFromDisk      ;go do disk

7c5d: 20 55 08     :LoadTape       jsr     ClearScreen
7c60: a9 95                        lda     #$95              ;"please prepare your cassette"
7c62: 20 92 08                     jsr     DrawMsgN_Row22
7c65: 60                           rts

                   ; 
                   ; Saves a game to disk or tape.
                   ; 
7c66: 20 55 08     SaveDiskOrTape  jsr     ClearScreen
7c69: a2 00                        ldx     #$00
7c6b: 86 06                        stx     char_horiz        ;top left corner
7c6d: 86 07                        stx     char_vert
7c6f: a2 00                        ldx     #<msg_save_dort   ;get pointer to disk-or-tape string
7c71: 86 0c                        stx     string_ptr
7c73: a2 7c                        ldx     #>msg_save_dort
7c75: 86 0d                        stx     string_ptr+1
7c77: 20 e5 08                     jsr     DrawMsg           ;"save to disk or tape (T or D)?"
7c7a: 20 94 7c                     jsr     GetKeyTD          ;get answer
7c7d: c9 54                        cmp     #‘T’
7c7f: f0 03                        beq     :RedrawSaveTape   ;go do tape
7c81: 4c ef 7c                     jmp     SaveToDisk        ;go do disk

                   ]func_cmd       .var    $0f    {addr/1}

7c84: 20 55 08     :RedrawSaveTape jsr     ClearScreen
7c87: 20 15 10                     jsr     DrawMaze          ;draw maze
7c8a: a2 07                        ldx     #FN_DRAW_INV
7c8c: 86 0f                        stx     ]func_cmd
7c8e: 20 34 1a                     jsr     ObjMgmtFunc       ;draw inventory
7c91: 4c bc 31                     jmp     SaveToTape        ;do save to tape

                   ; 
                   ; Gets the next keystroke, looping until we see 'T' or 'D'.
                   ; 
7c94: 2c 10 c0     GetKeyTD        bit     KBDSTRB
7c97: 20 43 12     :Loop           jsr     DrawBlinkingApple
7c9a: 2c 00 c0                     bit     KBD
7c9d: 10 f8                        bpl     :Loop
7c9f: ad 00 c0                     lda     KBD
7ca2: 29 7f                        and     #%01111111        ;strip high bit
7ca4: c9 54                        cmp     #‘T’              ;was it a 'T'?
7ca6: f0 04                        beq     :GotTorD          ;yes, bail
7ca8: c9 44                        cmp     #‘D’              ;was it a 'D'?
7caa: d0 e8                        bne     GetKeyTD          ;no, try again
7cac: 48           :GotTorD        pha                       ;save value
7cad: 20 6e 12                     jsr     DrawSpace         ;erase cursor
7cb0: 68                           pla                       ;restore value
7cb1: 60                           rts

                   ; 
                   ; DOS 3.3 RWTS parameter block.
                   ; 
7cb2: 00                           .dd1    $00               ;looks like a DCT
7cb3: 01                           .dd1    $01
7cb4: ef d8                        .dd2    $d8ef
7cb6: 01           rwts_iob        .dd1    $01               ;table type (must be $01)
7cb7: 60                           .dd1    $60               ;slot x16
7cb8: 01                           .dd1    $01               ;drive (1/2)
7cb9: 00                           .dd1    $00               ;vol num expected (0=any)
7cba: 02                           .dd1    $02               ;track #
7cbb: 0f                           .dd1    $0f               ;sector #
7cbc: 00 3f                        .dd2    Setup             ;DCT address (incorrect address, should be $7cb2)
7cbe: 93 61                        .dd2    plyr_facing       ;buffer
7cc0: 00                           .dd1    $00
7cc1: 00                           .dd1    $00               ;partial sector byte count
7cc2: 01           rwts_cmd        .dd1    $01               ;cmd: $01=read, $02=write
7cc3: 00           rwts_ret        .dd1    $00               ;error code: $00=no error
7cc4: 00                           .dd1    $00               ;last access vol
7cc5: 60                           .dd1    $60               ;last access slot
7cc6: 01                           .dd1    $01               ;last access drive
                   ; 
7cc7: d0           msg_place_disk  .dd1    “P”
7cc8: 6c 61 63 65+                 .str    ‘lace data diskette in DRIVE 1, SLOT 6.’
7cee: 80                           .dd1    $80

                   • Clear variables

7cef: a2 02        SaveToDisk      ldx     #$02              ;WRITE
7cf1: 8e c2 7c                     stx     rwts_cmd
7cf4: 20 4f 7d                     jsr     DoDiskIO          ;write the sector
7cf7: 90 06                        bcc     DrawAndReturn     ;no error, branch to run game
7cf9: 20 74 7d                     jsr     ConvertRWTSErr    ;failed, convert code to message
7cfc: 4c 23 7e                     jmp     HandleWriteErr    ;report and handle the error

                   ]func_cmd       .var    $0f    {addr/1}

7cff: 20 55 08     DrawAndReturn   jsr     ClearScreen
7d02: 20 15 10                     jsr     DrawMaze          ;draw maze
7d05: a2 07                        ldx     #FN_DRAW_INV
7d07: 86 0f                        stx     ]func_cmd
7d09: 4c 34 1a                     jmp     ObjMgmtFunc       ;draw inventory and return

7d0c: a2 01        LoadFromDisk    ldx     #$01              ;READ
7d0e: 8e c2 7c                     stx     rwts_cmd
7d11: 20 4f 7d                     jsr     DoDiskIO          ;read the sector
7d14: 90 06                        bcc     VerifySave        ;no error, branch to check magic value
7d16: 20 74 7d                     jsr     ConvertRWTSErr    ;failed, convert code to message
7d19: 4c 1d 7e                     jmp     HandleReadErr     ;report and handle the error

                   ; 
                   ; Checks to see if the saved game data has the word "DEATH".
                   ; 
                   ; On success or failure, the caller's return address is popped off before
                   ; returning.  (The I/O failure code pops the return address before returning
                   ; after a "load" failure.)
                   ; 
7d1c: a0 00        VerifySave      ldy     #$00
7d1e: b9 00 62                     lda     save_magic,y
7d21: c9 44                        cmp     #‘D’
7d23: d0 25                        bne     :BadMagic
7d25: c8                           iny
7d26: b9 00 62                     lda     save_magic,y      ;(why not "lda save_magic+1"?)
7d29: c9 45                        cmp     #‘E’
7d2b: d0 1d                        bne     :BadMagic
7d2d: c8                           iny
7d2e: b9 00 62                     lda     save_magic,y
7d31: c9 41                        cmp     #‘A’
7d33: d0 15                        bne     :BadMagic
7d35: c8                           iny
7d36: b9 00 62                     lda     save_magic,y
7d39: c9 54                        cmp     #‘T’
7d3b: d0 0d                        bne     :BadMagic
7d3d: c8                           iny
7d3e: b9 00 62                     lda     save_magic,y
7d41: c9 48                        cmp     #‘H’
7d43: d0 05                        bne     :BadMagic
7d45: 68                           pla                       ;pop return address
7d46: 68                           pla
7d47: 4c 4a 08                     jmp     GetStarted        ;start the game

7d4a: a9 05        :BadMagic       lda     #$05
7d4c: 4c 1d 7e                     jmp     HandleReadErr

                   ; 
                   ; Prompts the user to insert a disk, then invokes RWTS to read or write.
                   ; 
7d4f: a9 0a        DoDiskIO        lda     #$0a              ;linefeed
7d51: 20 92 11                     jsr     PrintSpecialChar
7d54: a2 c7                        ldx     #<msg_place_disk  ;get pointer to message string
7d56: 86 0c                        stx     string_ptr        ;"place data disk..."
7d58: a2 7c                        ldx     #>msg_place_disk
7d5a: 86 0d                        stx     string_ptr+1
7d5c: 20 e5 08                     jsr     DrawMsg
7d5f: a9 0a                        lda     #$0a              ;linefeed
7d61: 20 92 11                     jsr     PrintSpecialChar
7d64: a9 96                        lda     #$96              ;"when ready, press any key"
7d66: 20 e2 08                     jsr     DrawMsgN
7d69: 20 e9 0f                     jsr     WaitKeyCursor
7d6c: a9 7c                        lda     #>rwts_iob
7d6e: a0 b6                        ldy     #<rwts_iob
7d70: 20 d9 03                     jsr     DOS_RWTS          ;read or write sector
7d73: 60                           rts

                   ; 
                   ; Converts an RWTS error code to a message index.
                   ; 
                   ; On exit:
                   ;   A-reg: error message index (1-4)
                   ; 
7d74: ad c3 7c     ConvertRWTSErr  lda     rwts_ret          ;get RWTS error code
7d77: c9 10                        cmp     #$10              ;write protect error?
7d79: d0 03                        bne     :Not10            ;no, branch
7d7b: a9 01                        lda     #$01
7d7d: 60                           rts

7d7e: c9 20        :Not10          cmp     #$20              ;volume mismatch error?
7d80: d0 03                        bne     :Not20            ;no, branch
7d82: a9 02                        lda     #$02
7d84: 60                           rts

7d85: c9 40        :Not20          cmp     #$40              ;drive error?
7d87: d0 03                        bne     :Not40            ;no, branch
7d89: a9 03                        lda     #$03
7d8b: 60                           rts

7d8c: a9 04        :Not40          lda     #$04              ;generic read error
7d8e: 60                           rts

                   ; 
                   ; I/O error messages.
                   ; 
7d8f: 44 49 53 4b+ msg_io_err      .str    ‘DISKETTE WRITE PROTECTED!’ ;$01, +$00
7da8: 80                           .dd1    $80
7da9: 56 4f 4c 55+                 .str    ‘VOLUME MISMATCH!’ ;$02, +$1a
7db9: 80                           .dd1    $80
7dba: 44 52 49 56+                 .str    ‘DRIVE ERROR! CAUSE UNKNOWN!’ ;$03, +$2b
7dd5: 80                           .dd1    $80
7dd6: 52 45 41 44+                 .str    ‘READ ERROR! CHECK YOUR DISKETTE!’ ;$04, +$47
7df6: 80                           .dd1    $80
7df7: 4e 4f 54 20+                 .str    ‘NOT A DEATHMAZE FILE! INPUT REJECTED!’ ;$05, +$68
7e1c: 80                           .dd1    $80

                   ; 
                   ; Handles an I/O error.
                   ; 
                   ; We start by converting the IO error code (1-5) to a pointer into the string
                   ; table.  (For some reason this is done with direct offsets, rather than walking
                   ; through the strings as is done elsewhere.)
                   ; 
                   ; When we finish, we either resume the game (if this was a failed write), or go
                   ; back to the start (if this was a failed read).
                   ; 
                   ; On entry:
                   ;   A-reg: error code (1-5)
                   ; 
                   ]write_flag     .var    $10    {addr/1}
                   ]tmp            .var    $19    {addr/2}

7e1d: a2 00        HandleReadErr   ldx     #$00              ;clear flag
7e1f: 86 10                        stx     ]write_flag
7e21: f0 04                        beq     :Handle1          ;(always)

                   ; Alternate entry point, used when a write operation failed.  (We can continue
                   ; playing after a failed write, but not after a failed read.)
7e23: a2 ff        HandleWriteErr  ldx     #$ff              ;set flag
7e25: 86 10                        stx     ]write_flag
7e27: a8           :Handle1        tay                       ;put error index in Y-reg
7e28: 88                           dey                       ;decrement
7e29: d0 02                        bne     :Not1
7e2b: f0 17                        beq     :ShowError        ;show, with offset $00

7e2d: 88           :Not1           dey
7e2e: d0 04                        bne     :Not2
7e30: a0 1a                        ldy     #$1a
7e32: d0 10                        bne     :ShowError

7e34: 88           :Not2           dey
7e35: d0 04                        bne     :Not3
7e37: a0 2b                        ldy     #$2b
7e39: d0 09                        bne     :ShowError

7e3b: 88           :Not3           dey
7e3c: d0 04                        bne     :Not4
7e3e: a0 47                        ldy     #$47
7e40: d0 02                        bne     :ShowError

7e42: a0 68        :Not4           ldy     #$68              ;offset to "bad save" message
                   ; The message offset is in the Y-reg.  Form pointer by adding to table address.
7e44: 84 19        :ShowError      sty     ]tmp
7e46: a2 00                        ldx     #$00
7e48: 86 1a                        stx     ]tmp+1
7e4a: a2 8f                        ldx     #<msg_io_err
7e4c: 86 0c                        stx     string_ptr
7e4e: a2 7d                        ldx     #>msg_io_err
7e50: 86 0d                        stx     string_ptr+1
7e52: 18                           clc
7e53: a5 19                        lda     ]tmp
7e55: 65 0c                        adc     string_ptr
7e57: 85 0c                        sta     string_ptr
7e59: a5 1a                        lda     ]tmp+1
7e5b: 65 0d                        adc     string_ptr+1
7e5d: 85 0d                        sta     string_ptr+1
                   ; 
7e5f: a9 0a                        lda     #$0a
7e61: 20 92 11                     jsr     PrintSpecialChar  ;print newline
7e64: 20 e5 08                     jsr     DrawMsg           ;draw error string
7e67: 20 e9 0f                     jsr     WaitKeyCursor
7e6a: a5 10                        lda     ]write_flag       ;was this a write operation?
7e6c: f0 03                        beq     :NotWrite         ;no, jump back to start
7e6e: 4c ff 7c                     jmp     DrawAndReturn     ;yes, resume game

7e71: 68           :NotWrite       pla                       ;pop caller's return address
7e72: 68                           pla
7e73: 4c 05 08                     jmp     Start

7e76: ad a5 61 d0+                 .junk   393
Symbol Table
DrawVisWalls	$12a6
font_glyphs	$6294
Start	$0805
HTML generated by 6502bench SourceGen v1.7.5-dev4 on 2021/08/14
Expression style: Merlin
