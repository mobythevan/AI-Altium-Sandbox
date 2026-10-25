{ Arrange the existing LED circuit on a 2 x 2 inch rectangular test PCB.
  Run ArrangeLEDComponents after transferring the wired schematic to PCB.
  Expected designators: R1 base resistor, R2 LED resistor, Q1 NPN, D1 LED.
  These constants may be changed to match an annotated schematic.
  Footprints AND pad nets must already exist. No footprints are imported.
  Placement only: no routing, board resizing, library changes or saving.
  Target Altium 26; NOT runtime-tested. Use an unrouted test board/copy.
  Pad roles are inferred from the schematic's existing connectivity; this
  does not independently prove transistor pin mapping or LED polarity.
  Uses pad-centre gaps (not copper-edge clearances): R1-Q1 200 mil,
  Q1-D1 400 mil vertical, D1-R2 200 mil. Bounds and overlap checks are
  conservative footprint rectangles, not a replacement for courtyard DRC,
  keepout/cutout checks or engineering placement review.
  https://www.altium.com/documentation/altium-dxp-developer/pcb-api-design-objects-interfaces-reference
}


Const
    BaseResRef = 'R1';
    LEDResRef = 'R2';
    TransistorRef = 'Q1';
    LEDRef = 'D1';
Var
    LPBoard : IPCB_Board;
    LPParts : Array[0..3] Of IPCB_Component;
    LPOldX, LPOldY : Array[0..3] Of Integer;
    LPOldAngle : Array[0..3] Of Double;

{ Progress reporting uses Messages panel; does not clear existing messages.
  Source reviewed only; not runtime-tested in Altium 26.
  Panel repaint may be delayed during busy operations. }
Var
    PLCLastStep : String;

Procedure PLCLog(Text : String);
Var
    WS : IWorkspace;
    MM : IMessagesManager;
Begin
    PLCLastStep := Text;
    { Reporting failures must not interrupt an editing transaction. }
    Try
        WS := GetWorkspace;
        If WS = Nil Then Exit;
        MM := WS.DM_MessagesManager;
        If MM = Nil Then Exit;
        MM.BeginUpdate;
        Try
            MM.AddMessage('Script', FormatDateTime('hh:nn:ss', Now) + ' ' + Text,
                          'Place_LED_PCB.pas', '', '', '', 3, False);
        Finally
            MM.EndUpdate;
        End;
        WS.DM_ShowMessageView;
    Except
        { Continue original operation if logging is unavailable. }
    End;
End;

Procedure PLCDialog(Text : String);
Begin
    PLCLog(Text);
    ShowMessage(Text);
End;

Procedure LPRequire(OK : Boolean; Msg : String);
Begin
    If Not OK Then
    Begin
        Raise(Msg);
    End;
End;

Function LPFind(Ref : String) : IPCB_Component;
Var It : IPCB_BoardIterator; C : IPCB_Component; N : Integer;
Begin
    PLCLog('Looking up component: ' + Ref + '');
    Result := Nil; N := 0;
    It := LPBoard.BoardIterator_Create;
    Try
        It.AddFilter_ObjectSet(MkSet(eComponentObject));
        It.AddFilter_LayerSet(AllLayers);
        It.AddFilter_Method(eProcessAll);
        C := It.FirstPCBObject;
        While C <> Nil Do
        Begin
            If UpperCase(C.Name.Text) = UpperCase(Ref) Then
            Begin Result := C; N := N + 1; End;
            C := It.NextPCBObject;
        End;
    Finally LPBoard.BoardIterator_Destroy(It); End;
    LPRequire(N = 1, 'Expected one ' + Ref + '. Transfer/annotate the schematic first.');
End;

Function LPNet(P : IPCB_Pad) : String;
Begin
    Result := '';
    If P.Net <> Nil Then Result := UpperCase(P.Net.Name);
End;

Procedure LPShared(A, B : IPCB_Component; Var PA, PB : IPCB_Pad);
Var IA, IB : IPCB_GroupIterator; P, Q : IPCB_Pad; N : Integer;
Begin
    PLCLog('Finding shared net between ' + A.Name.Text + ' and ' + B.Name.Text + '');
    PA := Nil; PB := Nil; N := 0;
    IA := A.GroupIterator_Create;
    Try
        IA.AddFilter_ObjectSet(MkSet(ePadObject));
        P := IA.FirstPCBObject;
        While P <> Nil Do
        Begin
            IB := B.GroupIterator_Create;
            Try
                IB.AddFilter_ObjectSet(MkSet(ePadObject));
                Q := IB.FirstPCBObject;
                While Q <> Nil Do
                Begin
                    If (LPNet(P) <> '') And (LPNet(P) = LPNet(Q)) Then
                    Begin PA := P; PB := Q; N := N + 1; End;
                    Q := IB.NextPCBObject;
                End;
            Finally B.GroupIterator_Destroy(IB); End;
            P := IA.NextPCBObject;
        End;
    Finally A.GroupIterator_Destroy(IA); End;
    LPRequire(N = 1, 'Expected one connected pad pair between ' +
        A.Name.Text + ' and ' + B.Name.Text + '. Check PCB pad nets.');
