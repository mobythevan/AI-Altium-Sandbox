{ Managed LED circuit test for Altium Designer 26.
  Uses the signed-in Motive Power Workspace; no IntLib or URL required.
  R1/R2: CMP-009-00075-3 (1k, 0402, 5%, 63mW, per supplied catalog screenshot)
  Q1: CMP-039-000021-1; D1: CMP-007-00008-2.
  Library values, comments, models and managed links are retained.
  These are the requested test parts; current/power suitability is not calculated.
  Use a NEW BLANK SchDoc. No automatic save or Workspace changes.
  The one-resistor loader was tested by Bryan; these four-part scripts have
  NOT yet been runtime-tested. Partial parts/wires may remain on error.
  Debug output uses Messages panel; final/error dialogs are also provided.
}
{ Run BuildWiredLEDTest.
  VCC and GND are power ports; CTRL remains a net label.
  Intended circuit assumes an NPN transistor: CTRL -> R1 -> base;
  VCC -> R2 -> D1 anode; D1 cathode -> collector; emitter -> GND.
  Semantic pin names are required, or VERIFIED numeric overrides below.
  Pin iterators filter the current part and display mode.
  All raw pins are logged before checks to diagnose unexpected counts.
  Connected pin endpoints include pin length/orientation before alignment/wiring.
  Endpoint correction is based on observed body-root coordinates; verify in Altium.
  Unexpected pin identities/orientations or failed alignment stop BEFORE wiring.
}
Const
    MPWorkspaceName = 'Motive Power';
    MPResistorID = 'CMP-009-00075-3';
    MPTransistorID = 'CMP-039-000021-1';
    MPLEDID = 'CMP-007-00008-2';
    MPVaultKind = 4; { TLibIdentifierKind: VaultName }
    BasePinOverride = '';
    CollectorPinOverride = '';
    EmitterPinOverride = '';
    AnodePinOverride = '';
    CathodePinOverride = '';
Var
    WTDoc : ISch_Document;
    WTCompleted : Boolean;

{ Progress reporting uses Messages panel; does not clear existing messages.
  Source reviewed only; not runtime-tested in Altium 26.
  Panel repaint may be delayed during busy operations. }
Var
    WLDLastStep : String;

Procedure WLDLog(Text : String);
Var
    WS : IWorkspace;
    MM : IMessagesManager;
Begin
    WLDLastStep := Text;
    { Reporting failures must not interrupt an editing transaction. }
    Try
        WS := GetWorkspace;
        If WS = Nil Then Exit;
        MM := WS.DM_MessagesManager;
        If MM = Nil Then Exit;
        MM.BeginUpdate;
        Try
            MM.AddMessage('Script', FormatDateTime('hh:nn:ss', Now) + ' ' + Text,
                          'Wire_LED_Test.pas', '', '', '', 3, False);
        Finally
            MM.EndUpdate;
        End;
        WS.DM_ShowMessageView;
    Except
        { Continue original operation if logging is unavailable. }
    End;
End;

Procedure WLDDialog(Text : String);
Begin
    WLDLog(Text);
    ShowMessage(Text);
End;

Procedure WTRequire(Condition : Boolean; MessageText : String);
Begin
    If Not Condition Then Raise(MessageText);
End;

Function WLDLoadManaged(Doc : ISch_Document; RequestedID, Ref : String;
                            XMil, YMil : Integer) : ISch_Component;
Var
    C : ISch_Component;
    Attached : Boolean;
    LoadedID, VG, IG, RG : String;
