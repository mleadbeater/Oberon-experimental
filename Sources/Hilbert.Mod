MODULE Hilbert;  (*NW 8.1.13 for RISC / AP 5.1.17*)
  IMPORT Raster, Viewers, Texts, Oberon, MenuViewers, TextFrames;

  CONST Menu = "System.Close System.Copy System.Grow | System.Expand System.Clone";

  VAR x, y, d: INTEGER;
    A, B, C, D: PROCEDURE (i: INTEGER);

  PROCEDURE E;
  BEGIN Raster.ReplConst(Raster.white, x, y, d, 1, Raster.paint); INC(x, d)
  END E;

  PROCEDURE N;
  BEGIN Raster.ReplConst(Raster.white, x, y, 1, d, Raster.paint); INC(y, d)
  END N;

  PROCEDURE W;
  BEGIN DEC(x, d); Raster.ReplConst(Raster.white, x, y, d, 1, Raster.paint)
  END W;

  PROCEDURE S;
  BEGIN DEC(y, d); Raster.ReplConst(Raster.white, x, y, 1, d, Raster.paint)
  END S;

  PROCEDURE HA(i: INTEGER);
  BEGIN
    IF i > 0 THEN D(i-1); W; A(i-1); S; A(i-1); E; B(i-1) END
  END HA;

  PROCEDURE HB(i: INTEGER);
  BEGIN
    IF i > 0 THEN C(i-1); N; B(i-1); E; B(i-1); S; A(i-1) END
  END HB;

  PROCEDURE HC(i: INTEGER);
  BEGIN
    IF i > 0 THEN B(i-1); E; C(i-1); N; C(i-1); W; D(i-1) END
  END HC;

  PROCEDURE HD(i: INTEGER);
  BEGIN
    IF i > 0 THEN A(i-1); S; D(i-1); W; D(i-1); N; C(i-1) END
  END HD;

  PROCEDURE DrawHilbert(F: Viewers.Frame);
    VAR k, n, w, x0, y0: INTEGER;
  BEGIN k := 0; d := 8;
    IF F.W < F.H THEN w := F.W ELSE w := F.H END ;
    WHILE d*2 < w DO d := d*2; INC(k) END ;
    Raster.ReplConst(Raster.black, F.X, F.Y, F.W, F.H, Raster.replace);
    x0 := F.W DIV 2; y0 := F.H DIV 2; n := 0;
    WHILE n < k DO
      d := d DIV 2; INC(x0, d DIV 2); INC(y0, d DIV 2);
      x := F.X + x0; y := F.Y + y0; INC(n); HA(n)
    END
  END DrawHilbert;

  PROCEDURE Handler(F: Viewers.Frame; VAR M: Viewers.FrameMsg);
    VAR F0: Viewers.Frame;
  BEGIN
    IF M IS Viewers.InputMsg THEN
      IF M(Viewers.InputMsg).id = Viewers.track THEN
        Oberon.DrawMouseArrow(M(Viewers.InputMsg).X, M(Viewers.InputMsg).Y)
      END
    ELSIF M IS Viewers.ViewerMsg THEN
      IF (M(Viewers.ViewerMsg).id = Viewers.restore) OR (M(Viewers.ViewerMsg).id = Viewers.modify) THEN
        F.Y := M(Viewers.ViewerMsg).Y; F.H := M(Viewers.ViewerMsg).H; DrawHilbert(F)
      END
    ELSIF M IS Viewers.ControlMsg THEN
      IF M(Viewers.ControlMsg).id = Viewers.neutralize THEN Oberon.RemoveMarks(F.X, F.Y, F.W, F.H) END
    ELSIF M IS Viewers.CopyMsg THEN
      NEW(F0); F0^ := F^; M(Viewers.CopyMsg).F := F0
    END
  END Handler;

  PROCEDURE New(): Viewers.Frame;
    VAR F: Viewers.Frame;
  BEGIN NEW(F); F.handle := Handler; RETURN F
  END New;

  PROCEDURE Draw*;
    VAR V: Viewers.Viewer; X, Y: INTEGER;
  BEGIN Oberon.AllocateUserViewer(Oberon.Par.vwr.X, X, Y);
    V := MenuViewers.New(TextFrames.NewMenu("Hilbert", Menu), New(), TextFrames.menuH, X, Y)
  END Draw;
  
BEGIN A := HA; B := HB; C := HC; D := HD
END Hilbert.
