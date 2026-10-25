{ Resize the active PCB's outer board shape to a 2 inch square.
  Target: Altium Designer 26; NOT runtime-tested in Altium.
  Add this file to an Altium Script Project, activate a test PcbDoc,
  and run ResizePCBToTwoInchSquare.

  The existing board outline bounding box's lower-left corner is retained.
  Both dimensions are exactly 2000 mils = 2 inches = 50.8 mm.
  This replaces the OUTER BOARD SHAPE with four straight sides.
  It does not scale/move components, tracks, vias, holes or cutouts, and
  does not update separately drawn mechanical-layer/keepout outlines.
  Intended for a conventional single-region rigid PCB test, not rigid-flex.
  Repour polygons and run DRC after resizing a populated board.
  No automatic save. First run on a copy or a new test PCB.

  API reference:
  https://www.altium.com/documentation/altium-dxp-developer/pcb-api-design-objects-interfaces-reference
}



{ Progress reporting uses Messages panel; does not clear existing messages.
  Source reviewed only; not runtime-tested in Altium 26.
  Panel repaint may be delayed during busy operations. }
Var
    RSZLastStep : String;

Procedure RSZLog(Text : String);
Var
    WS : IWorkspace;
    MM : IMessagesManager;
Begin
    RSZLastStep := Text;
    { Reporting failures must not interrupt an editing transaction. }
    Try
        WS := GetWorkspace;
        If WS = Nil Then Exit;
        MM := WS.DM_MessagesManager;
        If MM = Nil Then Exit;
        MM.BeginUpdate;
        Try
            MM.AddMessage('Script', FormatDateTime('hh:nn:ss', Now) + ' ' + Text,
                          'Resize_PCB_2in_Square.pas', '', '', '', 3, False);
        Finally
            MM.EndUpdate;
        End;
        WS.DM_ShowMessageView;
    Except
        { Continue original operation if logging is unavailable. }
    End;
End;

Procedure RSZDialog(Text : String);
Begin
    RSZLog(Text);
    ShowMessage(Text);
End;

Procedure SquareOutlineVertex(Outline : IPCB_BoardOutline;
                              Index, XCoord, YCoord : Integer);
Var
    Segment : TPolySegment;
Begin
    { Read/modify/write the segment record rather than editing a temporary
      record returned by the indexed property. }
    RSZLog('Setting outline vertex ' + IntToStr(Index) + '');
    Segment := Outline.Segments[Index];
    Segment.Kind := ePolySegmentLine;
    Segment.vx := XCoord;
    Segment.vy := YCoord;
    Segment.cx := 0;
    Segment.cy := 0;
    Segment.Radius := 0;
    Segment.Angle1 := 0;
    Segment.Angle2 := 0;
    Outline.Segments[Index] := Segment;
End;

Procedure ResizePCBToTwoInchSquareImpl;
Var
    Board : IPCB_Board;
    Outline : IPCB_BoardOutline;
    Bounds : TCoordRect;
    LeftX, BottomY, SideLength : Integer;
    ActualWidth, ActualHeight : Integer;
    BoardFileName : String;
Begin
    If PCBServer = Nil Then
    Begin
        RSZLog('STOP: PCBServer unavailable.');
        Exit;
    End;
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        RSZDialog('Open and activate a test PCB document first.');
        Exit;
    End;
    { Check the document actually returned by PCBServer, rather than relying
      on IsLibrary. Never proceed for a library or an unidentified document. }
    BoardFileName := Board.FileName;
    RSZLog('PCBServer current document: ' + BoardFileName);
    If UpperCase(ExtractFileExt(BoardFileName)) <> '.PCBDOC' Then
    Begin
        RSZDialog('PCBServer returned "' + BoardFileName +
            '". Activate a saved test .PcbDoc and run again. No outline changed.');
        Exit;
    End;
    RSZLog('Obtaining board outline');
    Outline := Board.BoardOutline;
    If Outline = Nil Then
    Begin
        RSZDialog('The active PCB has no accessible board outline.');
        Exit;
    End;

    Try
        Outline.Invalidate;
        Outline.Rebuild;
        Outline.Validate;
        RSZLog('Reading outline bounds');
        Bounds := Outline.BoundingRectangle;
        LeftX := Bounds.Left;
        BottomY := Bounds.Bottom;
        SideLength := MilsToCoord(2000);

        RSZLog('Beginning board outline edit');
        PCBServer.PreProcess;
        Try
            PCBServer.SendMessageToRobots(Outline.I_ObjectAddress,
                c_Broadcast, PCBM_BeginModify, c_NoEventData);
            Try
                Outline.PointCount := 4;
                { Counterclockwise; the outline closes the last vertex
                  to the first automatically. }
                SquareOutlineVertex(Outline, 0, LeftX, BottomY);
                SquareOutlineVertex(Outline, 1, LeftX + SideLength, BottomY);
                SquareOutlineVertex(Outline, 2, LeftX + SideLength, BottomY + SideLength);
                SquareOutlineVertex(Outline, 3, LeftX, BottomY + SideLength);
                Outline.Invalidate;
                Outline.Rebuild;
                Outline.Validate;
            Finally
                PCBServer.SendMessageToRobots(Outline.I_ObjectAddress,
                    c_Broadcast, PCBM_EndModify, c_NoEventData);
            End;
        Finally
            PCBServer.PostProcess;
        End;

        Board.ViewManager_FullUpdate;
        Client.SendMessage('PCB:Zoom', 'Action=Redraw', 255, Client.CurrentView);
        RSZLog('Reading outline bounds');
        Bounds := Outline.BoundingRectangle;
        RSZLog('Checking resulting board dimensions');
        ActualWidth := Bounds.Right - Bounds.Left;
        ActualHeight := Bounds.Top - Bounds.Bottom;
        If (ActualWidth = SideLength) And (ActualHeight = SideLength) Then
            RSZDialog('Board outline dimensions verified: 2.000 x 2.000 inches ' +
                '(50.8 x 50.8 mm). Lower-left anchor retained. No file was saved.')
        Else
            RSZDialog('Outline edit completed, but the dimension check did not match. ' +
                'Width: ' + CoordUnitToString(ActualWidth, eImperial) +
                '; height: ' + CoordUnitToString(ActualHeight, eImperial) +
                '. Inspect the board before saving.');
    Except
        RSZLog('ERROR: ' + ExceptionMessage + '; previous step: ' + RSZLastStep);
        RSZDialog('Board resize stopped: ' + ExceptionMessage +
            '. The outline may be partially changed; inspect or undo before saving.');
    End;
End;

Procedure ResizePCBToTwoInchSquare;
Begin
    RSZLog('START: ResizePCBToTwoInchSquare');
    Try
        ResizePCBToTwoInchSquareImpl;
        RSZLog('END: ResizePCBToTwoInchSquare returned. Review prior messages for warnings or errors.');
    Except
        RSZLog('UNHANDLED ERROR: ' + ExceptionMessage + '; previous step: ' + RSZLastStep);
        Raise;
    End;
End;