Begin
    Result := Nil;
    C := Nil;
    Attached := False;
    Try
        WLDLog('Loading ' + Ref + ': ' + RequestedID + ' from ' + MPWorkspaceName);
        C := SchServer.LoadComponent(MPVaultKind, MPWorkspaceName, RequestedID);
        If C = Nil Then Raise('Managed item did not resolve: ' + RequestedID);
        LoadedID := C.DesignItemId;
        VG := C.VaultGUID;
        IG := C.ItemGUID;
        RG := C.RevisionGUID;
        WLDLog(Ref + ' loaded ID=' + LoadedID + '; VaultGUID=' + VG +
            '; ItemGUID=' + IG + '; RevisionGUID=' + RG);
        If UpperCase(LoadedID) <> UpperCase(RequestedID) Then
            Raise('Loaded ID differs from requested ID for ' + Ref);
        If (VG = '') Or (IG = '') Or (RG = '') Then
            Raise('Incomplete managed link for ' + Ref + '. Nothing added for this part.');

        WLDLog('Positioning and adding ' + Ref);
        SchServer.ProcessControl.PreProcess(Doc, '');
        Try
            C.MoveToXY(MilsToCoord(XMil), MilsToCoord(YMil));
            C.Designator.Text := Ref;
            { Retain source orientation, comments, values, models and managed links. }
            Doc.AddSchObject(C);
            Attached := True;
            SchServer.RobotManager.SendMessage(Doc.I_ObjectAddress,
                c_BroadCast, SCHM_PrimitiveRegistration, C.I_ObjectAddress);
        Finally
            SchServer.ProcessControl.PostProcess(Doc, '');
            Doc.GraphicallyInvalidate;
        End;
        If (C.VaultGUID <> VG) Or (C.ItemGUID <> IG) Or (C.RevisionGUID <> RG) Then
            Raise('Managed link changed after adding ' + Ref + '. Inspect the sheet.');
        Result := C;
        WLDLog(Ref + ' added with managed identifiers retained.');
    Except
        WLDLog('Load/place failed for ' + Ref + ': ' + ExceptionMessage);
        If Not Attached Then
        Begin
            If C <> Nil Then
            Begin
                Try
                    SchServer.DestroySchObject(C);
                Except
                    WLDLog('Cleanup of unattached ' + Ref + ' failed.');
                End;
            End;
        End;
        Raise;
    End;
End;

Function WTPlace(RequestedID, Ref : String;
                 XMil, YMil : Integer) : ISch_Component;
Begin
    Result := WLDLoadManaged(WTDoc, RequestedID, Ref, XMil, YMil);
End;

{ Endpoint correction for the observed managed symbols: Location is the
  body-side pin root; the electrical end is PinLength along Orientation.
  Uses placed pin orientation (0=right, 1=up, 2=left, 3=down).
  No additional component rotation is applied: placed pin coordinates and
  orientation already describe the sheet. Verify endpoints in Altium. }
Function WTPinX(P : ISch_Pin) : Integer;
Begin
    Result := P.Location.X;
    Case P.Orientation Of
        0: Result := Result + P.PinLength;
        1: Result := Result;
        2: Result := Result - P.PinLength;
        3: Result := Result;
    Else
        Raise('Unsupported pin orientation: ' + IntToStr(P.Orientation));
    End;
End;

Function WTPinY(P : ISch_Pin) : Integer;
Begin
    Result := P.Location.Y;
    Case P.Orientation Of
        0: Result := Result;
        1: Result := Result + P.PinLength;
        2: Result := Result;
        3: Result := Result - P.PinLength;
    Else
        Raise('Unsupported pin orientation: ' + IntToStr(P.Orientation));
    End;
End;

Procedure WTDumpPins(C : ISch_Component);
Var
    It : ISch_Iterator;
    P : ISch_Pin;
    N : Integer;
Begin
    WLDLog('Inspecting all pin representations on ' + C.Designator.Text);
    It := C.SchIterator_Create;
    WTRequire(It <> Nil, 'Cannot create pin diagnostic iterator.');
    N := 0;
    Try
        It.AddFilter_ObjectSet(MkSet(ePin));
        P := It.FirstSchObject;
        While P <> Nil Do
        Begin
            N := N + 1;
            WLDLog(C.Designator.Text + ' raw pin ' + IntToStr(N) +
                ': number=[' + P.Designator + '] name=[' + P.Name +
                '] root X=' + IntToStr(P.Location.X) + ' Y=' + IntToStr(P.Location.Y) +
                '; length=' + IntToStr(P.PinLength) + '; orientation=' + IntToStr(P.Orientation) +
                '; wire end X=' + IntToStr(WTPinX(P)) + ' Y=' + IntToStr(WTPinY(P)));
            P := It.NextSchObject;
        End;
    Finally
        C.SchIterator_Destroy(It);
    End;
    WLDLog(C.Designator.Text + ' total raw pin count=' + IntToStr(N));
End;

Function WTRole(C : ISch_Component; ShortRole, LongRole,
                OverrideID : String) : ISch_Pin;
Var
    It : ISch_Iterator;
    P : ISch_Pin;
    N, D, Inventory : String;
    Match : Boolean;
    Hits : Integer;
