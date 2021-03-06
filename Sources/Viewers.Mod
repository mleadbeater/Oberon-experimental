MODULE Viewers; (*JG 14.9.90 / NW 15.9.13 / AP 12.12.90 / 11.2.17*)
  CONST restore* = 0; modify* = 1; suspend* = 2; consume* = 3; track* = 4;
    defocus* = 5; neutralize* = 6; mark* = 7; inf = 65535; DnLength* = 24;

  TYPE Frame* = POINTER TO FrameDesc;
    FrameMsg* = RECORD END;
    Handler* = PROCEDURE (F: Frame; VAR M: FrameMsg);
    FrameDesc* = RECORD next*, dsc*, parent, prev: Frame;
      X*, Y*, W*, H*, minH*: INTEGER;
      handle*: Handler;
      state*: INTEGER (*>1: displayed; 1: filler; 0: closed; -1: track; <-1: suspended*)
    END;

    Viewer* = POINTER TO ViewerDesc;
    ViewerDesc* = RECORD (FrameDesc) END;

    Track = POINTER TO TrackDesc;
    TrackDesc = RECORD (ViewerDesc) under: Frame END;

    Display* = POINTER TO DisplayDesc; (*logical display area*)
    DisplayDesc* = RECORD (ViewerDesc)
      curW*, id*: INTEGER;
      name*: ARRAY DnLength OF CHAR;
      focusViewer*,
      backup: Viewer (*last closed viewer*)
    END;

    ViewerMsg* = RECORD (FrameMsg)
      id*: INTEGER;                    (*restore, modify, suspend*)
      X*, Y*, W*, H*: INTEGER;
      state*: INTEGER
    END;

    InputMsg* = RECORD (FrameMsg)
      id*, X*, Y*: INTEGER;            (*consume, track*)
      keys*: SET;
      ch*: CHAR
    END;

    ControlMsg* = RECORD (FrameMsg)
      id*, X*, Y*: INTEGER             (*defocus, neutralize, mark*)
    END;

    CopyMsg* = RECORD (FrameMsg)
      F*: Frame
    END;

  VAR CurDisplay*, root*: Display;
    nextId: INTEGER;

  PROCEDURE This* (D: Display; X, Y: INTEGER): Viewer;
    VAR T, V: Frame;
  BEGIN
    IF (X < inf) & (Y < D.H) THEN
      T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      V := T.dsc;
      REPEAT V := V.next UNTIL Y < V.Y + V.H
    ELSE V := NIL
    END;
    RETURN V(Viewer)
  END This;

  PROCEDURE ThisViewer* (F: Frame): Viewer;
  BEGIN WHILE (F # NIL) & (F.parent # NIL) & (F.parent.state # -1) (*~track*) DO F := F.parent END ;
    RETURN F(Viewer)
  END ThisViewer;

  PROCEDURE ThisDisplay* (F: Frame): Display;
  BEGIN WHILE (F # NIL) & (F.parent # NIL) (*~display*) DO F := F.parent END ;
    RETURN F(Display)
  END ThisDisplay;

  PROCEDURE SetFocusViewer* (D: Display; V: Viewer);
  BEGIN D.focusViewer := V
  END SetFocusViewer;

  PROCEDURE PassFocus* (V: Viewer);
    VAR M: ControlMsg;
  BEGIN M.id := defocus; CurDisplay.focusViewer.handle(CurDisplay.focusViewer, M);
    SetFocusViewer(ThisDisplay(V), V)
  END PassFocus;

  PROCEDURE Adjust* (F: Frame; id, Y, H: INTEGER);
    VAR M: ViewerMsg;
  BEGIN M.id := id; M.Y := Y; M.H := H; F.handle(F, M); F.Y := Y; F.H := H
  END Adjust;

  PROCEDURE Open* (D: Display; V: Viewer; X, Y: INTEGER);
    VAR T, v: Frame; M: ViewerMsg;
  BEGIN
    IF (V.state = 0) & (X < inf) THEN
      IF Y > D.H THEN Y := D.H END;
      T := D.dsc.next; (*first track*)
      WHILE X >= T.X + T.W DO T := T.next END;
      v := T.dsc.next;
      WHILE Y > v.Y + v.H DO v := v.next END;
      IF Y < v.Y + V.minH THEN Y := v.Y + V.minH END;
      IF (v.next.Y # 0) & (Y > v.Y + v.H - v.minH) THEN
        V.X := T.X; V.W := T.W; V.Y := v.Y; V.H := v.H;
        M.id := suspend; M.state := 0;
        v.handle(v, M); v(Viewer).state := 0;
        V.next := v.next; V.prev := v.prev; v.prev.next := V; v.next.prev := V;
        V.parent := T; V.state := 2
      ELSE V.X := T.X; V.W := T.W; V.Y := v.Y; V.H := Y - v.Y;
        Adjust(v, modify, Y, v.Y + v.H - Y);
        V.next := v; V.prev := v.prev; v.prev.next := V; v.prev := V;
        V.parent := T; V.state := 2
      END
    END
  END Open;

  PROCEDURE Validate* (V: Viewer; VAR Y, H: INTEGER);
    VAR D: Display; v: Frame; s: INTEGER;
  BEGIN
    IF V.state > 1 THEN D := ThisDisplay(V);
      IF H < V.minH THEN H := V.minH END;
      v := V.prev; s := 0;
      WHILE v.state > 1 DO s := s + v.minH; v := v.prev END;
      IF Y < s THEN Y := s END;
      v := V.next; s := 0;
      WHILE v.state > 1 DO s := s + v.minH; v := v.next END;
      IF Y > D.H - s - V.minH THEN Y := D.H - s - V.minH; H := V.minH
      ELSIF Y + H > D.H - s THEN H := D.H - s - Y
      END
    END
  END Validate;

  PROCEDURE Change* (V: Viewer; Y, H: INTEGER);
    CONST none = 0; self = 1; above = 2; below = 3;
    VAR v: Frame; a, b: BOOLEAN; i, y, dY: INTEGER; m: ARRAY 3 OF INTEGER;
  BEGIN (*Y,H validated*)
    IF V.state > 1 THEN
      m[0] := none; m[1] := self; m[2] := none;
      a := Y + H > V.Y + V.H; b := Y + H < V.Y + V.H;
      IF Y < V.Y THEN m[0] := below;
        IF a THEN  m[1] := above; m[2] := self ELSIF b THEN m[2] := above END
      ELSIF Y > V.Y THEN m[2] := below;
        IF a THEN m[0] := above ELSIF b THEN m[0] := self; m[1] := above END
      ELSE
        IF a THEN m[0] := above ELSIF b THEN m[2] := above ELSE m[1] := none END
      END;
      FOR i := 0 TO 2 DO
        IF m[i] = self THEN Adjust(V, modify, Y, H)
        ELSIF m[i] = above THEN v := V.next;
          IF a THEN dY := Y + H - V.Y - V.H;
            WHILE (v.state > 1) & (dY > v.H - v.minH) DO dY := dY - v.H + v.minH; v := v.next END ;
            y := v.Y;
            IF v.state > 1 THEN Adjust(v, modify, y + dY, v.H - dY); v := v.prev; y := y + dY - v.minH
            ELSE v.Y := v.Y + dY; v.H := v.H - dY; v := v.prev; y := y + dY - v.minH
            END ;
            WHILE v # V DO Adjust(v, modify, y, v.minH); v := v.prev; y := y - v.minH END
          ELSE Adjust(v, modify, Y + H, v.Y + v.H - Y - H)
          END
        ELSIF m[i] = below THEN v := V.prev;
          IF v.state > 1 THEN
            IF Y > V.Y THEN Adjust(v, modify, v.Y, Y - v.Y)
            ELSE dY := V.Y - Y;
              WHILE (v.state > 1) & (dY > v.H - v.minH) DO dY := dY - v.H + v.minH; v := v.prev END ;
              IF v.state > 1 THEN Adjust(v, modify, v.Y, v.H - dY); y := v.Y + v.H ELSE y := v.Y END ;
              v := v.next;
              WHILE v # V DO Adjust(v, modify, y, v.minH); y := y + v.H; v := v.next END
            END
          END
        END
      END
    END
  END Change;

  PROCEDURE RestoreTrack (S: Frame);
    VAR T, t, v: Frame; M: ViewerMsg;
  BEGIN t := S.next;
    WHILE t.next # S DO t := t.next END;
    T := S(Track).under;
    WHILE T.next # NIL DO T := T.next END;
    t.next := S(Track).under; T.next := S.next; M.id := restore;
    REPEAT t := t.next; v := t.dsc;
      REPEAT v := v.next; v.handle(v, M); v(Viewer).state := - v(Viewer).state
      UNTIL v = t.dsc
    UNTIL t = T
  END RestoreTrack;

  PROCEDURE Close* (V: Viewer);
    VAR D: Display; T, U: Frame; M: ViewerMsg;
  BEGIN
    IF V.state > 1 THEN D := ThisDisplay(V);
      U := V.next; T := D.dsc;
      REPEAT T := T.next UNTIL V.X < T.X + T.W;
      IF (T(Track).under = NIL) OR (U.next # V) THEN
        M.id := suspend; M.state := 0;
        V.handle(V, M); V.state := 0; D.backup := V;
        Adjust(U, modify, V.Y, V.H + U.H);
        V.prev.next := V.next; V.next.prev := V.prev
      ELSE (*close track*)
        M.id := suspend; M.state := 0;
        V.handle(V, M); V.state := 0; D.backup := V;
        U.handle(U, M); U(Viewer).state := 0;
        RestoreTrack(T)
      END
    END
  END Close;

  PROCEDURE Recall* (D: Display; VAR V: Viewer); (*last closed viewer*)
  BEGIN V := D.backup
  END Recall;

  PROCEDURE Flush* (D: Display); (*last closed viewer*)
  BEGIN D.backup := NIL
  END Flush;

  PROCEDURE Locate* (D: Display; X, H: INTEGER; VAR fil, bot, alt, max: Frame);
    VAR T, V: Frame;
  BEGIN
    IF X < inf THEN
      T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      fil := T.dsc; bot := fil.next;
      IF bot.next # fil THEN
        alt := bot.next; V := alt.next;
        WHILE (V # fil) & (alt.H < H) DO
          IF V.H > alt.H THEN alt := V END;
          V := V.next
        END
      ELSE alt := bot
      END;
      max := T.dsc; V := max.next;
      WHILE V # fil DO
        IF V.H > max.H THEN max := V END;
        V := V.next
      END
    END
  END Locate;

  PROCEDURE Install* (V: Viewer; F: Frame); (*install frame F in viewer V*)
    VAR v: Frame;
  BEGIN F.parent := V; F.next := NIL;
    IF V.dsc = NIL THEN V.dsc := F
    ELSE v := V.dsc;
      WHILE v.next # NIL DO v := v.next END;
      v.next := F
    END
  END Install;

  PROCEDURE InitFiller (X, Y, W, H, minH: INTEGER; Filler: Viewer); (*except parent & dsc*)
  BEGIN Filler.X := X; Filler.Y := Y; Filler.W := W; Filler.H := H; Filler.minH := minH;
    Filler.state := 1; Filler.next := Filler; Filler.prev := Filler
  END InitFiller;

  PROCEDURE InitTrack* (D: Display; W, H: INTEGER; Filler: Viewer);
    VAR T, fillerTrack: Track; fillerViewer: Viewer;
  BEGIN InitFiller(D.curW, 0, W, H, 0, Filler); Filler.dsc := NIL;
    NEW(T); T.dsc := Filler; Filler.parent := T; T.parent := D; T.under := NIL;
    T.X := D.curW; T.Y := 0; T.W := W; T.H := H; T.minH := 0; T.state := -1; (*track*)
    fillerTrack := D.dsc(Track); fillerViewer := fillerTrack.dsc(Viewer);
    fillerViewer.X := D.curW + W; fillerViewer.W := inf - fillerViewer.X;
    fillerTrack.X := fillerViewer.X; fillerTrack.W := fillerViewer.W;
    T.next := fillerTrack; T.prev := fillerTrack.prev; T.prev.next := T; fillerTrack.prev := T;
    D.curW := D.curW + W
  END InitTrack;

  PROCEDURE OpenTrack* (D: Display; X, W: INTEGER; Filler: Viewer);
    VAR newT: Track; S, T, t, v: Frame; M: ViewerMsg; v0: Viewer;
  BEGIN
    IF (X < inf) & (Filler.state = 0) THEN
      T := D.dsc.next;
      WHILE X >= T.X + T.W DO T := T.next END;
      S := T.prev;
      WHILE X + W > T.X + T.W DO T := T.next END;
      M.id := suspend; t := S;
      REPEAT t := t.next; v := t.dsc;
        REPEAT v := v.next; M.state := -v(Viewer).state; v.handle(v, M); v(Viewer).state := M.state
        UNTIL v = t.dsc
      UNTIL t = T;
      InitFiller(S.next.X, 0, T.X + T.W - S.next.X, D.H, 0, Filler); Filler.dsc := NIL;
      NEW(newT); newT.dsc := Filler; Filler.parent := newT; newT.parent := D;
      newT.X := Filler.X; newT.Y := 0; newT.W := Filler.W; newT.H := D.H; newT.minH := 0;
      newT.state := -1; (*track*) newT.under := S.next; 
      newT.next := T.next; newT.prev := S; S.next := newT; T.next.prev := newT; T.next := NIL
    END
  END OpenTrack;

  PROCEDURE CloseTrack* (D: Display; X: INTEGER);
    VAR T, V: Frame; M: ViewerMsg;
  BEGIN
    IF X < inf THEN
      T := D.dsc;
      REPEAT T := T.next UNTIL X < T.X + T.W;
      IF T(Track).under # NIL THEN
        M.id := suspend; M.state := 0; V := T.dsc;
        REPEAT V := V.next; V.handle(V, M); V(Viewer).state := 0 UNTIL V = T.dsc;
        RestoreTrack(T)
      END
    END
  END CloseTrack;

  PROCEDURE Broadcast* (VAR M: FrameMsg); (*to current display*)
    VAR T, V: Frame;
  BEGIN
    IF CurDisplay # NIL THEN
      T := CurDisplay.dsc.next;
      WHILE T # CurDisplay.dsc DO
        V := T.dsc;
        REPEAT V := V.next; V.handle(V, M) UNTIL V = T.dsc;
        T := T.next
      END
    END
  END Broadcast;

  PROCEDURE SetDisplayName* (D: Display; name: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < DnLength) & (name[i] > 0X) DO D.name[i] := name[i]; INC(i) END;
    IF i < DnLength THEN D.name[i] := 0X END
  END SetDisplayName;

  PROCEDURE InitDisplay* (D: Display; W, H: INTEGER; name: ARRAY OF CHAR);
    VAR fillerTrack: Track; fillerViewer: Viewer;
  BEGIN D.id := nextId;
    SetDisplayName(D, name); D.curW := 0; D.focusViewer := NIL; D.backup := NIL;
    D.X := 0; D.Y := 0; D.W := W; D.H := H; D.minH := 1; D.state := 0; D.parent := NIL;
    NEW(fillerTrack); InitFiller(0, 0, inf, H, 0, fillerTrack); D.dsc := fillerTrack;
    NEW(fillerViewer); InitFiller(0, 0, inf, H, 0, fillerViewer); fillerTrack.dsc := fillerViewer;
    fillerTrack.parent := D; fillerViewer.parent := fillerTrack; fillerViewer.dsc := NIL;
    IF root = NIL THEN root := D ELSE D.prev := root.prev; D.prev.next := D END;
    root.prev := D; D.next := NIL; nextId := nextId + 1
  END InitDisplay;

  PROCEDURE SetDisplay* (D: Display);
    VAR M: ViewerMsg;
  BEGIN
    IF CurDisplay # NIL THEN M.id := suspend; Broadcast(M); CurDisplay.state := -CurDisplay.state END;
    CurDisplay := D(Display);
    IF CurDisplay.state = 0 THEN CurDisplay.state := 2 ELSE CurDisplay.state := -CurDisplay.state END;
    M.id := restore; Broadcast(M)
  END SetDisplay;

  PROCEDURE GetDisplay* (id: INTEGER): Display;
    VAR S: Frame;
  BEGIN S := root;
    WHILE (S # NIL) & (id # S(Display).id) DO S := S.next END ;
    RETURN S(Display)
  END GetDisplay;

  PROCEDURE CloseDisplay* (id, hint: INTEGER); (*except last display*)
    VAR D: Display;
  BEGIN D := GetDisplay(id);
    IF (D # NIL) & (root # NIL) & (root.next # NIL) THEN D.state := 0;
      IF D = root (*first*) THEN D.next.prev := D.prev; root := D.next(Display)
      ELSIF D = root.prev (*last*) THEN root.prev := D.prev; D.prev.next := NIL
      ELSE D.next.prev := D.prev; D.prev.next := D.next
      END;
      IF D.id = CurDisplay.id THEN
        IF hint = CurDisplay.id THEN D := root
        ELSE D := GetDisplay(hint);
          IF (D = NIL) OR (D.state = 0) OR (D.state = 1) THEN D := root END
        END;
        SetDisplay(D)
      END
    END
  END CloseDisplay;

BEGIN root := NIL; CurDisplay := NIL; nextId := 0
END Viewers.
