MODULE MenuViewers; (*JG 26.8.90 / 16.9.93 / NW 10.3.13 / AP 12.12.90 / 20.3.17*)
  IMPORT Input, Raster, Viewers, Oberon;

  TYPE Viewer* = POINTER TO ViewerDesc;
    ViewerDesc* = RECORD (Viewers.ViewerDesc) menuH*: INTEGER END;

  PROCEDURE Draw (V: Viewer; Y, H, col: INTEGER);
  BEGIN
    Raster.ReplConst(col, V.X, Y, 1, H, Raster.replace);
    Raster.ReplConst(col, V.X + V.W - 1, Y, 1, H, Raster.replace);
    Raster.ReplConst(col, V.X + 1, Y, V.W - 2, 1, Raster.replace);
    Raster.ReplConst(col, V.X + 1, Y + H - 1, V.W - 2, 1, Raster.replace)
  END Draw;

  PROCEDURE Restore (V: Viewer);
    VAR Menu, Main: Viewers.Frame;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    Oberon.RemoveMarks(V.X, V.Y, V.W, V.H); Draw(V, V.Y, V.H, Raster.white);
    IF V.H > V.menuH + 1 THEN
      Main.X := V.X + 1; Main.Y := V.Y + 1; Main.W := V.W - 2; Main.H := V.H - V.menuH - 1;
      Menu.X := V.X + 1; Menu.Y := V.Y + V.H - V.menuH; Menu.W := V.W - 2; Menu.H := V.menuH - 1;
      Viewers.Adjust(Menu, Viewers.restore, Menu.Y, Menu.H);
      Viewers.Adjust(Main, Viewers.restore, Main.Y, Main.H)
    ELSE
      Menu.X := V.X + 1; Menu.Y := V.Y + 1; Menu.W := V.W - 2; Menu.H := V.H - 2;
      Viewers.Adjust(Menu, Viewers.restore, Menu.Y, Menu.H)
    END
  END Restore;

  PROCEDURE Modify (V: Viewer; Y, H: INTEGER);
    VAR Menu, Main: Viewers.Frame;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    Oberon.RemoveMarks(V.X, V.Y, V.W, V.H); Draw(V, V.Y, V.H, Raster.black);
    IF H > V.menuH + 1 THEN
      IF Y + H > V.Y + V.H THEN
        Viewers.Adjust(Menu, Viewers.modify, Y + H - V.menuH, V.menuH - 1);
        Viewers.Adjust(Main, Viewers.modify, Y + 1, H - V.menuH - 1)
      ELSE
        Viewers.Adjust(Main, Viewers.modify, Y + 1, H - V.menuH - 1);
        Viewers.Adjust(Menu, Viewers.modify, Y + H - V.menuH, V.menuH - 1)
      END
    ELSIF Y + H > V.Y + V.H THEN
      Viewers.Adjust(Menu, Viewers.modify, Y + 1, H - 2);
      Viewers.Adjust(Main, Viewers.modify, Y + H - V.menuH, 0)
    ELSE
      Viewers.Adjust(Main, Viewers.modify, Y + H - V.menuH, 0);
      Viewers.Adjust(Menu, Viewers.modify, Y + 1, H - 2)
    END ;
    Draw(V, Y, H, Raster.white)
  END Modify;

  PROCEDURE Suspend (V: Viewer);
  BEGIN Viewers.Adjust(V.dsc, Viewers.suspend, V.Y + V.H - V.menuH, V.H - V.menuH - 1);
    Viewers.Adjust(V.dsc.next, Viewers.suspend, V.Y + V.H - 1, V.menuH - 1)
  END Suspend;

  PROCEDURE Move (V: Viewer; X, Y: INTEGER; Keys: SET);
    VAR Y0, H: INTEGER; keysum: SET;
      D: Viewers.Display; v: Viewers.Viewer;
  BEGIN (*Keys # {}*) keysum := Keys; Input.Mouse(Keys, X, Y); Y0 := Y;
    WHILE Keys # {} DO keysum := keysum + Keys;
      Oberon.DrawMouseStar(X, Y); Input.Mouse(Keys, X, Y)
    END ;
    Oberon.FadeMouse;
    IF (Y # Y0) & ~(0 IN keysum) THEN (*~MR*)
      D := Viewers.ThisDisplay(V); v := Viewers.This(D, X, Y);
      IF v = V.next THEN Y0 := V.Y;
        IF Y > v.Y + v.H - v.minH THEN H := v.Y + v.H - Y0; Viewers.Close(v) ELSE H := Y - Y0 END ;
        Viewers.Validate(V, Y0, H); Viewers.Change(V, Y0, H)
      ELSIF v = V THEN Y0 := V.Y;
        IF Y < V.Y + V.minH THEN H := V.minH ELSE H := Y - Y0 END ;
        Viewers.Validate(V, Y0, H); Viewers.Change(V, Y0, H)
      ELSIF V.minH <= v.H THEN
        IF Y > v.Y + v.H - v.minH THEN Y := v.Y + v.H END ;
        IF Y < v.Y + V.minH THEN Y := v.Y + V.minH END ;
        Viewers.Close(V); Viewers.Open(D, V, X, Y); Restore(V)
      END
    END
  END Move;

  PROCEDURE Change (V: Viewer; X, Y: INTEGER; Keys: SET);
    VAR Y0, H: INTEGER;
  BEGIN (*Keys # {}*) Input.Mouse(Keys, X, Y);
    WHILE Keys # {} DO Y0 := Y;
      Oberon.DrawMouseArrow(X, Y); Input.Mouse(Keys, X, Y);
      IF (Y # Y0) & (Keys = {2}) THEN (*ML*)
        IF Y > Y0 THEN H := V.H + Y - Y0; Y0 := V.Y
        ELSIF Y0 - Y > V.H - V.minH THEN Y0 := V.Y + V.H - V.minH - Y0 + Y; H := V.minH
        ELSE H := V.H - Y0 + Y; Y0 := V.Y
        END ;
        Viewers.Validate(V, Y0, H); Viewers.Change(V, Y0, H)
      END
    END
  END Change;

  PROCEDURE Grow (V: Viewers.Viewer);
    VAR D: Viewers.Display; Y, H: INTEGER;
  BEGIN D := Viewers.ThisDisplay(V); Y := 0; H := D.H;
    Viewers.Validate(V, Y, H); Viewers.Change(V, Y, H)
  END Grow;

  PROCEDURE Copy (V: Viewer; VAR V1: Viewer);
    VAR Menu, Main: Viewers.Frame; M: Viewers.CopyMsg;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    NEW(V1); V1^ := V^; V1.state := 0; V1.dsc := NIL;
    M.F := NIL; Menu.handle(Menu, M); Viewers.Install(V1, M.F);
    M.F := NIL; Main.handle(Main, M); Viewers.Install(V1, M.F)
  END Copy;

  PROCEDURE Handle* (V: Viewers.Frame; VAR M: Viewers.FrameMsg);
    VAR X, Y: INTEGER;
      Menu, Main: Viewers.Frame; V1: Viewer;
  BEGIN Menu := V.dsc; Main := V.dsc.next;
    CASE V OF Viewer:
      CASE M OF
      Viewers.ViewerMsg:
        IF M.id = Viewers.restore THEN Restore(V(Viewer))
        ELSIF M.id = Viewers.suspend THEN Suspend(V(Viewer))
        ELSIF M.id = Viewers.modify THEN Modify(V(Viewer), M.Y, M.H)
        END |
      Viewers.InputMsg:
        IF M.id = Viewers.track THEN X := M.X; Y := M.Y;
          IF Y < V.Y + 1 THEN Oberon.DrawMouseArrow(X, Y)
          ELSIF Y < V.Y + V.H - V(Viewer).menuH THEN Main.handle(Main, M)
          ELSIF Y < V.Y + V.H - V(Viewer).menuH + 2 THEN Menu.handle(Menu, M)
          ELSIF Y < V.Y + V.H - 1 THEN
            IF X < V.X + V.W - 30 THEN
              IF 2 IN M.keys THEN Change(V(Viewer), X, Y, M.keys) ELSE Menu.handle(Menu, M) END
            ELSIF 1 IN M.keys THEN Menu.handle(Menu, M)
            ELSIF 2 IN M.keys THEN Move(V(Viewer), X, Y, M.keys)
            ELSIF M.keys = {0} THEN Grow(V)
            ELSE Oberon.DrawMouseStar(X, Y)
            END
          ELSE Oberon.DrawMouseArrow(X, Y)
          END
        ELSIF M.id = Viewers.consume THEN Menu.handle(Menu, M); Main.handle(Main, M)
        END |
      Viewers.ControlMsg:
        IF M.id = Viewers.mark THEN
          X := M.X; Y := M.Y; Oberon.DrawMouseArrow(X, Y); Oberon.DrawPointerStar(X, Y)
        ELSIF M.id = Viewers.defocus THEN Menu.handle(Menu, M); Main.handle(Main, M)
        ELSIF M.id = Viewers.neutralize THEN Menu.handle(Menu, M); Main.handle(Main, M)
        END |
      Viewers.CopyMsg: Copy(V(Viewer), V1); M.F := V1 |
      Viewers.FrameMsg: Menu.handle(Menu, M); Main.handle(Main, M)
      END
    END
  END Handle;

  PROCEDURE New* (Menu, Main: Viewers.Frame; menuH, X, Y: INTEGER): Viewer;
    VAR V: Viewer;
  BEGIN NEW(V); V.handle := Handle; V.menuH := menuH; V.minH := menuH + 2;
    Viewers.Install(V, Menu); (*V.dsc*) Viewers.Install(V, Main); (*V.dsc.next*)
    Viewers.Open(Viewers.CurDisplay, V, X, Y); Restore(V); RETURN V
  END New;

END MenuViewers.
