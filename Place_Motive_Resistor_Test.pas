{ Managed resistor placement experiment for Altium Designer 26.
  Run PlaceMotiveResistorTest on a NEW BLANK schematic.
  Uses the existing signed-in Motive Power Workspace; no URL/password.
  Requests CMP-009-00075-3 exactly as supplied; no guessed revision suffix.
  Places ONE resistor at (1000,1000) mils, preserving library parameters/models.
  Does not save, wire, edit the Workspace, or use an IntLib.
  Requires first-run testing in Altium 26; not runtime-verified here.

  Loader approach independently described in:
  https://github.com/salitronic/eda-agent/blob/main/docs/RELEASE_VERIFICATION.md
  Altium documents VaultName as TLibIdentifierKind ordinal 4:
  https://www.altium.com/documentation/altium-dxp-developer/system-api-constants-and-types
  Stop after any error and inspect the test sheet before retrying.
  Syntax-check errors occur before execution and cannot be logged.
}
Const
    MPWorkspace = 'Motive Power';
    MPItemID = 'CMP-009-00075-3';
    MPVaultNameKind = 4;
Var
    MPStage : String;

Procedure MPLog(Text : String);
Var
    WS : IWorkspace;
    MM : IMessagesManager;
Begin
    { Logging failures do not interrupt schematic edits. }
    Try
        WS := GetWorkspace;
        If WS = Nil Then Exit;
        MM := WS.DM_MessagesManager;
        If MM = Nil Then Exit;
        MM.BeginUpdate;
        Try
            MM.AddMessage('Managed component test',
                FormatDateTime('hh:nn:ss', Now) + ' ' + Text,
                'Place_Motive_Resistor_Test.pas', '', '', '', 3, False);
        Finally
            MM.EndUpdate;
        End;
        WS.DM_ShowMessageView;
    Except
        { Final/error dialogs remain available if panel reporting fails. }
    End;
End;

Procedure MPStep(Text : String);
Begin
    MPStage := Text;
    MPLog(Text);
End;

Procedure MPRequire(Condition : Boolean; Text : String);
Begin
    If Not Condition Then
    Begin
        Raise(Text);
    End;
End;

Procedure PlaceMotiveResistorTest;
Var
    Doc : ISch_Document;
    Part : ISch_Component;
    It : ISch_Iterator;
    Existing : ISch_BasicContainer;
    LoadedID, VaultID, ItemID, RevisionID, FailureText : String;
    Attached : Boolean;
Begin
    Part := Nil;
    Attached := False;
    MPStep('START: checking active blank schematic');
    Try
        MPRequire(SchServer <> Nil, 'Schematic server unavailable.');
        Doc := SchServer.GetCurrentSchDocument;
        MPRequire(Doc <> Nil, 'Activate a new blank SchDoc first.');
        It := Doc.SchIterator_Create;
        MPRequire(It <> Nil, 'Could not create schematic iterator.');
        Try
            It.AddFilter_ObjectSet(MkSet(eSchComponent, eWire, eNetLabel,
                ePowerObject, ePort, eSheetSymbol, eBus, eJunction));
            Existing := It.FirstSchObject;
            MPRequire(Existing = Nil,
                'Use a blank test sheet. Existing circuit objects found.');
        Finally
            Doc.SchIterator_Destroy(It);
        End;

        MPStep('Loading ' + MPItemID + ' from Workspace: ' + MPWorkspace);
        { Uses Altium session authentication. No library-name substitution
          into the file-based PlaceLibraryComponent method is attempted. }
        Part := SchServer.LoadComponent(MPVaultNameKind, MPWorkspace, MPItemID);
        MPRequire(Part <> Nil,
            'LoadComponent returned Nil. The item did not resolve with this Workspace name and ID.');

        MPStep('Reading loaded component identity and managed link');
        LoadedID := Part.DesignItemId;
        VaultID := Part.VaultGUID;
        ItemID := Part.ItemGUID;
        RevisionID := Part.RevisionGUID;
        MPLog('Loaded Design Item ID: ' + LoadedID);
        MPLog('VaultGUID: ' + VaultID);
        MPLog('ItemGUID: ' + ItemID);
        MPLog('RevisionGUID: ' + RevisionID);
        MPRequire(UpperCase(LoadedID) = UpperCase(MPItemID),
            'Loaded Design Item ID differs from the requested ID. Nothing added.');
        MPRequire((VaultID <> '') And (ItemID <> '') And (RevisionID <> ''),
            'Loaded component lacks a complete managed link. Nothing added.');

        MPStep('Beginning schematic edit transaction');
        SchServer.ProcessControl.PreProcess(Doc, '');
        Try
            MPStep('Positioning loaded resistor at X=1000, Y=1000 mil');
            Part.MoveToXY(MilsToCoord(1000), MilsToCoord(1000));
            { Keep the library orientation, designator template, values,
              symbol and footprint associations supplied by the loader. }
            MPStep('Adding resistor to schematic');
            Doc.AddSchObject(Part);
            Attached := True;
            MPStep('Registering resistor for schematic editing');
            SchServer.RobotManager.SendMessage(Doc.I_ObjectAddress,
                c_BroadCast, SCHM_PrimitiveRegistration, Part.I_ObjectAddress);
        Finally
            SchServer.ProcessControl.PostProcess(Doc, '');
            Doc.GraphicallyInvalidate;
        End;

        MPStep('Checking managed identifiers after placement');
        MPRequire((Part.VaultGUID = VaultID) And (Part.ItemGUID = ItemID) And
                  (Part.RevisionGUID = RevisionID),
                  'Managed identifiers changed during placement. Inspect the sheet.');
        MPLog('COMPLETE: resistor added; managed identifiers retained in memory. No file saved.');
        ShowMessage('One managed resistor added: ' + LoadedID + #13#10 +
            'Inspect its Properties, symbol, and footprint link.' + #13#10 +
            'No file saved. Save/reopen verification has not been performed.');
    Except
        FailureText := 'Stopped at: ' + MPStage + #13#10 + ExceptionMessage;
        MPLog('ERROR: ' + FailureText);
        { Never destroy an object after it has been attached to the sheet. }
        If Not Attached Then
        Begin
            If Part <> Nil Then
            Begin
                Try
                    SchServer.DestroySchObject(Part);
                Except
                    MPLog('WARNING: cleanup of the unattached component failed.');
                End;
            End;
        End;
        ShowMessage(FailureText + #13#10 +
            'Inspect the test sheet before retrying. No file saved.');
    End;
End;