End;

Function LPOther(C : IPCB_Component; P : IPCB_Pad) : IPCB_Pad;
Var It : IPCB_GroupIterator; Q : IPCB_Pad; N : Integer;
Begin
    PLCLog('Looking up component: ' + Ref + '');
    Result := Nil; N := 0;
    It := C.GroupIterator_Create;
    Try
        It.AddFilter_ObjectSet(MkSet(ePadObject));
        Q := It.FirstPCBObject;
        While Q <> Nil Do
        Begin
            N := N + 1;
            If Q.I_ObjectAddress <> P.I_ObjectAddress Then Result := Q;
            Q := It.NextPCBObject;
        End;
    Finally C.GroupIterator_Destroy(It); End;
    LPRequire((N = 2) And (Result <> Nil), C.Name.Text + ': expected two pads.');
End;

Function LPAngle(DX, DY : Double) : Double;
Begin
    LPRequire((DX <> 0) Or (DY <> 0), 'Coincident pads cannot define orientation.');
    If DX = 0 Then
    Begin
        If DY > 0 Then Result := 90 Else Result := 270;
    End
    Else
    Begin
        Result := ArcTan(DY / DX) * 180 / 3.141592653589793;
        If DX < 0 Then Result := Result + 180;
        If Result < 0 Then Result := Result + 360;
    End;
End;

Procedure LPOrient(C : IPCB_Component; P, Other : IPCB_Pad; Angle : Double);
Var R : Double;
Begin
    PLCLog('Orienting ' + C.Name.Text + ' from actual pad geometry');
    R := C.Rotation + Angle - LPAngle(Other.X-P.X, Other.Y-P.Y);
    While R < 0 Do R := R + 360;
    While R >= 360 Do R := R - 360;
    C.Rotation := R;
End;

Procedure LPAnchor(C : IPCB_Component; P : IPCB_Pad; X, Y : Integer);
Begin
    PLCLog('Moving ' + C.Name.Text + ' to pad anchor ' + IntToStr(X) + ',' + IntToStr(Y));
    C.MoveByXY(X-P.X, Y-P.Y);
End;

Procedure ArrangeLEDComponentsImpl;
Var
    Bounds, ABox, BBox : TCoordRect;
    RB, RBOuter, QB, QC, DK, DA, RL, RLOuter : IPCB_Pad;
    I, J, Begun : Integer;