Begin
    WLDLog('Resolving pin role ' + LongRole + ' on ' + C.Designator.Text + '');
    Result := Nil;
    Hits := 0;
    Inventory := '';
    It := C.SchIterator_Create;
    Try
        It.AddFilter_ObjectSet(MkSet(ePin));
        It.AddFilter_CurrentPartPrimitives;
        It.AddFilter_CurrentDisplayModePrimitives;
        P := It.FirstSchObject;
        While P <> Nil Do
        Begin
            N := UpperCase(Trim(P.Name));
            D := UpperCase(Trim(P.Designator));
            Inventory := Inventory + '[' + D + ':' + N + '] ';
            If OverrideID <> '' Then
                Match := D = UpperCase(OverrideID)
            Else
                Match := (N = ShortRole) Or (N = LongRole) Or
                         (D = ShortRole) Or (D = LongRole);
            If Match Then
            Begin
                Result := P;
                Hits := Hits + 1;
            End;
            P := It.NextSchObject;
        End;
    Finally
        C.SchIterator_Destroy(It);
    End;
    WLDLog(C.Designator.Text + ' pin inventory: ' + Inventory);
    WTRequire(Hits = 1, C.Designator.Text + ': cannot uniquely identify ' +
        LongRole + '. Pins are ' + Inventory +
        '. Set the verified pin override at the top of the script.');
End;

Procedure WTResistorPins(C : ISch_Component; Var LeftPin, RightPin : ISch_Pin);
Var
    It : ISch_Iterator;
    P, Temp : ISch_Pin;
    Count : Integer;
    Inventory : String;
Begin
    WLDLog('Checking resistor pins on ' + C.Designator.Text + '');
    LeftPin := Nil;
    RightPin := Nil;
    Count := 0;
    Inventory := '';
    It := C.SchIterator_Create;
    Try
        It.AddFilter_ObjectSet(MkSet(ePin));
        It.AddFilter_CurrentPartPrimitives;
        It.AddFilter_CurrentDisplayModePrimitives;
        P := It.FirstSchObject;
        While P <> Nil Do
        Begin
            Count := Count + 1;
            Inventory := Inventory + '[' + P.Designator + ':' + P.Name + '] ';
            If Count = 1 Then LeftPin := P;
            If Count = 2 Then RightPin := P;
            P := It.NextSchObject;
        End;
    Finally
        C.SchIterator_Destroy(It);
    End;
    WLDLog(C.Designator.Text + ' active pin count=' + IntToStr(Count) + '; pins=' + Inventory);
    WTRequire(Count = 2, C.Designator.Text + ': expected two active pins; found ' +
        IntToStr(Count) + '. Pins: ' + Inventory + '. See Messages for raw pin inventory.');
    If WTPinX(LeftPin) > WTPinX(RightPin) Then
    Begin
        Temp := LeftPin;
        LeftPin := RightPin;
        RightPin := Temp;
    End;
    WTRequire((WTPinX(LeftPin) < WTPinX(RightPin)) And
              (WTPinY(LeftPin) = WTPinY(RightPin)),
        C.Designator.Text + ': expected a horizontal resistor symbol.');
End;

Procedure WTAnchorPin(Part : ISch_Component; Pin : ISch_Pin;
                      TargetX, TargetY : Integer);
Var
    NewX, NewY : Integer;
Begin
    WLDLog('Aligning ' + Part.Designator.Text + ' pin ' + Pin.Designator +
        ': X=' + IntToStr(WTPinX(Pin)) + ', Y=' + IntToStr(WTPinY(Pin)) +
        ' -> X=' + IntToStr(TargetX) + ', Y=' + IntToStr(TargetY));
    NewX := Part.Location.X + TargetX - WTPinX(Pin);
    NewY := Part.Location.Y + TargetY - WTPinY(Pin);
    SchServer.ProcessControl.PreProcess(WTDoc, '');
    Try
        SchServer.RobotManager.SendMessage(Part.I_ObjectAddress,
            c_BroadCast, SCHM_BeginModify, c_NoEventData);
        Try
            Part.MoveToXY(NewX, NewY);
        Finally
            SchServer.RobotManager.SendMessage(Part.I_ObjectAddress,
                c_BroadCast, SCHM_EndModify, c_NoEventData);
        End;
    Finally
        SchServer.ProcessControl.PostProcess(WTDoc, '');
    End;
End;

Procedure WTWire(X1, Y1, X2, Y2 : Integer);
Var
    W : ISch_Wire;
Begin
    If (X1 = X2) And (Y1 = Y2) Then Exit;
    WTRequire((X1 = X2) Or (Y1 = Y2), 'Internal error: diagonal segment.');
    WLDLog('Creating wire: ' + IntToStr(X1) + ',' + IntToStr(Y1) + ' to ' + IntToStr(X2) + ',' + IntToStr(Y2) + '');
    W := SchServer.SchObjectFactory(eWire, eCreate_GlobalCopy);
    WTRequire(W <> Nil, 'Could not create wire.');
    W.Location := Point(X1, Y1);
    W.LineWidth := eSmall;
    W.InsertVertex(1);
    W.SetState_Vertex(1, Point(X1, Y1));
    W.InsertVertex(2);
    W.SetState_Vertex(2, Point(X2, Y2));
    WTDoc.RegisterSchObjectInContainer(W);
    SchServer.RobotManager.SendMessage(WTDoc.I_ObjectAddress,
        c_BroadCast, SCHM_PrimitiveRegistration, W.I_ObjectAddress);
