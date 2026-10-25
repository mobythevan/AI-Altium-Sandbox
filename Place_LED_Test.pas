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
Const
    MPWorkspaceName = 'Motive Power';
    MPResistorID = 'CMP-009-00075-3';
    MPTransistorID = 'CMP-039-000021-1';
    MPLEDID = 'CMP-007-00008-2';
    MPVaultKind = 4; { TLibIdentifierKind: VaultName }

{ Progress reporting uses Messages panel; does not clear existing messages.
  Source reviewed only; not runtime-tested in Altium 26.
  Panel repaint may be delayed during busy operations. }
Var
    PLDLastStep : String;

Procedure PLDLog(Text : String);
Var
    WS : IWorkspace;
    MM : IMessagesManager;
Begin
    PLDLastStep := Text;
    { Reporting failures must not interrupt an editing transaction. }
    Try
        WS := GetWorkspace;
        If WS = Nil Then Exit;
        MM := WS.DM_MessagesManager;
        If MM = Nil Then Exit;
        MM.BeginUpdate;
        Try
            MM.AddMessage('Script', FormatDateTime('hh:nn:ss', Now) + ' ' + Text,
                          'Place_LED_Test.pas', '', '', '', 3, False);
        Finally
            MM.EndUpdate;
        End;
        WS.DM_ShowMessageView;
    Except
        { Continue original operation if logging is unavailable. }
    End;
End;

Procedure PLDDialog(Text : String);
Begin
    PLDLog(Text);
    ShowMessage(Text);
End;

Function PLDLoadManaged(Doc : ISch_Document; RequestedID, Ref : String;
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
        PLDLog('Loading ' + Ref + ': ' + RequestedID + ' from ' + MPWorkspaceName);
        C := SchServer.LoadComponent(MPVaultKind, MPWorkspaceName, RequestedID);
        If C = Nil Then Raise('Managed item did not resolve: ' + RequestedID);
        LoadedID := C.DesignItemId;
        VG := C.VaultGUID;
        IG := C.ItemGUID;
        RG := C.RevisionGUID;
        PLDLog(Ref + ' loaded ID=' + LoadedID + '; VaultGUID=' + VG +
            '; ItemGUID=' + IG + '; RevisionGUID=' + RG);
        If UpperCase(LoadedID) <> UpperCase(RequestedID) Then
            Raise('Loaded ID differs from requested ID for ' + Ref);
        If (VG = '') Or (IG = '') Or (RG = '') Then
            Raise('Incomplete managed link for ' + Ref + '. Nothing added for this part.');

        PLDLog('Positioning and adding ' + Ref);
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
        PLDLog(Ref + ' added with managed identifiers retained.');
    Except
        PLDLog('Load/place failed for ' + Ref + ': ' + ExceptionMessage);
        If Not Attached Then
        Begin
            If C <> Nil Then
            Begin
                Try
                    SchServer.DestroySchObject(C);
                Except
                    PLDLog('Cleanup of unattached ' + Ref + ' failed.');
                End;
            End;
        End;
        Raise;
    End;
End;

Procedure PlaceLEDTestImpl;
Var
    SchDoc : ISch_Document;
    It : ISch_Iterator;
    Existing : ISch_BasicContainer;
    R1, R2, Q1, D1 : ISch_Component;
Begin
    If SchServer = Nil Then
    Begin
        PLDLog('STOP: SchServer unavailable.');
        Exit;
    End;
    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then
    Begin
        PLDDialog('Open and activate a blank test schematic first.');
        Exit;
    End;
    PLDLog('Checking blank schematic');
    It := SchDoc.SchIterator_Create;
    If It = Nil Then Raise('Could not create schematic iterator.');
    Try
        It.AddFilter_ObjectSet(MkSet(eSchComponent, eWire, eNetLabel,
            ePowerObject, ePort, eSheetSymbol, eBus, eJunction));
        Existing := It.FirstSchObject;
        If Existing <> Nil Then Raise('Use a NEW BLANK test schematic.');
    Finally
        SchDoc.SchIterator_Destroy(It);
    End;
    R1 := PLDLoadManaged(SchDoc, MPResistorID, 'R1', 1000, 1500);
    R2 := PLDLoadManaged(SchDoc, MPResistorID, 'R2', 2000, 1500);
    Q1 := PLDLoadManaged(SchDoc, MPTransistorID, 'Q1', 1000, 750);
    D1 := PLDLoadManaged(SchDoc, MPLEDID, 'D1', 2000, 750);
    PLDDialog('Four managed parts added. R1 and R2 use the requested 1k resistor. ' +
        'No wiring or saving performed. Inspect models and managed links.');

    PLDLog('Refreshing schematic');
    SchDoc.GraphicallyInvalidate;
End;

Procedure PlaceLEDTest;
Begin
    PLDLog('START: PlaceLEDTest');
    Try
        PlaceLEDTestImpl;
        PLDLog('END: PlaceLEDTest returned. Review prior messages for warnings or errors.');
    Except
        PLDLog('UNHANDLED ERROR: ' + ExceptionMessage + '; previous step: ' + PLDLastStep);
        ShowMessage('Placement stopped: ' + ExceptionMessage +
            '. Inspect the sheet; partial parts may remain. No file saved.');
    End;
End;