Begin
    If PCBServer = Nil Then
    Begin
        PLCLog('STOP: PCBServer unavailable.');
        Exit;
    End;
    LPBoard := PCBServer.GetCurrentPCBBoard;
    If LPBoard = Nil Then
    Begin PLCDialog('Activate the 2 x 2 inch test PCB first.'); Exit; End;
    If LPBoard.IsLibrary Then Exit;
    Begun := 0;
    Try
        PLCLog('Checking 2 inch board outline');
        LPBoard.BoardOutline.Invalidate;
        LPBoard.BoardOutline.Rebuild;
        LPBoard.BoardOutline.Validate;
        Bounds := LPBoard.BoardOutline.BoundingRectangle;
        LPRequire((Abs(Bounds.Right-Bounds.Left-MilsToCoord(2000)) <= 1) And
                  (Abs(Bounds.Top-Bounds.Bottom-MilsToCoord(2000)) <= 1),
                  'Expected a 2 x 2 inch board. Run the resize script first.');
        LPParts[0] := LPFind(TransistorRef);
        LPParts[1] := LPFind(BaseResRef);
        LPParts[2] := LPFind(LEDRef);
        LPParts[3] := LPFind(LEDResRef);
        For I := 0 To 3 Do
        Begin
            LPRequire(Not LPParts[I].PrimitiveLock, LPParts[I].Name.Text + ' is locked.');
            LPRequire(LPParts[I].Layer = eTopLayer, 'This test expects top-side components.');
            LPOldX[I] := LPParts[I].X;
            LPOldY[I] := LPParts[I].Y;
            LPOldAngle[I] := LPParts[I].Rotation;
        End;
        LPShared(LPParts[1], LPParts[0], RB, QB);
        LPShared(LPParts[0], LPParts[2], QC, DK);
        LPShared(LPParts[2], LPParts[3], DA, RL);
        LPRequire((QB.I_ObjectAddress <> QC.I_ObjectAddress) And
                  (DK.I_ObjectAddress <> DA.I_ObjectAddress) And
                  (LPNet(QB) <> LPNet(QC)) And (LPNet(QC) <> LPNet(DA)),
                  'Circuit nets are shorted or ambiguous.');
        RBOuter := LPOther(LPParts[1], RB);
        RLOuter := LPOther(LPParts[3], RL);
        LPOther(LPParts[2], DK);

        PCBServer.PreProcess;
        Try
            For I := 0 To 3 Do
            Begin
                PCBServer.SendMessageToRobots(LPParts[I].I_ObjectAddress,
                    c_Broadcast, PCBM_BeginModify, c_NoEventData);
                Begun := Begun + 1;
            End;
            Try
                { Make the collector lie right of the base, irrespective
                  of initial footprint rotation. Anchor the BASE pad. }
                LPOrient(LPParts[0], QB, QC, 0);
                LPAnchor(LPParts[0], QB,
                    Bounds.Left+MilsToCoord(1100), Bounds.Bottom+MilsToCoord(650));
                { R1's base-connected pad faces Q1; body extends left. }
                LPOrient(LPParts[1], RB, RBOuter, 180);
                LPAnchor(LPParts[1], RB, QB.X-MilsToCoord(200), QB.Y);
                { LED cathode below anode, above collector. }
                LPOrient(LPParts[2], DK, DA, 90);
                LPAnchor(LPParts[2], DK, QC.X, QC.Y+MilsToCoord(400));
                { R2's LED-connected pad faces the LED, body extends up. }
                LPOrient(LPParts[3], RL, RLOuter, 90);
                LPAnchor(LPParts[3], RL, DA.X, DA.Y+MilsToCoord(200));

                For I := 0 To 3 Do
                Begin
                    PLCLog('Checking component bounds and overlap');
                    ABox := LPParts[I].BoundingRectangleNoNameComment;
                    LPRequire((ABox.Left >= Bounds.Left+MilsToCoord(50)) And
                              (ABox.Right <= Bounds.Right-MilsToCoord(50)) And
                              (ABox.Bottom >= Bounds.Bottom+MilsToCoord(50)) And
                              (ABox.Top <= Bounds.Top-MilsToCoord(50)),
                              LPParts[I].Name.Text + ' does not fit with the test edge margin.');
                    For J := I+1 To 3 Do
                    Begin
                        BBox := LPParts[J].BoundingRectangleNoNameComment;
                        LPRequire((ABox.Right < BBox.Left) Or (BBox.Right < ABox.Left) Or
                                  (ABox.Top < BBox.Bottom) Or (BBox.Top < ABox.Bottom),
                                  'Footprint rectangles overlap. Adjust spacing for these footprints.');
                    End;
                End;
            Except
        PLCLog('ERROR: ' + ExceptionMessage + '; previous step: ' + PLCLastStep);
                PLCLog('Placement failed; attempting position and rotation restoration');
                { Restore positions/rotations if placement or checks fail. }
                For I := 0 To 3 Do
                Begin
                    LPParts[I].Rotation := LPOldAngle[I];
                    LPParts[I].MoveToXY(LPOldX[I], LPOldY[I]);
                End;
                Raise;
            End;
        Finally
            For I := 0 To Begun-1 Do
                PCBServer.SendMessageToRobots(LPParts[I].I_ObjectAddress,
                    c_Broadcast, PCBM_EndModify, c_NoEventData);
            PCBServer.PostProcess;
            LPBoard.ViewManager_FullUpdate;
        End;
        PLCDialog('Four components arranged. Base resistor pad is 200 mil from ' +
            'the base pad. Inspect placement and run DRC. No routing or saving performed.');
    Except
        PLCLog('ERROR: ' + ExceptionMessage + '; previous step: ' + PLCLastStep);
        PLCDialog('Placement stopped: ' + ExceptionMessage +
            '. Inspect the PCB; any attempted placement restoration also needs verification.');
    End;
End;

Procedure ArrangeLEDComponents;
Begin
    PLCLog('START: ArrangeLEDComponents');
    Try
        ArrangeLEDComponentsImpl;
        PLCLog('END: ArrangeLEDComponents returned. Review prior messages for warnings or errors.');
    Except
        PLCLog('UNHANDLED ERROR: ' + ExceptionMessage + '; previous step: ' + PLCLastStep);
        Raise;
    End;
End;