End;

Procedure WTLabel(NetName : String; X, Y : Integer);
Var
    L : ISch_NetLabel;
Begin
    WLDLog('Adding net label: ' + NetName + '');
    L := SchServer.SchObjectFactory(eNetLabel, eCreate_GlobalCopy);
    WTRequire(L <> Nil, 'Could not create net label.');
    L.Text := NetName;
    L.Location := Point(X, Y);
    WTDoc.RegisterSchObjectInContainer(L);
    SchServer.RobotManager.SendMessage(WTDoc.I_ObjectAddress,
        c_BroadCast, SCHM_PrimitiveRegistration, L.I_ObjectAddress);
End;

Procedure WTPowerPort(NetName : String; X, Y : Integer;
                      GroundSymbol : Boolean);
Var
    P : ISch_PowerObject;
Begin
    WLDLog('Adding power port ' + NetName + ' at wire endpoint X=' +
        IntToStr(X) + ', Y=' + IntToStr(Y));
    P := SchServer.SchObjectFactory(ePowerObject, eCreate_Default);
    WTRequire(P <> Nil, 'Could not create power port ' + NetName);
    P.Text := NetName;
    P.ShowNetName := True;
    P.Location := Point(X, Y);
    If GroundSymbol Then
    Begin
        P.Style := ePowerGndPower;
        P.Orientation := eRotate270;
    End
    Else
    Begin
        P.Style := ePowerBar;
        P.Orientation := eRotate90;
    End;
    WTDoc.RegisterSchObjectInContainer(P);
    SchServer.RobotManager.SendMessage(WTDoc.I_ObjectAddress,
        c_BroadCast, SCHM_PrimitiveRegistration, P.I_ObjectAddress);
End;

Procedure BuildWiredLEDTestImpl;
Var
    RBase, RLED, Q, D : ISch_Component;
    BL, BR, RL, RR, B, C, E, A, K : ISch_Pin;
    It : ISch_Iterator;
    Existing : ISch_BasicContainer;
    Gap, BendX : Integer;
Begin
    If SchServer = Nil Then
    Begin
        WLDLog('STOP: SchServer unavailable.');
        Exit;
    End;
    WTDoc := SchServer.GetCurrentSchDocument;
    If WTDoc = Nil Then
    Begin
        WLDDialog('Activate a new blank schematic and run BuildWiredLEDTest.');
        Exit;
    End;
    Try
        WLDLog('Checking blank schematic');
        It := WTDoc.SchIterator_Create;
        WTRequire(It <> Nil, 'Could not create schematic iterator.');
        Try
            It.AddFilter_ObjectSet(MkSet(eSchComponent, eWire, eNetLabel,
                ePowerObject, ePort, eSheetSymbol, eBus, eJunction));
            Existing := It.FirstSchObject;
            WTRequire(Existing = Nil, 'Use a new blank test sheet. Existing circuit objects found.');
        Finally
            WTDoc.SchIterator_Destroy(It);
        End;

        RBase := WTPlace(MPResistorID, 'R1', 1600, 1200);
        RLED := WTPlace(MPResistorID, 'R2', 1300, 2400);
        D := WTPlace(MPLEDID, 'D1', 2400, 2400);
        Q := WTPlace(MPTransistorID, 'Q1', 3400, 1200);

        WTDumpPins(RBase);
        WTDumpPins(RLED);
        WTDumpPins(Q);
        WTDumpPins(D);
        WTResistorPins(RBase, BL, BR);
        WTResistorPins(RLED, RL, RR);
        B := WTRole(Q, 'B', 'BASE', BasePinOverride);
        C := WTRole(Q, 'C', 'COLLECTOR', CollectorPinOverride);
        E := WTRole(Q, 'E', 'EMITTER', EmitterPinOverride);
        A := WTRole(D, 'A', 'ANODE', AnodePinOverride);
        K := WTRole(D, 'K', 'CATHODE', CathodePinOverride);

        { Reject unexpected orientations before drawing any wires. }
        WTRequire((WTPinX(A) < WTPinX(K)) And
                  (WTPinY(A) = WTPinY(K)),
                  'Expected horizontal LED with anode left and cathode right.');
        WTRequire((WTPinX(B) < WTPinX(C)) And
                  (WTPinX(B) < WTPinX(E)) And
                  (WTPinY(E) < WTPinY(B)) And
                  (WTPinY(B) < WTPinY(C)),
                  'Unexpected NPN symbol geometry: expected base left, collector up, emitter down.');
        { Library insertion origins need not coincide with pin hotspots.
          Anchor actual connected pins, then re-read them before wiring. }
        WLDLog('Aligning component pin endpoints before wiring');
        Gap := MilsToCoord(400);
        WTAnchorPin(RBase, BR, WTPinX(B)-Gap, WTPinY(B));
        WTAnchorPin(D, K, WTPinX(C)-Gap, WTPinY(C)+2*Gap);
        A := WTRole(D, 'A', 'ANODE', AnodePinOverride);
        K := WTRole(D, 'K', 'CATHODE', CathodePinOverride);
        WTAnchorPin(RLED, RR, WTPinX(A)-Gap, WTPinY(A));
        WTResistorPins(RBase, BL, BR);
        WTResistorPins(RLED, RL, RR);
        WLDLog('Aligned R1 output Y=' + IntToStr(WTPinY(BR)) +
            '; Q1 base Y=' + IntToStr(WTPinY(B)));
        WLDLog('Aligned R2 output Y=' + IntToStr(WTPinY(RR)) +
            '; D1 anode Y=' + IntToStr(WTPinY(A)));
        WTRequire((WTPinX(RR) < WTPinX(A)) And
                  (WTPinX(K) < WTPinX(C)) And
                  (WTPinX(BR) < WTPinX(B)) And
                  (WTPinY(RL) = WTPinY(A)) And
                  (WTPinY(BR) = WTPinY(B)) And
                  (WTPinY(C) < WTPinY(K)),
                  'Pin alignment did not produce the required wire geometry. See alignment coordinates in Messages.');

        SchServer.ProcessControl.PreProcess(WTDoc, '');
        Try
            WLDLog('Pin geometry checks passed; starting wiring');
            Gap := MilsToCoord(400);
            { Input -> base resistor -> base. }
            WTWire(WTPinX(BL)-Gap, WTPinY(BL), WTPinX(BL), WTPinY(BL));
            WTLabel('CTRL', WTPinX(BL)-Gap, WTPinY(BL));
            WTWire(WTPinX(BR), WTPinY(BR), WTPinX(B), WTPinY(B));
            { VCC power port -> LED resistor -> anode. }
            WTWire(WTPinX(RL)-Gap, WTPinY(RL), WTPinX(RL), WTPinY(RL));
            WTPowerPort('VCC', WTPinX(RL)-Gap, WTPinY(RL), False);
            WTWire(WTPinX(RR), WTPinY(RR), WTPinX(A), WTPinY(A));
            { Cathode -> collector via an orthogonal corner above Q1. }
            BendX := WTPinX(C);
            WTWire(WTPinX(K), WTPinY(K), BendX, WTPinY(K));
            WTWire(BendX, WTPinY(K), WTPinX(C), WTPinY(C));
            { Emitter -> GND power port. }
            WTWire(WTPinX(E), WTPinY(E), WTPinX(E), WTPinY(E)-Gap);
            WTPowerPort('GND', WTPinX(E), WTPinY(E)-Gap, True);
        Finally
            SchServer.ProcessControl.PostProcess(WTDoc, '');
        End;
        WTDoc.GraphicallyInvalidate;
        WTCompleted := True;
        WLDDialog('Placement and wiring calls completed. Inspect pin endpoints and ' +
            'validate connectivity in Altium. R1/R2 retain the requested 1k library part; no file was saved.');
    Except
        WLDLog('ERROR: ' + ExceptionMessage + '; previous step: ' + WLDLastStep);
        WLDDialog('Wiring test stopped: ' + ExceptionMessage +
            ' Parts or partial wires may remain. Use a fresh sheet for a retry.');
        WTDoc.GraphicallyInvalidate;
    End;
End;

Procedure BuildWiredLEDTest;
Begin
    WTCompleted := False;
    WLDLog('START: BuildWiredLEDTest - VCC/GND power ports revision');
    Try
        BuildWiredLEDTestImpl;
        If WTCompleted Then
            WLDLog('COMPLETE: placement and wiring calls finished; inspect connectivity in Altium.')
        Else
            WLDLog('STOPPED: wiring test did not complete. See preceding messages.');
    Except
        WLDLog('UNHANDLED ERROR: ' + ExceptionMessage + '; previous step: ' + WLDLastStep);
        Raise;
    End;
End;
